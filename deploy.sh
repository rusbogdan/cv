#!/bin/bash
set -e

# deploy.sh — Build images locally, transfer to EC2, and deploy.
#
# Usage:
#   DOMAIN=example.com EC2_HOST=user@ec2-ip ./deploy.sh
#
# Optional:
#   EMAIL=you@example.com  — for Let's Encrypt registration
#   EC2_KEY=~/.ssh/key.pem — SSH key for EC2

DOMAIN="${DOMAIN:?Usage: DOMAIN=example.com EC2_HOST=user@ec2-ip ./deploy.sh}"
EC2_HOST="${EC2_HOST:?Set EC2_HOST=user@ec2-host-or-ip}"
EMAIL="${EMAIL:-}"
EC2_KEY="${EC2_KEY:-}"
TARGET_PLATFORM="linux/arm64"

SSH_OPTS=""
SCP_OPTS=""
if [ -n "$EC2_KEY" ]; then
    SSH_OPTS="-i $EC2_KEY"
    SCP_OPTS="-i $EC2_KEY"
fi

echo "==> Domain: $DOMAIN"
echo "==> EC2 host: $EC2_HOST"
echo "==> Target platform: $TARGET_PLATFORM"
echo ""

# ---------------------------------------------------------------------------
# Step 1: Build WASM artifacts (always amd64 — output is platform-independent)
# ---------------------------------------------------------------------------
echo "==> Building WASM artifacts"
docker build --platform linux/amd64 -t cv-wasm-builder -f frontend/Dockerfile.wasm-build frontend
docker run --platform linux/amd64 --rm -v "$PWD/frontend:/workout" cv-wasm-builder

sudo chown -R "$(id -u):$(id -g)" frontend/dist/
sed -i 's|<script src="cv_wasm.js">|<script>var Module={ENV:{API_BASE_URL:location.origin+"/api"}};</script>\n<script src="cv_wasm.js">|' frontend/dist/cv_wasm.html
sed -i '/^prefer /d' frontend/dist/Cv/qmldir

# ---------------------------------------------------------------------------
# Step 2: Cross-build runtime images for arm64
# ---------------------------------------------------------------------------
echo "==> Cross-building arm64 runtime images"

# Ensure buildx builder with QEMU support exists
docker buildx inspect cv-builder >/dev/null 2>&1 || \
    docker buildx create --name cv-builder --use
docker buildx use cv-builder

docker buildx build --platform "$TARGET_PLATFORM" \
    -t cv-backend:deploy \
    --load \
    backend

docker buildx build --platform "$TARGET_PLATFORM" \
    -t cv-frontend:deploy \
    -f frontend/Dockerfile.nginx \
    --load \
    frontend

# ---------------------------------------------------------------------------
# Step 3: Save images to tar and transfer to EC2
# ---------------------------------------------------------------------------
echo "==> Saving images to tar"
docker save cv-backend:deploy cv-frontend:deploy | gzip > /tmp/cv-images.tar.gz
echo "    $(du -h /tmp/cv-images.tar.gz | cut -f1) compressed"

echo "==> Transferring images to EC2"
scp $SCP_OPTS /tmp/cv-images.tar.gz "$EC2_HOST:/tmp/cv-images.tar.gz"

# ---------------------------------------------------------------------------
# Step 4: Transfer compose and config files to EC2
# ---------------------------------------------------------------------------
echo "==> Transferring deployment files to EC2"
ssh $SSH_OPTS "$EC2_HOST" "mkdir -p ~/cv/infra ~/cv/frontend/nginx"

scp $SCP_OPTS \
    infra/docker-compose.local.yml \
    "$EC2_HOST:~/cv/infra/docker-compose.local.yml"

# ---------------------------------------------------------------------------
# Step 5: Load images and start services on EC2
# ---------------------------------------------------------------------------
echo "==> Loading images and starting services on EC2"
ssh $SSH_OPTS "$EC2_HOST" bash -s "$DOMAIN" "$EMAIL" <<'REMOTE'
set -e
DOMAIN="$1"
EMAIL="$2"

echo "==> Loading Docker images"
docker load < /tmp/cv-images.tar.gz
rm -f /tmp/cv-images.tar.gz

# Tag images so compose can find them
docker tag cv-backend:deploy cv-backend:latest
docker tag cv-frontend:deploy cv-frontend:latest

cd ~/cv

# Create a compose override that uses pre-built images instead of building
cat > infra/docker-compose.images.yml <<EOF
services:
  backend:
    image: cv-backend:latest
    build: !reset null
  frontend:
    image: cv-frontend:latest
    build: !reset null
EOF

export PLATFORM="linux/arm64"
export DOMAIN="$DOMAIN"

# Stop any existing containers
docker compose -f infra/docker-compose.local.yml -f infra/docker-compose.images.yml down 2>/dev/null || true

# Bootstrap Let's Encrypt certificate if not already present
if ! docker volume ls -q | grep -q letsencrypt; then
    echo "==> Obtaining initial Let's Encrypt certificate"

    # Create volumes with a temporary self-signed cert so nginx can boot
    docker volume create cv_letsencrypt > /dev/null
    docker volume create cv_certbot-webroot > /dev/null

    CERT_DIR="/etc/letsencrypt/live/$DOMAIN"
    docker run --rm --entrypoint sh \
        -v cv_letsencrypt:/etc/letsencrypt \
        alpine/openssl -c "
            mkdir -p $CERT_DIR &&
            openssl req -x509 -nodes -days 1 -newkey rsa:2048 \
                -keyout $CERT_DIR/privkey.pem \
                -out $CERT_DIR/fullchain.pem \
                -subj '/CN=$DOMAIN'
        "

    # Start nginx so certbot can reach /.well-known/acme-challenge/
    docker compose -f infra/docker-compose.local.yml -f infra/docker-compose.images.yml up -d frontend

    # Get the real certificate
    EMAIL_FLAG=""
    if [ -n "$EMAIL" ]; then
        EMAIL_FLAG="--email $EMAIL"
    else
        EMAIL_FLAG="--register-unsafely-without-email"
    fi
    docker compose -f infra/docker-compose.local.yml -f infra/docker-compose.images.yml run --rm certbot \
        certbot certonly --webroot -w /var/www/certbot \
        -d "$DOMAIN" $EMAIL_FLAG --agree-tos --non-interactive --force-renewal

    docker compose -f infra/docker-compose.local.yml -f infra/docker-compose.images.yml down
fi

echo "==> Starting all services"
docker compose -f infra/docker-compose.local.yml -f infra/docker-compose.images.yml up -d

echo ""
echo "Site is live at https://$DOMAIN"
REMOTE

rm -f /tmp/cv-images.tar.gz
echo "==> Deploy complete"
