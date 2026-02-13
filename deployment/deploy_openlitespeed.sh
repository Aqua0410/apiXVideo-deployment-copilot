#!/bin/bash
# =============================================================================
# FastAPI Video API - Universal OpenLiteSpeed Deployment
# =============================================================================
# Works with ANY Hostinger VPS or Linux server running OpenLiteSpeed
# 
# QUICK START (non-interactive):
#   ./deploy_openlitespeed.sh --fast
# 
# INTERACTIVE:
#   ./deploy_openlitespeed.sh
#
# CUSTOM CONFIG:
#   ./deploy_openlitespeed.sh --config /path/to/deploy.conf --fast
# =============================================================================

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}ℹ${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }

# Default config file
CONFIG_FILE="${SCRIPT_DIR}/../deployment/deploy.conf"
FAST_MODE=false
INTERACTIVE=true

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --fast)
            FAST_MODE=true
            INTERACTIVE=false
            shift
            ;;
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --interactive)
            INTERACTIVE=true
            FAST_MODE=false
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --fast          Non-interactive mode (uses config file / defaults)"
            echo "  --interactive   Interactive mode (ask questions) [DEFAULT]"
            echo "  --config FILE   Use custom config file"
            echo "  --help          Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                           # Interactive mode"
            echo "  $0 --fast                    # Non-interactive (fast setup)"
            echo "  $0 --config custom.conf --fast  # Custom config + fast"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# =============================================================================
# LOAD CONFIGURATION
# =============================================================================

if [ -f "$CONFIG_FILE" ]; then
    log_info "Loading config from: $CONFIG_FILE"
    source "$CONFIG_FILE"
else
    log_warning "Config file not found: $CONFIG_FILE"
    log_info "Using defaults..."
    DEPLOY_DIR="/var/www/fastapi-video-api"
    SERVICE_NAME="fastapi-video-api"
    INTERNAL_PORT="8000"
    DOMAIN_NAME="yourdomain.com"
    SESSION_SECRET="$(openssl rand -base64 32)"
    WORKER_MULTIPLIER="2"
    MAX_REQUESTS="5000"
    TIMEOUT="60"
    LOG_LEVEL="info"
fi

# =============================================================================
# INTERACTIVE MODE - Ask for confirmations/changes
# =============================================================================

if [ "$INTERACTIVE" = true ]; then
    clear
    echo "============================================================"
    echo "  🚀 FastAPI Video API - Universal Deployment"
    echo "============================================================"
    echo ""
    echo "Configuration loaded:"
    echo "  Project Dir:   $DEPLOY_DIR"
    echo "  Service Name:  $SERVICE_NAME"
    echo "  Port:          $INTERNAL_PORT"
    echo "  Domain:        $DOMAIN_NAME"
    echo ""
    read -p "Continue with these settings? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Asking for custom configuration..."
        
        read -p "📁 Project directory [$DEPLOY_DIR]: " INPUT
        DEPLOY_DIR="${INPUT:-$DEPLOY_DIR}"
        
        read -p "🏷️  Service name [$SERVICE_NAME]: " INPUT
        SERVICE_NAME="${INPUT:-$SERVICE_NAME}"
        
        read -p "🔌 Internal port [$INTERNAL_PORT]: " INPUT
        INTERNAL_PORT="${INPUT:-$INTERNAL_PORT}"
        
        read -p "🌐 Domain name [$DOMAIN_NAME]: " INPUT
        DOMAIN_NAME="${INPUT:-$DOMAIN_NAME}"
        
        # Offer to change API key
        read -p "🔑 Generate new API key? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            SESSION_SECRET="$(openssl rand -base64 32)"
            log_success "Generated new API key"
        fi
    fi
    echo ""
fi

# =============================================================================
# FINAL SUMMARY
# =============================================================================

echo "============================================================"
echo "  📋 DEPLOYMENT CONFIGURATION"
echo "============================================================"
echo ""
echo "  Project Dir:   $DEPLOY_DIR"
echo "  Service Name:  $SERVICE_NAME"
echo "  Internal Port: $INTERNAL_PORT"
echo "  Domain:        $DOMAIN_NAME"
echo "  Workers:       CPU × $WORKER_MULTIPLIER"
echo ""
echo "============================================================"
echo ""

if [ "$FAST_MODE" = false ] && [ "$INTERACTIVE" = true ]; then
    read -p "Press Enter to start deployment, or Ctrl+C to cancel..."
fi

# =============================================================================
# STEP 1: Detect OS and install dependencies
# =============================================================================

log_info "STEP 1: Detecting OS and installing dependencies..."

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    log_error "Cannot detect OS"
    exit 1
