#!/bin/bash
# =============================================================================
# FastAPI Video API - Ultra-Fast Setup Script
# =============================================================================
# ONE-LINER DEPLOYMENT for CI/CD or new servers
#
# Usage (paste this on new server):
#   bash <(curl -s https://raw.githubusercontent.com/YOUR_REPO/apiXVideo/main/deployment/setup.sh)
#
# Or locally:
#   ./deployment/setup.sh
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}→${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    log_error "Please run with sudo"
    exit 1
fi

# Detect if we're in repo or need to clone
REPO_URL="${1:-}"
SETUP_DIR="${2:-.}"

if [ ! -f "$SETUP_DIR/deployment/deploy.conf" ] && [ -n "$REPO_URL" ]; then
    log_info "Cloning repository..."
    if ! git clone "$REPO_URL" "$SETUP_DIR" 2>/dev/null; then
        log_error "Failed to clone repository"
        exit 1
    fi
fi

# Verify we're in right place
if [ ! -f "$SETUP_DIR/deployment/deploy.conf" ]; then
    log_error "deployment/deploy.conf not found!"
    log_info "Make sure you run this from project root or provide repo URL"
    exit 1
fi

cd "$SETUP_DIR"

log_success "Setup starting..."
echo ""

# Load quick config
source deployment/deploy.conf

# Show what we're deploying
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🚀 FastAPI Video API - Deployment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  📍 Configuration:"
echo "     Path:    $DEPLOY_DIR"
echo "     Service: $SERVICE_NAME"
echo "     Port:    $INTERNAL_PORT"
echo "     Domain:  $DOMAIN_NAME"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if already deployed
if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    log_warning "Service already running. Stopping..."
    systemctl stop "$SERVICE_NAME" || true
    sleep 1
fi

# Run deployment in non-interactive mode
log_info "Running deployment..."
chmod +x deployment/deploy_openlitespeed.sh
deployment/deploy_openlitespeed.sh --fast

log_success "Setup complete!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🎉 Deployed Successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  📊 Service:"
echo "     sudo systemctl status $SERVICE_NAME"
echo ""
echo "  📋 Logs:"
echo "     sudo journalctl -u $SERVICE_NAME -f"
echo ""
echo "  🧪 Test:"
echo "     curl http://localhost:$INTERNAL_PORT/"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
