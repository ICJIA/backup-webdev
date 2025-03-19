#!/bin/bash
# ===============================================================================
# utils.sh - General purpose utility functions for WebDev Backup Tool
# ===============================================================================
#
# @file            utils.sh
# @description     Provides core utility functions used throughout the application
# @author          Claude
# @version         1.6.0
#
# This file contains shared utility functions that are used by multiple scripts
# in the WebDev Backup Tool. These functions are general purpose and not specific
# to any particular domain of the application.
# ===============================================================================

# Set the project root directory
SCRIPT_DIR_UTILS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Import core configuration (will set paths correctly)
if [[ "$SCRIPT_DIR_UTILS" == */src/utils ]]; then
    source "$SCRIPT_DIR_UTILS/../core/config.sh"
else
    source "$SCRIPT_DIR_UTILS/config.sh"
fi

# ===============================================================================
# Terminal Colors
# ===============================================================================

# Define terminal colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
MAGENTA="\033[0;35m"
CYAN="\033[0;36m"
NC="\033[0m"  # No Color

# ===============================================================================
# File System Functions
# ===============================================================================

/**
 * @function       find_projects
 * @description    Find all project directories in the given path
 * @param {string} source_dir - Directory to search for projects
 * @param {number} depth - How deep to search for directories (default: 1)
 * @returns        List of project directories
 */
find_projects() {
    local source_dir=$1
    local depth=${2:-1}
    
    # Ensure source directory exists
    if [ ! -d "$source_dir" ]; then
        return 1
    fi
    
    # Find all directories up to the specified depth, excluding hidden directories
    find "$source_dir" -maxdepth $depth -type d -not -path "*/\.*" | grep -v "/$" | sort
}

/**
 * @function       get_directory_size
 * @description    Calculate the size of a directory, optionally excluding certain directories
 * @param {string} dir - Directory to calculate size for
 * @param {string} exclude - Optional pattern to exclude (e.g., "node_modules")
 * @returns        Size in bytes
 */
get_directory_size() {
    local dir=$1
    local exclude=$2
    
    if [ -n "$exclude" ]; then
        # With exclusion pattern
        du -sb --exclude="$exclude" "$dir" 2>/dev/null | cut -f1
    else
        # Without exclusion
        du -sb "$dir" 2>/dev/null | cut -f1
    fi
}

/**
 * @function       format_size
 * @description    Format a size in bytes to a human-readable format (B, KB, MB, GB, TB)
 * @param {number} size - Size in bytes
 * @returns        Formatted size string
 */
format_size() {
    local size=$1
    
    if [ -z "$size" ] || ! [[ "$size" =~ ^[0-9]+$ ]]; then
        echo "0 B"
        return
    fi
    
    if [ "$size" -lt 1024 ]; then
        echo "$size B"
    elif [ "$size" -lt 1048576 ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $size/1024}") KB"
    elif [ "$size" -lt 1073741824 ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $size/1048576}") MB"
    elif [ "$size" -lt 1099511627776 ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $size/1073741824}") GB"
    else
        echo "$(awk "BEGIN {printf \"%.2f\", $size/1099511627776}") TB"
    fi
}

/**
 * @function       verify_directory
 * @description    Verify a directory exists and is writable, optionally create it
 * @param {string} dir - Directory to verify
 * @param {string} label - Label for error messages
 * @param {boolean} create - Whether to create the directory if it doesn't exist
 * @returns        0 on success, 1 on failure
 */
verify_directory() {
    local dir=$1
    local label=${2:-"Directory"}
    local create=${3:-false}
    
    # Check if directory exists
    if [ ! -d "$dir" ]; then
        if [ "$create" = true ]; then
            # Create directory if requested
            if ! mkdir -p "$dir" 2>/dev/null; then
                echo -e "${RED}ERROR: Failed to create $label: $dir${NC}"
                return 1
            fi
            echo -e "${GREEN}✓ Created $label: $dir${NC}"
        else
            echo -e "${RED}ERROR: $label does not exist: $dir${NC}"
            return 1
        fi
    fi
    
    # Check if directory is writable
    if [ ! -w "$dir" ]; then
        echo -e "${RED}ERROR: $label is not writable: $dir${NC}"
        return 1
    fi
    
    # Create a test file to verify filesystem write capability
    local test_file="$dir/.write_test_$$"
    if ! touch "$test_file" 2>/dev/null; then
        echo -e "${RED}ERROR: Cannot write to $label: $dir${NC}"
        echo -e "${RED}The filesystem may be read-only or full.${NC}"
        return 1
    else
        rm -f "$test_file"
    fi
    
    echo -e "${GREEN}✓ $label directory is accessible and writable: $dir${NC}"
    return 0
}

