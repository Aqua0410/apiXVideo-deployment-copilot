#!/bin/bash
# =============================================================================
# FastAPI Video API - Server Status Check
# =============================================================================
# Run this to verify your deployment is healthy
#
# Usage:
#   ./deployment/health-check.sh
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

check_ok() { echo -e "${GREEN}✓${NC} $1"; }
check_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
check_fail() { echo -e "${RED}✗${NC} $1"; }
check_info() { echo -e "${BLUE}→${NC} $1"; }

# Load config
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONFIG_FILE="$SCRIPT_DIR/deploy.conf"

if [ ! -f "$CONFIG_FILE" ]; then
    check_fail "Config file not found: $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

clear
echo "============================================================"
echo "  🏥 FastAPI Video API - Health Check"
echo "============================================================"
echo ""

PASS=0
FAIL=0

# Check 1: Service running
echo "1️⃣  Service Status"
if systemctl is-active --quiet "$SERVICE_NAME"; then
    check_ok "Service is running"
    ((PASS++))
else
    check_fail "Service is NOT running"
    check_info "Start with: sudo systemctl start $SERVICE_NAME"
    ((FAIL++))
fi
echo ""

# Check 2: Port listening
echo "2️⃣  Port Listening"
if ss -tuln | grep -q ":$INTERNAL_PORT "; then
    check_ok "Port $INTERNAL_PORT is listening"
    ((PASS++))
else
    check_fail "Port $INTERNAL_PORT is NOT listening"
    ((FAIL++))
fi
echo ""

# Check 3: API responds
echo "3️⃣  API Health"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$INTERNAL_PORT/ 2>/dev/null || echo "000")
if [ "$RESPONSE" = "200" ]; then
    check_ok "Health endpoint returns 200"
    ((PASS++))
else
    check_fail "Health endpoint returned $RESPONSE"
    ((FAIL++))
fi
echo ""

# Check 4: API key authentication
echo "4️⃣  API Key Authentication"
if [ -z "$SESSION_SECRET" ]; then
    check_warn "SESSION_SECRET not configured"
    ((FAIL++))
else
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "X-API-Key: $SESSION_SECRET" \
        http://localhost:$INTERNAL_PORT/files 2>/dev/null || echo "000")
    if [ "$RESPONSE" = "200" ]; then
        check_ok "API key authentication works"
        ((PASS++))
    else
        check_fail "API key authentication failed (HTTP $RESPONSE)"
        ((FAIL++))
    fi
fi
echo ""

# Check 5: Data directory
echo "5️⃣  Data Directory"
if [ -d "$DEPLOY_DIR/data" ]; then
    FILES=$(find "$DEPLOY_DIR/data" -type f 2>/dev/null | wc -l)
    check_ok "Data directory exists with $FILES files"
    ((PASS++))
else
    check_warn "Data directory not found at $DEPLOY_DIR/data"
    ((FAIL++))
fi
echo ""

# Check 6: Virtual environment
echo "6️⃣  Virtual Environment"
if [ -d "$DEPLOY_DIR/venv" ]; then
    PYTHON="$DEPLOY_DIR/venv/bin/python"
    VERSION=$($PYTHON --version 2>&1 | grep -oE '[0-9]+\.[0-9]+')
    check_ok "Virtual environment exists (Python $VERSION)"
    ((PASS++))
else
    check_fail "Virtual environment not found at $DEPLOY_DIR/venv"
    ((FAIL++))
fi
echo ""

# Check 7: Environment file
echo "7️⃣  Configuration File"
if [ -f "$DEPLOY_DIR/.env" ]; then
    check_ok "Environment file exists"
    ((PASS++))
else
    check_fail "Environment file not found at $DEPLOY_DIR/.env"
    ((FAIL++))
fi
echo ""

# Check 8: Systemd service
echo "8️⃣  Systemd Service"
if systemctl is-enabled --quiet "$SERVICE_NAME"; then
    check_ok "Service is enabled (auto-start on reboot)"
    ((PASS++))
else
    check_warn "Service is NOT enabled for auto-start"
    check_info "Enable with: sudo systemctl enable $SERVICE_NAME"
    ((FAIL++))
fi
echo ""

# Check 9: Recent logs
echo "9️⃣  Recent Logs"
ERRORS=$(sudo journalctl -u "$SERVICE_NAME" -n 50 2>/dev/null | grep -i "error" | wc -l)
if [ "$ERRORS" -eq 0 ]; then
    check_ok "No errors in recent logs"
    ((PASS++))
else
    check_warn "Found $ERRORS error(s) in recent logs"
    check_info "View with: sudo journalctl -u $SERVICE_NAME -f"
    ((FAIL++))
fi
echo ""

# Check 10: CPU and RAM
echo "🔟  System Resources"
UPTIME=$(uptime | awk -F'load average:' '{print $2}')
MEMORY=$(free -h | awk '/^Mem:/ {print $3 "/"$2}')
CPUS=$(nproc)
check_ok "CPU: $CPUS cores | RAM: $MEMORY | Load:$UPTIME"
((PASS++))
echo ""

# Summary
echo "============================================================"
echo "  📊 Summary"
echo "============================================================"
echo ""
echo "  Checks passed:  $PASS"
echo "  Checks failed:  $FAIL"
echo ""

if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed! Service is healthy.${NC}"
    echo ""
else
    echo -e "${YELLOW}⚠ Some checks failed. Review messages above.${NC}"
    echo ""
    echo "Troubleshooting:"
    echo ""
    echo "  1. View service status:"
    echo "     sudo systemctl status $SERVICE_NAME"
    echo ""
    echo "  2. View full logs:"
    echo "     sudo journalctl -u $SERVICE_NAME -n 100"
    echo ""
    echo "  3. Restart service:"
    echo "     sudo systemctl restart $SERVICE_NAME"
    echo ""
    echo "  4. Check port conflicts:"
    echo "     sudo ss -tuln | grep $INTERNAL_PORT"
    echo ""
fi

echo ""
echo "============================================================"
echo "  📋 Quick Commands"
echo "============================================================"
echo ""
echo "  Status:   sudo systemctl status $SERVICE_NAME"
echo "  Logs:     sudo journalctl -u $SERVICE_NAME -f"
echo "  Restart:  sudo systemctl restart $SERVICE_NAME"
echo "  Stop:     sudo systemctl stop $SERVICE_NAME"
echo "  Config:   cat $DEPLOY_DIR/.env"
echo ""
echo "============================================================"
echo ""

exit $FAIL
