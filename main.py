import os
import json
from pathlib import Path
from fastapi import FastAPI, HTTPException, Depends, Header
from typing import Optional

app = FastAPI()
DATA_DIR = "data"
API_KEY = os.getenv("SESSION_SECRET")

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
def get_file(filepath: str, api_key: str = Depends(verify_api_key)):
    # Enforce .json extension
    if not filepath.endswith('.json'):
        raise HTTPException(status_code=400, detail="Only .json files are allowed")
    
    # Prevent directory traversal attacks (allow forward slashes for subdirs)
    if '..' in filepath or '\\' in filepath:
        raise HTTPException(status_code=404, detail="File not found")
    
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
            return json.load(f)
    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail="Invalid JSON in file")
    except (OSError, UnicodeDecodeError):
        raise HTTPException(status_code=404, detail="File not found")