fi

log_info "Detected OS: $OS"

if [[ "$OS" == "almalinux" || "$OS" == "centos" || "$OS" == "rhel" ]]; then
    log_info "Setting up for AlmaLinux/CentOS/RHEL..."
    
    if ! command -v python3.11 &> /dev/null; then
        log_info "Installing Python 3.11..."
        sudo dnf install -y python3.11 python3.11-devel python3.11-pip 2>/dev/null
    else
        log_success "Python 3.11 already installed"
    fi
    
    sudo dnf install -y git curl openssl 2>/dev/null || true
    
elif [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    log_info "Setting up for Ubuntu/Debian..."
    
    sudo apt-get update -qq
    
    if ! command -v python3.11 &> /dev/null; then
        log_info "Installing Python 3.11..."
        sudo apt-get install -y python3.11 python3.11-venv python3.11-dev python3-pip 2>/dev/null
    else
        log_success "Python 3.11 already installed"
    fi
    
    sudo apt-get install -y git curl openssl 2>/dev/null || true
else
    log_warning "Unknown OS: $OS (attempting generic setup...)"
fi

log_success "System dependencies ready"
echo ""

# =============================================================================
# STEP 2: Create project directory and setup Python
# =============================================================================

log_info "STEP 2: Setting up project directory..."

sudo mkdir -p $DEPLOY_DIR
cd $DEPLOY_DIR

VENV_DIR="$DEPLOY_DIR/venv"

# Create/recreate virtual environment
if [ -d "$VENV_DIR" ]; then
    log_warning "Virtual environment exists, removing old one..."
    sudo rm -rf $VENV_DIR
fi

log_info "Creating Python virtual environment..."
sudo python3.11 -m venv $VENV_DIR

# Install Python dependencies
log_info "Installing Python packages..."
sudo $VENV_DIR/bin/pip install --upgrade pip setuptools wheel -q
sudo $VENV_DIR/bin/pip install fastapi uvicorn gunicorn httpx pydantic python-dotenv -q

# Copy source files from script directory to deployment directory
SOURCE_DIR="$SCRIPT_DIR/.."
log_info "Copying source files from $SOURCE_DIR..."

if [ -f "$SOURCE_DIR/main.py" ]; then
    sudo cp "$SOURCE_DIR/main.py" $DEPLOY_DIR/
    log_success "Copied main.py"
else
    log_warning "main.py not found in source directory"
fi

if [ -d "$SOURCE_DIR/data" ]; then
    sudo cp -r "$SOURCE_DIR/data" $DEPLOY_DIR/
    log_success "Copied data directory"
else
    log_warning "data directory not found in source directory"
fi

# Set proper permissions
sudo chown -R nobody:nobody $DEPLOY_DIR
sudo chmod 755 $DEPLOY_DIR
sudo chmod 644 $DEPLOY_DIR/main.py 2>/dev/null || true

log_success "Project directory ready"
echo ""

# =============================================================================
# STEP 3: Create environment file
# =============================================================================

log_info "STEP 3: Creating environment file..."

sudo tee $DEPLOY_DIR/.env > /dev/null <<EOF
# FastAPI Video API - Environment Configuration
# Generated: $(date)
SESSION_SECRET=$SESSION_SECRET
LOG_LEVEL=$LOG_LEVEL
EOF

sudo chmod 600 $DEPLOY_DIR/.env
log_success "Environment file created"
echo ""

# =============================================================================
# STEP 4: Create gunicorn configuration
# =============================================================================

log_info "STEP 4: Creating gunicorn configuration..."

sudo tee $DEPLOY_DIR/gunicorn_conf.py > /dev/null <<'GUNICORN_EOF'
import os
from multiprocessing import cpu_count

# Worker configuration
num_cpus = cpu_count()
worker_multiplier = int(os.getenv('WORKER_MULTIPLIER', '2'))
workers = max(2, num_cpus * worker_multiplier)
worker_class = "uvicorn.workers.UvicornWorker"
worker_connections = 1000
max_requests = int(os.getenv('MAX_REQUESTS', '5000'))
max_requests_jitter = 250
timeout = int(os.getenv('TIMEOUT', '60'))

# Binding
port = os.getenv('INTERNAL_PORT', '8000')
bind = f"0.0.0.0:{port}"

# Logging to stdout - systemd captures automatically
loglevel = os.getenv('LOG_LEVEL', 'info')
accesslog = "-"
errorlog = "-"

# Other settings
preload_app = False
keepalive = 10
graceful_timeout = 30
GUNICORN_EOF

log_success "Gunicorn config created"
echo ""

# =============================================================================
# STEP 5: Create systemd service
# =============================================================================

log_info "STEP 5: Creating systemd service..."

sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null <<SYSTEMD_EOF
[Unit]
Description=FastAPI Video API - $SERVICE_NAME
After=network.target
Documentation=https://fastapi.tiangolo.com

[Service]
Type=notify
User=root
WorkingDirectory=$DEPLOY_DIR
Environment="PATH=$VENV_DIR/bin"
EnvironmentFile=$DEPLOY_DIR/.env
Environment="INTERNAL_PORT=$INTERNAL_PORT"
Environment="WORKER_MULTIPLIER=$WORKER_MULTIPLIER"
Environment="MAX_REQUESTS=$MAX_REQUESTS"
Environment="TIMEOUT=$TIMEOUT"
ExecStart=$VENV_DIR/bin/gunicorn main:app -c gunicorn_conf.py
ExecReload=/bin/kill -s HUP \$MAINPID
KillMode=mixed
TimeoutStopSec=5
PrivateTmp=true
StandardOutput=journal
StandardError=journal
SyslogIdentifier=$SERVICE_NAME
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SYSTEMD_EOF

sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME

log_success "Systemd service created"
echo ""

# =============================================================================
# STEP 6: Start the service
# =============================================================================

log_info "STEP 6: Starting service..."

sudo systemctl restart $SERVICE_NAME
sleep 2

if systemctl is-active --quiet $SERVICE_NAME; then
    log_success "Service is running!"
else
    log_warning "Service may have issues. Check with:"
    echo "   sudo systemctl status $SERVICE_NAME"
    echo "   sudo journalctl -u $SERVICE_NAME -f"
fi
echo ""

# =============================================================================
# COMPLETION
# =============================================================================

clear
echo ""
echo "============================================================"
echo "  🎉 DEPLOYMENT COMPLETE!"
echo "============================================================"
echo ""
echo "  📊 Service Information:"
echo "     Name:     $SERVICE_NAME"
echo "     Port:     $INTERNAL_PORT"
echo "     Domain:   $DOMAIN_NAME"
echo "     Path:     $DEPLOY_DIR"
echo ""
echo "  🔑 API Key:"
echo "     $SESSION_SECRET"
echo ""
echo "============================================================"
echo "  📋 VERIFY DEPLOYMENT:"
echo "============================================================"
echo ""
echo "  Check service status:"
echo "    sudo systemctl status $SERVICE_NAME"
echo ""
echo "  View logs (realtime):"
echo "    sudo journalctl -u $SERVICE_NAME -f"
echo ""
echo "  Test health endpoint (local):"
echo "    curl http://localhost:$INTERNAL_PORT/"
echo ""
echo "  Test with API key:"
echo "    curl -H 'X-API-Key: $SESSION_SECRET' \\"
echo "      http://localhost:$INTERNAL_PORT/files"
echo ""
echo "============================================================"
echo "  🌐 CONFIGURE CYBERPANEL:"
echo "============================================================"
echo ""
echo "  1. Add External App in CyberPanel WebAdmin:"
echo "     Name: $SERVICE_NAME"
echo "     Address: 127.0.0.1"
echo "     Port: $INTERNAL_PORT"
echo ""
echo "  2. Add Rewrite Rule for $DOMAIN_NAME:"
echo "     RewriteEngine On"
echo "     RewriteCond %{REQUEST_FILENAME} !-f"
echo "     RewriteCond %{REQUEST_FILENAME} !-d"
echo "     RewriteRule ^(.*)$ http://127.0.0.1:$INTERNAL_PORT/\$1 [P,L]"
echo ""
echo "  3. Enable SSL (if needed)"
echo ""
echo "  4. Restart OpenLiteSpeed"
echo ""
echo "============================================================"
echo ""

# Save credentials
sudo tee $DEPLOY_DIR/CREDENTIALS.txt > /dev/null <<CREDS_EOF
============================================================
FastAPI Video API - Credentials
Generated: $(date)
============================================================

SERVICE NAME: $SERVICE_NAME
INTERNAL PORT: $INTERNAL_PORT
DOMAIN: $DOMAIN_NAME
PROJECT PATH: $DEPLOY_DIR

API KEY (SESSION_SECRET):
$SESSION_SECRET

============================================================
KEEP THIS FILE SECURE!
Delete after saving credentials to a secure location.
============================================================
CREDS_EOF

sudo chmod 600 $DEPLOY_DIR/CREDENTIALS.txt

log_success "Credentials saved to: $DEPLOY_DIR/CREDENTIALS.txt"
echo ""

