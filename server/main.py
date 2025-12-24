"""
FastAPI Proxy Server for Moviebox API
Optimized based on moviebox-api tool analysis.

Supports:
- Home content browsing
- Search (suggestions and full search)
- Streaming (play endpoint)
- Downloading with quality variants
- Subtitles with language selection
"""

from fastapi import FastAPI, Request, Response, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, HttpUrl
import httpx
from typing import Optional, List
import json
import gzip

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


# ==================== Response Models ====================

class StreamFile(BaseModel):
    """Single stream file metadata"""
    id: str
    url: str
    format: str = "mp4"
    resolutions: int  # Note: API uses 'resolutions' not 'resolution'
    size: int
    duration: int = 0
    codecName: str = ""


class StreamResponse(BaseModel):
    """Streaming API response"""
    streams: List[StreamFile] = []
    dash: List[dict] = []
    hls: List[dict] = []
    freeNum: int = 0
    limited: bool = False
    hasResource: bool = False


class MediaFile(BaseModel):
    """Downloadable media file metadata"""
    id: str
    url: str
    resolution: int
    size: int


class CaptionFile(BaseModel):
    """Subtitle/caption file metadata"""
    id: str
    lan: str  # Language code (e.g., "en")
    lanName: str  # Language name (e.g., "English")
    url: str
    size: int
    delay: int = 0


class DownloadResponse(BaseModel):
    """Download API response with media files and subtitles"""
    downloads: List[MediaFile] = []
    captions: List[CaptionFile] = []
    limited: bool = False
    limitedCode: str = ""
    hasResource: bool = False


# ==================== HTTP Client ====================

