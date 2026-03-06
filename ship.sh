#!/bin/bash
set -euo pipefail

# =============================================================================
# ship.sh — Bootstrap local tools, build images, deploy to EC2 (all-in-one)
# =============================================================================

# ---- Configuration (edit these) ---------------------------------------------
DOMAIN="timel.es"
EMAIL="rusbogdanclaudiu@gmail.com"                              # Let's Encrypt email (blank = no email)
EC2_HOST="ubuntu@54.145.118.248"            # user@host or user@ip
EC2_KEY="$HOME/cv-keys/quick_python_hosting.pem"        # path to PEM key (leave empty if using ssh-agent)
EC2_PLATFORM="linux/arm64"            # EC2 instance architecture
S3_BUCKET="cv-wasm-assets-timel-es"        # S3 bucket for WASM static assets
AWS_REGION="us-east-1"                      # S3 bucket region
AWS_ACCESS_KEY_ID=""                        # leave empty to use ~/.aws/credentials or instance profile
AWS_SECRET_ACCESS_KEY=""                    # leave empty to use ~/.aws/credentials or instance profile
# -----------------------------------------------------------------------------

SSH_OPTS=()
SCP_OPTS=()
if [ -n "$EC2_KEY" ]; then
    SSH_OPTS=(-i "$EC2_KEY")
    SCP_OPTS=(-i "$EC2_KEY")
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# =============================================================================
# Phase 1: Bootstrap local build dependencies
# =============================================================================
phase_bootstrap() {
    echo ""
    echo "============================================"
    echo "  Phase 1: Bootstrap local build tools"
    echo "============================================"

    if docker buildx version &>/dev/null; then
        echo "==> Docker + buildx already installed, skipping bootstrap"
        return 0
    fi

    echo "==> Updating package index"
    sudo apt-get update

    echo "==> Installing prerequisites"
    sudo apt-get install -y \
        ca-certificates curl gnupg git openssl sed \
        qemu-user-static binfmt-support

    echo "==> Adding Docker GPG key and repository"
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    echo "==> Installing Docker Engine and Compose plugin"
    sudo apt-get update
    sudo apt-get install -y \
        docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin

    echo "==> Enabling Docker"
    sudo systemctl enable --now docker

    echo "==> Registering QEMU binfmt handlers with fix-binary flag"
    sudo systemctl restart binfmt-support
    if [ -f /proc/sys/fs/binfmt_misc/qemu-x86_64 ]; then
        echo -1 | sudo tee /proc/sys/fs/binfmt_misc/qemu-x86_64 > /dev/null
    fi
    QEMU_BIN=$(command -v qemu-x86_64-static 2>/dev/null || echo /usr/bin/qemu-x86_64-static)
    echo ":qemu-x86_64:M::\\x7fELF\\x02\\x01\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\x3e\\x00:\\xff\\xff\\xff\\xff\\xff\\xfe\\xfe\\x00\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff\\xff:${QEMU_BIN}:F" \
        | sudo tee /proc/sys/fs/binfmt_misc/register > /dev/null

    echo "==> Adding current user to docker group"
    sudo usermod -aG docker "$USER"

    echo "==> Bootstrap complete (you may need to 'newgrp docker' or re-login)"
}

# =============================================================================
# Phase 2: Build WASM artifacts + cross-build arm64 runtime images
# =============================================================================
phase_build() {
    echo ""
    echo "============================================"
    echo "  Phase 2: Build"
    echo "============================================"

    # -- WASM build (always amd64, output is platform-independent) --
    echo "==> Building WASM artifacts"
    docker build --platform linux/amd64 -t cv-wasm-builder \
        -f frontend/Dockerfile.wasm-build .
    docker run --platform linux/amd64 --rm \
        -v "$SCRIPT_DIR/frontend:/workout" cv-wasm-builder

    sudo chown -R "$(id -u):$(id -g)" frontend/dist/
    sed -i '/^prefer /d' frontend/dist/Cv/qmldir

    # -- Cross-build runtime images for EC2 architecture --
    echo "==> Cross-building $EC2_PLATFORM runtime images"
    docker buildx inspect cv-builder &>/dev/null || \
        docker buildx create --name cv-builder --use
    docker buildx use cv-builder

    docker buildx build --platform "$EC2_PLATFORM" \
        -t cv-backend:deploy --load backend
}

