import os
import json
from pathlib import Path
from fastapi import FastAPI, HTTPException

app = FastAPI()
DATA_DIR = "data"

@app.get("/files")
def list_files():
    files = [f for f in os.listdir(DATA_DIR) if f.endswith(".txt")]
    return {"files": files}

@app.get("/files/{filename}")
def get_file(filename: str):
    # Enforce .txt extension
    if not filename.endswith('.txt'):
        raise HTTPException(status_code=400, detail="Only .txt files are allowed")
    
    # Prevent directory traversal attacks
    if '/' in filename or '\\' in filename or '..' in filename:
        raise HTTPException(status_code=404, detail="File not found")
    
    # Construct and validate the file path
    data_path = Path(DATA_DIR).resolve()
    file_path = (data_path / filename).resolve()
    
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