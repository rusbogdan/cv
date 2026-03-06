#!/bin/bash
set -e

PLATFORM="${PLATFORM:-linux/$(uname -m | sed 's/x86_64/amd64/' | sed 's/aarch64/arm64/')}"
DOMAIN="${DOMAIN:?Usage: DOMAIN=example.com ./build.sh}"
EMAIL="${EMAIL:-}"

echo "==> Target platform: $PLATFORM"
echo "==> Domain: $DOMAIN"

# Step 1: build WASM artifacts into frontend/dist/ (Qt downloaded inside container)
# WASM builder must run on amd64 (emscripten + Qt host tools are x86-only);
# output is platform-independent .wasm/.js/.html files.
docker build --platform linux/amd64 -t cv-wasm-builder -f frontend/Dockerfile.wasm-build frontend
docker run --platform linux/amd64 --rm -v "$PWD/frontend:/workout" cv-wasm-builder

# Step 2: fix ownership (Docker outputs as root) and post-process dist
sudo chown -R "$(id -u):$(id -g)" frontend/dist/
sed -i 's|<script src="cv_wasm.js">|<script>var Module={ENV:{API_BASE_URL:location.origin+"/api"}};</script>\n<script src="cv_wasm.js">|' frontend/dist/cv_wasm.html
sed -i '/^prefer /d' frontend/dist/Cv/qmldir

# Step 3: stop any previously running containers
docker compose -f infra/docker-compose.local.yml down

# Step 4: obtain Let's Encrypt certificate if not already present
# Start nginx temporarily on port 80 only (with a self-signed placeholder so it boots)
CERT_VOL="$(docker volume ls -q | grep letsencrypt || true)"
if [ -z "$CERT_VOL" ]; then
    echo "==> Obtaining initial Let's Encrypt certificate"

    # Create volumes and a temporary self-signed cert so nginx can start
    docker volume create --name "$(basename "$PWD")_letsencrypt" > /dev/null
    docker volume create --name "$(basename "$PWD")_certbot-webroot" > /dev/null

    CERT_DIR="/etc/letsencrypt/live/$DOMAIN"
    docker run --rm \
        -v "$(basename "$PWD")_letsencrypt:/etc/letsencrypt" \
        alpine/openssl sh -c "
            mkdir -p $CERT_DIR &&
            openssl req -x509 -nodes -days 1 -newkey rsa:2048 \
                -keyout $CERT_DIR/privkey.pem \
                -out $CERT_DIR/fullchain.pem \
                -subj '/CN=$DOMAIN'
        "

    # Start frontend (nginx) so certbot can reach /.well-known/acme-challenge/
    PLATFORM="$PLATFORM" DOMAIN="$DOMAIN" \
        docker compose -f infra/docker-compose.local.yml up -d frontend

    # Run certbot to get the real certificate
    EMAIL_FLAG=""
    if [ -n "$EMAIL" ]; then
        EMAIL_FLAG="--email $EMAIL"
    else
        EMAIL_FLAG="--register-unsafely-without-email"
    fi

    docker compose -f infra/docker-compose.local.yml run --rm certbot \
        certbot certonly --webroot -w /var/www/certbot \
        -d "$DOMAIN" $EMAIL_FLAG --agree-tos --non-interactive --force-renewal

    # Stop the temporary frontend
    docker compose -f infra/docker-compose.local.yml down
fi

# Step 5: build and start all services
echo "==> Starting services"
PLATFORM="$PLATFORM" DOMAIN="$DOMAIN" docker compose -f infra/docker-compose.local.yml up --build -d

echo ""
echo "Site is live at https://$DOMAIN"
