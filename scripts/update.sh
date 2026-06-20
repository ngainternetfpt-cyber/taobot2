#!/usr/bin/env bash
# =============================================================================
# update.sh — Script update GoClaw lên phiên bản mới nhất
# =============================================================================
set -euo pipefail

VPS_HOST="161.248.146.211"
VPS_USER="root"
VPS_PORT="22"
DEPLOY_PATH="/opt/goclaw"

echo "🔄 Updating GoClaw to latest version..."

ssh -p "$VPS_PORT" "${VPS_USER}@${VPS_HOST}" << REMOTE
    set -e
    cd "$DEPLOY_PATH"

    echo "📥 Pulling latest upstream changes..."
    git pull origin main || git pull origin master || true

    echo "📥 Pulling latest Docker image..."
    docker compose -f docker-compose.yml -f docker-compose.postgres.yml -f docker-compose.override.yml pull

    echo "🔄 Restarting all services..."
    docker compose -f docker-compose.yml -f docker-compose.postgres.yml -f docker-compose.override.yml up -d

    echo "⏳ Waiting 30s for full startup..."
    sleep 30

    echo "📊 Current status:"
    docker compose ps

    echo "🧹 Cleaning old images..."
    docker image prune -f

    echo "✅ Update complete!"
REMOTE

echo "✅ GoClaw updated successfully!"
echo "🌐 https://agenttwo.nguyentannga.name.vn"
