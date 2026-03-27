#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# LocalIntel — Full Setup Script for New Machine
# Run from: ~/Nextcloud/localintel/main/localintel/webapp/
#
# Usage:
#   chmod +x setup.sh
#   ./setup.sh
#
# What it does:
#   1. Installs Docker Engine + Docker Compose (if not present)
#   2. Adds your user to the docker group (no more sudo for docker)
#   3. Builds and starts all 4 containers (db, api, nginx, tunnel)
#   4. Waits for PostGIS to be healthy
#   5. Runs the data ingestion pipeline (panel + inequality metrics)
#   6. Prints service URLs
# ──────────────────────────────────────────────────────────────────────────────

set -euo pipefail

WEBAPP_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$WEBAPP_DIR"

echo "╔══════════════════════════════════════════════════╗"
echo "║   LocalIntel — SSA Inequality Mapping Engine     ║"
echo "║   Setup Script                                   ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "Working directory: $WEBAPP_DIR"
echo ""

# ── Step 1: Check / Install Docker ────────────────────────────────────────────

if command -v docker &>/dev/null; then
    echo "✓ Docker already installed: $(docker --version)"
else
    echo "Installing Docker Engine..."
    # Remove old packages
    for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
        sudo apt-get remove -y "$pkg" 2>/dev/null || true
    done

    # Add Docker's official GPG key and repo
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Detect distro (works for Ubuntu and Linux Mint)
    if [ -f /etc/upstream-release/lsb-release ]; then
        # Linux Mint: use upstream Ubuntu codename
        DISTRO_CODENAME=$(grep DISTRIB_CODENAME /etc/upstream-release/lsb-release | cut -d= -f2)
    else
        DISTRO_CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
    fi

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $DISTRO_CODENAME stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    echo "✓ Docker installed: $(docker --version)"
fi

# ── Step 2: Ensure Docker daemon is running ───────────────────────────────────

if ! docker info &>/dev/null 2>&1; then
    echo "Starting Docker daemon..."
    sudo systemctl start docker
    sudo systemctl enable docker
    echo "✓ Docker daemon started"
else
    echo "✓ Docker daemon is running"
fi

# ── Step 3: Add user to docker group (avoids sudo for future commands) ────────

if ! groups "$USER" | grep -q '\bdocker\b'; then
    echo "Adding $USER to docker group..."
    sudo usermod -aG docker "$USER"
    echo "⚠  You were added to the docker group."
    echo "   If docker commands fail with 'permission denied', run:"
    echo "   newgrp docker"
    echo "   then re-run this script."
    echo ""
fi

# ── Step 4: Build and start containers ────────────────────────────────────────

echo ""
echo "Building and starting Docker containers..."
echo "(This may take 2-5 minutes on first run)"
echo ""

docker compose up -d --build

echo ""
echo "Waiting for PostGIS to be healthy..."
RETRIES=30
until docker compose exec -T db pg_isready -U localintel &>/dev/null; do
    RETRIES=$((RETRIES - 1))
    if [ $RETRIES -le 0 ]; then
        echo "✗ PostGIS did not become healthy in time"
        echo "  Check: docker compose logs db"
        exit 1
    fi
    sleep 2
done
echo "✓ PostGIS is ready"

# ── Step 5: Run data ingestion ────────────────────────────────────────────────

echo ""
echo "Running data ingestion (panel.csv.gz → PostgreSQL)..."
echo "This will insert ~600K observations and compute ~46K inequality metrics."
echo ""

docker compose exec -T api python -m backend.ingest \
    --panel /app/data/panel.csv.gz \
    --drop

echo ""
echo "✓ Data ingestion complete"

# ── Step 6: Status report ─────────────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║   All services are running!                      ║"
echo "╠══════════════════════════════════════════════════╣"
echo "║                                                  ║"
echo "║   Dashboard:  http://localhost:8090               ║"
echo "║   API:        http://localhost:8001/api/health    ║"
echo "║   PostGIS:    localhost:5433                      ║"
echo "║                                                  ║"
echo "║   Useful commands:                               ║"
echo "║     docker compose ps          # status          ║"
echo "║     docker compose logs -f     # live logs       ║"
echo "║     docker compose down        # stop all        ║"
echo "║     docker compose up -d       # restart         ║"
echo "║                                                  ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
