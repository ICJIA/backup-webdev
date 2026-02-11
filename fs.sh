#!/bin/bash
# fs.sh - Filesystem operations for backup-webdev
# This file contains filesystem-related functions used across scripts

# Source the shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Create backup archive with compression
create_backup_archive() {
    local source_dir=$1
    local project=$2
    local backup_file=$3
    local log_file=${4:-}
    local compression=${5:-6}
    # Exclude node_modules contents completely (at any depth), but allow .env files
    # The pattern */node_modules/* excludes all contents inside node_modules directories
    local exclude_pattern=${6:-"*/node_modules/*"}
    
    # Determine if we want to use parallel compression
    local parallel_threads=${7:-1}
    local silent_mode=${8:-false}
    
    # Estimate the source size (for progress reporting)
    local source_size=$(get_directory_size "$source_dir/$project" "node_modules")
    log "Estimated source size: $(format_size $source_size)" "$log_file" "$silent_mode"
    
    # Create a temporary log for capturing tar output
    local tar_log=$(mktemp)
    
    if [ "$parallel_threads" -gt 1 ] && command -v pigz >/dev/null 2>&1; then
        # Use pigz for parallel compression
        log "Using parallel compression with $parallel_threads threads (pigz)" "$log_file" "$silent_mode"
        
        # Run tar with pigz in background so we can monitor
        if [ "$silent_mode" = false ]; then
            # Show progress for interactive mode
            (tar --use-compress-program="pigz -$compression" -cf "$backup_file" \
                --exclude="$exclude_pattern" \
                --exclude="node_modules/*" \
                --exclude="*/node_modules" \
                -C "$source_dir" "$project" 2> "$tar_log") &
            
            # Get PID of background tar process
            local tar_pid=$!
            
            # Show real-time progress by monitoring the output file size
            monitor_file_progress "$backup_file" "$((source_size / 5))" "Compressing $project" "$tar_pid"
            
            # Wait for tar to finish
            wait $tar_pid
            local tar_status=$?
            
            # Append tar log to main log
            if [ -f "$tar_log" ]; then
                cat "$tar_log" >> "$log_file"
                rm -f "$tar_log"
            fi
            
            return $tar_status
        else
            # Silent mode - just run normally
            if tar --use-compress-program="pigz -$compression" -cf "$backup_file" \
                --exclude="$exclude_pattern" \
                --exclude="node_modules/*" \
                --exclude="*/node_modules" \
                -C "$source_dir" "$project" 2>> "$log_file"; then
                rm -f "$tar_log"
                return 0
            else
                local tar_status=$?
                if [ -f "$tar_log" ]; then
                    cat "$tar_log" >> "$log_file"
                    rm -f "$tar_log"
                fi
                return $tar_status
            fi
        fi
    else
        # Use standard compression with gzip
        log "Using standard compression with gzip" "$log_file" "$silent_mode"
        
        # Run tar in background so we can monitor
        if [ "$silent_mode" = false ]; then
            # Show progress for interactive mode
            (tar -czf "$backup_file" \
                --exclude="$exclude_pattern" \
                --exclude="node_modules/*" \
                --exclude="*/node_modules" \
                -C "$source_dir" "$project" 2> "$tar_log") &
            
            # Get PID of background tar process
            local tar_pid=$!
            
            # Show real-time progress by monitoring the output file size
            monitor_file_progress "$backup_file" "$((source_size / 5))" "Compressing $project" "$tar_pid"
            
            # Wait for tar to finish
            wait $tar_pid
            local tar_status=$?
            
            # Append tar log to main log
            if [ -f "$tar_log" ]; then
                cat "$tar_log" >> "$log_file"
                rm -f "$tar_log"
            fi
            
            return $tar_status
        else
            # Silent mode - just run normally
            if tar -czf "$backup_file" \
                --exclude="$exclude_pattern" \
                --exclude="node_modules/*" \
                --exclude="*/node_modules" \
                -C "$source_dir" "$project" 2>> "$log_file"; then
                rm -f "$tar_log"
                return 0
            else
                local tar_status=$?
                if [ -f "$tar_log" ]; then
                    cat "$tar_log" >> "$log_file"
                    rm -f "$tar_log"
                fi
                return $tar_status
            fi
        fi
    fi
}

