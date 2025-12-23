import httpx
import json
from html.parser import HTMLParser

class NuxtDataParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.nuxt_data = None
        self.in_script = False
        self.script_id = None

    def handle_starttag(self, tag, attrs):
        if tag == "script":
            attrs_dict = dict(attrs)
            if attrs_dict.get("id") == "__NUXT_DATA__":
                self.in_script = True

    def handle_data(self, data):
        if self.in_script:
            self.nuxt_data = data

    def handle_endtag(self, tag):
        if tag == "script":
            self.in_script = False

def resolve(val, pool, cache, visited):
    if not isinstance(val, int) or val < 0 or val >= len(pool):
        return val
    if val in cache:
        return cache[val]
    if val in visited:
        return None
    
    visited.add(val)
    raw = pool[val]
    resolved = None
    
    if isinstance(raw, list):
        resolved = [resolve(e, pool, cache, visited) for e in raw]
    elif isinstance(raw, dict):
        resolved = {str(k): resolve(v, pool, cache, visited) for k, v in raw.items()}
    else:
        resolved = raw
        
    visited.remove(val)
    cache[val] = resolved
    return resolved

def test_movie(url):
    print(f"Testing URL: {url}")
    headers = {
        "User-Agent": "Mozilla/5.0",
        "ngrok-skip-browser-warning": "true"
    }
    
    try:
        response = httpx.get(url, headers=headers, follow_redirects=True)
        print(f"Status: {response.status_code}")
        
        parser = NuxtDataParser()
        parser.feed(response.text)
        
        if not parser.nuxt_data:
            print("FAILED: __NUXT_DATA__ not found")
            return

        pool = json.loads(parser.nuxt_data)
        cache = {}
        
        # Search for resData
        found = False
        for i in range(len(pool)):
            item = pool[i]
            if isinstance(item, dict) and any(k in item for k in ["resData", "$sresData", "metadata"]):
                resolved = resolve(i, pool, cache, set())
                data = resolved.get("resData") or resolved.get("$sresData") or (resolved if "metadata" in resolved else None)
                
                if data and isinstance(data, dict) and "metadata" in data:
                    print(f"\n--- SUCCESS: Found resData at index {i} ---")
                    print(f"Title: {data.get('metadata', {}).get('title')}")
                    
                    resource = data.get("resource", {})
                    print(f"Resource Keys: {list(resource.keys())}")
                    
                    if "videoAddress" in resource:
                        print(f"Direct Video Address: {resource['videoAddress']}")
                    
                    if "items" in resource:
                        print("Stream Items:")
                        for item in resource["items"]:
                            print(f"  - {item.get('resolution')}: {item.get('url')}")
                            
                    if "seasons" in resource:
                        print(f"Found {len(resource['seasons'])} seasons")
                        for s in resource["seasons"]:
                            print(f"  Season: {s.get('name')}")
                            for ep in s.get("items", []):
                                print(f"    Ep {ep.get('episode')}: {ep.get('title')} -> URL: {ep.get('url') is not None}")
                    
                    found = True
                    break
        
        if not found:
            print("FAILED: Could not find resData in pool")
            
    except Exception as e:
        print(f"ERROR: {e}")

if __name__ == "__main__":
    test_movie("https://0c92fda59773.ngrok-free.app/detail/avatar-fire-and-ash-cam-ixOH9eSiw5")
