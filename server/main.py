"""
FastAPI Proxy Server for Moviebox API
Runs on local network so Chromecast can access moviebox.ph through your Mac.
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

# Target API
MOVIEBOX_BASE_URL = "https://moviebox.ph"

# Persistent client with cookies
client = httpx.AsyncClient(
    base_url=MOVIEBOX_BASE_URL,
    headers={
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Referer": MOVIEBOX_BASE_URL,
        "Origin": MOVIEBOX_BASE_URL,
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
        print("✓ Moviebox session initialized")
    except Exception as e:
        print(f"⚠ Failed to init cookies: {e}")


@app.on_event("shutdown")
async def shutdown():
    await client.aclose()


@app.get("/")
async def root():
    return {"status": "ok", "message": "Moviebox Proxy Server", "target": MOVIEBOX_BASE_URL}


@app.get("/health")
async def health():
    return {"status": "healthy"}


@app.api_route("/wefeed-h5-bff/{path:path}", methods=["GET", "POST", "PUT", "DELETE"])
async def proxy_api(path: str, request: Request):
    """Proxy all /wefeed-h5-bff/* requests to moviebox.ph"""
    
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
        if key.lower() not in ["host", "content-length"]:
            headers[key] = value
    
    try:
        # Make the proxied request
        if request.method == "GET":
            response = await client.get(full_path, headers=headers)
        elif request.method == "POST":
            # Check if JSON
            content_type = request.headers.get("content-type", "")
            if "application/json" in content_type:
                response = await client.post(full_path, content=body, headers=headers)
            else:
                response = await client.post(full_path, data=body, headers=headers)
        elif request.method == "PUT":
            response = await client.put(full_path, content=body, headers=headers)
        elif request.method == "DELETE":
            response = await client.delete(full_path, headers=headers)
        else:
            response = await client.request(request.method, full_path, content=body, headers=headers)
        
        # Filter out headers that don't apply after decompression by httpx
        # httpx automatically decompresses gzip/deflate responses
        filtered_headers = {}
        skip_headers = {"content-encoding", "content-length", "transfer-encoding"}
        for key, value in response.headers.items():
            if key.lower() not in skip_headers:
                filtered_headers[key] = value
        
        # Return the response
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
    
    try:
        response = await client.get(full_path)
        
        # Filter out compression headers since httpx decompresses
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
    print("Starting Moviebox Proxy Server...")
    print("Access at: http://0.0.0.0:8000")
    print("Your Chromecast should connect to: http://192.168.1.7:8000")
    uvicorn.run(app, host="0.0.0.0", port=8000)
