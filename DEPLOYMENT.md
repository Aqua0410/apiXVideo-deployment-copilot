# 🚀 FastAPI Video API - Universal Deployment Guide

**Deploy to ANY Hostinger VPS in 5 minutes with ONE command**

---

## ⚡ Quick Start

### One-Command Deployment (on new server)

```bash
# Copy entire command to new server terminal
git clone https://github.com/YOUR_USERNAME/apiXVideo /var/www/apiXVideo && \
cd /var/www/apiXVideo && \
chmod +x deployment/*.sh && \
sudo ./deployment/deploy_openlitespeed.sh --fast
```

**That's it!** Your API is deployed in ~5 minutes.

---

## 📁 What You Get

After running the script, everything is automatically set up:

- ✅ Python 3.11 virtual environment
- ✅ FastAPI application running on port **8000** (or custom)
- ✅ Gunicorn workers (optimized for your CPU)
- ✅ Systemd service (auto-restart on reboot)
- ✅ Environment variables with your API key
- ✅ Ready to connect to OpenLiteSpeed/CyberPanel

---

## 🔧 Configuration (EDIT ONCE)

Before first deployment, edit `deployment/deploy.conf`:

```bash
nano deployment/deploy.conf
```

Key settings:

```bash
DEPLOY_DIR="/var/www/fastapi-video-api"  # Where to install
SERVICE_NAME="fastapi-video-api"         # Service name
INTERNAL_PORT="8000"                     # Port (change if conflicts)
DOMAIN_NAME="yourdomain.com"             # Your domain
SESSION_SECRET="your-secure-key"         # API key
```

**Then commit to git:**

```bash
git add deployment/deploy.conf
git commit -m "deployment config"
git push
```

---

## 🎯 Deployment Modes

### Interactive (ask questions)
```bash
./deployment/deploy_openlitespeed.sh
```

### Fast (no questions, uses config)
```bash
./deployment/deploy_openlitespeed.sh --fast
```

### Custom config
```bash
./deployment/deploy_openlitespeed.sh --config custom.conf --fast
```

---

## 📦 Deployment Scripts Overview

| Script | Purpose | Usage |
|--------|---------|-------|
| `deploy_openlitespeed.sh` | Main deployment | `./deploy_openlitespeed.sh [--fast]` |
| `setup.sh` | Ultra-fast setup | `sudo ./setup.sh` (or curl-bash) |
| `quick-restore.sh` | Emergency recovery | `./quick-restore.sh` |
| `backup.sh` | Backup video data | `./backup.sh` |
| `restore.sh` | Restore video data | `./restore.sh backup.tar.gz` |
| `health-check.sh` | Verify deployment | `./health-check.sh` |

---

## 🌐 CyberPanel Configuration

After deployment, configure OpenLiteSpeed:

### 1. Add External App (WebAdmin Console)
- Go to: **Server Configuration → External App**
- **Name:** fastapi-video-api
- **Address:** 127.0.0.1
- **Port:** 8000 (your INTERNAL_PORT)

### 2. Add Rewrite Rule (for your domain)
- Go to: **Websites → Your Domain → Rewrite Rules**
- Add:
```
RewriteEngine On
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule ^(.*)$ http://127.0.0.1:8000/$1 [P,L]
```

### 3. Enable SSL & Restart
- SSL → Issue SSL Certificate
- Service Manager → Restart OpenLiteSpeed

---

## ✅ Verify Deployment

### Check service status
```bash
sudo systemctl status fastapi-video-api
```

### View logs
```bash
sudo journalctl -u fastapi-video-api -f
```

### Run health check
```bash
./deployment/health-check.sh
```

### Test API
```bash
# Local
curl http://localhost:8000/

# With API key
curl -H "X-API-Key: your-api-key" http://localhost:8000/files

# After CyberPanel setup (external)
curl -H "X-API-Key: your-api-key" https://yourdomain.com/files
```

---

## 🆘 Emergency Recovery

### Scenario: Server crashed, need new VPS

**Option 1: Fast recovery (5 minutes)**

```bash
# On new server
cd /var/www/apiXVideo

# Restore data if available
./deployment/restore.sh backups/backup.tar.gz

# Redeploy
sudo ./deployment/deploy_openlitespeed.sh --fast
```

**Option 2: Full redeploy from scratch**

```bash
# On new server
git clone https://github.com/YOUR_REPO/apiXVideo /var/www/apiXVideo && \
cd /var/www/apiXVideo && \
sudo chmod +x deployment/*.sh && \
sudo ./deployment/deploy_openlitespeed.sh --fast
```

**Time:** ~5 minutes, everything automated!

---

## 📊 Monitoring & Maintenance

### Daily checks
```bash
# Health check (runs all diagnostics)
./deployment/health-check.sh

# View logs
sudo journalctl -u fastapi-video-api -f
```

### Weekly backup
```bash
./deployment/backup.sh
```

### Monthly recovery drill
```bash
./deployment/quick-restore.sh
```

---

## 🔑 API Usage

