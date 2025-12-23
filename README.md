# Moviebox App

A Flutter application for streaming and downloading movies and TV series, powered by a FastAPI proxy server.

## 📋 Table of Contents

- [Features](#-features)
- [Architecture](#-architecture)
- [Prerequisites](#-prerequisites)
- [Environment Setup](#-environment-setup)
- [Running the App](#-running-the-app)
- [API Reference](#-api-reference)
- [Project Structure](#-project-structure)
- [Troubleshooting](#-troubleshooting)

## ✨ Features

- **Search** - Search movies and TV series by title
- **Browse** - Explore home content with categories and banners
- **Stream** - Watch content directly in the app with quality selection
- **TV Series Support** - Navigate seasons and episodes
- **Subtitles** - Multiple language subtitles (defaults to English)
- **Download** - Download movies and episodes for offline viewing

## 🏗 Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Flutter App   │────▶│  FastAPI Proxy  │────▶│  Moviebox API   │
│  (Android/iOS)  │     │   (localhost)   │     │ (h5.aoneroom)   │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                               │
                               ▼
                        ┌─────────────────┐
                        │     ngrok       │
                        │  (for mobile)   │
                        └─────────────────┘
```

The FastAPI proxy server handles:
- Session/cookie management for API authentication
- Proper Referer headers required by the Moviebox API
- CORS for Flutter web/mobile access
- Request forwarding to the upstream API

## 📦 Prerequisites

| Requirement | Version | Path |
|-------------|---------|------|
| Flutter | 3.x | `/Users/cruzr/flutter/bin/flutter` |
| Java JDK | 17 | `/Users/cruzr/projects/moviebox-app/jdk-17.0.17+10/Contents/Home` |
| Python | 3.10+ | System |
| ngrok | 2.x+ | System (for mobile testing) |

## ⚙️ Environment Setup

### 1. Create `.env` file

Copy the example and update with your ngrok URL:

```bash
cp .env.example .env
```

Edit `.env`:
```env
MOVIEBOX_API_URL=https://your-ngrok-url.ngrok-free.app
```

### 2. Set JAVA_HOME (for Android builds)

```bash
export JAVA_HOME=/Users/cruzr/projects/moviebox-app/jdk-17.0.17+10/Contents/Home
export PATH=$JAVA_HOME/bin:$PATH
```

### 3. Install Python dependencies

```bash
cd server
pip install -r requirements.txt
```

### 4. Install Flutter dependencies

```bash
flutter pub get
```

## 🚀 Running the App

### Start the FastAPI Server

```bash
cd server
python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

The server will be available at `http://localhost:8000`

### Expose via ngrok (for mobile devices)

```bash
ngrok http 8000
```

Update your `.env` file with the ngrok URL.

### Run Flutter App

**On Connected Android Device:**
```bash
export JAVA_HOME=/Users/cruzr/projects/moviebox-app/jdk-17.0.17+10/Contents/Home
export PATH=$JAVA_HOME/bin:$PATH

flutter run -d 121024044J103033 \
  --dart-define=MOVIEBOX_API_URL=https://your-ngrok-url.ngrok-free.app
```

**On iOS Simulator:**
```bash
flutter run -d iPhone
```

**On Web:**
```bash
flutter run -d chrome
```

## 📡 API Reference

The FastAPI proxy forwards requests to `https://h5.aoneroom.com` (Moviebox mirror).

### Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | Health check |
| GET | `/wefeed-h5-bff/web/home` | Home page content with categories |
| POST | `/wefeed-h5-bff/web/subject/search-suggest` | Search suggestions |
| POST | `/wefeed-h5-bff/web/subject/search` | Full search with pagination |
| GET | `/wefeed-h5-bff/web/subject/play` | Get streaming URLs |
| GET | `/wefeed-h5-bff/web/subject/download` | Get download URLs + subtitles |
| GET | `/detail/{path}` | HTML detail page for parsing |

### Streaming API Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `subjectId` | string | Content ID |
| `se` | int | Season number (1 for movies) |
| `ep` | int | Episode number (1 for movies) |

### Request Headers

| Header | Description |
|--------|-------------|
| `X-Detail-Path` | Detail path for proper Referer (e.g., `avatar-xyz`) |
| `ngrok-skip-browser-warning` | Skip ngrok interstitial page |

### Response Structure

**Streaming Response:**
```json
{
  "streams": [
    {
      "id": "string",
      "url": "https://...",
      "resolutions": 1080,
      "format": "mp4",
      "size": 1234567890
    }
  ],
  "dash": [],
  "hls": [],
  "hasResource": true
}
```

**Download Response:**
```json
{
  "downloads": [
    {
      "id": "string",
      "url": "https://...",
      "resolution": 1080,
      "size": 1234567890
    }
  ],
  "captions": [
    {
      "id": "string",
      "lan": "en",
      "lanName": "English",
      "url": "https://...",
      "size": 12345
    }
  ],
  "hasResource": true
}
```

## 📁 Project Structure

```
moviebox-app/
├── lib/
│   ├── api/
│   │   └── moviebox_api.dart      # API client
│   ├── models/
│   │   └── movie_models.dart      # Data models
│   ├── ui/
│   │   ├── home/
│   │   │   └── home_screen.dart   # Home page
│   │   ├── details/
│   │   │   └── details_screen.dart # Movie/series details
│   │   ├── player/
│   │   │   └── player_screen.dart  # Video player
│   │   └── search/
│   │       └── search_screen.dart  # Search page
│   └── main.dart                   # App entry point
├── server/
│   ├── main.py                     # FastAPI proxy server
│   └── requirements.txt            # Python dependencies
├── .env                            # Environment variables (gitignored)
├── .env.example                    # Example environment file
└── pubspec.yaml                    # Flutter dependencies
```

## 🔧 Troubleshooting

### "Streaming link not available"

1. Ensure the FastAPI server is running
2. Check that `X-Detail-Path` header is being sent
3. Verify the ngrok URL is accessible

### Video not playing / stuck on loading

1. Check the stream URL in logs
2. Ensure proper Referer header is set in player
3. Try a different content item

### API returns empty response

The Moviebox API requires specific headers:
- `Referer: https://h5.aoneroom.com/movies/{detailPath}`
- `Origin: https://h5.aoneroom.com`

The FastAPI proxy handles this automatically when `X-Detail-Path` is provided.

### Android build fails

Ensure JAVA_HOME is set:
```bash
export JAVA_HOME=/Users/cruzr/projects/moviebox-app/jdk-17.0.17+10/Contents/Home
```

### Flutter not found

Add Flutter to PATH:
```bash
export PATH="/Users/cruzr/flutter/bin:$PATH"
```

## 📄 License

This project is for educational purposes only. All content is sourced from third-party providers.
