"""
FastAPI Proxy Server for Moviebox API
Optimized based on moviebox-api tool analysis.
"""

from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware
import httpx
from typing import Optional
import json

app = FastAPI(title="Moviebox Proxy Server")

# Allow CORS for all origins (needed for Flutter app)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Primary Target (Most stable for Nuxt 3 and play API)
TARGET_BASE_URL = "https://h5.aoneroom.com"

# Persistent client with cookies
client = httpx.AsyncClient(
    base_url=TARGET_BASE_URL,
    headers={
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Referer": TARGET_BASE_URL,
        "Origin": TARGET_BASE_URL,
    },
    follow_redirects=True,
    timeout=30.0,
)


@app.on_event("startup")
async def startup():
    """Initialize cookies on startup"""
    try:
        # Fetch app info to establish session cookies
        await client.get("/wefeed-h5-bff/app/get-latest-app-pkgs?app_name=moviebox")
        print(f"✓ Moviebox session initialized on {TARGET_BASE_URL}")
    except Exception as e:
        print(f"⚠ Failed to init cookies: {e}")


@app.on_event("shutdown")
async def shutdown():
    await client.aclose()


@app.get("/")
async def root():
    return {"status": "ok", "message": "Moviebox Proxy Server", "target": TARGET_BASE_URL}


@app.get("/health")
async def health():
    return {"status": "healthy"}


@app.api_route("/wefeed-h5-bff/{path:path}", methods=["GET", "POST", "PUT", "DELETE"])
async def proxy_api(path: str, request: Request):
    """Proxy all /wefeed-h5-bff/* requests"""
    
    full_path = f"/wefeed-h5-bff/{path}"
    
    # Get query params
    query_string = str(request.url.query) if request.url.query else ""
    if query_string:
        full_path = f"{full_path}?{query_string}"
    
    # Get request body for POST/PUT
    body = None
    if request.method in ["POST", "PUT"]:
        body = await request.body()
    
    # Forward headers (filter out host-specific ones)
    headers = {}
    for key, value in request.headers.items():
        key_lower = key.lower()
        if key_lower in ["host", "content-length"]:
            continue
        
        # Translate Referer/Origin to target domain
        # Exclude original Referer/Origin; we will set them centrally
        if key_lower in ["referer", "origin"]:
            continue
            
        headers[key] = value

    # Set default Referer/Origin for all requests
    headers["Referer"] = TARGET_BASE_URL
    headers["Origin"] = TARGET_BASE_URL
    
    # Special handling for /play endpoint which requires specific Referer
    if "subject/play" in path:
        # Read detailPath from custom header (sent by Flutter app)
        detail_path = request.headers.get("x-detail-path")
        if detail_path:
            # Use /movies/{detailPath} format - required by API to return streams
            headers["Referer"] = f"{TARGET_BASE_URL}/movies/{detail_path}"
            print(f"Proxying play request with Referer: {headers['Referer']}")

    try:
        if request.method == "GET":
            response = await client.get(full_path, headers=headers)
        elif request.method == "POST":
            content_type = request.headers.get("content-type", "")
            if "application/json" in content_type:
                response = await client.post(full_path, content=body, headers=headers)
            else:
                response = await client.post(full_path, data=body, headers=headers)
        else:
            response = await client.request(request.method, full_path, content=body, headers=headers)
        
        filtered_headers = {}
        skip_headers = {"content-encoding", "content-length", "transfer-encoding"}
        for key, value in response.headers.items():
            if key.lower() not in skip_headers:
                filtered_headers[key] = value
        
        return Response(
            content=response.content,
            status_code=response.status_code,
            headers=filtered_headers,
            media_type=response.headers.get("content-type"),
        )
    
    except httpx.RequestError as e:
        return Response(
            content=json.dumps({"error": str(e)}),
            status_code=502,
            media_type="application/json",
        )


@app.api_route("/{path:path}", methods=["GET"])
async def proxy_html(path: str, request: Request):
    """Proxy HTML pages (for detail pages that need scraping)"""
    
    full_path = f"/{path}"
    query_string = str(request.url.query) if request.url.query else ""
    if query_string:
        full_path = f"{full_path}?{query_string}"
    
    # Forward headers from the request
    headers = {}
    for key, value in request.headers.items():
        key_lower = key.lower()
        if key_lower in ["host", "content-length"]:
            continue
        
        if key_lower in ["referer", "origin"]:
            headers[key] = TARGET_BASE_URL
        else:
            headers[key] = value

    try:
        response = await client.get(full_path, headers=headers)
        
        filtered_headers = {}
        skip_headers = {"content-encoding", "content-length", "transfer-encoding"}
        for key, value in response.headers.items():
            if key.lower() not in skip_headers:
                filtered_headers[key] = value
        
        return Response(
            content=response.content,
            status_code=response.status_code,
            headers=filtered_headers,
            media_type=response.headers.get("content-type"),
        )
    except httpx.RequestError as e:
        return Response(
            content=json.dumps({"error": str(e)}),
            status_code=502,
            media_type="application/json",
        )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)