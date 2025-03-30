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

# SECURITY IMPROVEMENT: Replace unsafe eval-based command execution with array-based approach
run_cmd() {
    local cmd=("$@")
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}DRY RUN: Would execute: ${cmd[*]}${NC}"
        return 0
    else
        "${cmd[@]}" # Execute command using array to prevent injection
        return $?
    fi
}

# Safe version of the confirm function
safe_confirm() {
    if [ "$SKIP_CONFIRMATION" = true ]; then
        return 0
    fi
    
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

# SECURITY IMPROVEMENT: Safe path handling function
validate_path() {
    local path="$1"
    local type="$2"  # "dir" or "file"
    
    # Remove any potential command injection characters
    path=$(echo "$path" | tr -d ';&|$()`')
    
    if [ "$type" = "dir" ]; then
        # Ensure it's an absolute path or relative to home
        if [[ ! "$path" =~ ^/ && ! "$path" =~ ^~ ]]; then
            echo "Error: Directory path must be absolute or relative to home"
            return 1
        fi
        
        # Further validations could be added here
    fi
    
    echo "$path"
}

# SECURITY IMPROVEMENT: Function to sanitize input
sanitize_input() {
    local input="$1"
    # Remove potentially dangerous characters
    echo "$input" | tr -d ';&|$()`'
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

# Verify backup integrity with enhanced checks
verify_backup() {
    local backup_file=$1
    local log_file=${2:-}
    local silent_mode=${3:-false}
    local thorough=${4:-false}
    
    # Basic test: integrity of compressed file
    if ! tar -tzf "$backup_file" > /dev/null 2>&1; then
        log "✗ Backup integrity check failed: $(basename "$backup_file")" "$log_file" "$silent_mode"
        return 1
    fi
    
    # Check file is not empty
    local file_size=$(du -b "$backup_file" | cut -f1)
    if [ "$file_size" -eq 0 ]; then
        log "✗ Backup file is empty: $(basename "$backup_file")" "$log_file" "$silent_mode"
        return 1
    fi
    
    # Calculate and store checksum
    local checksum=$(calculate_checksum "$backup_file")
    local checksum_file="${backup_file}.sha256"
    echo "$checksum  $(basename "$backup_file")" > "$checksum_file"
    log "Checksum saved to: $checksum_file" "$log_file" "$silent_mode"
    
    # If thorough check requested, actually extract to temp and verify extraction
    if [ "$thorough" = true ]; then
        log "Performing thorough integrity verification..." "$log_file" "$silent_mode"
        
        # Create temporary directory for extraction test
        local temp_dir=$(mktemp -d)
        log "Using temporary directory for extraction test: $temp_dir" "$log_file" "$silent_mode"
        
        # Attempt to extract a small portion (just list files then extract one small file)
        local file_count=$(tar -tzf "$backup_file" | wc -l)
        log "Archive contains $file_count files/directories" "$log_file" "$silent_mode"
        
        # Try to extract a small text file for verification
        # Find the first small file (likely a .md, .txt, .json, etc.)
        local small_file=$(tar -tzf "$backup_file" | grep -E '\.(md|txt|json|js|css|html)$' | head -1)
        
        if [ -n "$small_file" ]; then
            if tar -xzf "$backup_file" -C "$temp_dir" "$small_file" 2>/dev/null; then
                log "✓ Successfully extracted test file: $small_file" "$log_file" "$silent_mode"
                if [ -f "$temp_dir/$small_file" ]; then
                    log "✓ Extracted file exists and is readable" "$log_file" "$silent_mode"
                else
                    log "✗ Extracted file does not exist or is not readable" "$log_file" "$silent_mode"
                    rm -rf "$temp_dir"
                    return 1
                fi
            else
                log "✗ Failed to extract test file" "$log_file" "$silent_mode"
                rm -rf "$temp_dir"
                return 1
            fi
        else
            log "No suitable small file found for extraction test, skipping this step" "$log_file" "$silent_mode"
        fi
        
        # Clean up
        rm -rf "$temp_dir"
    fi
    
    # All checks passed
    log "✓ Backup integrity verified for: $(basename "$backup_file")" "$log_file" "$silent_mode"
    return 0
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

# Animated progress indicator for operations with indeterminate progress
animated_progress() {
    local pid=$1      # Process ID to monitor
    local message=$2  # Status message to display
    local interval=${3:-0.2}  # Refresh interval
    local symbols=("-" "\\" "|" "/")  # Animation frames
    local i=0
    
    # Save cursor position
    tput sc
    
    while kill -0 $pid 2>/dev/null; do
        symbol=${symbols[$i]}
        i=$(( (i + 1) % 4 ))
        
        # If silent mode is enabled, don't show animation
        if [ "$SILENT_MODE" != "true" ]; then
            # Move to saved position and print progress
            tput rc
            printf "\r[%s] %s " "$symbol" "$message"
        fi
        
        sleep $interval
    done
    
    # Clear line
    tput rc
    printf "\r%-80s\r" " "
}

# Estimate progress based on file size change
monitor_file_progress() {
    local file_path=$1      # File path to monitor
    local expected_size=$2  # Expected final size (approx)
    local message=$3        # Status message to display
    local pid=$4            # Process ID to monitor (optional)
    local interval=${5:-1}  # Refresh interval in seconds
    
    # Initialize progress variables
    local current_size=0
    local last_size=0
    local start_time=$(date +%s)
    local elapsed=0
    local speed=0
    local eta=0
    
    while true; do
        # Check if file exists yet
        if [ -f "$file_path" ]; then
            current_size=$(du -b "$file_path" 2>/dev/null | cut -f1)
            
            # If expected size is not provided, use some heuristics
            if [ -z "$expected_size" ] || [ "$expected_size" -eq 0 ]; then
                # Just show size
                printf "\r[%s] %s - %s " "↑" "$message" "$(format_size $current_size)"
            else
                # Calculate progress
                local percent=$((current_size * 100 / expected_size))
                if [ "$percent" -gt 100 ]; then
                    percent=100
                fi
                
                # Calculate speed
                if [ "$elapsed" -gt 0 ]; then
                    speed=$((current_size / elapsed))
                fi
                
                # Calculate ETA
                if [ "$speed" -gt 0 ]; then
                    eta=$(((expected_size - current_size) / speed))
                fi
                
                # Format for display
                local speed_formatted=$(format_size $speed)
                local eta_formatted=$(format_time $eta)
                
                # Show progress
                printf "\r[%3d%%] %s - %s at %s/s, ETA: %s " \
                       "$percent" "$message" "$(format_size $current_size)" "$speed_formatted" "$eta_formatted"
            fi
            
            # Store last size for speed calculation
            last_size=$current_size
        else
            printf "\r[...] %s - Waiting for file..." "$message"
        fi
        
        # Check if monitored process still exists
        if [ -n "$pid" ] && ! kill -0 $pid 2>/dev/null; then
            printf "\r%-80s\r" " "
            printf "\r[100%%] %s - Completed (%s) " "$message" "$(format_size $current_size)"
            break
        fi
        
        # Update elapsed time
        elapsed=$(($(date +%s) - start_time))
        
        # If file size hasn't changed in 5 seconds and process is not running, assume we're done
        if [ "$current_size" -eq "$last_size" ] && [ "$elapsed" -gt 5 ] && [ -n "$pid" ] && ! kill -0 $pid 2>/dev/null; then
            printf "\r%-80s\r" " "
            printf "\r[100%%] %s - Completed (%s) " "$message" "$(format_size $current_size)"
            break
        fi
        
        sleep $interval
    done
    
    printf "\n"
}

# Format time in seconds to readable format
format_time() {
    local seconds=$1
    
    if [ "$seconds" -lt 60 ]; then
        echo "${seconds}s"
    elif [ "$seconds" -lt 3600 ]; then
        local m=$((seconds / 60))
        local s=$((seconds % 60))
        printf "%dm %ds" $m $s
    else
        local h=$((seconds / 3600))
        local m=$(((seconds % 3600) / 60))
        printf "%dh %dm" $h $m
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

# SECURITY IMPROVEMENT: Secure way to check required tools
check_required_tools() {
    local missing_tools=()
    
    for tool in "$@"; do
        if ! command -v "$tool" > /dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo "Error: Required tools not installed: ${missing_tools[*]}"
        return 1
    fi
    
    return 0
}

# Function to open a file in the default browser (in background)
open_in_browser() {
    local file_path="$1"
    
    # Make sure the file exists
    if [ ! -f "$file_path" ]; then
        echo -e "${RED}Error: File not found: $file_path${NC}"
        return 1
    fi
    
    # Convert to file:// URL if it's a local path and doesn't already have a scheme
    if [[ ! "$file_path" =~ ^[a-zA-Z]+:// ]]; then
        # Make sure it's an absolute path
        if [[ ! "$file_path" =~ ^/ ]]; then
            file_path="$(pwd)/$file_path"
        fi
        file_path="file://$file_path"
    fi
    
    # Create a temporary script to run the browser command
    local temp_script=$(mktemp)
    
    # Make the script executable
    chmod +x "$temp_script"
    
    # Detect OS and write appropriate command to script
    if [ "$(uname)" == "Darwin" ]; then
        # macOS
        echo "#!/bin/bash" > "$temp_script"
        echo "open \"$file_path\" &>/dev/null" >> "$temp_script"
    elif [ "$(uname)" == "Linux" ]; then
        # Linux - try different commands in order
        echo "#!/bin/bash" > "$temp_script"
        echo "if command -v xdg-open &>/dev/null; then" >> "$temp_script"
        echo "    xdg-open \"$file_path\" &>/dev/null" >> "$temp_script"
        echo "elif command -v gnome-open &>/dev/null; then" >> "$temp_script"
        echo "    gnome-open \"$file_path\" &>/dev/null" >> "$temp_script"
        echo "elif command -v kde-open &>/dev/null; then" >> "$temp_script"
        echo "    kde-open \"$file_path\" &>/dev/null" >> "$temp_script"
        echo "else" >> "$temp_script"
        echo "    echo 'No suitable browser command found'" >> "$temp_script"
        echo "    exit 1" >> "$temp_script"
        echo "fi" >> "$temp_script"
    elif [[ "$(uname)" == *"MINGW"* || "$(uname)" == *"MSYS"* || "$(uname)" == *"CYGWIN"* ]]; then
        # Windows
        echo "#!/bin/bash" > "$temp_script"
        echo "start \"$file_path\" &>/dev/null" >> "$temp_script"
    else
        echo -e "${YELLOW}Unknown OS. Please open this file manually:${NC}"
        echo -e "${GREEN}$file_path${NC}"
        rm -f "$temp_script"
        return 1
    fi
    
    # Add self-cleanup to script
    echo "rm -f \"$temp_script\"" >> "$temp_script"
    
    # Run the script in the background, completely detached from parent process
    nohup "$temp_script" >/dev/null 2>&1 &
    
    # Brief pause to allow browser to start
    sleep 0.5
    
    return 0
}

# End of utility functions