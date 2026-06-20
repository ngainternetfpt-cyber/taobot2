# GoClaw — Deployment Repo

> Repo quản lý deployment của **GoClaw AI Agent Platform** lên VPS tại domain [`agenttwo.nguyentannga.name.vn`](https://agenttwo.nguyentannga.name.vn)

## 🌐 Links

| | URL |
|---|---|
| **Web UI** | https://agenttwo.nguyentannga.name.vn |
| **GoClaw Upstream** | https://github.com/nextlevelbuilder/goclaw |
| **GoClaw Docs** | https://docs.goclaw.sh |

## 📁 Cấu trúc repo

```
taobot2/
├── .github/
│   └── workflows/
│       └── deploy.yml          # GitHub Actions CI/CD — auto deploy khi push
├── nginx/
│   └── goclaw.conf             # Nginx reverse proxy config (reference)
├── scripts/
│   ├── setup-vps.sh            # Script cài đặt VPS từ đầu (chạy 1 lần)
│   ├── deploy.sh               # Deploy thủ công lên VPS
│   └── update.sh               # Update GoClaw lên phiên bản mới nhất
├── docker-compose.override.yml # Production Docker config (ports, restart, healthcheck)
├── .gitignore
└── README.md
```

## 🚀 Hướng dẫn triển khai

### Lần đầu (Setup VPS)

1. **SSH vào VPS:**
   ```bash
   ssh root@161.248.146.211
   ```

2. **Chạy setup script:**
   ```bash
   curl -fsSL https://raw.githubusercontent.com/ngainternetfpt-cyber/taobot2/main/scripts/setup-vps.sh | bash
   ```
   Script sẽ tự động:
   - Cài Docker, Nginx, Certbot
   - Clone GoClaw upstream repo
   - Sinh secrets (.env)
   - Khởi chạy GoClaw + PostgreSQL
   - Cấu hình Nginx reverse proxy
   - Cấp SSL Let's Encrypt
   - Tạo SSH deploy key cho GitHub Actions

3. **Copy private key** từ output script → GitHub Secret `VPS_SSH_KEY`

### Cấu hình GitHub Secrets

Vào `Settings → Secrets and variables → Actions` của repo này:

| Secret | Giá trị |
|---|---|
| `VPS_HOST` | `161.248.146.211` |
| `VPS_USER` | `root` |
| `VPS_PORT` | `22` |
| `VPS_SSH_KEY` | Private key từ VPS (output setup script) |
| `VPS_DEPLOY_PATH` | `/opt/goclaw` |

### CI/CD tự động

Sau khi setup GitHub Secrets xong, mỗi khi **push lên nhánh `main`** hoặc `master`:
- GitHub Actions sẽ tự động SSH vào VPS
- Pull image GoClaw mới nhất
- Restart container (zero-downtime)
- Health check sau deploy

### Deploy thủ công

```bash
# Từ máy local (cần SSH access)
bash scripts/deploy.sh

# Hoặc trigger workflow thủ công trên GitHub Actions tab
```

## 🔧 Vận hành VPS

```bash
# SSH vào VPS
ssh root@161.248.146.211

# Xem trạng thái containers
cd /opt/goclaw
docker compose -f docker-compose.yml -f docker-compose.postgres.yml -f docker-compose.override.yml ps

# Xem logs GoClaw
docker compose logs -f goclaw

# Xem logs PostgreSQL
docker compose logs -f postgres

# Restart GoClaw
docker compose -f docker-compose.yml -f docker-compose.postgres.yml -f docker-compose.override.yml restart goclaw

# Restart tất cả
docker compose -f docker-compose.yml -f docker-compose.postgres.yml -f docker-compose.override.yml restart

# Stop tất cả
docker compose -f docker-compose.yml -f docker-compose.postgres.yml -f docker-compose.override.yml down

# Update lên phiên bản mới nhất
bash scripts/update.sh
```

## 🔐 Bảo mật

- ⚠️ File `.env` chứa secrets — **KHÔNG bao giờ commit lên Git**
- Nginx chỉ expose port 80/443 ra internet, GoClaw bind localhost:18790
- UFW chỉ cho phép SSH, 80, 443
- SSL/TLS tự động gia hạn qua Certbot

## 📊 Monitoring

- Health check tự động chạy mỗi 5 phút qua cron
- Logs: `/var/log/goclaw-health.log`
- Nginx logs: `/var/log/nginx/goclaw_*.log`

## 🤖 GoClaw — First-time Setup

Sau khi cài đặt, truy cập https://agenttwo.nguyentannga.name.vn:

1. **Đăng ký tài khoản Admin** đầu tiên
2. **Cấu hình LLM Provider** (OpenRouter, OpenAI, Anthropic, Gemini...)
3. **Tạo Agent đầu tiên**
4. Kết nối các kênh (Telegram, Discord, Zalo, Slack...)
5. Bắt đầu sử dụng!

> 📖 Tham khảo: [docs.goclaw.sh](https://docs.goclaw.sh)