### Get your API key
```bash
cat /var/www/fastapi-video-api/.env | grep SESSION_SECRET
```

### Make requests
```bash
# Health check
curl https://yourdomain.com/

# List files
curl -H "X-API-Key: YOUR_KEY" https://yourdomain.com/files

# Get reels
curl -H "X-API-Key: YOUR_KEY" https://yourdomain.com/reels?page=1&limit=20

# Delete video
curl -X DELETE \
  -H "X-API-Key: YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{"video_url": "https://example.com/video.mp4"}' \
  https://yourdomain.com/videos
```

---

## 🐛 Troubleshooting

### Service won't start
```bash
# Check error
sudo journalctl -u fastapi-video-api -n 50

# Restart
sudo systemctl restart fastapi-video-api
```

### Port already in use
```bash
# Change INTERNAL_PORT in deploy.conf
nano deployment/deploy.conf  # Change to 8001, 8002, etc

# Redeploy
sudo ./deployment/deploy_openlitespeed.sh --fast
```

### CyberPanel not forwarding requests
1. Verify external app: WebAdmin → External App → Check address/port
2. Check rewrite rules: Websites → Domain → Rewrite Rules
3. Verify service running: `sudo systemctl status fastapi-video-api`
4. Check port: `sudo ss -tuln | grep 8000`

### Data missing after redeploy
```bash
# Restore from backup
./deployment/restore.sh backups/last_backup.tar.gz

# Restart service
sudo systemctl restart fastapi-video-api
```

---

## 📋 Directory Structure

```
/var/www/fastapi-video-api/
├── main.py                    # FastAPI app
├── requirements.txt           # Dependencies
├── .env                       # API key (SECURE!)
├── gunicorn_conf.py          # Worker config
├── venv/                     # Python environment
├── data/                     # Video data
│   ├── categoryvideo/        # Categories
│   ├── reelsvideo/          # Reels
│   └── livestream/          # Livestream
├── deployment/              # Deploy scripts
│   ├── deploy.conf          # Config (EDIT THIS)
│   ├── deploy_openlitespeed.sh
│   ├── quick-restore.sh
│   ├── backup.sh
│   ├── restore.sh
│   ├── health-check.sh
│   └── README.md            # Full documentation
├── CREDENTIALS.txt          # API key backup
└── backups/                 # Data backups
```

---

## 💡 Tips & Best Practices

1. **Backup config file:**
   ```bash
   git add deployment/deploy.conf
   git commit -m "Save deployment config"
   ```

2. **Secure your API key:**
   - Store in a password manager
   - Never commit `.env` file to git
   - Rotate periodically

3. **Monitor actively:**
   ```bash
   # Watch logs every day
   sudo journalctl -u fastapi-video-api -f
   
   # Run health check weekly
   ./deployment/health-check.sh
   ```

4. **Regular backups:**
   ```bash
   # Daily backup script
   0 2 * * * cd /var/www/apiXVideo && ./deployment/backup.sh
   ```

5. **Document your setup:**
   - Keep API key in secure location
   - Document INTERNAL_PORT used
   - Note your DOMAIN_NAME

---

## 🎓 Advanced Usage

### Auto-scaling data refresh
```bash
# Edit main.py auto-refresh frequency
# Currently: 5 minutes
# Change in: auto_refresh_reels() async function
```

### Custom worker count
```bash
# Edit deploy.conf
WORKER_MULTIPLIER="4"  # More workers for high load
```

### Larger request bodies
```bash
# Edit CyberPanel rewrite rule
# Add: client_max_body_size 100M;
```

---

## 📞 Support Resources

- **Logs:** `sudo journalctl -u fastapi-video-api -f`
- **Config:** `cat /var/www/fastapi-video-api/.env`
- **Status:** `./deployment/health-check.sh`
- **Docs:** `deployment/README.md`

---

## 🔄 Migration Checklist

Migrating to new server? Follow this:

- [ ] Edit `deployment/deploy.conf` with same settings
- [ ] Commit to git: `git push`
- [ ] Backup data: `./deployment/backup.sh`
- [ ] Transfer backup: `scp backups/*.tar.gz new-server:`
- [ ] Deploy new server: `sudo ./deployment/deploy_openlitespeed.sh --fast`
- [ ] Restore data: `./deployment/restore.sh backups/*.tar.gz`
- [ ] Verify: `./deployment/health-check.sh`
- [ ] Test API: `curl http://localhost:8000/`
- [ ] Configure CyberPanel on new server
- [ ] Update DNS if needed

**Total time: ~15 minutes**

---

## 🎯 Summary

| Task | Time | Command |
|------|------|---------|
| Initial Deploy | 5 min | `sudo ./deploy_openlitespeed.sh --fast` |
| Verify Health | 1 min | `./health-check.sh` |
| Backup Data | 2 min | `./backup.sh` |
| Restore Server | 5 min | `./restore.sh backup.tar.gz` |
| Migration | 15 min | Config + backup + deploy + restore |

---

**Last Updated:** February 13, 2026
**Status:** ✅ Production Ready - Fully Automated - Universal
