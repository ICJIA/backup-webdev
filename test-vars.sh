#!/bin/bash
# Source the shared modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/utils.sh"

echo "SCRIPT_DIR: $SCRIPT_DIR"
echo "DEFAULT_BACKUP_DIR: $DEFAULT_BACKUP_DIR"
echo "BACKUP_DIR: $BACKUP_DIR"
echo "DEFAULT_SOURCE_DIRS: ${DEFAULT_SOURCE_DIRS[*]}"