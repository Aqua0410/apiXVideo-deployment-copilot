import os
import json
import asyncio
import tempfile
from pathlib import Path
from fastapi import FastAPI, HTTPException, Depends, Header
from typing import Optional, Dict, Any, List
import httpx
from datetime import datetime, timedelta

app = FastAPI()
DATA_DIR = "data"
API_KEY = os.getenv("SESSION_SECRET")

# In-memory cache for reels data
_reels_cache = {"data": None, "timestamp": None, "ttl": 300}  # 5 min cache

def verify_api_key(x_api_key: Optional[str] = Header(None)):
    if x_api_key != API_KEY or not x_api_key:
        raise HTTPException(status_code=401, detail="Invalid or missing API key")
    return x_api_key

@app.get("/")
def health_check():
    return {"status": "healthy", "message": "FastAPI File Server is running"}

@app.get("/files")
def list_files(api_key: str = Depends(verify_api_key)):
    files = []
    data_path = Path(DATA_DIR)
    
    # Recursively find all .json files
    for json_file in data_path.rglob("*.json"):
        # Get relative path from data directory
        relative_path = json_file.relative_to(data_path)
        files.append(str(relative_path))
    
    return {"files": files}

@app.get("/files/{filepath:path}")
async def get_file(filepath: str, api_key: str = Depends(verify_api_key)):
    # Enforce .json extension
    if not filepath.endswith('.json'):
        raise HTTPException(status_code=400, detail="Only .json files are allowed")
    
    # Prevent directory traversal attacks (allow forward slashes for subdirs)
    if '..' in filepath or '\\' in filepath:
        raise HTTPException(status_code=404, detail="File not found")
    
    # Special optimized handling for reels.json with caching
    if filepath == "reelsvideo/reels.json":
        # Check cache first
        if _reels_cache["data"] and _reels_cache["timestamp"]:
            cache_age = (datetime.now() - _reels_cache["timestamp"]).total_seconds()
            if cache_age < _reels_cache["ttl"]:
                return _reels_cache["data"]
    
    # Construct and validate the file path
    data_path = Path(DATA_DIR).resolve()
    file_path = (data_path / filepath).resolve()
    
    # Ensure the resolved path is within the data directory
    if not file_path.is_relative_to(data_path):
        raise HTTPException(status_code=404, detail="File not found")
    
    # Check if file exists
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="File not found")
    
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            data = json.load(f)
            
        # Cache reels.json for performance
        if filepath == "reelsvideo/reels.json":
            _reels_cache["data"] = data
            _reels_cache["timestamp"] = datetime.now()
            
        return data
        
    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail="Invalid JSON in file")
    except (OSError, UnicodeDecodeError):
        raise HTTPException(status_code=404, detail="File not found")

async def fetch_fresh_reels_data() -> List[Dict[str, Any]]:
    """Fetch fresh video data from tik.porn API and transform to our format"""
    api_url = "https://apiv2.tik.porn/getnextvideos"
    payload = {"amount": 100}
    
    # Retry configuration
    max_retries = 3
    base_delay = 1
    
    for attempt in range(max_retries):
        try:
            timeout_config = httpx.Timeout(30.0, connect=10.0)
            async with httpx.AsyncClient(timeout=timeout_config) as client:
                response = await client.post(api_url, json=payload)
                response.raise_for_status()
                
                api_data = response.json()
                
                # Transform API response to our reels format
                transformed_reels = []
                
                # Check if response has the expected structure
                if isinstance(api_data, dict) and api_data.get("code") == 200 and "data" in api_data:
                    videos = api_data["data"]
                    
                    for video in videos:
                        try:
                            # Use actual URLs from API response
                            mp4_url = video.get("mp4_url", "")
                            medium_thumb = video.get("medium_thumb", "")
                            
                            # Get title from video_text field
                            video_text_data = video.get("video_text", {})
                            title = ""
                            if isinstance(video_text_data, dict):
                                display_title = video_text_data.get("display_video_title", {})
                                if isinstance(display_title, dict):
                                    default_title = display_title.get("default", {})
                                    if isinstance(default_title, dict):
                                        title = default_title.get("text", "")
                            
                            # Fallback to action name if no title
                            if not title:
                                action_name = video.get("action_name", "")
                                title = f"{action_name} | Tik.Porn" if action_name else "Video | Tik.Porn"
                            
                            # Only add videos with valid URLs
                            if mp4_url and medium_thumb:
                                reel = {
                                    "thumb": medium_thumb,
                                    "video": mp4_url,
                                    "video_text": title
                                }
                                transformed_reels.append(reel)
                                
                        except Exception as e:
                            # Skip invalid video entries
                            continue
                
                return transformed_reels
                
        except httpx.HTTPStatusError as e:
            if e.response.status_code == 429:  # Rate limited
                if attempt < max_retries - 1:
                    delay = base_delay * (2 ** attempt)  # Exponential backoff
                    await asyncio.sleep(delay)
                    continue
            raise HTTPException(status_code=502, detail=f"External API error: {e.response.status_code}")
        except httpx.RequestError:
            if attempt < max_retries - 1:
                delay = base_delay * (2 ** attempt)
                await asyncio.sleep(delay)
                continue
            raise HTTPException(status_code=502, detail="Failed to connect to external API")
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Error fetching data: {str(e)}")
    
    # If all retries failed
    raise HTTPException(status_code=502, detail="External API request failed after retries")

async def write_reels_atomically(data: Dict[str, Any], file_path: Path):
    """Write reels data atomically to prevent corruption"""
    # Write to temporary file first
    temp_file = file_path.with_suffix('.tmp')
    
    try:
        with open(temp_file, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
            f.flush()
            os.fsync(f.fileno())  # Force write to disk
        
        # Atomic move to final location
        temp_file.replace(file_path)
        
    except Exception:
        # Clean up temp file on error
        if temp_file.exists():
            temp_file.unlink()
        raise

@app.post("/refresh-reels")
async def refresh_reels_data(api_key: str = Depends(verify_api_key)):
    """Fetch fresh reels data and update reels.json file"""
    try:
        # Fetch fresh data from external API
        fresh_reels = await fetch_fresh_reels_data()
        
        if not fresh_reels:
            raise HTTPException(status_code=502, detail="No data received from external API")
        
        # Update reels.json file atomically
        reels_file = Path(DATA_DIR) / "reelsvideo" / "reels.json"
        
        # Create directory if it doesn't exist
        reels_file.parent.mkdir(parents=True, exist_ok=True)
        
        # Create new JSON structure
        updated_data = {
            "reels": fresh_reels
        }
        
        # Atomic write
        await write_reels_atomically(updated_data, reels_file)
        
        # Update cache
        _reels_cache["data"] = updated_data
        _reels_cache["timestamp"] = datetime.now()
        
        return {
            "status": "success",
            "message": f"Updated reels.json with {len(fresh_reels)} new videos",
            "videos_count": len(fresh_reels)
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error updating reels data: {str(e)}")