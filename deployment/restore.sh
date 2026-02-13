#!/bin/bash
# Symlink to backup.sh for restore mode
# This file acts as the restore companion to backup.sh
# Both scripts share the same code and mode is detected by filename

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
exec bash "$SCRIPT_DIR/backup.sh" "$@"
