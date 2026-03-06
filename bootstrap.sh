#!/bin/bash
set -euo pipefail

# bootstrap.sh — install all dependencies on a clean Ubuntu host

echo "==> Updating package index"
sudo apt-get update

echo "==> Installing prerequisites"
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    git \
    openssl \
    sed \
    qemu-user-static binfmt-support

echo "==> Adding Docker GPG key and repository"
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "==> Installing Docker Engine and Compose plugin"
sudo apt-get update
sudo apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

echo "==> Enabling and starting Docker"
sudo systemctl enable --now docker

echo "==> Registering QEMU binfmt handlers with fix-binary flag for Docker builds"
# The apt-installed qemu-user-static registers handlers without the F (fix-binary)
# flag, which means Docker build can't find the QEMU binary inside container
# namespaces. We need to re-register with flag=F so the kernel opens the
# interpreter at registration time rather than at execve time.
sudo systemctl restart binfmt-support
# Re-register x86_64 handler with fix-binary (F) flag
if [ -f /proc/sys/fs/binfmt_misc/qemu-x86_64 ]; then
    echo -1 | sudo tee /proc/sys/fs/binfmt_misc/qemu-x86_64 > /dev/null
fi
QEMU_BIN=$(command -v qemu-x86_64-static 2>/dev/null || echo /usr/bin/qemu-x86_64-static)
echo ":qemu-x86_64:M::\\x7fELF\\x02\\x01\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\x3e\\x00:\\xff\\xff\\xff\\xff\\xff\\xfe\\xfe\\x00\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff\\xff:${QEMU_BIN}:F" \
    | sudo tee /proc/sys/fs/binfmt_misc/register > /dev/null
echo "    qemu-x86_64 handler registered with fix-binary flag"

echo "==> Adding current user to docker group (takes effect on next login)"
sudo usermod -aG docker "$USER"

echo "==> Verifying installation"
docker --version
docker compose version

echo ""
echo "Done. Log out and back in (or run 'newgrp docker') for group changes to take effect."
echo "Then run: ./build.sh"
