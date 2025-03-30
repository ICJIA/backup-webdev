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
            -C "$source_dir" "$project" 2>> "$log_file"; then
            return 0
        else
            return 1
        fi
    else
        # First level backup - create snapshot
        if tar --listed-incremental="$snapshot_file" -czf "$backup_file" \
            --exclude="$exclude_pattern" \
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
    
    # Extract specific path if provided, otherwise extract entire archive
    if [ -n "$specific_path" ]; then
        if tar -xzf "$backup_file" -C "$extract_dir" "$specific_path" 2>> "$log_file"; then
            log "Extracted $specific_path from $(basename "$backup_file")" "$log_file"
            return 0
        else
            log "Failed to extract $specific_path from $(basename "$backup_file")" "$log_file"
            return 1
        fi
    else
        if tar -xzf "$backup_file" -C "$extract_dir" 2>> "$log_file"; then
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

# Get size of a directory (excluding specific patterns)
get_directory_size() {
    local dir_path=$1
    local exclude_pattern=${2:-"node_modules"}
    
    if [ -d "$dir_path" ]; then
        du -sb --exclude="$exclude_pattern" "$dir_path" 2>/dev/null | cut -f1
    else
        echo "0"
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
    # Use -not -path "*/\.*" to exclude hidden directories
    # Use -not -path "*/node_modules*" to exclude node_modules which can be large
    find "$source_dir" -maxdepth "$max_depth" -mindepth 1 -type d \
         -not -path "*/\.*" \
         -not -path "*/node_modules*" \
         | sort
}

# Find the most recent backup for a project
find_latest_backup() {
    local backup_dir=$1
    local project=${2:-}
    
    if [ ! -d "$backup_dir" ]; then
        return 1
    fi
    
    if [ -n "$project" ]; then
        # Look for specific project backups
        find "$backup_dir" -type f -name "${project}_*.tar.gz" -printf "%T@ %p\n" | sort -nr | head -1 | cut -d' ' -f2-
    else
        # Look for any backup
        find "$backup_dir" -type d -name "webdev_backup_*" -printf "%T@ %p\n" | sort -nr | head -1 | cut -d' ' -f2-
    fi
}

