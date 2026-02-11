#!/bin/bash
# utils.sh - Shared utility functions for backup-webdev
# This file contains common functions used across all scripts
#
# SCRIPT TYPE: Module (sourced by other scripts, not executed directly)
#
# STRUCTURE: Path helpers → OS/time utilities → Formatting → Logging →
#            Validation → Backup verification → Email

# Set restrictive umask to ensure secure file creation
umask 027

# Source the shared configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Version checking function
check_version_compatibility() {
    local required_version="${1:-$VERSION}"
    local current_version="${VERSION:-unknown}"
    
    if [ "$current_version" = "unknown" ]; then
        echo -e "${YELLOW}Warning: Version information not available${NC}" >&2
        return 0  # Don't fail if version not set
    fi
    
    # Simple version check (can be enhanced for semantic versioning)
    if [ "$current_version" != "$required_version" ]; then
        echo -e "${YELLOW}Warning: Version mismatch detected${NC}" >&2
        echo -e "  Current: $current_version" >&2
        echo -e "  Expected: $required_version" >&2
        echo -e "  This may cause compatibility issues." >&2
        return 1
    fi
    
    return 0
}

# Source secrets file if it exists (contains API keys and sensitive data)
if [ -f "$SCRIPT_DIR/secrets.sh" ]; then
    source "$SCRIPT_DIR/secrets.sh"
fi

# Load utility submodules (order matters: os sets IS_MACOS used by time, path)
source "$SCRIPT_DIR/utils-os.sh"
source "$SCRIPT_DIR/utils-time.sh"
source "$SCRIPT_DIR/utils-path.sh"
source "$SCRIPT_DIR/utils-format.sh"

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

# Check if this is the first run and prompt user to configure
check_first_run() {
    local config_file="$SCRIPT_DIR/config.sh"
    
    # Check if configuration marker exists
    if [ ! -f "$FIRST_RUN_MARKER" ]; then
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}${BOLD}                   FIRST TIME SETUP${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo
        echo -e "${YELLOW}This appears to be your first time running the backup tool.${NC}"
        echo
        echo -e "${WHITE}Current Configuration:${NC}"
        echo -e "  ${CYAN}Config File:${NC}    $config_file"
        echo -e "  ${CYAN}Source:${NC}         ${DEFAULT_SOURCE_DIRS[*]}"
        echo -e "  ${CYAN}Destination:${NC}    $DEFAULT_BACKUP_DIR"
        echo -e "  ${CYAN}OS Detected:${NC}    $(get_os_version_display)"
        echo
        echo -e "${YELLOW}These defaults may not be appropriate for your system.${NC}"
        echo
        read -p "$(echo -e ${WHITE}Would you like to configure the backup settings now? [y/N]: ${NC})" -n 1 -r configure_now
        echo
        
        if [[ "$configure_now" =~ ^[Yy]$ ]]; then
            echo
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${GREEN}${BOLD}                   CONFIGURATION GUIDE${NC}"
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo
            echo -e "${WHITE}To configure your backup settings:${NC}"
            echo
            echo -e "${CYAN}1.${NC} Open the configuration file:"
            echo -e "   ${GREEN}nano $config_file${NC}"
            echo -e "   ${YELLOW}or${NC}"
            echo -e "   ${GREEN}vi $config_file${NC}"
            echo
            echo -e "${CYAN}2.${NC} Update these key settings:"
            echo
            echo -e "   ${WHITE}DEFAULT_SOURCE_DIRS${NC} - Directories to back up"
            echo -e "   Example for macOS:"
            echo -e "     ${GREEN}DEFAULT_SOURCE_DIRS=(\"\$HOME/Developer\" \"\$HOME/Documents/Projects\")${NC}"
            echo
            echo -e "   Example for Linux:"
            echo -e "     ${GREEN}DEFAULT_SOURCE_DIRS=(\"/home/user/projects\" \"/home/user/repos\")${NC}"
            echo
            echo -e "   ${WHITE}DEFAULT_BACKUP_DIR${NC} - Where to store backups"
            echo -e "   Examples:"
            echo -e "     ${GREEN}DEFAULT_BACKUP_DIR=\"$HOME/backups\"${NC}"
            echo -e "     ${GREEN}DEFAULT_BACKUP_DIR=\"/Volumes/MyDrive/backups\"${NC}"
            echo -e "     ${GREEN}DEFAULT_BACKUP_DIR=\"/mnt/backup-drive/backups\"${NC}"
            echo
            echo -e "${CYAN}3.${NC} Save and close the file"
            echo
            echo -e "${CYAN}4.${NC} Run the backup tool again:"
            echo -e "   ${GREEN}./webdev-backup.sh${NC}"
            echo
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo
            echo -e "${YELLOW}Exiting to allow you to configure the tool...${NC}"
            echo
            exit 0
        else
            # User declined to configure, mark as configured and continue
            touch "$FIRST_RUN_MARKER"
            echo
            echo -e "${GREEN}Using default settings. You can configure anytime by editing:${NC}"
            echo -e "${CYAN}$config_file${NC}"
            echo
            sleep 2
        fi
    fi
}

