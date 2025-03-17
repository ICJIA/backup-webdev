#!/bin/bash
# utils.sh - Shared utility functions for backup-webdev
# This file contains common functions used across all scripts

# Source the shared configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Source secrets file if it exists (contains API keys and sensitive data)
if [ -f "$SCRIPT_DIR/secrets.sh" ]; then
    source "$SCRIPT_DIR/secrets.sh"
fi

# Terminal colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Format size function (converts bytes to human readable format)
format_size() {
    local size=$1
    awk '
        BEGIN {
            suffix[1] = "B"
            suffix[2] = "KB"
            suffix[3] = "MB"
            suffix[4] = "GB"
            suffix[5] = "TB"
        }
        {
            for (i = 5; i > 0; i--) {
                if ($1 >= 1024 ^ (i - 1)) {
                    printf("%.2f %s", $1 / (1024 ^ (i - 1)), suffix[i])
                    break
                }
            }
        }
    ' <<< "$size"
}

# Error handling function
handle_error() {
    local exit_code=$1
    local error_message=$2
    local log_file=${3:-}
    local silent_mode=${4:-false}
    
    if [[ -n "$log_file" && -d "$(dirname "$log_file")" ]]; then
        echo "ERROR: $error_message (Exit code: $exit_code)" | tee -a "$log_file"
    else
        echo -e "${RED}ERROR: $error_message (Exit code: $exit_code)${NC}"
    fi
    
    if [[ "$silent_mode" == true ]]; then
        echo "BACKUP FAILED: $error_message"
    fi
    
    exit $exit_code
}

# Logging function
log() {
    local message=$1
    local log_file=${2:-}
    local silent_mode=${3:-false}
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    if [[ -n "$log_file" && -d "$(dirname "$log_file")" ]]; then
        echo "$timestamp - $message" >> "$log_file"
    fi
    
    if [[ "$silent_mode" == false ]]; then
        echo -e "$timestamp - $message"
    fi
}

# Section headers function
section() {
    local title=$1
    echo -e "\n${YELLOW}===== $title =====${NC}"
    
    if [[ -n "$2" && -d "$(dirname "$2")" ]]; then
        echo "===== $title =====" >> "$2"
    fi
}

# Function to run commands with dry run support
run_cmd() {
    local command=$1
    local dry_run=${2:-false}
    
    if [ "$dry_run" = true ]; then
        echo -e "${YELLOW}DRY RUN: Would execute: $command${NC}"
        return 0
    else
        eval "$command"
        return $?
    fi
}

