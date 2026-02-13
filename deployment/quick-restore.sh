#!/bin/bash
# =============================================================================
# FastAPI Video API - Quick Restore Script
# =============================================================================
# ONE-COMMAND SERVER RECOVERY
# 
# Usage:
#   copy-paste this entire command to a NEW server
#
# Full one-liner deployment (5 minutes):
#   git clone <repo-url> /var/www/apiXVideo && cd /var/www/apiXVideo && \
#   chmod +x deployment/*.sh && ./deployment/deploy_openlitespeed.sh --fast
#
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }

clear
echo "============================================================"
echo "  🚀 FastAPI Video API - Quick Restore"
echo "============================================================"
echo ""

# Determine where we are
if [ -f "deployment/deploy.conf" ]; then
    REPO_ROOT="$(pwd)"
    log_success "Found project repository at: $REPO_ROOT"
else
    log_error "Not in project root directory!"
    echo "Please run this from the project root (where 'deployment' folder is)"
    exit 1
fi

cd $REPO_ROOT

# Load configuration
if [ -f "deployment/deploy.conf" ]; then
    source deployment/deploy.conf
    log_success "Configuration loaded"
else
    log_error "Missing deployment/deploy.conf"
    exit 1
fi

echo ""
echo "============================================================"
echo "  📋 QUICK RESTORE - Configuration"
echo "============================================================"
echo ""
echo "  Project Dir:   $DEPLOY_DIR"
echo "  Service Name:  $SERVICE_NAME"
echo "  Port:          $INTERNAL_PORT"
echo "  Domain:        $DOMAIN_NAME"
echo ""
echo "============================================================"
echo ""

read -p "⚠️  This will REPLACE the existing installation. Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Cancelled"
    exit 0
fi

echo ""

# Check if service is already running
if systemctl is-active --quiet $SERVICE_NAME; then
    log_warning "Stopping existing service..."
    sudo systemctl stop $SERVICE_NAME || true
    sleep 1
fi

# Remove old installation
if [ -d "$DEPLOY_DIR" ]; then
    log_warning "Removing old deployment directory..."
    sudo rm -rf $DEPLOY_DIR
fi

# Copy project files
log_info "Copying project files..."
sudo mkdir -p $DEPLOY_DIR
sudo cp -r . $DEPLOY_DIR/
sudo chmod -R 755 $DEPLOY_DIR

cd $DEPLOY_DIR

log_success "Files copied"
echo ""

# Run actual deployment (non-interactive, fast)
log_info "Running deployment script..."
echo ""

# Make scripts executable
chmod +x deployment/*.sh

# Run with fast mode
bash deployment/deploy_openlitespeed.sh --fast

log_success "Quick restore completed!"
echo ""
echo "============================================================"
echo "  ⏱️  RESTORE TIME: ~5 minutes"
echo "============================================================"
echo ""
echo "  Service Status:"
echo "    sudo systemctl status $SERVICE_NAME"
echo ""
echo "  View Logs:"
echo "    sudo journalctl -u $SERVICE_NAME -f"
echo ""
echo "  Verify:"
echo "    curl http://localhost:$INTERNAL_PORT/"
echo ""
echo "============================================================"
echo ""
