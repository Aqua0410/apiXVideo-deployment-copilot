# 🚀 FastAPI Video API - Deployment Guide

Universal deployment scripts for any Hostinger VPS or Linux server running OpenLiteSpeed.

## ⚡ Quick Start (5 minutes)

### First-Time Deployment

```bash
# 1. SSH into your new Hostinger VPS
ssh root@YOUR_SERVER_IP

# 2. Copy project to server
git clone <your-repo-url> /var/www/apiXVideo
cd /var/www/apiXVideo

# 3. Make scripts executable
chmod +x deployment/*.sh

# 4. Run deployment (interactive)
./deployment/deploy_openlitespeed.sh

# Or non-interactive (uses config file):
./deployment/deploy_openlitespeed.sh --fast
```

### Emergency Server Recovery (2 minutes)

```bash
# On new server - single command
git clone <your-repo-url> /var/www/apiXVideo && \
cd /var/www/apiXVideo && \
chmod +x deployment/*.sh && \
./deployment/deploy_openlitespeed.sh --fast
```

## 📋 Configuration Files

### `deployment/deploy.conf`

**Edit this ONCE, then you can redeploy to any server!**

```bash
# Project Configuration
DEPLOY_DIR="/var/www/fastapi-video-api"
SERVICE_NAME="fastapi-video-api"
INTERNAL_PORT="8000"
DOMAIN_NAME="yourdomain.com"

# API Security
SESSION_SECRET="your-api-key-here"

# Worker Configuration
WORKER_MULTIPLIER="2"    # CPU_count × 2 workers
MAX_REQUESTS="5000"
TIMEOUT="60"
```

**Customize before first deployment!**

## 🔧 Deployment Scripts

### `deploy_openlitespeed.sh`

Universal deployment script that works with any Linux server.

**Modes:**

```bash
# Interactive mode (default) - asks for confirmations
./deploy_openlitespeed.sh

# Fast mode (non-interactive) - uses config file
./deploy_openlitespeed.sh --fast

# Custom config file
./deploy_openlitespeed.sh --config custom.conf --fast

# Help
./deploy_openlitespeed.sh --help
```

**What it does:**
- ✅ Detects OS (AlmaLinux, CentOS, Ubuntu, Debian)
- ✅ Installs Python 3.11
- ✅ Creates virtual environment
- ✅ Installs all dependencies
- ✅ Creates `.env` file with API key
- ✅ Sets up gunicorn configuration
- ✅ Creates systemd service
- ✅ Starts the service

### `quick-restore.sh`

One-command recovery to a new server.

```bash
# From project root on new server
./deployment/quick-restore.sh
```

## 📖 Usage Examples

### Example 1: Initial Setup (Interactive)

```bash
ssh root@147.93.27.148
git clone https://github.com/yourname/apiXVideo /var/www/apiXVideo
cd /var/www/apiXVideo

# Edit config if needed
nano deployment/deploy.conf

# Run interactive deployment
chmod +x deployment/deploy_openlitespeed.sh
./deployment/deploy_openlitespeed.sh
```

### Example 2: Fast Setup (Non-Interactive)

```bash
ssh root@147.93.27.148
git clone https://github.com/yourname/apiXVideo /var/www/apiXVideo
cd /var/www/apiXVideo

# Uses deploy.conf settings
./deployment/deploy_openlitespeed.sh --fast
```

### Example 3: Emergency Migration to New Server

```bash
# Complete one-liner (copy-paste to new server)
git clone https://github.com/yourname/apiXVideo /var/www/apiXVideo && \
cd /var/www/apiXVideo && \
chmod +x deployment/*.sh && \
./deployment/deploy_openlitespeed.sh --fast
```

**Result: Deployed in ~5 minutes!**

## 🔍 After Deployment

### Verify Service is Running

```bash
sudo systemctl status fastapi-video-api
```

### View Live Logs

```bash
sudo journalctl -u fastapi-video-api -f
```

### Test API (Local)

```bash
# Health check
curl http://localhost:8000/

# With API key
curl -H "X-API-Key: your-api-key" http://localhost:8000/files
```

### Restart Service

```bash
sudo systemctl restart fastapi-video-api
```

### Stop Service

```bash
sudo systemctl stop fastapi-video-api
```

## 🌐 Configure CyberPanel

Once deployed, configure OpenLiteSpeed reverse proxy:

### Step 1: Add External App

1. Login to CyberPanel (WebAdmin)
2. Go to: **Server Configuration → External App**
3. Click **Add External App**
   - **Name:** fastapi-video-api
   - **Address:** 127.0.0.1
   - **Port:** 8000 (or your INTERNAL_PORT)
4. Click **Save**

### Step 2: Add Rewrite Rule

1. Go to: **Websites → Your Domain**
2. Go to: **Rewrite Rules**
3. Add this:

```
RewriteEngine On
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule ^(.*)$ http://127.0.0.1:8000/$1 [P,L]
```

Replace `8000` with your `INTERNAL_PORT` if different.

### Step 3: Enable SSL

1. Go to: **SSL → Manage SSL**
2. Select your domain
3. Click **Issue SSL** (or Use Existing)

### Step 4: Restart OpenLiteSpeed

