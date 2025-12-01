#!/bin/bash
# config.sh - Configuration file for WebDev Backup Tool
#
# SCRIPT TYPE: Module (sourced by other scripts, not executed directly)
# This script defines configuration variables and is sourced by other scripts.
#
# =====================================================================
# CONFIGURATION VARIABLES - Modify these values to change backup behavior
# =====================================================================

# Version information
VERSION="1.7.0"

# Get the script's directory - don't modify this
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ----------------
# Backup Locations
# ----------------

# Default backup destination directory
# This is where backups will be stored
# Auto-detect OS and use appropriate default path

# Function to find first external volume on macOS (not the main hard drive)
# This helps save space on the main drive by using external storage when available
find_macos_external_volume() {
    # Check if /Volumes directory exists (it should on macOS)
    if [ ! -d "/Volumes" ]; then
        echo ""
        return 1
    fi
    
    # Get the main system volume mount point
    local main_volume="/"
    if [ -d "/System/Volumes/Data" ]; then
        main_volume="/System/Volumes/Data"
    fi
    
    # Look for external volumes in /Volumes
    # External volumes (USB drives, external hard drives, etc.) are typically mounted at /Volumes/VolumeName
    # Exclude system volumes and hidden volumes
    for volume in /Volumes/*; do
        # Skip if not a directory or if it's the main system volume
        if [ ! -d "$volume" ] || [ "$volume" = "$main_volume" ] || [ "$volume" = "/Volumes/Macintosh HD" ]; then
            continue
        fi
        
        # Check if it's writable
        if [ -w "$volume" ]; then
            # Check if it's not a system volume (exclude things like Recovery, Preboot, etc.)
            local volume_name=$(basename "$volume")
            # Exclude known system volumes and hidden/system directories
            if [[ ! "$volume_name" =~ ^(Recovery|Preboot|Update|VM|com\.apple\.|\.|\.\.)$ ]]; then
                # Found a valid external volume - return the backups path
                echo "$volume/backups"
                return 0
            fi
        fi
    done
    
    # No external volume found, return empty
    echo ""
    return 1
}

# Set default backup directory based on OS
if [ "$(uname -s)" = "Darwin" ]; then
    # macOS - try to find external volume first, fallback to home directory
    EXTERNAL_VOLUME=$(find_macos_external_volume)
    if [ -n "$EXTERNAL_VOLUME" ]; then
        DEFAULT_BACKUP_DIR="$EXTERNAL_VOLUME"
    else
        # Fallback to home directory if no external volume found
        DEFAULT_BACKUP_DIR="$HOME/backups"
    fi
else
    # Linux/WSL2 - always use /mnt/e/backups (WSL2 default)
    DEFAULT_BACKUP_DIR="/mnt/e/backups"
fi

# Backup naming convention - prefix for backup directories (OS-agnostic)
BACKUP_PREFIX="webdev_backup"

# ----------------------
# Default Source Directories
# ----------------------

# NOTE: By default, the script will back up all folders in the home directory (~)
# To exclude specific folders, use the --exclude option on the command line
# IMPORTANT: The .ssh directory is ALWAYS backed up (mandatory) and cannot be excluded
#
# To manually specify source directories, add them to this array:
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
# By default, back up the entire home directory
if [ ${#DEFAULT_SOURCE_DIRS[@]} -eq 0 ]; then
    # Default to home directory to back up all folders
    DEFAULT_SOURCE_DIRS+=("$HOME")
fi

# For backward compatibility - first directory is the default single source
DEFAULT_SOURCE_DIR="${DEFAULT_SOURCE_DIRS[0]}"

# Verify and create backup directory if needed
if [ ! -d "$DEFAULT_BACKUP_DIR" ]; then
    # Create the backup directory if it doesn't exist
    if ! mkdir -p "$DEFAULT_BACKUP_DIR" 2>/dev/null; then
        # If creation fails, try fallback based on OS
        if [ "$(uname -s)" = "Darwin" ]; then
            # macOS: Fallback to home directory
            DEFAULT_BACKUP_DIR="$HOME/backups"
            mkdir -p "$DEFAULT_BACKUP_DIR"
        else
            # WSL2/Linux: Fallback to home directory (shouldn't happen with /mnt/e/backups)
            DEFAULT_BACKUP_DIR="$HOME/backups"
            mkdir -p "$DEFAULT_BACKUP_DIR"
        fi
    fi
elif [ ! -w "$DEFAULT_BACKUP_DIR" ]; then
    # If directory exists but isn't writable, use fallback
    if [ "$(uname -s)" = "Darwin" ]; then
        # macOS: Fallback to home directory
        DEFAULT_BACKUP_DIR="$HOME/backups"
        mkdir -p "$DEFAULT_BACKUP_DIR"
    else
        # WSL2/Linux: Fallback to home directory
        DEFAULT_BACKUP_DIR="$HOME/backups"
        mkdir -p "$DEFAULT_BACKUP_DIR"
    fi
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
export BACKUP_HISTORY_LOG TEST_HISTORY_LOG VERSION