# ===============================================================================
# Logging Functions
# ===============================================================================

/**
 * @function       log
 * @description    Log a message to both console and log file
 * @param {string} message - Message to log
 * @param {string} log_file - Path to log file
 * @param {boolean} silent - Whether to suppress console output
 */
log() {
    local message=$1
    local log_file=$2
    local silent=${3:-false}
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Always write to log file if specified
    if [ -n "$log_file" ]; then
        echo "$timestamp - $message" >> "$log_file"
    fi
    
    # Write to console unless in silent mode
    if [ "$silent" != true ]; then
        echo "$timestamp - $message"
    fi
}

/**
 * @function       section
 * @description    Log a section header to both console and log file
 * @param {string} title - Section title
 * @param {string} log_file - Path to log file
 */
section() {
    local title=$1
    local log_file=$2
    
    echo -e "\n${YELLOW}===== $title =====${NC}"
    
    if [ -n "$log_file" ]; then
        echo -e "===== $title =====" >> "$log_file"
    fi
}

/**
 * @function       handle_error
 * @description    Handle an error with consistent formatting
 * @param {number} exit_code - Exit code to return
 * @param {string} error_message - Error message to display
 * @param {string} log_file - Path to log file
 * @param {boolean} silent - Whether to suppress console output
 */
handle_error() {
    local exit_code=$1
    local error_message=$2
    local log_file=$3
    local silent=${4:-false}
    
    log "ERROR: $error_message" "$log_file" "$silent"
    
    if [ "$silent" != true ]; then
        echo -e "${RED}ERROR: $error_message${NC}"
    fi
    
    exit $exit_code
}

# ===============================================================================
# Utility Functions
# ===============================================================================

/**
 * @function       confirm
 * @description    Ask for user confirmation with yes/no prompt
 * @param {string} message - Prompt message
 * @param {string} default - Default response if user just presses Enter (y/n)
 * @returns        0 for yes, 1 for no
 */
confirm() {
    local message="${1:-Are you sure you want to proceed?}"
    local default="${2:-n}"
    
    if [ "$default" = "y" ]; then
        read -p "$message [Y/n] " response
        case "$response" in
            [nN][oO]|[nN]) 
                return 1
                ;;
            *)
                return 0
                ;;
        esac
    else
        read -p "$message [y/N] " response
        case "$response" in
            [yY][eE][sS]|[yY]) 
                return 0
                ;;
            *)
                return 1
                ;;
        esac
    fi
}

/**
 * @function       check_required_tools
 * @description    Check if required tools are installed
 * @param          List of tool names to check
 * @returns        0 if all tools are available, 1 otherwise
 */
check_required_tools() {
    local missing=()
    
    for tool in "$@"; do
        if ! command -v $tool >/dev/null 2>&1; then
            missing+=("$tool")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}ERROR: Required tools not installed: ${missing[*]}${NC}"
        return 1
    fi
    
    return 0
}

/**
 * @function       run_cmd
 * @description    Run a command with dry-run support
 * @param {string} cmd - Command to run
 * @param {boolean} dry_run - Whether to simulate execution
 * @returns        Command exit code
 */
run_cmd() {
    local cmd=$1
    local dry_run=${2:-false}
    
    if [ "$dry_run" = true ]; then
        echo -e "${YELLOW}DRY RUN: Would execute: $cmd${NC}"
        return 0
    else
        eval "$cmd"
        return $?
    fi
}

# Export colors
export RED GREEN YELLOW BLUE MAGENTA CYAN NC