1. Dashboard → **Service Manager**
2. Click **Restart OpenLiteSpeed**

## 🔐 API Usage

### Get Your API Key

After deployment, get it from:

```bash
cat /var/www/fastapi-video-api/CREDENTIALS.txt
```

### Make API Requests

```bash
# Health check
curl https://yourdomain.com/

# List all files
curl -H "X-API-Key: YOUR_API_KEY" https://yourdomain.com/files

# Get reels (paginated)
curl -H "X-API-Key: YOUR_API_KEY" \
  "https://yourdomain.com/reels?page=1&limit=20"

# Delete a video
curl -X DELETE \
  -H "X-API-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"video_url": "https://example.com/video.mp4"}' \
  https://yourdomain.com/videos

# Refresh reels data
curl -X POST \
  -H "X-API-Key: YOUR_API_KEY" \
  https://yourdomain.com/refresh-reels
```

## ⚙️ Configuration Details

### Environment Variables

Auto-generated in `.env` during deployment:

- `SESSION_SECRET` - Your API key
- `LOG_LEVEL` - Logging level (default: info)
- `INTERNAL_PORT` - Port for gunicorn (set in systemd)
- `WORKER_MULTIPLIER` - Worker calculation factor

### Systemd Service

Location: `/etc/systemd/system/fastapi-video-api.service`

```bash
# Reload after manual edits
sudo systemctl daemon-reload

# View full service file
sudo systemctl cat fastapi-video-api
```

### Gunicorn Configuration

Location: `/var/www/fastapi-video-api/gunicorn_conf.py`

Auto-calculated workers: `CPU_count × WORKER_MULTIPLIER`

Example: 8 vCPU × 2 = 16 workers

## 🐛 Troubleshooting

### Service won't start

```bash
# Check logs for errors
sudo journalctl -u fastapi-video-api -n 50

# Check if port is in use
sudo ss -tuln | grep :8000

# Verify permissions
ls -la /var/www/fastapi-video-api/
```

### Port already in use

Change `INTERNAL_PORT` in `deploy.conf` and redeploy:

```bash
# Edit config
nano deployment/deploy.conf
# Change INTERNAL_PORT to 8001, 8002, etc.

# Redeploy
./deployment/deploy_openlitespeed.sh --fast
```

### API key not working

Check that you're using the correct key:

```bash
cat /var/www/fastapi-video-api/.env | grep SESSION_SECRET
```

Include in header as:
```bash
curl -H "X-API-Key: YOUR_KEY" https://yourdomain.com/
```

### Check CPU and workers

```bash
# Count CPUs
nproc

# See running workers
ps aux | grep gunicorn
```

## 📦 Directory Structure

After deployment:

```
/var/www/fastapi-video-api/
├── main.py                 # FastAPI application
├── requirements.txt        # Python dependencies
├── .env                    # Environment variables (KEEP SECURE!)
├── .env.systemd           # Systemd-compatible env file
├── gunicorn_conf.py       # Gunicorn configuration
├── venv/                  # Python virtual environment
├── data/                  # Video data
│   ├── categoryvideo/     # Category data (0.json-54.json)
│   ├── reelsvideo/        # Reels data
│   └── livestream/        # Livestream data
├── deployment/            # Deployment scripts
│   ├── deploy.conf
│   ├── deploy_openlitespeed.sh
│   ├── quick-restore.sh
│   └── CREDENTIALS.txt    # API key (DELETE AFTER SAVING!)
└── CREDENTIALS.txt        # Full credentials backup
```

## 🔄 How to Migrate to New Server

1. **Backup configuration:**
   ```bash
   # From old server
   scp root@old-server:/var/www/fastapi-video-api/deployment/deploy.conf ./
   scp root@old-server:/var/www/fastapi-video-api/.env ./
   ```

2. **Commit to git:**
   ```bash
   git add deployment/deploy.conf
   git commit -m "deployment config"
   git push
   ```

3. **Deploy to new server:**
   ```bash
   # One command!
   ssh root@new-server 'bash -c "git clone <repo> /var/www/apiXVideo && cd /var/www/apiXVideo && chmod +x deployment/*.sh && ./deployment/deploy_openlitespeed.sh --fast"'
   ```

## 💡 Best Practices

1. **Version control your config:**
   ```bash
   git add deployment/deploy.conf
   git commit -m "Update deployment config"
   ```

2. **Backup credentials:**
   ```bash
   # After deployment
   scp root@server:/var/www/fastapi-video-api/CREDENTIALS.txt ~/secure/
   ```

3. **Monitor logs regularly:**
   ```bash
   sudo journalctl -u fastapi-video-api -f
   ```

4. **Keep data backed up:**
   ```bash
   # Regular backups
   scp -r root@server:/var/www/fastapi-video-api/data/ ~/backups/
   ```

5. **Test recovery process:**
   ```bash
   # Practice quick-restore periodically
   ./deployment/quick-restore.sh
   ```

## 📞 Support

For issues:

1. Check logs: `sudo journalctl -u fastapi-video-api -f`
2. Verify config: `cat deployment/deploy.conf`
3. Test endpoint: `curl http://localhost:8000/`
4. Check permissions: `ls -la /var/www/fastapi-video-api/`

---

**Last Updated:** February 13, 2026