# =============================================================================
# Phase 3: Upload WASM static assets to S3 and patch HTML to load from S3
# =============================================================================
phase_cdn() {
    echo ""
    echo "============================================"
    echo "  Phase 3: Upload WASM assets to S3"
    echo "============================================"

    # Export AWS credentials if set explicitly in config
    [ -n "$AWS_ACCESS_KEY_ID" ]     && export AWS_ACCESS_KEY_ID
    [ -n "$AWS_SECRET_ACCESS_KEY" ] && export AWS_SECRET_ACCESS_KEY
    export AWS_DEFAULT_REGION="$AWS_REGION"

    CDN_URL="https://${S3_BUCKET}.s3.${AWS_REGION}.amazonaws.com"

    # Install AWS CLI v2 if not present
    if ! command -v aws &>/dev/null; then
        echo "==> Installing AWS CLI v2"
        curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
        unzip -q /tmp/awscliv2.zip -d /tmp/awscli
        sudo /tmp/awscli/aws/install
        rm -rf /tmp/awscliv2.zip /tmp/awscli
    fi

    # Verify credentials before doing any work
    if ! aws sts get-caller-identity &>/dev/null; then
        echo "ERROR: AWS credentials not configured."
        echo "  Option 1: Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY in ship.sh config"
        echo "  Option 2: Run 'aws configure' first"
        echo "  Option 3: Use an IAM instance profile (on EC2)"
        exit 1
    fi

    # Create bucket if it doesn't exist
    if ! aws s3api head-bucket --bucket "$S3_BUCKET" --region "$AWS_REGION" 2>/dev/null; then
        echo "==> Creating S3 bucket: $S3_BUCKET"
        if [ "$AWS_REGION" = "us-east-1" ]; then
            aws s3api create-bucket --bucket "$S3_BUCKET" --region "$AWS_REGION"
        else
            aws s3api create-bucket --bucket "$S3_BUCKET" --region "$AWS_REGION" \
                --create-bucket-configuration LocationConstraint="$AWS_REGION"
        fi

        # Disable block public access so we can set public-read ACL
        aws s3api put-public-access-block --bucket "$S3_BUCKET" \
            --public-access-block-configuration \
            "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"

        # Set bucket CORS policy for browser access
        aws s3api put-bucket-cors --bucket "$S3_BUCKET" --cors-configuration '{
            "CORSRules": [{
                "AllowedOrigins": ["*"],
                "AllowedMethods": ["GET"],
                "AllowedHeaders": ["*"],
                "MaxAgeSeconds": 86400
            }]
        }'

        # Public read bucket policy
        aws s3api put-bucket-policy --bucket "$S3_BUCKET" --policy "{
            \"Version\": \"2012-10-17\",
            \"Statement\": [{
                \"Sid\": \"PublicRead\",
                \"Effect\": \"Allow\",
                \"Principal\": \"*\",
                \"Action\": \"s3:GetObject\",
                \"Resource\": \"arn:aws:s3:::${S3_BUCKET}/*\"
            }]
        }"
    fi

    # Pre-compress assets with brotli (all modern browsers support it).
    # Upload compressed files under the original names with Content-Encoding: br
    # so S3 serves them transparently — the browser decompresses, WASM runtime
    # never knows. Typical result: 24 MB -> 6.3 MB, 552 KB JS -> 101 KB.
    echo "==> Compressing WASM assets with brotli"
    if ! command -v brotli &>/dev/null; then
        sudo apt-get install -y brotli
    fi
    brotli -q 11 -f -o frontend/dist/cv_wasm.wasm.br  frontend/dist/cv_wasm.wasm
    brotli -q 11 -f -o frontend/dist/cv_wasm.js.br    frontend/dist/cv_wasm.js
    brotli -q 11 -f -o frontend/dist/qtloader.js.br   frontend/dist/qtloader.js

    echo "    $(du -h frontend/dist/cv_wasm.wasm | cut -f1) -> $(du -h frontend/dist/cv_wasm.wasm.br | cut -f1) (wasm)"
    echo "    $(du -h frontend/dist/cv_wasm.js   | cut -f1) -> $(du -h frontend/dist/cv_wasm.js.br   | cut -f1) (js)"

    echo "==> Uploading compressed assets to s3://${S3_BUCKET}/"
    aws s3 cp frontend/dist/cv_wasm.wasm.br "s3://${S3_BUCKET}/cv_wasm.wasm" \
        --content-type "application/wasm" --content-encoding "br" --region "$AWS_REGION"
    aws s3 cp frontend/dist/cv_wasm.js.br "s3://${S3_BUCKET}/cv_wasm.js" \
        --content-type "application/javascript" --content-encoding "br" --region "$AWS_REGION"
    aws s3 cp frontend/dist/qtloader.js.br "s3://${S3_BUCKET}/qtloader.js" \
        --content-type "application/javascript" --content-encoding "br" --region "$AWS_REGION"

    echo "==> Verifying S3 Content-Encoding headers"
    for key in cv_wasm.wasm cv_wasm.js qtloader.js; do
        enc=$(aws s3api head-object --bucket "$S3_BUCKET" --key "$key" --region "$AWS_REGION" \
              --query 'ContentEncoding' --output text 2>/dev/null || echo "MISSING")
        size=$(aws s3api head-object --bucket "$S3_BUCKET" --key "$key" --region "$AWS_REGION" \
               --query 'ContentLength' --output text 2>/dev/null || echo "?")
        echo "    $key: ContentEncoding=$enc  ContentLength=${size} bytes"
        if [ "$enc" != "br" ]; then
            echo "  WARNING: $key is NOT brotli-encoded on S3 — browser will receive uncompressed file!"
        fi
    done

    echo "==> Patching cv_wasm.html (loading UI + CDN URLs)"
    CDN_URL="$CDN_URL" python3 << 'PYEOF'
