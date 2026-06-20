#!/usr/bin/env bash
# =============================================================================
# setup-vps.sh — Script cài đặt GoClaw trên VPS Ubuntu 24 từ đầu
# Domain: agenttwo.nguyentannga.name.vn
# =============================================================================
# CÁCH DÙNG:
#   SSH vào VPS rồi chạy:
#   curl -fsSL https://raw.githubusercontent.com/ngainternetfpt-cyber/taobot2/main/scripts/setup-vps.sh | bash
#   HOẶC:
#   bash scripts/setup-vps.sh
# =============================================================================

set -euo pipefail

# ── Cấu hình ──────────────────────────────────────────────────────────────────
DEPLOY_PATH="/opt/goclaw"
DOMAIN="agenttwo.nguyentannga.name.vn"
GOCLAW_UPSTREAM="https://github.com/nextlevelbuilder/goclaw.git"
GOCLAW_PORT="18790"
NGINX_CONF="/etc/nginx/sites-available/goclaw"

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log_info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
log_step()    { echo -e "\n${BOLD}${BLUE}━━━ $* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

# ── Kiểm tra root ─────────────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && log_error "Script này phải chạy với quyền root (sudo hoặc root user)"

echo -e "${BOLD}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║          GoClaw VPS Setup Script                        ║"
echo "║          Domain: ${DOMAIN}          ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ══════════════════════════════════════════════════════════════════════════════
log_step "BƯỚC 1: Update hệ thống & Cài packages"
# ══════════════════════════════════════════════════════════════════════════════
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq
apt-get install -y -qq \
    curl git openssl ufw \
    nginx certbot python3-certbot-nginx \
    htop jq unzip rsync
log_success "Packages đã được cài đặt"

# ══════════════════════════════════════════════════════════════════════════════
log_step "BƯỚC 2: Cài Docker Engine"
# ══════════════════════════════════════════════════════════════════════════════
if ! command -v docker &>/dev/null; then
    log_info "Đang cài Docker Engine..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
    log_success "Docker đã được cài đặt"
else
    log_success "Docker đã tồn tại: $(docker --version)"
fi

if ! docker compose version &>/dev/null 2>&1; then
    log_info "Cài Docker Compose plugin..."
    apt-get install -y -qq docker-compose-plugin
fi
log_success "Docker Compose: $(docker compose version --short)"

# ══════════════════════════════════════════════════════════════════════════════
log_step "BƯỚC 3: Cấu hình UFW Firewall"
# ══════════════════════════════════════════════════════════════════════════════
ufw --force reset > /dev/null 2>&1
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp   comment "HTTP - Nginx"
ufw allow 443/tcp  comment "HTTPS - Nginx"
ufw --force enable
log_success "UFW firewall đã được cấu hình:"
ufw status numbered

# ══════════════════════════════════════════════════════════════════════════════
log_step "BƯỚC 4: Clone GoClaw upstream repo"
# ══════════════════════════════════════════════════════════════════════════════
if [ -d "$DEPLOY_PATH/.git" ]; then
    log_warn "Thư mục $DEPLOY_PATH đã tồn tại, pulling latest..."
    cd "$DEPLOY_PATH"
    git pull origin main || git pull origin master || true
else
    log_info "Clone GoClaw từ upstream..."
    git clone "$GOCLAW_UPSTREAM" "$DEPLOY_PATH"
fi
log_success "GoClaw source đã được clone vào $DEPLOY_PATH"

# ══════════════════════════════════════════════════════════════════════════════
log_step "BƯỚC 5: Tạo file .env với secrets"
# ══════════════════════════════════════════════════════════════════════════════
cd "$DEPLOY_PATH"

if [ -f ".env" ]; then
    log_warn ".env đã tồn tại — bỏ qua để không ghi đè secrets"
else
    log_info "Sinh secrets tự động..."

    GATEWAY_TOKEN=$(openssl rand -hex 32)
    ENCRYPTION_KEY=$(openssl rand -hex 32)
    POSTGRES_PASS=$(openssl rand -hex 16)

    cat > .env << EOF
# ======================================================
# GoClaw Production Environment
# ======================================================
# CẢNH BÁO: KHÔNG commit file này lên Git!
# Generated: $(date '+%Y-%m-%d %H:%M:%S')

# --- Gateway (QUAN TRỌNG - Lưu lại!) ---
GOCLAW_GATEWAY_TOKEN=${GATEWAY_TOKEN}
GOCLAW_ENCRYPTION_KEY=${ENCRYPTION_KEY}

# --- GoClaw App ---
GOCLAW_HOST=0.0.0.0
GOCLAW_PORT=${GOCLAW_PORT}

# --- PostgreSQL ---
POSTGRES_USER=goclaw
POSTGRES_PASSWORD=${POSTGRES_PASS}
POSTGRES_DB=goclaw
POSTGRES_PORT=5432

# --- LLM Provider API Keys ---
# Điền vào các key bạn sử dụng qua GoClaw Dashboard
# (Không bắt buộc điền trực tiếp vào đây)
# OPENROUTER_API_KEY=
# OPENAI_API_KEY=
# ANTHROPIC_API_KEY=
# GOOGLE_AI_API_KEY=
EOF

    chmod 600 .env
    log_success ".env đã được tạo với secrets tự động"
    echo ""
    echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║  ⚠️  LƯU CÁC THÔNG TIN SAU VÀO CHỖ AN TOÀN!             ║${NC}"
    echo -e "${YELLOW}╠═══════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║  Gateway Token:    ${GATEWAY_TOKEN:0:20}...${NC}"
    echo -e "${YELLOW}║  Encryption Key:   ${ENCRYPTION_KEY:0:20}...${NC}"
    echo -e "${YELLOW}║  Postgres Pass:    ${POSTGRES_PASS}${NC}"
    echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
fi

# ══════════════════════════════════════════════════════════════════════════════
log_step "BƯỚC 6: Tạo docker-compose.override.yml"
# ══════════════════════════════════════════════════════════════════════════════
cat > "$DEPLOY_PATH/docker-compose.override.yml" << 'OVERRIDE_EOF'
services:
  goclaw:
    image: ghcr.io/nextlevelbuilder/goclaw:latest
    container_name: goclaw
    restart: unless-stopped
    ports:
      - "127.0.0.1:18790:18790"
    env_file:
      - .env
    environment:
      - GOCLAW_HOST=0.0.0.0
      - GOCLAW_PORT=18790
    volumes:
      - goclaw_data:/app/data
    depends_on:
      postgres:
        condition: service_healthy
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "5"
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://localhost:18790/ || exit 0"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  postgres:
    image: pgvector/pgvector:pg18
    container_name: goclaw_postgres
    restart: unless-stopped
    ports:
      - "127.0.0.1:5432:5432"
    env_file:
      - .env
    environment:
      - POSTGRES_USER=${POSTGRES_USER:-goclaw}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=${POSTGRES_DB:-goclaw}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    logging:
      driver: "json-file"
      options:
        max-size: "5m"
        max-file: "3"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-goclaw} -d ${POSTGRES_DB:-goclaw}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s