# Display current configuration (always show this)
display_current_config() {
    local config_file="$SCRIPT_DIR/config.sh"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}${BOLD}                 CURRENT CONFIGURATION${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Config File:${NC}     $config_file"
    echo -e "${CYAN}Source Dirs:${NC}     ${DEFAULT_SOURCE_DIRS[*]}"
    echo -e "${CYAN}Destination:${NC}     $DEFAULT_BACKUP_DIR"
    echo -e "${CYAN}Full Path:${NC}       $(cd "$DEFAULT_BACKUP_DIR" 2>/dev/null && pwd || echo "$DEFAULT_BACKUP_DIR (not created yet)")"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
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

# Logging function with standardized format
log() {
    local message=$1
    local log_file=${2:-}
    local silent_mode=${3:-false}
    local log_level=${4:-INFO}
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    # Standardized log format: [TIMESTAMP] [LEVEL] MESSAGE
    local log_entry="[$timestamp] [$log_level] $message"
    
    if [[ -n "$log_file" && -d "$(dirname "$log_file")" ]]; then
        echo "$log_entry" >> "$log_file"
    fi
    
    if [[ "$silent_mode" == false ]]; then
        # Color code based on log level
        case "$log_level" in
            ERROR|FATAL)
                echo -e "${RED}$log_entry${NC}"
                ;;
            WARNING|WARN)
                echo -e "${YELLOW}$log_entry${NC}"
                ;;
            DEBUG)
                if [ "${DEBUG_MODE:-false}" = "true" ]; then
                    echo -e "${CYAN}$log_entry${NC}"
                fi
                ;;
            *)
                echo -e "$log_entry"
                ;;
        esac
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

# SECURITY IMPROVEMENT: Use array-based command execution approach
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

# SECURITY IMPROVEMENT: Comprehensive function to sanitize input against command injection
sanitize_input() {
    local input="$1"
    local strict="${2:-false}"  # strict mode removes more characters
    
    if [ -z "$input" ]; then
        echo ""
        return 0
    fi
    
    # Basic protection against command injection
    local sanitized=$(echo "$input" | tr -d ';&|$()`')
    
    # More aggressive sanitization for highly sensitive contexts
    if [ "$strict" = "true" ]; then
        sanitized=$(echo "$sanitized" | tr -d '<>{}[]!?*#~\\\r\n\t')
        # Remove backticks and $() syntax which could be used for command substitution
        sanitized=$(echo "$sanitized" | sed 's/`[^`]*`//g' | sed 's/\$([^)]*)//g')
        # Remove common shell command sequences
        sanitized=$(echo "$sanitized" | sed 's/\b\(sudo\|bash\|sh\|chmod\|chown\|rm\|mv\|cp\|cat\)\b//g')
    fi
    
    echo "$sanitized"
}

