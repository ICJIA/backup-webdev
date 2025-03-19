#!/bin/bash
# error-handling.sh - Centralized error handling for WebDev Backup Tool

# Get the script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Create the errors log directory if it doesn't exist
ERROR_LOG_DIR="$LOGS_DIR/errors"
mkdir -p "$ERROR_LOG_DIR"
ERROR_LOG="$ERROR_LOG_DIR/errors_$(date +%Y-%m-%d).log"

# Error levels
readonly ERROR_INFO=0      # Informational message
readonly ERROR_WARNING=1   # Warning, non-critical
readonly ERROR_CRITICAL=2  # Critical error, operation cannot continue
readonly ERROR_FATAL=3     # Fatal error, script termination required

# Error codes and meanings
declare -A ERROR_CODES=(
    [1]="Configuration error"
    [2]="File system error"
    [3]="Missing dependencies"
    [4]="Permission denied"
    [5]="Network error"
    [6]="Backup creation failed"
    [7]="Verification failed"
    [8]="Restore operation failed"
    [9]="Cloud upload/download failed"
    [10]="Invalid arguments"
    [99]="Unknown error"
)

# Terminal colors
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Central error handling function
handle_error() {
    local code="${1:-99}"
    local message="${2:-Unknown error}"
    local log_file="${3:-$ERROR_LOG}"
    local silent="${4:-false}"
    local level="${5:-$ERROR_CRITICAL}"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    # Get calling information
    local calling_script=$(caller | awk '{print $2}')
    local calling_line=$(caller | awk '{print $1}')
    
    # Format error message for logging
    local error_type=${ERROR_CODES[$code]:-"Unknown error type"}
    local log_message="[$timestamp] [${error_type}] (Code: $code) ${message}"
    local detail_message="In script $calling_script at line $calling_line"
    
    # Log to error file
    mkdir -p "$(dirname "$log_file")" # Ensure log directory exists
    echo "$log_message" >> "$log_file"
    echo "  $detail_message" >> "$log_file"
    
    # Also log to operation-specific log if provided and different from error log
    if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "$log_file" ]; then
        echo "$log_message" >> "$LOG_FILE"
        echo "  $detail_message" >> "$LOG_FILE"
    fi
    
    # Display error to console if not in silent mode
    if [ "$silent" = false ]; then
        case $level in
            $ERROR_INFO)
                echo -e "${CYAN}INFO: ${message}${NC}"
                ;;
            $ERROR_WARNING)
                echo -e "${YELLOW}WARNING: ${message}${NC}"
                ;;
            $ERROR_CRITICAL)
                echo -e "${RED}ERROR: ${message}${NC}"
                ;;
            $ERROR_FATAL)
                echo -e "${RED}FATAL ERROR: ${message}${NC}"
                echo -e "${RED}The program will now exit.${NC}"
                ;;
        esac
    fi
    
    # For fatal errors, exit the program
    if [ $level -eq $ERROR_FATAL ]; then
        exit $code
    fi
    
    return $code
}

# Function to log a warning (non-critical issue)
log_warning() {
    handle_error 1 "$1" "$ERROR_LOG" false $ERROR_WARNING
}

# Function to log an informational message
log_info() {
    handle_error 1 "$1" "$ERROR_LOG" false $ERROR_INFO
}

# Function to verify external dependencies and log appropriate errors
verify_dependencies() {
    local missing_deps=()
    
    for dep in "$@"; do
        if ! command -v "$dep" &>/dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        handle_error 3 "Missing required dependencies: ${missing_deps[*]}" "$ERROR_LOG" false $ERROR_CRITICAL
        return 1
    fi
    
    return 0
}

# Function to check file system access with proper error handling
check_fs_access() {
    local path="$1"
    local access_type="$2" # "read", "write", or "execute"
    local is_critical="${3:-true}"
    
    if [ ! -e "$path" ]; then
        if [ "$is_critical" = true ]; then
            handle_error 2 "Path does not exist: $path" "$ERROR_LOG" false $ERROR_CRITICAL
        else
            log_warning "Path does not exist: $path"
        fi
        return 1
    fi
    
    case "$access_type" in
        read)
            if [ ! -r "$path" ]; then
                if [ "$is_critical" = true ]; then
                    handle_error 4 "No read permission for: $path" "$ERROR_LOG" false $ERROR_CRITICAL
                else
                    log_warning "No read permission for: $path"
                fi
                return 1
            fi
            ;;
        write)
            if [ ! -w "$path" ]; then
                if [ "$is_critical" = true ]; then
                    handle_error 4 "No write permission for: $path" "$ERROR_LOG" false $ERROR_CRITICAL
                else
                    log_warning "No write permission for: $path"
                fi
                return 1
            fi
            ;;
        execute)
            if [ ! -x "$path" ]; then
                if [ "$is_critical" = true ]; then
                    handle_error 4 "No execute permission for: $path" "$ERROR_LOG" false $ERROR_CRITICAL
                else
                    log_warning "No execute permission for: $path"
                fi
                return 1
            fi
            ;;
        *)
            log_warning "Invalid access type specified: $access_type"
            return 1
            ;;
    esac
    
    return 0
}

# Function to log script start with standardized format
log_script_start() {
    local script_name="$1"
    local log_file="${2:-$LOG_FILE}"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    echo "=========================================" >> "$log_file"
    echo "[$timestamp] STARTING: $script_name" >> "$log_file"
    echo "=========================================" >> "$log_file"
}

# Function to log script end with standardized format
log_script_end() {
    local script_name="$1"
    local status="$2" # "SUCCESS", "PARTIAL", "FAILED"
    local log_file="${3:-$LOG_FILE}"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    echo "-----------------------------------------" >> "$log_file"
    echo "[$timestamp] FINISHED: $script_name - Status: $status" >> "$log_file"
    echo "=========================================" >> "$log_file"
    echo "" >> "$log_file"
}

# Export functions for use in other scripts
export -f handle_error log_warning log_info
export -f verify_dependencies check_fs_access
export -f log_script_start log_script_end