# Create incremental backup archive
create_incremental_backup() {
    local source_dir=$1
    local project=$2
    local backup_file=$3
    local snapshot_file=${4:-}
    local log_file=${5:-}
    local compression=${6:-6}
    local exclude_pattern=${7:-"*/node_modules/*"}
    
    # If no snapshot file, create one
    if [ -z "$snapshot_file" ]; then
        snapshot_file="${backup_file}.snapshot"
    fi
    
    # Check if snapshot exists for incremental backup
    if [ -f "$snapshot_file" ]; then
        # Incremental backup using existing snapshot
        if tar --listed-incremental="$snapshot_file" -czf "$backup_file" \
            --exclude="$exclude_pattern" \
            --exclude="node_modules/*" \
            --exclude="*/node_modules" \
            -C "$source_dir" "$project" 2>> "$log_file"; then
            return 0
        else
            return 1
        fi
    else
        # First level backup - create snapshot
        if tar --listed-incremental="$snapshot_file" -czf "$backup_file" \
            --exclude="$exclude_pattern" \
            --exclude="node_modules/*" \
            --exclude="*/node_modules" \
            -C "$source_dir" "$project" 2>> "$log_file"; then
            return 0
        else
            return 1
        fi
    fi
}

# Create differential backup archive
create_differential_backup() {
    local source_dir=$1
    local project=$2
    local backup_file=$3
    local base_snapshot=${4:-}
    local log_file=${5:-}
    local compression=${6:-6}
    local exclude_pattern=${7:-"*/node_modules/*"}
    
    # Check for base snapshot - if not exists, create full backup
    if [ -z "$base_snapshot" ] || [ ! -f "$base_snapshot" ]; then
        log "No base snapshot found, creating full backup as reference" "$log_file"
        # Create base snapshot with new backup
        base_snapshot="${backup_file}.base-snapshot"
        
        if tar --listed-incremental="$base_snapshot" -czf "$backup_file" \
            --exclude="$exclude_pattern" \
            --exclude="node_modules/*" \
            --exclude="*/node_modules" \
            -C "$source_dir" "$project" 2>> "$log_file"; then
            return 0
        else
            return 1
        fi
    else
        # Create a temporary snapshot for this differential backup
        local temp_snapshot=$(mktemp)
        
        # Copy the base snapshot to use as reference
        cp "$base_snapshot" "$temp_snapshot"
        
        # Create differential backup
        if tar --listed-incremental="$temp_snapshot" -czf "$backup_file" \
            --exclude="$exclude_pattern" \
            --exclude="node_modules/*" \
            --exclude="*/node_modules" \
            -C "$source_dir" "$project" 2>> "$log_file"; then
            rm -f "$temp_snapshot"
            return 0
        else
            rm -f "$temp_snapshot"
            return 1
        fi
    fi
}

# Extract backup archive
extract_backup() {
    local backup_file=$1
    local extract_dir=$2
    local log_file=${3:-}
    local specific_path=${4:-}
    
    # Create extraction directory if it doesn't exist
    if [ ! -d "$extract_dir" ]; then
        mkdir -p "$extract_dir" || return 1
        log "Created extraction directory: $extract_dir" "$log_file"
    fi
    
    # Build safe tar flags (--no-same-owner prevents restoring as root-owned files;
    # macOS BSD tar doesn't support it, so only add on GNU tar / Linux)
    local tar_safe_flags=""
    if [ "$(uname -s)" != "Darwin" ]; then
        tar_safe_flags="--no-same-owner"
    fi

    # Extract specific path if provided, otherwise extract entire archive
    if [ -n "$specific_path" ]; then
        if tar -xzf "$backup_file" $tar_safe_flags -C "$extract_dir" "$specific_path" 2>> "$log_file"; then
            log "Extracted $specific_path from $(basename "$backup_file")" "$log_file"
            return 0
        else
            log "Failed to extract $specific_path from $(basename "$backup_file")" "$log_file"
            return 1
        fi
    else
        if tar -xzf "$backup_file" $tar_safe_flags -C "$extract_dir" 2>> "$log_file"; then
            log "Extracted $(basename "$backup_file")" "$log_file"
            return 0
        else
            log "Failed to extract $(basename "$backup_file")" "$log_file"
            return 1
        fi
    fi
}

