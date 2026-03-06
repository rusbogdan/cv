
from __future__ import annotations
import json
from pathlib import Path
from typing import Any, Dict

import yaml
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse

APP_DIR = Path(__file__).resolve().parent
CV_PATH = APP_DIR / "cv.yaml"

app = FastAPI(title="cv-backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

def load_cv() -> Dict[str, Any]:
    data = yaml.safe_load(CV_PATH.read_text(encoding="utf-8"))
    return data if isinstance(data, dict) else {}

@app.get("/health")
def health():
    return {"status":"ok"}

@app.get("/cv")
def get_cv():
    return JSONResponse(load_cv())

ALLOWED_IMAGES = {
    "picture.jpg": "image/jpeg",
    "contributions.png": "image/png",
}

@app.get("/image")
def image(name: str = "picture.jpg"):
    if name not in ALLOWED_IMAGES:
        return JSONResponse({"error": "not found"}, status_code=404)
    return FileResponse(APP_DIR / name, media_type=ALLOWED_IMAGES[name])

@app.get("/under-the-hood")
def under():
    return {
        "snippets":[
            {"title":"FastAPI endpoint","lang":"python","code":"GET /cv -> JSONResponse(load_cv())"},
            {"title":"WebSocket example","lang":"python","code":"WS /ws streams events"}
        ],
        "notes":[
            "TLS terminated at nginx with Let's Encrypt certificates.",
            "Certbot sidecar handles automatic renewal every 12 hours."
        ]
    }

@app.websocket("/ws")
async def ws(websocket: WebSocket):
    await websocket.accept()
    try:
        while True:
            data = await websocket.receive_text()
            try:
                obj = json.loads(data)
            except Exception:
                obj = {"type":"unknown"}

            if obj.get("type") == "refresh_cv":
                await websocket.send_json({"type":"cv_updated","cv":load_cv()})
            else:
                await websocket.send_json({"type":"echo","payload":obj})
    except WebSocketDisconnect:
        pass