volumes:
  goclaw_data:
    driver: local
  postgres_data:
    driver: local
OVERRIDE_EOF
log_success "docker-compose.override.yml đã được tạo"

# ══════════════════════════════════════════════════════════════════════════════
log_step "BƯỚC 7: Khởi chạy GoClaw + PostgreSQL"
# ══════════════════════════════════════════════════════════════════════════════
cd "$DEPLOY_PATH"
log_info "Pulling Docker images..."
docker compose -f docker-compose.yml -f docker-compose.postgres.yml -f docker-compose.override.yml pull

log_info "Starting containers..."
docker compose -f docker-compose.yml -f docker-compose.postgres.yml -f docker-compose.override.yml up -d

log_info "Waiting 30s for GoClaw to initialize..."
sleep 30

log_info "Container status:"
docker compose -f docker-compose.yml -f docker-compose.postgres.yml -f docker-compose.override.yml ps

# ══════════════════════════════════════════════════════════════════════════════
log_step "BƯỚC 8: Cấu hình Nginx Reverse Proxy"
# ══════════════════════════════════════════════════════════════════════════════

# Xóa default site nếu còn
rm -f /etc/nginx/sites-enabled/default

cat > "$NGINX_CONF" << NGINX_EOF
# Nginx config cho GoClaw — ${DOMAIN}
# Certbot sẽ tự động bổ sung SSL section

server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    location /.well-known/acme-challenge/ {
        root /var/www/html;
        try_files \$uri =404;
    }

    location / {
        proxy_pass http://127.0.0.1:${GOCLAW_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade    \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host               \$host;
        proxy_set_header X-Real-IP          \$remote_addr;
        proxy_set_header X-Forwarded-For    \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto  \$scheme;
        proxy_read_timeout   300s;
        proxy_connect_timeout 75s;
        proxy_send_timeout   300s;
        proxy_buffering off;
        proxy_cache off;
    }
}
NGINX_EOF

ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/goclaw
nginx -t
systemctl reload nginx
log_success "Nginx đã được cấu hình và reload"