# List backup archive contents
list_backup_contents() {
    local backup_file=$1
    local filter=${2:-}
    
    if [ -n "$filter" ]; then
        tar -tzf "$backup_file" | grep "$filter"
    else
        tar -tzf "$backup_file"
    fi
}

# Get size of a directory (excluding specific patterns) - cross-platform
get_directory_size() {
    local dir_path=$1
    local exclude_pattern=${2:-"node_modules"}
    
    if [ ! -d "$dir_path" ]; then
        echo "0"
        return
    fi
    
    # macOS du doesn't support --exclude, so use find + du
    if [ "$(uname -s)" = "Darwin" ]; then
        # macOS: Use find to exclude patterns, then sum with awk
        find "$dir_path" -type f ! -path "*/$exclude_pattern/*" -exec du -k {} + 2>/dev/null | \
            awk '{sum += $1} END {print sum * 1024}'
    else
        # Linux: Use du with --exclude (GNU du)
        du -sb --exclude="$exclude_pattern" "$dir_path" 2>/dev/null | cut -f1
    fi
}

# Find projects in a directory
find_projects() {
    local source_dir=$1
    local max_depth=${2:-1}
    
    if [ ! -d "$source_dir" ]; then
        return 1
    fi
    
    # Find directories only up to max_depth, with a timeout to prevent hanging
    # Use -not -path "*/\.*" to exclude hidden directories, BUT always include .ssh
    # Use -not -path "*/node_modules*" to exclude node_modules which can be large
    find "$source_dir" -maxdepth "$max_depth" -mindepth 1 -type d \
         \( -name ".ssh" -o -not -path "*/\.*" \) \
         -not -path "*/node_modules*" \
         | sort
}

# Find the most recent backup for a project (cross-platform)
find_latest_backup() {
    local backup_dir=$1
    local project=${2:-}
    
    if [ ! -d "$backup_dir" ]; then
        return 1
    fi
    
    if [ -n "$project" ]; then
        # Look for specific project backups
        if [ "$(uname -s)" = "Darwin" ]; then
            # macOS: Use find + stat instead of -printf
            find "$backup_dir" -type f -name "${project}_*.tar.gz" -exec stat -f "%m %N" {} \; | \
                sort -rn | head -1 | cut -d' ' -f2-
        else
            # Linux: Use GNU find -printf
            find "$backup_dir" -type f -name "${project}_*.tar.gz" -printf "%T@ %p\n" | \
                sort -nr | head -1 | cut -d' ' -f2-
        fi
    else
        # Look for any backup (supports both old wsl2_backup_* and new webdev_backup_* naming)
        if [ "$(uname -s)" = "Darwin" ]; then
            # macOS: Use find + stat instead of -printf
            find "$backup_dir" -type d \( -name "webdev_backup_*" -o -name "wsl2_backup_*" \) -exec stat -f "%m %N" {} \; | \
                sort -rn | head -1 | cut -d' ' -f2-
        else
            # Linux: Use GNU find -printf
            find "$backup_dir" -type d \( -name "webdev_backup_*" -o -name "wsl2_backup_*" \) -printf "%T@ %p\n" | \
                sort -nr | head -1 | cut -d' ' -f2-
        fi
    fi
}

