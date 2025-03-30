#!/bin/bash
# config.sh - Configuration file for WebDev Backup Tool

# Get the script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default source directories - define as array
DEFAULT_SOURCE_DIRS=()

# Check for ~/webdev directory and add it if exists
if [ -d "$HOME/webdev" ]; then
    DEFAULT_SOURCE_DIRS+=("$HOME/webdev")
fi

# Check for ~/inform6 directory and add it if exists
if [ -d "$HOME/inform6" ]; then
    DEFAULT_SOURCE_DIRS+=("$HOME/inform6")
fi

# If no default directories found, try to use parent directory of script
if [ ${#DEFAULT_SOURCE_DIRS[@]} -eq 0 ]; then
    # Try to use parent directory of script location
    parent_dir="$(dirname "$SCRIPT_DIR")"
    if [ -d "$parent_dir" ] && [ -r "$parent_dir" ]; then
        DEFAULT_SOURCE_DIRS+=("$parent_dir")
    else
        # Fallback to script directory itself
        DEFAULT_SOURCE_DIRS+=("$SCRIPT_DIR")
    fi
fi

# For backward compatibility - first directory is the default
DEFAULT_SOURCE_DIR="${DEFAULT_SOURCE_DIRS[0]}"

# Default backup destination - pick a reliable location
DEFAULT_BACKUP_DIR="/mnt/d/backups"
if [ ! -d "$DEFAULT_BACKUP_DIR" ] || [ ! -w "$DEFAULT_BACKUP_DIR" ]; then
    # Fallback to script directory if default isn't accessible
    DEFAULT_BACKUP_DIR="$SCRIPT_DIR/backups"
    # Create it if it doesn't exist
    [ ! -d "$DEFAULT_BACKUP_DIR" ] && mkdir -p "$DEFAULT_BACKUP_DIR"
fi

# Default cloud provider
DEFAULT_CLOUD_PROVIDER="do"

# Log and test directories
LOGS_DIR="$SCRIPT_DIR/logs"
TEST_DIR="$SCRIPT_DIR/test"
mkdir -p "$LOGS_DIR" "$TEST_DIR"

# Date format for backup directories and logs
DATE_FORMAT="%Y-%m-%d_%H-%M-%S"
DATE=$(date +$DATE_FORMAT)

# Backup naming convention
BACKUP_PREFIX="webdev_backup"

# Log files
BACKUP_HISTORY_LOG="$LOGS_DIR/backup_history.log"
TEST_HISTORY_LOG="$TEST_DIR/test_history.log"

# Set BACKUP_DIR to use DEFAULT_BACKUP_DIR
BACKUP_DIR="$DEFAULT_BACKUP_DIR"

# Export variables for use in other scripts
export SCRIPT_DIR DEFAULT_SOURCE_DIRS DEFAULT_SOURCE_DIR DEFAULT_BACKUP_DIR BACKUP_DIR DEFAULT_CLOUD_PROVIDER
export LOGS_DIR TEST_DIR DATE_FORMAT DATE BACKUP_PREFIX
export BACKUP_HISTORY_LOG TEST_HISTORY_LOG