# ══════════════════════════════════════════════════════════════════════════════
log_step "BƯỚC 9: Cấp SSL với Let's Encrypt"
# ══════════════════════════════════════════════════════════════════════════════
log_info "Kiểm tra domain trỏ về IP này..."
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "unknown")
log_info "IP VPS hiện tại: $SERVER_IP"

log_info "Cấp SSL certificate cho $DOMAIN..."
certbot --nginx \
    -d "$DOMAIN" \
    --non-interactive \
    --agree-tos \
    --email "admin@nguyentannga.name.vn" \
    --redirect \
    --keep-until-expiring \
    && log_success "SSL certificate đã được cấp thành công!" \
    || log_warn "Certbot gặp lỗi — kiểm tra domain DNS đã trỏ về IP VPS chưa"

# ══════════════════════════════════════════════════════════════════════════════
log_step "BƯỚC 10: Tạo SSH Deploy Key cho GitHub Actions"
# ══════════════════════════════════════════════════════════════════════════════
DEPLOY_KEY_FILE="/root/.ssh/goclaw_deploy_key"

if [ ! -f "$DEPLOY_KEY_FILE" ]; then
    log_info "Tạo SSH deploy key..."
    ssh-keygen -t ed25519 -C "github-actions-goclaw-deploy" \
        -f "$DEPLOY_KEY_FILE" -N ""

    # Thêm public key vào authorized_keys
    cat "${DEPLOY_KEY_FILE}.pub" >> /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    log_success "Deploy key đã được tạo"
fi

echo ""
echo -e "${BOLD}${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║  🔑 PRIVATE KEY cho GitHub Actions Secret VPS_SSH_KEY:   ║${NC}"
echo -e "${BOLD}${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
cat "${DEPLOY_KEY_FILE}"

# ══════════════════════════════════════════════════════════════════════════════
log_step "BƯỚC 11: Cài đặt Health Check Cron"
# ══════════════════════════════════════════════════════════════════════════════
cat > /opt/goclaw/healthcheck.sh << 'HEALTH_EOF'
#!/bin/bash
# GoClaw Health Check — chạy mỗi 5 phút qua cron
LOG="/var/log/goclaw-health.log"
DEPLOY_PATH="/opt/goclaw"

is_up() {
    curl -sf --max-time 5 http://127.0.0.1:18790/ > /dev/null 2>&1
}

if ! is_up; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  GoClaw unhealthy, restarting..." >> "$LOG"
    cd "$DEPLOY_PATH"
    docker compose -f docker-compose.yml -f docker-compose.postgres.yml \
        -f docker-compose.override.yml restart goclaw >> "$LOG" 2>&1
    sleep 15
    if is_up; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ GoClaw recovered" >> "$LOG"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ GoClaw failed to recover" >> "$LOG"
    fi
fi
HEALTH_EOF

chmod +x /opt/goclaw/healthcheck.sh

# Thêm cron job
(crontab -l 2>/dev/null | grep -v "goclaw/healthcheck" ; \
 echo "*/5 * * * * /opt/goclaw/healthcheck.sh") | crontab -
log_success "Health check cron đã được cài đặt (mỗi 5 phút)"

# ══════════════════════════════════════════════════════════════════════════════
log_step "HOÀN THÀNH!"
# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}${GREEN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              ✅ GoClaw đã được cài đặt thành công!          ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  🌐 Web UI:    https://${DOMAIN}    ║"
echo "║  🔌 API:       https://${DOMAIN}/api/v1 ║"
echo "║  📁 Deploy:    ${DEPLOY_PATH}                    ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  📋 Các bước tiếp theo:                                      ║"
echo "║  1. Copy private key ở trên → GitHub Secret: VPS_SSH_KEY    ║"
echo "║  2. Vào https://${DOMAIN} → Setup admin account ║"
echo "║  3. Cấu hình LLM Provider (OpenRouter, OpenAI, v.v.)        ║"
echo "║  4. Tạo Agent đầu tiên và bắt đầu sử dụng!                  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Final status
echo "Container Status:"
cd "$DEPLOY_PATH"
docker compose -f docker-compose.yml -f docker-compose.postgres.yml -f docker-compose.override.yml ps