# List all backups (cross-platform)
list_all_backups() {
    local backup_dir=$1
    local project=${2:-}
    
    if [ ! -d "$backup_dir" ]; then
        return 1
    fi
    
    if [ -n "$project" ]; then
        # List specific project backups
        if [ "$(uname -s)" = "Darwin" ]; then
            # macOS: Use find + stat instead of -printf
            find "$backup_dir" -type f -name "${project}_*.tar.gz" -exec stat -f "%m %N" {} \; | \
                sort -rn | cut -d' ' -f2-
        else
            # Linux: Use GNU find -printf
            find "$backup_dir" -type f -name "${project}_*.tar.gz" -printf "%T@ %p\n" | \
                sort -nr | cut -d' ' -f2-
        fi
    else
        # List all backup directories (supports both old wsl2_backup_* and new webdev_backup_* naming)
        if [ "$(uname -s)" = "Darwin" ]; then
            # macOS: Use find + stat instead of -printf
            find "$backup_dir" -type d \( -name "webdev_backup_*" -o -name "wsl2_backup_*" \) -exec stat -f "%m %N" {} \; | \
                sort -rn | cut -d' ' -f2-
        else
            # Linux: Use GNU find -printf
            find "$backup_dir" -type d \( -name "webdev_backup_*" -o -name "wsl2_backup_*" \) -printf "%T@ %p\n" | \
                sort -nr | cut -d' ' -f2-
        fi
    fi
}

# ---- Cloud helper: run an S3-compatible transfer (upload or download) ----
# Handles interactive progress monitoring, bandwidth limiting, and logging.
# Usage: _s3_transfer "upload"|"download" LOCAL REMOTE LABEL LOG SILENT LIMIT [ENDPOINT]
_s3_transfer() {
    local direction="$1" local_path="$2" remote_path="$3" label="$4"
    local log_file="$5" silent_mode="$6" limit_cmd="$7" endpoint_url="${8:-}"
    
    local ep_flag=""
    [ -n "$endpoint_url" ] && ep_flag="--endpoint-url $endpoint_url"
    
    local src dst
    if [ "$direction" = "upload" ]; then
        src="$local_path"; dst="$remote_path"
    else
        src="$remote_path"; dst="$local_path"
    fi
    
    log "${label}: $remote_path" "$log_file" "$silent_mode"
    
    if [ "$silent_mode" = false ] && [ "$direction" = "upload" ]; then
        local file_size
        file_size=$(get_file_size_bytes "$local_path")
        # shellcheck disable=SC2086
        (aws s3 cp $limit_cmd "$src" "$dst" $ep_flag 2>/dev/null) &
        local pid=$!
        monitor_file_progress "/dev/null" "$file_size" "$label" "$pid" 1
        wait $pid
        local status=$?
    else
        # shellcheck disable=SC2086
        aws s3 cp $limit_cmd "$src" "$dst" $ep_flag
        local status=$?
    fi
    
    if [ "$status" -eq 0 ]; then
        log "Successfully completed $label" "$log_file" "$silent_mode"
    else
        log "Failed: $label" "$log_file" "$silent_mode"
    fi
    return $status
}

# ---- Cloud helper: save/restore DO Spaces AWS credential swap ----
_do_save_aws_creds() {
    _SAVED_AWS_KEY="${AWS_ACCESS_KEY_ID:-}"
    _SAVED_AWS_SECRET="${AWS_SECRET_ACCESS_KEY:-}"
    _SAVED_AWS_REGION="${AWS_DEFAULT_REGION:-}"
    export AWS_ACCESS_KEY_ID="$DO_SPACES_KEY"
    export AWS_SECRET_ACCESS_KEY="$DO_SPACES_SECRET"
    export AWS_DEFAULT_REGION="${DO_SPACES_REGION:-nyc3}"
}
_do_restore_aws_creds() {
    if [ -n "$_SAVED_AWS_KEY" ]; then
        export AWS_ACCESS_KEY_ID="$_SAVED_AWS_KEY"
        export AWS_SECRET_ACCESS_KEY="$_SAVED_AWS_SECRET"
        export AWS_DEFAULT_REGION="$_SAVED_AWS_REGION"
    fi
}