# Validate path text before writing into config.sh literal entries.
# Reject quote and newline characters that could break shell syntax.
is_safe_config_literal() {
    local value="${1:-}"
    case "$value" in
        *\"*|*\'*|*$'\n'*|*$'\r'*)
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

# Sanitize and validate custom backup options for cron safety.
# Returns shell-escaped options string (without leading/trailing spaces) on stdout.
sanitize_cron_backup_options() {
    local raw="${1:-}"
    [ -z "$raw" ] && { echo ""; return 0; }

    # Reject obvious shell metacharacters for cron command safety
    case "$raw" in
        *";"*|*"|"*|*"&"*|*\`*|*'$('*|*"<"*|*">"*|*$'\n'*|*$'\r'*)
            return 1
            ;;
    esac

    local out=""
    local token next
    set -- $raw
    while [ $# -gt 0 ]; do
        token="$1"
        case "$token" in
            --incremental|--differential|--verify|--no-verify|--thorough-verify|--quick|--silent|--dry-run|--external)
                out="$out $(printf '%q' "$token")"
                shift
                ;;
            --compression|--parallel|--email|--cloud|--source|--sources|--destination|--dest|--bandwidth)
                next="$2"
                [ -z "$next" ] && return 1
                case "$next" in --*) return 1 ;; esac
                out="$out $(printf '%q' "$token") $(printf '%q' "$next")"
                shift 2
                ;;
            *)
                return 1
                ;;
        esac
    done

    echo "${out# }"
    return 0
}

# Verify directory exists and is accessible (uses colors from this file)
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

# Run a command with optional timeout (timeout/gtimeout on Linux, no timeout on macOS if missing)
run_with_timeout() {
    local seconds="$1"
    shift
    if command -v timeout >/dev/null 2>&1; then
        timeout "${seconds}s" "$@"
    elif command -v gtimeout >/dev/null 2>&1; then
        gtimeout "${seconds}s" "$@"
    else
        "$@"
    fi
}

# Hash stdin with SHA-256 (cross-platform: sha256sum vs shasum)
sha256_stdin() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum | cut -d' ' -f1
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 | cut -d' ' -f1
    else
        echo "" && return 1
    fi
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
    local file_size=$(get_file_size_bytes "$backup_file")
    if [ "$file_size" -eq 0 ]; then
        log "✗ Backup file is empty: $(basename "$backup_file")" "$log_file" "$silent_mode"
        return 1
    fi
    
    # Check archive is self-contained: exactly one top-level path (extract puts everything in one folder)
    local top_levels
    top_levels=$(tar -tzf "$backup_file" 2>/dev/null | cut -d/ -f1 | sort -u)
    local top_count
    top_count=$(echo "$top_levels" | grep -c . 2>/dev/null || echo "0")
    if [ "$top_count" -ne 1 ]; then
        log "✗ Backup is not self-contained (expected one top-level directory, got $top_count): $(basename "$backup_file")" "$log_file" "$silent_mode"
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
        
        # Create temporary directory for extraction test with secure permissions
        local temp_dir=$(mktemp -d)
        chmod 700 "$temp_dir"
        log "Using temporary directory for extraction test: $temp_dir" "$log_file" "$silent_mode"
        
        # Safely list archive contents (no extraction yet)
        local file_list=$(mktemp)
        chmod 600 "$file_list"
        tar -tzf "$backup_file" > "$file_list" 2>/dev/null
        local file_count=$(wc -l < "$file_list")
        log "Archive contains $file_count files/directories" "$log_file" "$silent_mode"
        
        # Check for dangerous paths in the archive that could lead to directory traversal
        if grep -q -E '^/|^\.\./|/\.\./|\.\./' "$file_list"; then
            log "✗ WARNING: Archive contains absolute or traversal paths - potential security risk!" "$log_file" "$silent_mode"
            rm -f "$file_list"
            rm -rf "$temp_dir"
            return 1
        fi
        
        # Try to extract a small text file for verification
        # Find the first small file (likely a .md, .txt, .json, etc.)
        local small_file=$(grep -E '\.(md|txt|json|js|css|html)$' "$file_list" | head -1)
        
        if [ -n "$small_file" ]; then
            # Validate path before extraction
            if [[ "$small_file" == *";"* || "$small_file" == *"&"* || "$small_file" == *"|"* || 
                  "$small_file" == *"$"* || "$small_file" == *"("* || "$small_file" == *")"* ]]; then
                log "✗ Archive contains potentially malicious filenames" "$log_file" "$silent_mode"
                rm -f "$file_list"
                rm -rf "$temp_dir"
                return 1
            fi
            
            # Safe extraction with --no-same-owner to avoid privilege escalation
            # and --no-absolute-names to prevent overwriting system files
            if tar -xzf "$backup_file" --no-same-owner --no-absolute-names -C "$temp_dir" "$small_file" 2>/dev/null; then
                log "✓ Successfully extracted test file: $small_file" "$log_file" "$silent_mode"
                if [ -f "$temp_dir/$small_file" ]; then
                    log "✓ Extracted file exists and is readable" "$log_file" "$silent_mode"
                else
                    log "✗ Extracted file does not exist or is not readable" "$log_file" "$silent_mode"
                    rm -f "$file_list"
                    rm -rf "$temp_dir"
                    return 1
                fi
            else
                log "✗ Failed to extract test file" "$log_file" "$silent_mode"
                rm -f "$file_list"
                rm -rf "$temp_dir"
                return 1
            fi
        else
            log "No suitable small file found for extraction test, skipping this step" "$log_file" "$silent_mode"
        fi
        
        # Clean up safely
        rm -f "$file_list"
        rm -rf "$temp_dir"
    fi
    
    # All checks passed
    log "✓ Backup integrity verified for: $(basename "$backup_file")" "$log_file" "$silent_mode"
    return 0
}

# Secure email notification function
send_email_notification() {
    local subject=$1
    local message=$2
    local recipient=${3:-}
    local attachment=${4:-}
    
    # Skip if no recipient
    if [[ -z "$recipient" ]]; then
        return 0
    fi
    
    # Validate recipient email format
    if ! [[ "$recipient" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo "Invalid email format: $recipient"
        return 1
    fi
    
    # Check if mail command exists
    if ! command -v mail >/dev/null 2>&1; then
        echo "Cannot send email - mail command not found"
        return 1
    fi
    
    # Sanitize inputs to prevent command injection
    local safe_subject=$(sanitize_input "$subject" "true")
    local safe_message=$(sanitize_input "$message")
    local safe_recipient=$(sanitize_input "$recipient" "true")
    
    # If credentials are available, use them
    if [[ -n "$EMAIL_USERNAME" && -n "$EMAIL_PASSWORD" && -n "$EMAIL_SMTP_SERVER" ]]; then
        # Create temporary mailrc file with secure permissions
        local mailrc_file=$(mktemp)
        chmod 600 "$mailrc_file"
        
        # Write config to mailrc securely
        {
            echo "set smtp=$EMAIL_SMTP_SERVER"
            echo "set smtp-use-starttls"
            echo "set smtp-auth=login"
            echo "set smtp-auth-user=$EMAIL_USERNAME"
            echo "set smtp-auth-password=$EMAIL_PASSWORD"
            echo "set from=${EMAIL_FROM:-$EMAIL_USERNAME}"
        } > "$mailrc_file"
        
        # Create a temporary message file with secure permissions
        local message_file=$(mktemp)
        chmod 600 "$message_file"
        echo "$safe_message" > "$message_file"
        
        # Send with or without attachment
        if [[ -n "$attachment" && -f "$attachment" ]]; then
            MAILRC="$mailrc_file" EMAIL="$EMAIL_USERNAME" mail -s "$safe_subject" -a "$attachment" "$safe_recipient" < "$message_file"
        else
            MAILRC="$mailrc_file" EMAIL="$EMAIL_USERNAME" mail -s "$safe_subject" "$safe_recipient" < "$message_file"
        fi
        
        # Securely clean up temporary files with sensitive data
        if command -v shred >/dev/null 2>&1; then
            shred -u "$mailrc_file" "$message_file"
        else
            # Overwrite with random data if shred not available
            dd if=/dev/urandom of="$mailrc_file" bs=1k count=1 conv=notrunc >/dev/null 2>&1
            dd if=/dev/urandom of="$message_file" bs=1k count=1 conv=notrunc >/dev/null 2>&1
            rm -f "$mailrc_file" "$message_file"
        fi
    else
        # Basic sending without authentication (use mktemp to avoid predictable path / symlink risk)
        local tmp_msg
        tmp_msg=$(mktemp) || { echo "ERROR: Failed to create temp file for email" >&2; return 1; }
        chmod 600 "$tmp_msg"
        echo "$safe_message" > "$tmp_msg"
        
        if [[ -n "$attachment" && -f "$attachment" ]]; then
            mail -s "$safe_subject" -a "$attachment" "$safe_recipient" < "$tmp_msg"
        else
            mail -s "$safe_subject" "$safe_recipient" < "$tmp_msg"
        fi
        local mail_ret=$?
        rm -f "$tmp_msg"
        return $mail_ret
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
            current_size=$(get_file_size_bytes "$file_path")
            
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

# End of utility functions