#!/bin/bash
# =============================================================================
# FastAPI Video API - Data Backup & Restore
# =============================================================================
# Backup your video data for safekeeping or migration to new servers
#
# Usage:
#   ./backup.sh                 # Backup to local file
#   ./backup.sh --remote-push   # Push backup to remote server
#   ./restore.sh backup.tar.gz  # Restore from backup file
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

# Get script name
SCRIPT_NAME=$(basename "$0")

# Determine if this is backup or restore
if [[ "$SCRIPT_NAME" == *"backup"* ]]; then
    MODE="backup"
elif [[ "$SCRIPT_NAME" == *"restore"* ]]; then
    MODE="restore"
else
    log_error "Script must be named backup.sh or restore.sh"
    exit 1
fi

# =============================================================================
# BACKUP MODE
# =============================================================================

if [ "$MODE" = "backup" ]; then
    echo "============================================================"
    echo "  📦 FastAPI Video API - Data Backup"
    echo "============================================================"
    echo ""
    
    # Configuration
    DATA_DIR="/var/www/fastapi-video-api/data"
    BACKUP_DIR="./backups"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_FILE="$BACKUP_DIR/apiXVideo_backup_$TIMESTAMP.tar.gz"
    
    # Check if data directory exists
    if [ ! -d "$DATA_DIR" ]; then
        log_error "Data directory not found: $DATA_DIR"
        exit 1
    fi
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    
    echo "  📁 Source: $DATA_DIR"
    echo "  💾 Backup: $BACKUP_FILE"
    echo ""
    
    # Count files
    FILE_COUNT=$(find "$DATA_DIR" -type f | wc -l)
    DIR_SIZE=$(du -sh "$DATA_DIR" | cut -f1)
    
    echo "  📊 Data to backup:"
    echo "     Files: $FILE_COUNT"
    echo "     Size:  $DIR_SIZE"
    echo ""
    
    read -p "  Start backup? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Cancelled"
        exit 0
    fi
    
    echo ""
    log_info "Creating backup..."
    tar -czf "$BACKUP_FILE" -C "$(dirname "$DATA_DIR")" "$(basename "$DATA_DIR")" 2>/dev/null
    
    BACKUP_SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
    
    log_success "Backup completed!"
    echo ""
    echo "  📦 Backup file: $BACKUP_FILE"
    echo "  💾 Compressed size: $BACKUP_SIZE"
    echo ""
    echo "  To restore on new server:"
    echo "    scp $BACKUP_FILE root@NEW_SERVER:/var/www/apiXVideo/backups/"
    echo "    ssh root@NEW_SERVER"
    echo "    ./deployment/restore.sh backups/$(basename $BACKUP_FILE)"
    echo ""
    
    # Optional: ask to push to remote
    if [ "$1" = "--remote-push" ]; then
        echo ""
        read -p "Remote server address: " REMOTE_SERVER
        if [ -n "$REMOTE_SERVER" ]; then
            log_info "Pushing backup to $REMOTE_SERVER..."
            mkdir -p backups 2>/dev/null || true
            scp "$BACKUP_FILE" root@"$REMOTE_SERVER":/var/www/apiXVideo/backups/ 2>/dev/null
            if [ $? -eq 0 ]; then
                log_success "Pushed to remote server"
            else
                log_warning "Failed to push to remote"
            fi
        fi
    fi
    
    echo ""

# =============================================================================
# RESTORE MODE
# =============================================================================

elif [ "$MODE" = "restore" ]; then
    echo "============================================================"
    echo "  📦 FastAPI Video API - Data Restore"
    echo "============================================================"
    echo ""
    
    BACKUP_FILE="${1:-}"
    
    if [ -z "$BACKUP_FILE" ]; then
        log_error "Usage: restore.sh <backup_file>"
        echo ""
        echo "Example:"
        echo "  ./deployment/restore.sh backups/apiXVideo_backup_20250213_120000.tar.gz"
        echo ""
        echo "Available backups:"
        ls -lh backups/*.tar.gz 2>/dev/null || echo "  No backups found"
        exit 1
    fi
    
    if [ ! -f "$BACKUP_FILE" ]; then
        log_error "Backup file not found: $BACKUP_FILE"
        exit 1
    fi
    
    DATA_DIR="/var/www/fastapi-video-api/data"
    
    echo "  💾 Backup file: $BACKUP_FILE"
    echo "  📁 Restore to:  $DATA_DIR"
    echo ""
    
    # Show backup contents preview
    echo "  📋 Backup contents:"
    tar -tzf "$BACKUP_FILE" | head -10 | sed 's/^/     /'
    echo "     ..."
    echo ""
    
    read -p "  Restore backup? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Cancelled"
        exit 0
    fi
    
    echo ""
    
    # Check if data exists
    if [ -d "$DATA_DIR" ]; then
        log_warning "Data directory already exists"
        read -p "  Overwrite? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Cancelled"
            exit 0
        fi
        sudo rm -rf "$DATA_DIR"
    fi
    
    # Restore
    log_info "Extracting backup..."
    sudo mkdir -p /var/www/fastapi-video-api
    sudo tar -xzf "$BACKUP_FILE" -C /var/www/fastapi-video-api 2>/dev/null
    
    # Verify
    if [ -d "$DATA_DIR" ]; then
        FILE_COUNT=$(find "$DATA_DIR" -type f | wc -l)
        DIR_SIZE=$(du -sh "$DATA_DIR" | cut -f1)
        
        log_success "Restore completed!"
        echo ""
        echo "  📊 Restored data:"
        echo "     Files: $FILE_COUNT"
        echo "     Size:  $DIR_SIZE"
        echo ""
        echo "  💡 Tip: Restart the service to ensure it loads new data"
        echo "     sudo systemctl restart fastapi-video-api"
        echo ""
    else
        log_error "Restore failed"
        exit 1
    fi
    
    echo ""
fi
