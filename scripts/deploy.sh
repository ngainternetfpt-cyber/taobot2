#!/usr/bin/env bash
# =============================================================================
# deploy.sh — Script deploy thủ công GoClaw lên VPS
# Dùng khi muốn deploy mà không cần GitHub Actions
# =============================================================================
# CÁCH DÙNG:
#   bash scripts/deploy.sh
# =============================================================================

set -euo pipefail

VPS_HOST="161.248.146.211"
VPS_USER="root"
VPS_PORT="22"
DEPLOY_PATH="/opt/goclaw"

GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
log_info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }

echo -e "${BOLD}🚀 Manual Deploy GoClaw to VPS${NC}"
echo "Host: $VPS_HOST | Path: $DEPLOY_PATH"
echo ""

log_info "Connecting to VPS and deploying..."

ssh -p "$VPS_PORT" "${VPS_USER}@${VPS_HOST}" << REMOTE
    set -e
    cd "$DEPLOY_PATH"
    echo "📥 Pulling latest image..."
    docker compose -f docker-compose.yml -f docker-compose.postgres.yml -f docker-compose.override.yml pull goclaw
    echo "🔄 Restarting GoClaw..."
    docker compose -f docker-compose.yml -f docker-compose.postgres.yml -f docker-compose.override.yml up -d --no-deps goclaw
    echo "⏳ Waiting 15s..."
    sleep 15
    echo "📊 Status:"
    docker compose ps
    echo "✅ Deploy complete!"
REMOTE

log_success "Deployment finished!"
echo "🌐 Visit: https://agenttwo.nguyentannga.name.vn"
