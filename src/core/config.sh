#!/bin/bash
# ===============================================================================
# config.sh - Configuration module for WebDev Backup Tool
# ===============================================================================
#
# @file            config.sh
# @description     Defines shared constants and global configuration settings
# @author          Claude
# @version         1.6.0
#
# This file is loaded by all scripts in the WebDev Backup Tool suite and provides
# a centralized place for configuration settings and constants.
# ===============================================================================

# @function        find_project_root
# @description     Find the project root directory regardless of script location
# @returns         Absolute path to the project root
find_project_root() {
    local script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # If we're in the src/core directory, go up two levels
    if [[ "$script_path" == */src/core ]]; then
        echo "$(cd "$script_path/../.." && pwd)"
    # If we're in src directory, go up one level
    elif [[ "$script_path" == */src ]]; then
        echo "$(cd "$script_path/.." && pwd)"
    # If we're already at the root (e.g., during transition)
    else
        echo "$script_path"
    fi
}

# Project root directory (base of the tool)
SCRIPT_DIR="$(find_project_root)"

# ===============================================================================
# Directories and Paths
# ===============================================================================

# Source directory structure (where the tool's code lives)
SRC_DIR="$SCRIPT_DIR/src"
CORE_DIR="$SRC_DIR/core"
UTILS_DIR="$SRC_DIR/utils"
UI_DIR="$SRC_DIR/ui"
CLOUD_DIR="$SRC_DIR/cloud"
TEST_SRC_DIR="$SRC_DIR/test"

# Binary directory (for launcher scripts)
BIN_DIR="$SCRIPT_DIR/bin"

# Data directories (created if they don't exist)
DATA_DIR="$SCRIPT_DIR/data"
LOGS_DIR="$DATA_DIR/logs"
BACKUP_DIR="$DATA_DIR/backups"
TEST_DIR="$DATA_DIR/test"
SNAPSHOTS_DIR="$DATA_DIR/snapshots"

# ===============================================================================
# Default values
# ===============================================================================

# Default source directory - one level up from script location if "webdev" exists there,
# otherwise use the parent directory of script location
if [ -d "$(dirname "$SCRIPT_DIR")/webdev" ]; then
    DEFAULT_SOURCE_DIR="$(dirname "$SCRIPT_DIR")/webdev"
elif [ -d "$SCRIPT_DIR/../webdev" ]; then
    DEFAULT_SOURCE_DIR="$SCRIPT_DIR/../webdev"
else
    # Fall back to the parent directory of this script
    DEFAULT_SOURCE_DIR="$(dirname "$SCRIPT_DIR")"
fi

# Default cloud provider for external backups
DEFAULT_CLOUD_PROVIDER="do"

# Date format for backup directories and logs
DATE_FORMAT="%Y-%m-%d_%H-%M-%S"
DATE=$(date +$DATE_FORMAT)

# Log files
BACKUP_HISTORY_LOG="$LOGS_DIR/backup_history.log"
TEST_HISTORY_LOG="$TEST_DIR/test_history.log"
FAILED_BACKUPS_LOG="$LOGS_DIR/failed_backups.log"

# ===============================================================================
# Script file references - for when scripts need to call other scripts
# ===============================================================================

# Core scripts
BACKUP_SCRIPT="$BIN_DIR/backup.sh"
RESTORE_SCRIPT="$BIN_DIR/restore.sh"
WEBDEV_BACKUP_SCRIPT="$BIN_DIR/webdev-backup.sh"

# Utility scripts
CLEANUP_SCRIPT="$BIN_DIR/cleanup.sh"
CONFIGURE_CRON_SCRIPT="$BIN_DIR/configure-cron.sh"

# Test scripts
RUN_TESTS_SCRIPT="$BIN_DIR/run-tests.sh"
TEST_BACKUP_SCRIPT="$TEST_SRC_DIR/test-backup.sh"
TEST_CRON_SCRIPT="$TEST_SRC_DIR/test-cron.sh"
TEST_TAR_SCRIPT="$TEST_SRC_DIR/test-tar-compatibility.sh"

# ===============================================================================
# Export variables for use in other scripts
# ===============================================================================

# Export directories and paths
export SCRIPT_DIR SRC_DIR CORE_DIR UTILS_DIR UI_DIR CLOUD_DIR TEST_SRC_DIR
export BIN_DIR DATA_DIR LOGS_DIR BACKUP_DIR TEST_DIR SNAPSHOTS_DIR

# Export defaults
export DEFAULT_SOURCE_DIR DEFAULT_CLOUD_PROVIDER DATE_FORMAT DATE

# Export log paths
export BACKUP_HISTORY_LOG TEST_HISTORY_LOG FAILED_BACKUPS_LOG

# Export script references
export BACKUP_SCRIPT RESTORE_SCRIPT WEBDEV_BACKUP_SCRIPT
export CLEANUP_SCRIPT CONFIGURE_CRON_SCRIPT
export RUN_TESTS_SCRIPT TEST_BACKUP_SCRIPT TEST_CRON_SCRIPT TEST_TAR_SCRIPT

# ===============================================================================
# Create necessary directories
# ===============================================================================

# Create data directories if they don't exist
mkdir -p "$LOGS_DIR" "$BACKUP_DIR" "$TEST_DIR" "$SNAPSHOTS_DIR" &>/dev/null