# Persistent client with cookies
client = httpx.AsyncClient(
    base_url=TARGET_BASE_URL,
    headers={
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Referer": TARGET_BASE_URL,
        "Origin": TARGET_BASE_URL,
        "Accept": "application/json",
        "Accept-Language": "en-US,en;q=0.5",
        "Accept-Encoding": "identity",  # Request uncompressed content to avoid decompression issues
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


# ==================== Endpoints ====================

@app.get("/")
async def root():
    return {"status": "ok", "message": "Moviebox Proxy Server", "target": TARGET_BASE_URL}


@app.get("/health")
async def health():
    return {"status": "healthy"}


def get_referer_for_detail(detail_path: Optional[str]) -> str:
    """Generate proper Referer URL for API requests"""
    if detail_path:
        # Clean up the path
        if detail_path.startswith("detail/"):
            detail_path = detail_path[7:]
        return f"{TARGET_BASE_URL}/movies/{detail_path}"
    return TARGET_BASE_URL


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
        
        # Exclude original Referer/Origin; we will set them centrally
        if key_lower in ["referer", "origin"]:
            continue
            
        headers[key] = value

    # Set default Referer/Origin for all requests
    headers["Referer"] = TARGET_BASE_URL
    headers["Origin"] = TARGET_BASE_URL
    
    # Special handling for /play and /download endpoints which require specific Referer
    if "subject/play" in path or "subject/download" in path:
        # Read detailPath from custom header (sent by Flutter app)
        detail_path = request.headers.get("x-detail-path")
        if detail_path:
            headers["Referer"] = get_referer_for_detail(detail_path)
            print(f"Proxying {path} with Referer: {headers['Referer']}")
        else:
            print(f"⚠ Missing X-Detail-Path header for {path}")

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
        
        # Decompress gzip content if needed
        content = response.content
        content_encoding = response.headers.get("content-encoding", "").lower()
        if content_encoding == "gzip" and content[:2] == b'\x1f\x8b':
            try:
                content = gzip.decompress(content)
            except Exception as e:
                print(f"Failed to decompress gzip: {e}")
        
        # Prevent Cloudflare/Render from re-compressing the response
        filtered_headers["Content-Encoding"] = "identity"
        filtered_headers["Cache-Control"] = "no-transform"
        
        return Response(
            content=content,
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
        
        # Decompress gzip content if needed
        content = response.content
        content_encoding = response.headers.get("content-encoding", "").lower()
        if content_encoding == "gzip" and content[:2] == b'\x1f\x8b':
            try:
                content = gzip.decompress(content)
            except Exception as e:
                print(f"Failed to decompress gzip: {e}")
        
        # Prevent Cloudflare/Render from re-compressing the response
        filtered_headers["Content-Encoding"] = "identity"
        filtered_headers["Cache-Control"] = "no-transform"
        
        return Response(
            content=content,
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


# ==================== Convenience Endpoints ====================

@app.get("/api/stream")
async def get_stream(
    subject_id: str = Query(..., alias="subjectId"),
    season: int = Query(1, alias="se"),
    episode: int = Query(1, alias="ep"),
    detail_path: str = Query(None, alias="detailPath"),
    quality: str = Query("best", description="Quality: best, worst, 720, 1080"),
):
    """
    Convenience endpoint to get streaming URL directly.
    Returns the best matching stream URL.
    """
    params = {"subjectId": subject_id, "se": season, "ep": episode}
    headers = {
        "Referer": get_referer_for_detail(detail_path),
        "Origin": TARGET_BASE_URL,
    }
    
    try:
        response = await client.get("/wefeed-h5-bff/web/subject/play", params=params, headers=headers)
        data = response.json().get("data", response.json())
        
        streams = data.get("streams", [])
        if not streams:
            return {"error": "No streams available", "data": data}
        
        # Sort by resolution descending
        streams.sort(key=lambda x: x.get("resolutions", 0), reverse=True)
        
        if quality == "worst":
            selected = streams[-1]
        elif quality.isdigit():
            target_res = int(quality)
            selected = next((s for s in streams if s.get("resolutions") == target_res), streams[0])
        else:  # "best" or default
            selected = streams[0]
        
        return {
            "url": selected.get("url"),
            "resolution": selected.get("resolutions"),
            "format": selected.get("format"),
            "all_streams": streams,
        }
    except Exception as e:
        return {"error": str(e)}


@app.get("/api/download")
async def get_download(
    subject_id: str = Query(..., alias="subjectId"),
    season: int = Query(1, alias="se"),
    episode: int = Query(1, alias="ep"),
    detail_path: str = Query(None, alias="detailPath"),
    quality: str = Query("best", description="Quality: best, worst, 720, 1080"),
    language: str = Query("en", description="Subtitle language code (default: en)"),
):
    """
    Convenience endpoint to get download URL and subtitles.
    Returns download URL and matching subtitle.
    """
    params = {"subjectId": subject_id, "se": season, "ep": episode}
    headers = {
        "Referer": get_referer_for_detail(detail_path),
        "Origin": TARGET_BASE_URL,
    }
    
    try:
        response = await client.get("/wefeed-h5-bff/web/subject/download", params=params, headers=headers)
        data = response.json().get("data", response.json())
        
        downloads = data.get("downloads", [])
        captions = data.get("captions", [])
        
        # Select download by quality
        selected_download = None
        if downloads:
            downloads.sort(key=lambda x: x.get("resolution", 0), reverse=True)
            if quality == "worst":
                selected_download = downloads[-1]
            elif quality.isdigit():
                target_res = int(quality)
                selected_download = next((d for d in downloads if d.get("resolution") == target_res), downloads[0])
            else:
                selected_download = downloads[0]
        
        # Select subtitle by language (default to English)
        selected_subtitle = None
        if captions:
            selected_subtitle = next((c for c in captions if c.get("lan") == language), None)
            if not selected_subtitle and language != "en":
                # Fallback to English
                selected_subtitle = next((c for c in captions if c.get("lan") == "en"), None)
            if not selected_subtitle:
                selected_subtitle = captions[0]
        
        return {
            "download": {
                "url": selected_download.get("url") if selected_download else None,
                "resolution": selected_download.get("resolution") if selected_download else None,
                "size": selected_download.get("size") if selected_download else None,
            } if selected_download else None,
            "subtitle": {
                "url": selected_subtitle.get("url") if selected_subtitle else None,
                "language": selected_subtitle.get("lanName") if selected_subtitle else None,
                "languageCode": selected_subtitle.get("lan") if selected_subtitle else None,
            } if selected_subtitle else None,
            "all_downloads": downloads,
            "all_subtitles": captions,
        }
    except Exception as e:
        return {"error": str(e)}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)