# Function to get confirmation from user
confirm() {
    local message="${1:-Are you sure you want to proceed?}"
    local default="${2:-n}"
    local skip=${3:-false}
    
    if [ "$skip" = true ]; then
        return 0
    fi
    
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

# Verify directory exists and is accessible
verify_directory() {
    local dir_path=$1
    local dir_type=$2
    local create=${3:-false}
    
    if [ ! -d "$dir_path" ]; then
        if [ "$create" = true ]; then
            mkdir -p "$dir_path" || return 1
            echo -e "${GREEN}✓ Created $dir_type directory: $dir_path${NC}"
        else
            echo -e "${RED}ERROR: $dir_type directory does not exist: $dir_path${NC}"
            return 1
        fi
    fi
    
    if [ ! -w "$dir_path" ]; then
        echo -e "${RED}ERROR: $dir_type directory is not writable: $dir_path${NC}"
        return 1
    fi
    
    # Test we can actually write to the filesystem
    local test_file="$dir_path/.write_test_$(date +%s)"
    if ! touch "$test_file" 2>/dev/null; then
        echo -e "${RED}ERROR: Cannot write to $dir_type directory: $dir_path${NC}"
        echo -e "${RED}The filesystem may be read-only or full.${NC}"
        return 1
    else
        rm -f "$test_file"
        echo -e "${GREEN}✓ $dir_type directory is accessible and writable: $dir_path${NC}"
    fi
    
    return 0
}

# Calculate checksum for a file
calculate_checksum() {
    local file_path=$1
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file_path" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file_path" | awk '{print $1}'
    else
        md5sum "$file_path" | awk '{print $1}'
    fi
}

# Verify backup integrity
verify_backup() {
    local backup_file=$1
    local log_file=${2:-}
    local silent_mode=${3:-false}
    
    # Test integrity of compressed file
    if tar -tzf "$backup_file" > /dev/null 2>&1; then
        log "✓ Backup integrity verified for: $(basename "$backup_file")" "$log_file" "$silent_mode"
        return 0
    else
        log "✗ Backup integrity check failed: $(basename "$backup_file")" "$log_file" "$silent_mode"
        return 1
    fi
}

# Send email notification
send_email_notification() {
    local subject=$1
    local message=$2
    local recipient=${3:-}
    local attachment=${4:-}
    
    # Skip if no recipient
    if [[ -z "$recipient" ]]; then
        return 0
    fi
    
    # Check if mail command exists
    if ! command -v mail >/dev/null 2>&1; then
        echo "Cannot send email - mail command not found"
        return 1
    fi
    
    # If credentials are available, use them
    if [[ -n "$EMAIL_USERNAME" && -n "$EMAIL_PASSWORD" && -n "$EMAIL_SMTP_SERVER" ]]; then
        # Create temporary mailrc file
        local mailrc_file=$(mktemp)
        echo "set smtp=$EMAIL_SMTP_SERVER" > "$mailrc_file"
        echo "set smtp-use-starttls" >> "$mailrc_file"
        echo "set smtp-auth=login" >> "$mailrc_file"
        echo "set smtp-auth-user=$EMAIL_USERNAME" >> "$mailrc_file"
        echo "set smtp-auth-password=$EMAIL_PASSWORD" >> "$mailrc_file"
        echo "set from=${EMAIL_FROM:-$EMAIL_USERNAME}" >> "$mailrc_file"
        
        # Send with or without attachment
        if [[ -n "$attachment" && -f "$attachment" ]]; then
            MAILRC="$mailrc_file" EMAIL="$EMAIL_USERNAME" echo "$message" | mail -s "$subject" -a "$attachment" "$recipient"
        else
            MAILRC="$mailrc_file" EMAIL="$EMAIL_USERNAME" echo "$message" | mail -s "$subject" "$recipient"
        fi
        
        # Clean up
        rm -f "$mailrc_file"
    else
        # Basic sending without authentication
        if [[ -n "$attachment" && -f "$attachment" ]]; then
            echo "$message" | mail -s "$subject" -a "$attachment" "$recipient"
        else
            echo "$message" | mail -s "$subject" "$recipient"
        fi
    fi
    
    return $?
}

# Generate a progress bar
progress_bar() {
    local current=$1
    local total=$2
    local width=${3:-50}
    local label=${4:-}
    
    # Calculate percentage
    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    
    # Construct the bar
    printf "\r["
    printf "%${filled}s" | tr ' ' '#'
    printf "%$(($width - $filled))s" | tr ' ' ' '
    printf "] %3d%%" "$percent"
    
    if [[ -n "$label" ]]; then
        printf " - %s" "$label"
    fi
    
    # Print newline if completed
    if [ "$current" -eq "$total" ]; then
        printf "\n"
    fi
}

# Get file modification time as Unix timestamp
get_file_mtime() {
    local file_path=$1
    stat -c %Y "$file_path" 2>/dev/null || \
    stat -f %m "$file_path" 2>/dev/null
}

# Compare two files to see if they're different
files_differ() {
    local file1=$1
    local file2=$2
    
    # If either file doesn't exist, they differ
    if [[ ! -f "$file1" || ! -f "$file2" ]]; then
        return 0  # true, they differ
    fi
    
    # Check size first (quick comparison)
    local size1=$(stat -c %s "$file1" 2>/dev/null || stat -f %z "$file1" 2>/dev/null)
    local size2=$(stat -c %s "$file2" 2>/dev/null || stat -f %z "$file2" 2>/dev/null)
    
    if [[ "$size1" != "$size2" ]]; then
        return 0  # true, they differ
    fi
    
    # Compare content
    cmp -s "$file1" "$file2"
    return $?  # 0 if same, 1 if different
}

# Check if required tools are installed
check_required_tools() {
    local tools=("$@")
    local missing=()
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing+=("$tool")
        fi
    done
    
    if (( ${#missing[@]} > 0 )); then
        echo -e "${RED}ERROR: Required tools not found: ${missing[*]}${NC}"
        echo "Please install these tools and try again."
        return 1
    fi
    
    return 0
}

# End of utility functions