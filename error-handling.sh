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

# Error code lookup (Bash 3.2 compatible; avoid associative arrays)
get_error_type() {
    case "${1:-99}" in
        1) echo "Configuration error" ;;
        2) echo "File system error" ;;
        3) echo "Missing dependencies" ;;
        4) echo "Permission denied" ;;
        5) echo "Network error" ;;
        6) echo "Backup creation failed" ;;
        7) echo "Verification failed" ;;
        8) echo "Restore operation failed" ;;
        9) echo "Cloud upload/download failed" ;;
        10) echo "Invalid arguments" ;;
        *) echo "Unknown error" ;;
    esac
}

# Terminal colors
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Central error reporting function (with severity levels and caller info).
# For a simple "log and exit" see handle_error() in utils.sh.
report_error() {
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
    local error_type
    error_type=$(get_error_type "$code")
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
                echo -e "${CYAN}ℹ INFO: ${message}${NC}"
                ;;
            $ERROR_WARNING)
                echo -e "${YELLOW}⚠ WARNING: ${message}${NC}"
                echo -e "${YELLOW}   Tip: Check the troubleshooting section in README.md for solutions${NC}"
                ;;
            $ERROR_CRITICAL)
                echo -e "${RED}✗ ERROR: ${message}${NC}"
                echo -e "${YELLOW}   Troubleshooting:${NC}"
                case $code in
                    1) echo -e "   - Run ./check-config.sh to verify configuration" ;;
                    2) echo -e "   - Check disk space: df -h" ;;
                    3) echo -e "   - Install missing tools or run ./install.sh" ;;
                    4) echo -e "   - Run ./secure-permissions.sh to fix permissions" ;;
                    5) echo -e "   - Check network connection and credentials" ;;
                    6) echo -e "   - Check backup destination is writable" ;;
                    7) echo -e "   - Backup may be corrupted, try another backup" ;;
                    8) echo -e "   - Check restore destination permissions" ;;
                    9) echo -e "   - Verify cloud credentials in secrets.sh" ;;
                    10) echo -e "   - Run with --help to see usage information" ;;
                esac
                echo -e "   - See README.md troubleshooting section for more help"
                ;;
            $ERROR_FATAL)
                echo -e "${RED}✗ FATAL ERROR: ${message}${NC}"
                echo -e "${RED}   The program will now exit.${NC}"
                echo -e "${YELLOW}   For help, see: README.md or run ./check-config.sh${NC}"
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
    report_error 1 "$1" "$ERROR_LOG" false $ERROR_WARNING
}

# Function to log an informational message
log_info() {
    report_error 1 "$1" "$ERROR_LOG" false $ERROR_INFO
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
        report_error 3 "Missing required dependencies: ${missing_deps[*]}" "$ERROR_LOG" false $ERROR_CRITICAL
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
            report_error 2 "Path does not exist: $path" "$ERROR_LOG" false $ERROR_CRITICAL
        else
            log_warning "Path does not exist: $path"
        fi
        return 1
    fi
    
    case "$access_type" in
        read)
            if [ ! -r "$path" ]; then
                if [ "$is_critical" = true ]; then
                    report_error 4 "No read permission for: $path" "$ERROR_LOG" false $ERROR_CRITICAL
                else
                    log_warning "No read permission for: $path"
                fi
                return 1
            fi
            ;;
        write)
            if [ ! -w "$path" ]; then
                if [ "$is_critical" = true ]; then
                    report_error 4 "No write permission for: $path" "$ERROR_LOG" false $ERROR_CRITICAL
                else
                    log_warning "No write permission for: $path"
                fi
                return 1
            fi
            ;;
        execute)
            if [ ! -x "$path" ]; then
                if [ "$is_critical" = true ]; then
                    report_error 4 "No execute permission for: $path" "$ERROR_LOG" false $ERROR_CRITICAL
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
export -f report_error log_warning log_info
export -f verify_dependencies check_fs_access
export -f log_script_start log_script_end
