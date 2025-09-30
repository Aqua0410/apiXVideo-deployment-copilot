import os
import json
import asyncio
import tempfile
import logging
from pathlib import Path
from fastapi import FastAPI, HTTPException, Depends, Header, Query
from typing import Optional, Dict, Any, List
import httpx
from datetime import datetime, timedelta

app = FastAPI()
DATA_DIR = "data"
API_KEY = os.getenv("SESSION_SECRET")

# In-memory cache for reels data
_reels_cache = {"data": None, "timestamp": None, "ttl": 300}  # 5 min cache

# Background task control
_background_task = None
_refresh_lock = asyncio.Lock()

# Setup logging
logging.basicConfig(level=logging.INFO)

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

@app.get("/reels")
async def get_reels_paginated(
    page: int = Query(1, ge=1, description="Page number (starts from 1)"),
    limit: int = Query(20, ge=1, le=100, description="Items per page (max 100)"),
    api_key: str = Depends(verify_api_key)
):
    """
    Get paginated reels data - optimized for mobile apps
    
    Parameters:
    - page: Page number (default: 1)
    - limit: Items per page (default: 20, max: 100)
    
    Example: /reels?page=1&limit=20
    """
    try:
        # Get reels data from cache or file
        reels_data = None
        
        # Check cache first
        if _reels_cache["data"] and _reels_cache["timestamp"]:
            cache_age = (datetime.now() - _reels_cache["timestamp"]).total_seconds()
            if cache_age < _reels_cache["ttl"]:
                reels_data = _reels_cache["data"]
        
        # Load from file if not in cache
        if not reels_data:
            reels_file = Path(DATA_DIR) / "reelsvideo" / "reels.json"
            if reels_file.exists():
                with open(reels_file, "r", encoding="utf-8") as f:
                    reels_data = json.load(f)
                    _reels_cache["data"] = reels_data
                    _reels_cache["timestamp"] = datetime.now()
            else:
                raise HTTPException(status_code=404, detail="Reels data not found")
        
        # Extract reels array
        all_reels = reels_data.get("reels", [])
        total_items = len(all_reels)
        
        # Calculate pagination
        total_pages = (total_items + limit - 1) // limit  # Ceiling division
        
        # Validate page number
        if page > total_pages and total_pages > 0:
            raise HTTPException(
                status_code=404, 
                detail=f"Page {page} not found. Total pages: {total_pages}"
            )
        
        # Calculate slice indices
        start_idx = (page - 1) * limit
        end_idx = start_idx + limit
        
        # Get paginated items
        paginated_reels = all_reels[start_idx:end_idx]
        
        # Return paginated response with metadata
        return {
            "page": page,
            "limit": limit,
            "total_items": total_items,
            "total_pages": total_pages,
            "has_next": page < total_pages,
            "has_previous": page > 1,
            "reels": paginated_reels
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error fetching reels: {str(e)}")

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

async def auto_refresh_reels():
    """Background task to automatically refresh reels data every 5 minutes"""
    while True:
        try:
            # Use lock to prevent multiple workers from refreshing simultaneously
            async with _refresh_lock:
                logging.info("Auto-refreshing reels data...")
                
                # Fetch fresh data
                fresh_reels = await fetch_fresh_reels_data()
                
                if fresh_reels:
                    # Update reels.json file atomically
                    reels_file = Path(DATA_DIR) / "reelsvideo" / "reels.json"
                    reels_file.parent.mkdir(parents=True, exist_ok=True)
                    
                    # Create new JSON structure
                    updated_data = {
                        "reels": fresh_reels
                    }
                    
                    # Atomic write with unique temp file
                    import uuid
                    temp_file = reels_file.with_suffix(f'.tmp.{uuid.uuid4().hex[:8]}')
                    
                    try:
                        with open(temp_file, "w", encoding="utf-8") as f:
                            json.dump(updated_data, f, indent=2, ensure_ascii=False)
                            f.flush()
                            os.fsync(f.fileno())  # Force write to disk
                        
                        # Atomic move to final location
                        temp_file.replace(reels_file)
                        
                        # Update cache
                        _reels_cache["data"] = updated_data
                        _reels_cache["timestamp"] = datetime.now()
                        
                        logging.info(f"Auto-refresh completed: {len(fresh_reels)} videos updated")
                        
                    except Exception:
                        # Clean up temp file on error
                        if temp_file.exists():
                            temp_file.unlink()
                        raise
                        
                else:
                    logging.warning("Auto-refresh failed: No data received")
                    
        except Exception as e:
            logging.error(f"Auto-refresh error: {str(e)}")
        
        # Wait 5 minutes before next refresh
        await asyncio.sleep(300)  # 300 seconds = 5 minutes

@app.on_event("startup")
async def startup_event():
    """Start background tasks when the application starts"""
    global _background_task
    
    # Only start background task in one worker (check if we're the first worker)
    worker_id = os.getpid()
    
    # Start the auto-refresh task only in first worker or single process
    if _background_task is None:
        _background_task = asyncio.create_task(auto_refresh_reels())
        logging.info(f"Background auto-refresh task started in worker {worker_id} (every 5 minutes)")
    
    # Do initial refresh only once
    try:
        async with _refresh_lock:
            reels_file = Path(DATA_DIR) / "reelsvideo" / "reels.json"
            
            # Only do initial refresh if file doesn't exist or is old
            if not reels_file.exists() or _reels_cache["data"] is None:
                fresh_reels = await fetch_fresh_reels_data()
                if fresh_reels:
                    reels_file.parent.mkdir(parents=True, exist_ok=True)
                    
                    updated_data = {"reels": fresh_reels}
                    
                    # Use unique temp file for initial load too
                    import uuid
                    temp_file = reels_file.with_suffix(f'.tmp.{uuid.uuid4().hex[:8]}')
                    
                    try:
                        with open(temp_file, "w", encoding="utf-8") as f:
                            json.dump(updated_data, f, indent=2, ensure_ascii=False)
                            f.flush()
                            os.fsync(f.fileno())
                        
                        temp_file.replace(reels_file)
                        
                        _reels_cache["data"] = updated_data
                        _reels_cache["timestamp"] = datetime.now()
                        
                        logging.info(f"Initial data loaded by worker {worker_id}: {len(fresh_reels)} videos")
                        
                    except Exception:
                        if temp_file.exists():
                            temp_file.unlink()
                        raise
            else:
                # Load existing data into cache
                with open(reels_file, "r", encoding="utf-8") as f:
                    _reels_cache["data"] = json.load(f)
                    _reels_cache["timestamp"] = datetime.fromtimestamp(reels_file.stat().st_mtime)
                logging.info(f"Worker {worker_id} loaded existing data from cache")
                
    except Exception as e:
        logging.error(f"Initial data load failed in worker {worker_id}: {str(e)}")

@app.on_event("shutdown")
async def shutdown_event():
    """Clean up background tasks when the application shuts down"""
    global _background_task
    
    if _background_task:
        _background_task.cancel()
        try:
            await _background_task
        except asyncio.CancelledError:
            pass
        logging.info("Background auto-refresh task stopped")