import os, re

cdn = os.environ["CDN_URL"]

with open("frontend/dist/cv_wasm.html", "r") as f:
    html = f.read()

# ── 1. Custom loading styles ──────────────────────────────────────────────────
loader_css = """
    /* Custom WASM loading screen */
    #qtspinner { position: fixed; inset: 0; overflow: hidden; background: #fff; }
    #cv-loader {
        position: absolute; top: 50%; left: 50%;
        transform: translate(-50%, -50%);
        display: flex; flex-direction: column; align-items: center; gap: 10px;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    }
    .cv-bar-track { width: 220px; height: 3px; background: #d0d7de; border-radius: 2px; overflow: hidden; }
    .cv-bar-fill  { height: 100%; width: 30%; background: #1a7f37; border-radius: 2px;
                    animation: cv-slide 1.5s ease-in-out infinite; }
    @keyframes cv-slide { 0%,100% { margin-left: -30%; } 65% { margin-left: 100%; } }
    #cv-status { font-size: 13px; color: #57606a; }
    #cv-bytes  { font-size: 11px; color: #8c959f; min-height: 15px; }
"""
html = html.replace("</style>", loader_css + "  </style>")

# ── 2. Replace qtspinner figure with custom loader ───────────────────────────
loader_html = """<figure style="overflow:visible;" id="qtspinner">
      <div id="cv-loader">
        <div class="cv-bar-track"><div class="cv-bar-fill"></div></div>
        <div id="cv-status">Loading...</div>
        <div id="cv-bytes"></div>
      </div>
    </figure>"""
