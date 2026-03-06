
# CV

Tiny demo showing:
- CV stored as YAML
- FastAPI backend (HTTPS + WebSocket)
- Qt Quick UI compiled to WebAssembly
- Containerized backend and frontend

## Structure
backend/ - FastAPI service exposing CV
frontend/ - Qt WASM UI
infra/ - local docker compose

## Local Run

1. Generate self-signed certificate:

openssl req -x509 -newkey rsa:2048 -nodes -keyout backend/app/certs/dev.key -out backend/app/certs/dev.crt -days 365 -subj "/CN=localhost"

2. Build frontend WASM (Qt downloaded automatically inside container):

docker build -t cv-wasm-builder -f frontend/Dockerfile.wasm-build frontend
docker run --rm -v "$PWD/frontend:/workout" cv-wasm-builder

3. Run services:

docker compose -f infra/docker-compose.local.yml up --build

Frontend: http://localhost:8081
Backend: https://localhost:8443



google-chrome-stable --enable-features=VaapiVideoDecoder,VaapiIgnoreDriverChecks,AcceleratedVideoDecodeLinuxGL --ignore-gpu-blocklist --enable-gpu-rasterization