# Upload backup to cloud storage
upload_to_cloud() {
    local backup_file=$1
    local provider=$2
    local log_file=${3:-}
    local bandwidth_limit=${4:-0}
    local silent_mode=${5:-false}
    
    local limit_cmd=""
    if [ "$bandwidth_limit" -gt 0 ]; then
        limit_cmd="--bwlimit=$bandwidth_limit"
    fi
    
    local file_size
    file_size=$(get_file_size_bytes "$backup_file")
    log "Starting upload of $(basename "$backup_file") ($(format_size "$file_size"))" "$log_file" "$silent_mode"
    
    case "$provider" in
        aws|s3)
            if ! command -v aws >/dev/null 2>&1; then
                log "AWS CLI not installed. Cannot upload to S3." "$log_file"; return 1
            fi
            if [ -n "${AWS_ACCESS_KEY_ID:-}" ] && [ -n "${AWS_SECRET_ACCESS_KEY:-}" ]; then
                export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
                export AWS_DEFAULT_REGION="${S3_REGION:-us-west-2}"
                log "Using AWS credentials from secrets file" "$log_file"
            fi
            local bucket="${S3_BUCKET:-webdev-backups}"
            _s3_transfer "upload" "$backup_file" "s3://$bucket/$(basename "$backup_file")" \
                "Uploading to S3" "$log_file" "$silent_mode" "$limit_cmd"
            return $?
            ;;
        do|spaces|digitalocean)
            if ! command -v aws >/dev/null 2>&1; then
                log "AWS CLI not installed. Cannot upload to DigitalOcean Spaces." "$log_file"; return 1
            fi
            if [ -n "${DO_SPACES_KEY:-}" ] && [ -n "${DO_SPACES_SECRET:-}" ]; then
                _do_save_aws_creds
                log "Using DigitalOcean Spaces credentials from secrets file" "$log_file"
            else
                log "DigitalOcean Spaces credentials not found in secrets file." "$log_file"; return 1
            fi
            local bucket="${DO_SPACES_BUCKET:-webdev-backups}"
            local endpoint="${DO_SPACES_ENDPOINT:-nyc3.digitaloceanspaces.com}"
            _s3_transfer "upload" "$backup_file" "s3://$bucket/$(basename "$backup_file")" \
                "Uploading to DigitalOcean Spaces" "$log_file" "$silent_mode" "$limit_cmd" "https://$endpoint"
            local ret=$?
            _do_restore_aws_creds
            return $ret
            ;;
        dropbox)
            if ! command -v dropbox-uploader >/dev/null 2>&1; then
                log "Dropbox Uploader not installed. Cannot upload to Dropbox." "$log_file"; return 1
            fi
            if [ -n "${DROPBOX_ACCESS_TOKEN:-}" ]; then
                local dropbox_config="${HOME}/.dropbox_uploader"
                echo "OAUTH_ACCESS_TOKEN=$DROPBOX_ACCESS_TOKEN" > "$dropbox_config"
                chmod 600 "$dropbox_config"
                log "Using Dropbox credentials from secrets file" "$log_file"
            fi
            local dropbox_path="/backups/$(basename "$backup_file")"
            log "Uploading to Dropbox: $dropbox_path" "$log_file"
            if dropbox-uploader upload "$backup_file" "$dropbox_path"; then
                log "Successfully uploaded to Dropbox: $dropbox_path" "$log_file"; return 0
            else
                log "Failed to upload to Dropbox: $dropbox_path" "$log_file"; return 1
            fi
            ;;
        gdrive|google)
            if ! command -v gdrive >/dev/null 2>&1; then
                log "Google Drive CLI not installed. Cannot upload to Google Drive." "$log_file"; return 1
            fi
            if [ -n "${GDRIVE_CLIENT_ID:-}" ] && [ -n "${GDRIVE_CLIENT_SECRET:-}" ] && [ -n "${GDRIVE_REFRESH_TOKEN:-}" ]; then
                mkdir -p "${HOME}/.gdrive"
                log "Using Google Drive credentials from secrets file" "$log_file"
            fi
            log "Uploading to Google Drive: $(basename "$backup_file")" "$log_file"
            if gdrive upload "$backup_file"; then
                log "Successfully uploaded to Google Drive" "$log_file"; return 0
            else
                log "Failed to upload to Google Drive" "$log_file"; return 1
            fi
            ;;
        *)
            log "Unknown cloud provider: $provider" "$log_file"; return 1
            ;;
    esac
}

