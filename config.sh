#!/bin/bash
# config.sh - Configuration file for WebDev Backup Tool
#
# =====================================================================
# CONFIGURATION VARIABLES - Modify these values to change backup behavior
# =====================================================================

# Get the script's directory - don't modify this
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ----------------
# Backup Locations
# ----------------

# Default backup destination directory
# This is where backups will be stored
DEFAULT_BACKUP_DIR="/mnt/f/backups"

# Backup naming convention - prefix for backup directories
BACKUP_PREFIX="webdev_backup"

# ----------------------
# Default Source Directories
# ----------------------

# NOTE: By default, the script will auto-detect the following directories:
# - $HOME/webdev (if it exists)
# - $HOME/inform6 (if it exists)
# - The parent directory of this script (if above directories don't exist)
# - The script directory itself (as last resort)
#
# To manually add source directories, add them to this array:
DEFAULT_SOURCE_DIRS=()
# Examples:
# DEFAULT_SOURCE_DIRS=("/home/user/projects" "/home/user/repositories")

# ----------------------
# Cloud Storage Settings
# ----------------------

# Default cloud storage provider
# Supported values: "aws", "s3", "do", "spaces", "dropbox", "gdrive", "google" 
DEFAULT_CLOUD_PROVIDER="do"

# ----------------------
# Date/Time Settings
# ----------------------

# Date format for backup directories and logs
DATE_FORMAT="%Y-%m-%d_%H-%M-%S"

# =====================================================================
# IMPLEMENTATION - Don't modify below this line unless you know what you're doing
# =====================================================================

# Auto-detect source directories if none are explicitly configured
if [ ${#DEFAULT_SOURCE_DIRS[@]} -eq 0 ]; then
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
fi

# For backward compatibility - first directory is the default single source
DEFAULT_SOURCE_DIR="${DEFAULT_SOURCE_DIRS[0]}"

# Verify and create backup directory if needed
if [ ! -d "$DEFAULT_BACKUP_DIR" ] || [ ! -w "$DEFAULT_BACKUP_DIR" ]; then
    # Fallback to script directory if default isn't accessible
    DEFAULT_BACKUP_DIR="$SCRIPT_DIR/backups"
    # Create it if it doesn't exist
    [ ! -d "$DEFAULT_BACKUP_DIR" ] && mkdir -p "$DEFAULT_BACKUP_DIR"
fi

# Current date for this run
DATE=$(date +$DATE_FORMAT)

# Log and test directories
LOGS_DIR="$SCRIPT_DIR/logs"
TEST_DIR="$SCRIPT_DIR/test"
mkdir -p "$LOGS_DIR" "$TEST_DIR"

# Log files
BACKUP_HISTORY_LOG="$LOGS_DIR/backup_history.log"
TEST_HISTORY_LOG="$TEST_DIR/test_history.log"

# Set BACKUP_DIR to use DEFAULT_BACKUP_DIR (can be overridden by command-line arguments)
BACKUP_DIR="$DEFAULT_BACKUP_DIR"

# Export variables for use in other scripts
export SCRIPT_DIR DEFAULT_SOURCE_DIRS DEFAULT_SOURCE_DIR DEFAULT_BACKUP_DIR BACKUP_DIR DEFAULT_CLOUD_PROVIDER
export LOGS_DIR TEST_DIR DATE_FORMAT DATE BACKUP_PREFIX
export BACKUP_HISTORY_LOG TEST_HISTORY_LOG