# List all backups
list_all_backups() {
    local backup_dir=$1
    local project=${2:-}
    
    if [ ! -d "$backup_dir" ]; then
        return 1
    fi
    
    if [ -n "$project" ]; then
        # List specific project backups
        find "$backup_dir" -type f -name "${project}_*.tar.gz" -printf "%T@ %p\n" | sort -nr | cut -d' ' -f2-
    else
        # List all backup directories
        find "$backup_dir" -type d -name "webdev_backup_*" -printf "%T@ %p\n" | sort -nr | cut -d' ' -f2-
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
    
    # Get file size for progress reporting
    local file_size=$(du -b "$backup_file" 2>/dev/null | cut -f1)
    log "Starting upload of $(basename "$backup_file") ($(format_size $file_size))" "$log_file" "$silent_mode"
    
    case "$provider" in
        aws|s3)
            # Check AWS CLI is installed
            if ! command -v aws >/dev/null 2>&1; then
                log "AWS CLI not installed. Cannot upload to S3." "$log_file"
                return 1
            fi
            
            # Set AWS credentials if available
            if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
                export AWS_ACCESS_KEY_ID
                export AWS_SECRET_ACCESS_KEY
                export AWS_DEFAULT_REGION="${S3_REGION:-us-west-2}"
                log "Using AWS credentials from secrets file" "$log_file"
            fi
            
            # Upload to S3
            local bucket="${S3_BUCKET:-webdev-backups}"
            local s3_path="s3://$bucket/$(basename "$backup_file")"
            
            log "Uploading to S3: $s3_path" "$log_file" "$silent_mode"
            
            if [ "$silent_mode" = false ]; then
                # Show progress for interactive mode
                (aws s3 cp $limit_cmd "$backup_file" "$s3_path" 2>/dev/null) &
                local upload_pid=$!
                
                # Monitor upload progress
                monitor_file_progress "/dev/null" "$file_size" "Uploading to S3" "$upload_pid" 1
                
                # Wait for upload to finish
                wait $upload_pid
                local upload_status=$?
                
                if [ "$upload_status" -eq 0 ]; then
                    log "Successfully uploaded to S3: $s3_path" "$log_file" "$silent_mode"
                    return 0
                else
                    log "Failed to upload to S3: $s3_path" "$log_file" "$silent_mode"
                    return 1
                fi
            else
                # Silent mode - run normally
                if aws s3 cp $limit_cmd "$backup_file" "$s3_path"; then
                    log "Successfully uploaded to S3: $s3_path" "$log_file" "$silent_mode"
                    return 0
                else
                    log "Failed to upload to S3: $s3_path" "$log_file" "$silent_mode"
                    return 1
                fi
            fi
            ;;
            
        do|spaces|digitalocean)
            # Check AWS CLI is installed (DO Spaces uses S3-compatible API)
            if ! command -v aws >/dev/null 2>&1; then
                log "AWS CLI not installed. Cannot upload to DigitalOcean Spaces." "$log_file"
                return 1
            fi
            
            # Set DigitalOcean Spaces credentials if available
            if [ -n "$DO_SPACES_KEY" ] && [ -n "$DO_SPACES_SECRET" ]; then
                # Store the current AWS creds if they exist
                local AWS_KEY_BACKUP="$AWS_ACCESS_KEY_ID"
                local AWS_SECRET_BACKUP="$AWS_SECRET_ACCESS_KEY"
                local AWS_REGION_BACKUP="$AWS_DEFAULT_REGION"
                
                # Set DO credentials
                export AWS_ACCESS_KEY_ID="$DO_SPACES_KEY"
                export AWS_SECRET_ACCESS_KEY="$DO_SPACES_SECRET"
                export AWS_DEFAULT_REGION="${DO_SPACES_REGION:-nyc3}"
                log "Using DigitalOcean Spaces credentials from secrets file" "$log_file"
            else
                log "DigitalOcean Spaces credentials not found in secrets file." "$log_file"
                return 1
            fi
            
            # Upload to DigitalOcean Spaces
            local bucket="${DO_SPACES_BUCKET:-webdev-backups}"
            local endpoint="${DO_SPACES_ENDPOINT:-nyc3.digitaloceanspaces.com}"
            local spaces_path="s3://$bucket/$(basename "$backup_file")"
            
            log "Uploading to DigitalOcean Spaces: $spaces_path" "$log_file" "$silent_mode"
            
            if [ "$silent_mode" = false ]; then
                # Show progress for interactive mode
                (aws s3 cp $limit_cmd "$backup_file" "$spaces_path" --endpoint-url "https://$endpoint" 2>/dev/null) &
                local upload_pid=$!
                
                # Monitor upload progress
                monitor_file_progress "/dev/null" "$file_size" "Uploading to DigitalOcean Spaces" "$upload_pid" 1
                
                # Wait for upload to finish
                wait $upload_pid
                local upload_status=$?
                
                # Restore original AWS credentials if they existed
                if [ -n "$AWS_KEY_BACKUP" ]; then
                    export AWS_ACCESS_KEY_ID="$AWS_KEY_BACKUP"
                    export AWS_SECRET_ACCESS_KEY="$AWS_SECRET_BACKUP"
                    export AWS_DEFAULT_REGION="$AWS_REGION_BACKUP"
                fi
                
                if [ "$upload_status" -eq 0 ]; then
                    log "Successfully uploaded to DigitalOcean Spaces: $spaces_path" "$log_file" "$silent_mode"
                    return 0
                else
                    log "Failed to upload to DigitalOcean Spaces: $spaces_path" "$log_file" "$silent_mode"
                    return 1
                fi
            else
                # Silent mode - run normally
                if aws s3 cp $limit_cmd "$backup_file" "$spaces_path" --endpoint-url "https://$endpoint"; then
                    log "Successfully uploaded to DigitalOcean Spaces: $spaces_path" "$log_file" "$silent_mode"
                    
                    # Restore original AWS credentials if they existed
                    if [ -n "$AWS_KEY_BACKUP" ]; then
                        export AWS_ACCESS_KEY_ID="$AWS_KEY_BACKUP"
                        export AWS_SECRET_ACCESS_KEY="$AWS_SECRET_BACKUP"
                        export AWS_DEFAULT_REGION="$AWS_REGION_BACKUP"
                    fi
                    
                    return 0
                else
                    log "Failed to upload to DigitalOcean Spaces: $spaces_path" "$log_file" "$silent_mode"
                    
                    # Restore original AWS credentials if they existed
                    if [ -n "$AWS_KEY_BACKUP" ]; then
                        export AWS_ACCESS_KEY_ID="$AWS_KEY_BACKUP"
                        export AWS_SECRET_ACCESS_KEY="$AWS_SECRET_BACKUP"
                        export AWS_DEFAULT_REGION="$AWS_REGION_BACKUP"
                    fi
                    
                    return 1
                fi
            fi
            ;;
        
        dropbox)
            # Check if Dropbox CLI is installed
            if ! command -v dropbox-uploader >/dev/null 2>&1; then
                log "Dropbox Uploader not installed. Cannot upload to Dropbox." "$log_file"
                return 1
            fi
            
            # Setup Dropbox credentials if available
            if [ -n "$DROPBOX_ACCESS_TOKEN" ]; then
                # Create or update the config file for dropbox-uploader
                local dropbox_config="${HOME}/.dropbox_uploader"
                echo "OAUTH_ACCESS_TOKEN=$DROPBOX_ACCESS_TOKEN" > "$dropbox_config"
                chmod 600 "$dropbox_config"
                
                log "Using Dropbox credentials from secrets file" "$log_file"
            fi
            
            # Upload to Dropbox
            local dropbox_path="/backups/$(basename "$backup_file")"
            
            log "Uploading to Dropbox: $dropbox_path" "$log_file"
            if dropbox-uploader upload "$backup_file" "$dropbox_path"; then
                log "Successfully uploaded to Dropbox: $dropbox_path" "$log_file"
                return 0
            else
                log "Failed to upload to Dropbox: $dropbox_path" "$log_file"
                return 1
            fi
            ;;
        
        gdrive|google)
            # Check if Google Drive CLI is installed
            if ! command -v gdrive >/dev/null 2>&1; then
                log "Google Drive CLI not installed. Cannot upload to Google Drive." "$log_file"
                return 1
            fi
            
            # Setup Google Drive credentials if available
            if [ -n "$GDRIVE_CLIENT_ID" ] && [ -n "$GDRIVE_CLIENT_SECRET" ] && [ -n "$GDRIVE_REFRESH_TOKEN" ]; then
                # Create or update the credentials file
                local gdrive_config_dir="${HOME}/.gdrive"
                mkdir -p "$gdrive_config_dir"
                
                log "Using Google Drive credentials from secrets file" "$log_file"
            fi
            
            # Upload to Google Drive
            log "Uploading to Google Drive: $(basename "$backup_file")" "$log_file"
            if gdrive upload "$backup_file"; then
                log "Successfully uploaded to Google Drive" "$log_file"
                return 0
            else
                log "Failed to upload to Google Drive" "$log_file"
                return 1
            fi
            ;;
        
        *)
            log "Unknown cloud provider: $provider" "$log_file"
            return 1
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
            # Check AWS CLI is installed
            if ! command -v aws >/dev/null 2>&1; then
                log "AWS CLI not installed. Cannot download from S3." "$log_file"
                return 1
            fi
            
            # Download from S3
            local bucket="${S3_BUCKET:-webdev-backups}"
            local s3_path="s3://$bucket/$backup_name"
            local local_path="$download_dir/$backup_name"
            
            log "Downloading from S3: $s3_path" "$log_file"
            if aws s3 cp $limit_cmd "$s3_path" "$local_path"; then
                log "Successfully downloaded from S3: $local_path" "$log_file"
                return 0
            else
                log "Failed to download from S3: $s3_path" "$log_file"
                return 1
            fi
            ;;
            
        do|spaces|digitalocean)
            # Check AWS CLI is installed (DO Spaces uses S3-compatible API)
            if ! command -v aws >/dev/null 2>&1; then
                log "AWS CLI not installed. Cannot download from DigitalOcean Spaces." "$log_file"
                return 1
            fi
            
            # Set DigitalOcean Spaces credentials if available
            if [ -n "$DO_SPACES_KEY" ] && [ -n "$DO_SPACES_SECRET" ]; then
                # Store the current AWS creds if they exist
                local AWS_KEY_BACKUP="$AWS_ACCESS_KEY_ID"
                local AWS_SECRET_BACKUP="$AWS_SECRET_ACCESS_KEY"
                local AWS_REGION_BACKUP="$AWS_DEFAULT_REGION"
                
                # Set DO credentials
                export AWS_ACCESS_KEY_ID="$DO_SPACES_KEY"
                export AWS_SECRET_ACCESS_KEY="$DO_SPACES_SECRET"
                export AWS_DEFAULT_REGION="${DO_SPACES_REGION:-nyc3}"
                log "Using DigitalOcean Spaces credentials from secrets file" "$log_file"
            else
                log "DigitalOcean Spaces credentials not found in secrets file." "$log_file"
                return 1
            fi
            
            # Download from DigitalOcean Spaces
            local bucket="${DO_SPACES_BUCKET:-webdev-backups}"
            local endpoint="${DO_SPACES_ENDPOINT:-nyc3.digitaloceanspaces.com}"
            local spaces_path="s3://$bucket/$backup_name"
            local local_path="$download_dir/$backup_name"
            
            log "Downloading from DigitalOcean Spaces: $spaces_path" "$log_file"
            if aws s3 cp $limit_cmd "$spaces_path" "$local_path" --endpoint-url "https://$endpoint"; then
                log "Successfully downloaded from DigitalOcean Spaces: $local_path" "$log_file"
                
                # Restore original AWS credentials if they existed
                if [ -n "$AWS_KEY_BACKUP" ]; then
                    export AWS_ACCESS_KEY_ID="$AWS_KEY_BACKUP"
                    export AWS_SECRET_ACCESS_KEY="$AWS_SECRET_BACKUP"
                    export AWS_DEFAULT_REGION="$AWS_REGION_BACKUP"
                fi
                
                return 0
            else
                log "Failed to download from DigitalOcean Spaces: $spaces_path" "$log_file"
                
                # Restore original AWS credentials if they existed
                if [ -n "$AWS_KEY_BACKUP" ]; then
                    export AWS_ACCESS_KEY_ID="$AWS_KEY_BACKUP"
                    export AWS_SECRET_ACCESS_KEY="$AWS_SECRET_BACKUP"
                    export AWS_DEFAULT_REGION="$AWS_REGION_BACKUP"
                fi
                
                return 1
            fi
            ;;
        
        dropbox)
            # Check if Dropbox CLI is installed
            if ! command -v dropbox-uploader >/dev/null 2>&1; then
                log "Dropbox Uploader not installed. Cannot download from Dropbox." "$log_file"
                return 1
            fi
            
            # Download from Dropbox
            local dropbox_path="/backups/$backup_name"
            local local_path="$download_dir/$backup_name"
            
            log "Downloading from Dropbox: $dropbox_path" "$log_file"
            if dropbox-uploader download "$dropbox_path" "$local_path"; then
                log "Successfully downloaded from Dropbox: $local_path" "$log_file"
                return 0
            else
                log "Failed to download from Dropbox: $dropbox_path" "$log_file"
                return 1
            fi
            ;;
        
        gdrive|google)
            # Check if Google Drive CLI is installed
            if ! command -v gdrive >/dev/null 2>&1; then
                log "Google Drive CLI not installed. Cannot download from Google Drive." "$log_file"
                return 1
            fi
            
            # First, find the file by name
            local file_id=$(gdrive list --query "name = '$backup_name'" --no-header | head -1 | awk '{print $1}')
            
            if [ -z "$file_id" ]; then
                log "File not found in Google Drive: $backup_name" "$log_file"
                return 1
            fi
            
            # Download from Google Drive
            log "Downloading from Google Drive: $backup_name (ID: $file_id)" "$log_file"
            if gdrive download --path "$download_dir" "$file_id"; then
                log "Successfully downloaded from Google Drive: $download_dir/$backup_name" "$log_file"
                return 0
            else
                log "Failed to download from Google Drive: $backup_name" "$log_file"
                return 1
            fi
            ;;
        
        *)
            log "Unknown cloud provider: $provider" "$log_file"
            return 1
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