# Download backup from cloud storage
download_from_cloud() {
    local backup_name=$1
    local download_dir=$2
    local provider=$3
    local log_file=${4:-}
    local bandwidth_limit=${5:-0}
    
    local limit_cmd=""
    if [ "$bandwidth_limit" -gt 0 ]; then
        limit_cmd="--bwlimit=$bandwidth_limit"
    fi
    
    case "$provider" in
        aws|s3)
            if ! command -v aws >/dev/null 2>&1; then
                log "AWS CLI not installed. Cannot download from S3." "$log_file"; return 1
            fi
            local bucket="${S3_BUCKET:-webdev-backups}"
            _s3_transfer "download" "$download_dir/$backup_name" "s3://$bucket/$backup_name" \
                "Downloading from S3" "$log_file" "true" "$limit_cmd"
            return $?
            ;;
        do|spaces|digitalocean)
            if ! command -v aws >/dev/null 2>&1; then
                log "AWS CLI not installed. Cannot download from DigitalOcean Spaces." "$log_file"; return 1
            fi
            if [ -n "${DO_SPACES_KEY:-}" ] && [ -n "${DO_SPACES_SECRET:-}" ]; then
                _do_save_aws_creds
                log "Using DigitalOcean Spaces credentials from secrets file" "$log_file"
            else
                log "DigitalOcean Spaces credentials not found in secrets file." "$log_file"; return 1
            fi
            local bucket="${DO_SPACES_BUCKET:-webdev-backups}"
            local endpoint="${DO_SPACES_ENDPOINT:-nyc3.digitaloceanspaces.com}"
            _s3_transfer "download" "$download_dir/$backup_name" "s3://$bucket/$backup_name" \
                "Downloading from DigitalOcean Spaces" "$log_file" "true" "$limit_cmd" "https://$endpoint"
            local ret=$?
            _do_restore_aws_creds
            return $ret
            ;;
        dropbox)
            if ! command -v dropbox-uploader >/dev/null 2>&1; then
                log "Dropbox Uploader not installed. Cannot download from Dropbox." "$log_file"; return 1
            fi
            local dropbox_path="/backups/$backup_name"
            log "Downloading from Dropbox: $dropbox_path" "$log_file"
            if dropbox-uploader download "$dropbox_path" "$download_dir/$backup_name"; then
                log "Successfully downloaded from Dropbox: $download_dir/$backup_name" "$log_file"; return 0
            else
                log "Failed to download from Dropbox: $dropbox_path" "$log_file"; return 1
            fi
            ;;
        gdrive|google)
            if ! command -v gdrive >/dev/null 2>&1; then
                log "Google Drive CLI not installed. Cannot download from Google Drive." "$log_file"; return 1
            fi
            local file_id
            file_id=$(gdrive list --query "name = '$backup_name'" --no-header | head -1 | awk '{print $1}')
            if [ -z "$file_id" ]; then
                log "File not found in Google Drive: $backup_name" "$log_file"; return 1
            fi
            log "Downloading from Google Drive: $backup_name (ID: $file_id)" "$log_file"
            if gdrive download --path "$download_dir" "$file_id"; then
                log "Successfully downloaded from Google Drive: $download_dir/$backup_name" "$log_file"; return 0
            else
                log "Failed to download from Google Drive: $backup_name" "$log_file"; return 1
            fi
            ;;
        *)
            log "Unknown cloud provider: $provider" "$log_file"; return 1
            ;;
    esac
}

# Find changed files since a specific date
find_changed_files() {
    local directory=$1
    local since_date=$2
    local exclude_pattern=${3:-"node_modules"}
    
    # Find files modified since given date
    find "$directory" -type f -not -path "*/$exclude_pattern/*" -newermt "$since_date" -print
}

# End of filesystem operations