html = re.sub(r'<figure[^>]*id="qtspinner"[^>]*>.*?</figure>', loader_html, html, flags=re.DOTALL)

# ── 3. Fix init() status reference: Qt uses #qtstatus but our element is #cv-status
html = html.replace("querySelector('#qtstatus')", "querySelector('#cv-status')")

# ── 3. Inject Module config + fetch-progress interceptor ─────────────────────
injection = """    <script>
    var Module = {
        ENV: { API_BASE_URL: location.origin + "/api" },
        locateFile: function(f) { return \"""" + cdn + """/" + f; }
    };
    /* Intercept WASM fetch to show download progress */
    (function() {
        var orig = window.fetch;
        window.fetch = function(url, opts) {
            var u = typeof url === "string" ? url : ((url && url.url) || "");
            if (u.indexOf(".wasm") !== -1) {
                var elStatus = document.getElementById("cv-status");
                var elBytes  = document.getElementById("cv-bytes");
                return orig(url, opts).then(function(resp) {
                    /* Content-Length from S3 = compressed (brotli) size.
                       The browser decompresses transparently before the
                       ReadableStream sees any bytes, so chunk.byteLength
                       reflects decompressed data — do NOT use it as a
                       network-transfer counter. */
                    var clHeader = resp.headers.get("content-length");
                    var networkMB = clHeader
                        ? (parseInt(clHeader) / 1048576).toFixed(1) + " MB"
                        : "";
                    if (elStatus) elStatus.textContent =
                        networkMB ? "Downloading WASM (" + networkMB + " brotli)..."
                                  : "Downloading WASM...";
                    if (elBytes) elBytes.textContent = "";
                    var reader = resp.body.getReader();
                    var chunks = [];
                    var ct = resp.headers.get("Content-Type") || "application/wasm";
                    function pump() {
                        return reader.read().then(function(r) {
                            if (r.done) {
                                if (elStatus) elStatus.textContent = "Initializing...";
                                /* Return plain response — strip Content-Encoding so the
                                   runtime does not attempt a second decompression pass */
                                return new Response(new Blob(chunks), {
                                    status: resp.status,
                                    statusText: resp.statusText,
                                    headers: { "Content-Type": ct }
                                });
                            }
                            chunks.push(r.value);
                            return pump();
                        });
                    }
                    return pump();
                });
            }
            return orig(url, opts);
        };
    })();
    </script>
    <script src=\"""" + cdn + """/cv_wasm.js\"></script>"""

html = html.replace('<script src="cv_wasm.js"></script>', injection)

# ── 4. qtloader.js from CDN ──────────────────────────────────────────────────
html = html.replace('src="qtloader.js"', 'src="' + cdn + '/qtloader.js"')

with open("frontend/dist/cv_wasm.html", "w") as f:
    f.write(html)

print("    cv_wasm.html patched OK")
print("    CDN base:", cdn)
PYEOF

    # Build frontend image AFTER html is patched so the correct html is baked in
    echo "==> Building frontend image with patched HTML"
    docker buildx build --platform "$EC2_PLATFORM" \
        -t cv-frontend:deploy -f frontend/Dockerfile.nginx --load frontend

    # Package both images now that frontend has the patched html
    echo "==> Saving images to /tmp/cv-images.tar.gz"
    docker save cv-backend:deploy cv-frontend:deploy | gzip > /tmp/cv-images.tar.gz
    echo "    Size: $(du -h /tmp/cv-images.tar.gz | cut -f1)"
}

