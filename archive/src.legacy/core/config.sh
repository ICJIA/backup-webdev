#!/bin/bash
# config.sh - Configuration file for WebDev Backup Tool (LEGACY - ARCHIVED)
#
# ⚠️  WARNING: This file is ARCHIVED and NOT ACTIVELY USED
# This file is kept for reference only. The active config.sh is in the root directory.
#
# This archived version contains hardcoded paths that differ from the active configuration:
# - Backup directory: /mnt/d/backups (archived version)
# - Logs directory: /home/cschw/backup-webdev/logs (hardcoded, archived version)
#
# DO NOT MODIFY THIS FILE - It is archived for historical reference only.
# Use the root-level config.sh for all configuration changes.

# Get the script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default source directories - define as array
# By default, back up the entire home directory
DEFAULT_SOURCE_DIRS=()

# Auto-detect source directories if none are explicitly configured
# By default, back up the entire home directory
if [ ${#DEFAULT_SOURCE_DIRS[@]} -eq 0 ]; then
    # Default to home directory to back up all folders
    DEFAULT_SOURCE_DIRS+=("$HOME")
fi

# For backward compatibility - first directory is the default
DEFAULT_SOURCE_DIR="${DEFAULT_SOURCE_DIRS[0]}"

# Default backup destination - pick a reliable location
# ⚠️ ARCHIVED: This path differs from active config.sh
DEFAULT_BACKUP_DIR="/mnt/d/backups"
# Verify and create backup directory if needed
if [ ! -d "$DEFAULT_BACKUP_DIR" ]; then
    # Create the backup directory if it doesn't exist
    mkdir -p "$DEFAULT_BACKUP_DIR" || {
        # Fallback to script directory if default isn't accessible
        DEFAULT_BACKUP_DIR="$SCRIPT_DIR/backups"
        mkdir -p "$DEFAULT_BACKUP_DIR"
    }
elif [ ! -w "$DEFAULT_BACKUP_DIR" ]; then
    # If directory exists but isn't writable, fallback to script directory
    DEFAULT_BACKUP_DIR="$SCRIPT_DIR/backups"
    mkdir -p "$DEFAULT_BACKUP_DIR"
fi

# Default cloud provider
DEFAULT_CLOUD_PROVIDER="do"

# Log and test directories
# ⚠️ ARCHIVED: Hardcoded paths - not used in active version
LOGS_DIR="/home/cschw/backup-webdev/logs"
TEST_DIR="/home/cschw/backup-webdev/test"
mkdir -p "$LOGS_DIR" "$TEST_DIR"

# Date format for backup directories and logs
DATE_FORMAT="%Y-%m-%d_%H-%M-%S"
DATE=$(date +$DATE_FORMAT)

# Backup naming convention
BACKUP_PREFIX="wsl2_backup"

# Log files
BACKUP_HISTORY_LOG="$LOGS_DIR/backup_history.log"
TEST_HISTORY_LOG="$TEST_DIR/test_history.log"

# Export variables for use in other scripts
export SCRIPT_DIR DEFAULT_SOURCE_DIRS DEFAULT_SOURCE_DIR DEFAULT_BACKUP_DIR DEFAULT_CLOUD_PROVIDER
export LOGS_DIR TEST_DIR DATE_FORMAT DATE BACKUP_PREFIX
export BACKUP_HISTORY_LOG TEST_HISTORY_LOG
