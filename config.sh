#!/bin/bash
# config.sh - Shared configuration for backup-webdev tools
# This file contains common constants and settings for all scripts

# Get the script's directory - parent directory of config.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default source directory - one level up from script location if "webdev" exists there 
# otherwise use the parent directory of script location
if [ -d "$(dirname "$SCRIPT_DIR")/webdev" ]; then
    DEFAULT_SOURCE_DIR="$(dirname "$SCRIPT_DIR")/webdev"
elif [ -d "$SCRIPT_DIR/../webdev" ]; then
    DEFAULT_SOURCE_DIR="$SCRIPT_DIR/../webdev"
else
    # Fall back to the parent directory of this script
    DEFAULT_SOURCE_DIR="$(dirname "$SCRIPT_DIR")"
fi

# Default backup destination
DEFAULT_BACKUP_DIR="/mnt/d/_WEBDEV_BACKUPS"

# Default cloud provider for external backups
DEFAULT_CLOUD_PROVIDER="do"

# Log and test directories
LOGS_DIR="$SCRIPT_DIR/logs"
TEST_DIR="$SCRIPT_DIR/test"

# Date format for backup directories and logs
DATE_FORMAT="%Y-%m-%d_%H-%M-%S"
DATE=$(date +$DATE_FORMAT)

# Log files
BACKUP_HISTORY_LOG="$LOGS_DIR/backup_history.log"
TEST_HISTORY_LOG="$TEST_DIR/test_history.log"

# Script files
BACKUP_SCRIPT="$SCRIPT_DIR/backup.sh"
TEST_SCRIPT="$SCRIPT_DIR/test-backup.sh"
RUN_TESTS_SCRIPT="$SCRIPT_DIR/run-tests.sh"
CLEANUP_SCRIPT="$SCRIPT_DIR/cleanup.sh"

# Export variables for use in other scripts
export SCRIPT_DIR DEFAULT_SOURCE_DIR DEFAULT_BACKUP_DIR DEFAULT_CLOUD_PROVIDER
export LOGS_DIR TEST_DIR DATE_FORMAT DATE
export BACKUP_HISTORY_LOG TEST_HISTORY_LOG
export BACKUP_SCRIPT TEST_SCRIPT RUN_TESTS_SCRIPT CLEANUP_SCRIPT