# =============================================================================
# Phase 4: Transfer and deploy to EC2
# =============================================================================
phase_deploy() {
    echo ""
    echo "============================================"
    echo "  Phase 4: Deploy to $EC2_HOST"
    echo "============================================"

    echo "==> Transferring images to EC2"
    scp "${SCP_OPTS[@]}" /tmp/cv-images.tar.gz "$EC2_HOST:/tmp/cv-images.tar.gz"

    echo "==> Transferring compose files to EC2"
    ssh "${SSH_OPTS[@]}" "$EC2_HOST" "mkdir -p ~/cv/infra"
    scp "${SCP_OPTS[@]}" \
        infra/docker-compose.local.yml \
        "$EC2_HOST:~/cv/infra/docker-compose.local.yml"

    echo "==> Deploying on EC2"
    ssh "${SSH_OPTS[@]}" "$EC2_HOST" bash -s "$DOMAIN" "$EMAIL" "$EC2_PLATFORM" <<'REMOTE'
set -e
DOMAIN="$1"
EMAIL="$2"
PLATFORM="$3"

echo "==> Loading Docker images"
docker load < /tmp/cv-images.tar.gz
rm -f /tmp/cv-images.tar.gz

docker tag cv-backend:deploy cv-backend:latest
docker tag cv-frontend:deploy cv-frontend:latest

cd ~/cv

cat > infra/docker-compose.images.yml <<EOF
services:
  backend:
    image: cv-backend:latest
    build: !reset null
  frontend:
    image: cv-frontend:latest
    build: !reset null
EOF

export PLATFORM DOMAIN

docker compose -f infra/docker-compose.local.yml -f infra/docker-compose.images.yml down 2>/dev/null || true

# Bootstrap Let's Encrypt certificate if not already present
if ! docker run --rm -v cv_letsencrypt:/check alpine test -f "/check/live/$DOMAIN/fullchain.pem" 2>/dev/null; then
    echo "==> Obtaining initial Let's Encrypt certificate"

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

    docker compose -f infra/docker-compose.local.yml -f infra/docker-compose.images.yml up -d frontend

    EMAIL_FLAG=""
    if [ -n "$EMAIL" ]; then
        EMAIL_FLAG="--email $EMAIL"
    else
        EMAIL_FLAG="--register-unsafely-without-email"
    fi
    docker run --rm \
        -v cv_letsencrypt:/etc/letsencrypt \
        -v cv_certbot-webroot:/var/www/certbot \
        certbot/certbot certonly --webroot -w /var/www/certbot \
        -d "$DOMAIN" $EMAIL_FLAG --agree-tos --non-interactive --force-renewal

    # Certbot saves to $DOMAIN-0001 if $DOMAIN dir already exists (from self-signed bootstrap).
    # Copy the real cert over the self-signed one so nginx finds it at the expected path.
    docker run --rm -v cv_letsencrypt:/etc/letsencrypt alpine sh -c "
        if [ -d '/etc/letsencrypt/live/${DOMAIN}-0001' ]; then
            cp -L /etc/letsencrypt/live/${DOMAIN}-0001/fullchain.pem /etc/letsencrypt/live/${DOMAIN}/fullchain.pem &&
            cp -L /etc/letsencrypt/live/${DOMAIN}-0001/privkey.pem   /etc/letsencrypt/live/${DOMAIN}/privkey.pem
        fi
    "

    docker compose -f infra/docker-compose.local.yml -f infra/docker-compose.images.yml down
fi

echo "==> Starting all services"
docker compose -f infra/docker-compose.local.yml -f infra/docker-compose.images.yml up -d

echo ""
echo "Site is live at https://$DOMAIN"
REMOTE

    rm -f /tmp/cv-images.tar.gz
}

# =============================================================================
# Main
# =============================================================================
echo "============================================"
echo "  CV Deploy Pipeline"
echo "  Domain:   $DOMAIN"
echo "  EC2:      $EC2_HOST"
echo "  Platform: $EC2_PLATFORM"
echo "============================================"

phase_bootstrap
phase_build
phase_cdn
phase_deploy

echo ""
echo "============================================"
echo "  Done! https://$DOMAIN"
echo "============================================"
