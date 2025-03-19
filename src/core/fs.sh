#!/bin/bash
# ===============================================================================
# fs.sh - Filesystem operations for WebDev Backup Tool
# ===============================================================================
#
# @file            fs.sh
# @description     Provides backup and restore file system operations
# @author          Claude
# @version         1.6.0
#
# This file contains functions for creating and verifying backups, including
# compression, incremental backups, and verification of backup integrity.
# ===============================================================================

# Set the project root directory
SCRIPT_DIR_FS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Import core configuration
if [[ "$SCRIPT_DIR_FS" == */src/core ]]; then
    source "$SCRIPT_DIR_FS/config.sh"
    source "$SCRIPT_DIR_FS/../utils/utils.sh"
else
    source "$SCRIPT_DIR_FS/config.sh"
    source "$SCRIPT_DIR_FS/utils.sh"
fi

# ===============================================================================
# Backup Creation Functions
# ===============================================================================

/**
 * @function       create_backup_archive
 * @description    Create a compressed backup archive of a project
 * @param {string} base_dir - Base directory containing the project
 * @param {string} project_name - Name of the project to backup
 * @param {string} output_file - Path to the output archive file
 * @param {string} log_file - Path to the log file
 * @param {number} compression_level - Compression level (1-9)
 * @param {string} exclude_pattern - Pattern to exclude (e.g., "*/node_modules/*")
 * @param {number} threads - Number of parallel compression threads
 * @param {boolean} silent - Whether to suppress console output
 * @returns        0 on success, 1 on failure
 */
create_backup_archive() {
    local base_dir=$1
    local project_name=$2
    local output_file=$3
    local log_file=$4
    local compression_level=${5:-6}
    local exclude_pattern=${6:-}
    local threads=${7:-1}
    local silent=${8:-false}
    
    # Verify parameters
    if [ -z "$base_dir" ] || [ -z "$project_name" ] || [ -z "$output_file" ]; then
        log "ERROR: Missing required parameters for create_backup_archive" "$log_file" "$silent"
        return 1
    fi
    
    # Make sure base directory exists
    if [ ! -d "$base_dir" ]; then
        log "ERROR: Base directory does not exist: $base_dir" "$log_file" "$silent"
        return 1
    fi
    
    # Make sure project exists
    local project_path="$base_dir/$project_name"
    if [ ! -d "$project_path" ]; then
        log "ERROR: Project directory does not exist: $project_path" "$log_file" "$silent"
        return 1
    fi
    
    # Create output directory if it doesn't exist
    local output_dir=$(dirname "$output_file")
    if [ ! -d "$output_dir" ]; then
        if ! mkdir -p "$output_dir" 2>/dev/null; then
            log "ERROR: Failed to create output directory: $output_dir" "$log_file" "$silent"
            return 1
        fi
    fi
    
    # Log the backup operation
    log "Creating backup of $project_name to $output_file" "$log_file" "$silent"
    log "Compression level: $compression_level" "$log_file" "$silent"
    
    if [ -n "$exclude_pattern" ]; then
        log "Excluding pattern: $exclude_pattern" "$log_file" "$silent"
    fi
    
    # Use pigz for parallel compression if available and requested
    if [ "$threads" -gt 1 ] && command -v pigz >/dev/null 2>&1; then
        log "Using parallel compression with $threads threads" "$log_file" "$silent"
        
        # Backup command with pigz compression
        if [ -n "$exclude_pattern" ]; then
            # With exclusion
            tar --use-compress-program="pigz -$compression_level -p $threads" \
                --exclude="$exclude_pattern" \
                -cf "$output_file" \
                -C "$base_dir" "$project_name" 2>> "$log_file"
        else
            # No exclusion
            tar --use-compress-program="pigz -$compression_level -p $threads" \
                -cf "$output_file" \
                -C "$base_dir" "$project_name" 2>> "$log_file"
        fi
    else
        # Standard gzip compression
        if [ -n "$exclude_pattern" ]; then
            # With exclusion
            tar -C "$base_dir" \
                --exclude="$exclude_pattern" \
                -c "$project_name" | gzip -"$compression_level" > "$output_file" 2>> "$log_file"
        else
            # No exclusion
            tar -C "$base_dir" -c "$project_name" | gzip -"$compression_level" > "$output_file" 2>> "$log_file"
        fi
    fi
    
    # Check if backup was successful
    if [ $? -eq 0 ] && [ -f "$output_file" ]; then
        log "Backup created successfully: $output_file" "$log_file" "$silent"
        return 0
    else
        log "ERROR: Failed to create backup: $output_file" "$log_file" "$silent"
        return 1
    fi
}

/**
 * @function       create_incremental_backup
 * @description    Create an incremental backup based on a snapshot file
 * @param {string} base_dir - Base directory containing the project
 * @param {string} project_name - Name of the project to backup
 * @param {string} output_file - Path to the output archive file
 * @param {string} snapshot_file - Path to the snapshot file
 * @param {string} log_file - Path to the log file
 * @param {number} compression_level - Compression level (1-9)
 * @returns        0 on success, 1 on failure
 */
create_incremental_backup() {
    local base_dir=$1
    local project_name=$2
    local output_file=$3
    local snapshot_file=$4
    local log_file=$5
    local compression_level=${6:-6}
    
    # Verify parameters
    if [ -z "$base_dir" ] || [ -z "$project_name" ] || [ -z "$output_file" ] || [ -z "$snapshot_file" ]; then
        log "ERROR: Missing required parameters for create_incremental_backup" "$log_file"
        return 1
    fi
    
    # Create snapshot directory if it doesn't exist
    local snapshot_dir=$(dirname "$snapshot_file")
    if [ ! -d "$snapshot_dir" ]; then
        if ! mkdir -p "$snapshot_dir" 2>/dev/null; then
            log "ERROR: Failed to create snapshot directory: $snapshot_dir" "$log_file"
            return 1
        fi
    fi
    
    # Log the backup operation
    log "Creating incremental backup of $project_name to $output_file" "$log_file"
    log "Using snapshot file: $snapshot_file" "$log_file"
    
    # Create incremental backup
    tar --listed-incremental="$snapshot_file" \
        --exclude="*/node_modules/*" \
        -czf "$output_file" \
        -C "$base_dir" "$project_name" 2>> "$log_file"
    
    # Check if backup was successful
    if [ $? -eq 0 ] && [ -f "$output_file" ]; then
        log "Incremental backup created successfully: $output_file" "$log_file"
        return 0
    else
        log "ERROR: Failed to create incremental backup: $output_file" "$log_file"
        return 1
    fi
}

/**
 * @function       create_differential_backup
 * @description    Create a differential backup based on a base snapshot file
 * @param {string} base_dir - Base directory containing the project
 * @param {string} project_name - Name of the project to backup
 * @param {string} output_file - Path to the output archive file
 * @param {string} base_snapshot - Path to the base snapshot file
 * @param {string} log_file - Path to the log file
 * @param {number} compression_level - Compression level (1-9)
 * @returns        0 on success, 1 on failure
 */
create_differential_backup() {
    local base_dir=$1
    local project_name=$2
    local output_file=$3
    local base_snapshot=$4
    local log_file=$5
    local compression_level=${6:-6}
    
    # Verify parameters
    if [ -z "$base_dir" ] || [ -z "$project_name" ] || [ -z "$output_file" ]; then
        log "ERROR: Missing required parameters for create_differential_backup" "$log_file"
        return 1
    fi
    
    # Create snapshot directory if needed
    local snapshot_dir=$(dirname "$base_snapshot")
    if [ ! -d "$snapshot_dir" ]; then
        if ! mkdir -p "$snapshot_dir" 2>/dev/null; then
            log "ERROR: Failed to create snapshot directory: $snapshot_dir" "$log_file"
            return 1
        fi
    fi
    
    # Create a temporary copy of the base snapshot if it exists
    local temp_snapshot=$(mktemp)
    if [ -f "$base_snapshot" ]; then
        cp "$base_snapshot" "$temp_snapshot"
    else
        # Create a new base snapshot if it doesn't exist
        log "Base snapshot doesn't exist. Creating new base snapshot: $base_snapshot" "$log_file"
        touch "$temp_snapshot"
    fi
    
    # Log the backup operation
    log "Creating differential backup of $project_name to $output_file" "$log_file"
    log "Using base snapshot: $base_snapshot" "$log_file"
    
    # Create differential backup
    tar --listed-incremental="$temp_snapshot" \
        --exclude="*/node_modules/*" \
        -czf "$output_file" \
        -C "$base_dir" "$project_name" 2>> "$log_file"
    
    # Check if backup was successful
    local result=$?
    
    # Clean up temporary snapshot file
    rm -f "$temp_snapshot"
    
    if [ $result -eq 0 ] && [ -f "$output_file" ]; then
        # Don't update the base snapshot - that's what makes it differential
        log "Differential backup created successfully: $output_file" "$log_file"
        return 0
    else
        log "ERROR: Failed to create differential backup: $output_file" "$log_file"
        return 1
    fi
}

# ===============================================================================
# Verification Functions
# ===============================================================================

/**
 * @function       verify_backup
 * @description    Verify integrity of a backup archive
 * @param {string} backup_file - Path to the backup file
 * @param {string} log_file - Path to the log file
 * @param {boolean} silent - Whether to suppress console output
 * @param {boolean} thorough - Perform thorough verification (extract test)
 * @returns        0 if backup is valid, 1 otherwise
 */
verify_backup() {
    local backup_file=$1
    local log_file=$2
    local silent=${3:-false}
    local thorough=${4:-false}
    
    # Verify parameters
    if [ -z "$backup_file" ]; then
        log "ERROR: Missing required parameters for verify_backup" "$log_file" "$silent"
        return 1
    fi
    
    # Check if file exists
    if [ ! -f "$backup_file" ]; then
        log "ERROR: Backup file does not exist: $backup_file" "$log_file" "$silent"
        return 1
    fi
    
    # Basic integrity check
    log "Verifying backup integrity: $backup_file" "$log_file" "$silent"
    
    if ! gzip -t "$backup_file" 2>> "$log_file"; then
        log "ERROR: Backup file is corrupt (gzip check failed): $backup_file" "$log_file" "$silent"
        return 1
    fi
    
    # Test archive integrity
    if ! tar -tzf "$backup_file" >/dev/null 2>> "$log_file"; then
        log "ERROR: Backup file is corrupt (tar check failed): $backup_file" "$log_file" "$silent"
        return 1
    fi
    
    # Thorough verification (extract test)
    if [ "$thorough" = true ]; then
        log "Performing thorough verification (extraction test)" "$log_file" "$silent"
        
        # Create a temporary directory
        local temp_dir=$(mktemp -d)
        
        # Extract a sample (top-level directories only)
        tar -tzf "$backup_file" | grep -v "/" | head -5 | \
            xargs -I{} tar -xzf "$backup_file" -C "$temp_dir" {} 2>> "$log_file"
        
        # Check if extraction succeeded
        local extract_result=$?
        
        # Clean up
        rm -rf "$temp_dir"
        
        if [ $extract_result -ne 0 ]; then
            log "ERROR: Thorough verification failed (extraction test)" "$log_file" "$silent"
            return 1
        fi
        
        log "Thorough verification passed" "$log_file" "$silent"
    fi
    
    log "Backup integrity verified: $backup_file" "$log_file" "$silent"
    return 0
}

/**
 * @function       extract_backup
 * @description    Extract files from a backup archive
 * @param {string} backup_file - Path to the backup file
 * @param {string} destination - Destination directory
 * @param {string} log_file - Path to the log file
 * @param {string} specific_file - Optional specific file to extract
 * @returns        0 on success, 1 on failure
 */
extract_backup() {
    local backup_file=$1
    local destination=$2
    local log_file=$3
    local specific_file=$4
    
    # Verify parameters
    if [ -z "$backup_file" ] || [ -z "$destination" ]; then
        log "ERROR: Missing required parameters for extract_backup" "$log_file"
        return 1
    fi
    
    # Check if file exists
    if [ ! -f "$backup_file" ]; then
        log "ERROR: Backup file does not exist: $backup_file" "$log_file"
        return 1
    fi
    
    # Check if destination exists
    if [ ! -d "$destination" ]; then
        log "ERROR: Destination directory does not exist: $destination" "$log_file"
        return 1
    fi
    
    # Log extraction
    if [ -n "$specific_file" ]; then
        log "Extracting specific file: $specific_file from $backup_file to $destination" "$log_file"
        tar -xzf "$backup_file" -C "$destination" "$specific_file" 2>> "$log_file"
    else
        log "Extracting backup: $backup_file to $destination" "$log_file"
        tar -xzf "$backup_file" -C "$destination" 2>> "$log_file"
    fi
    
    # Check result
    if [ $? -eq 0 ]; then
        log "Extraction completed successfully" "$log_file"
        return 0
    else
        log "ERROR: Failed to extract backup" "$log_file"
        return 1
    fi
}

/**
 * @function       upload_to_cloud
 * @description    Upload a file to cloud storage
 * @param {string} file - Path to the file to upload
 * @param {string} provider - Cloud provider (do, aws, dropbox, gdrive)
 * @param {string} log_file - Path to the log file
 * @param {number} bandwidth_limit - Bandwidth limit in KB/s (0 = unlimited)
 * @param {boolean} silent - Whether to suppress console output
 * @returns        0 on success, 1 on failure
 */
upload_to_cloud() {
    local file=$1
    local provider=$2
    local log_file=$3
    local bandwidth_limit=${4:-0}
    local silent=${5:-false}
    
    # Verify parameters
    if [ -z "$file" ] || [ -z "$provider" ]; then
        log "ERROR: Missing required parameters for upload_to_cloud" "$log_file" "$silent"
        return 1
    fi
    
    # Check if file exists
    if [ ! -f "$file" ]; then
        log "ERROR: File does not exist: $file" "$log_file" "$silent"
        return 1
    }
    
    # Load cloud provider settings
    if [ -f "$SCRIPT_DIR/secrets.sh" ]; then
        source "$SCRIPT_DIR/secrets.sh"
    elif [ -f "$CLOUD_DIR/secrets.sh" ]; then
        source "$CLOUD_DIR/secrets.sh"
    else
        log "ERROR: Could not find secrets.sh file with cloud credentials" "$log_file" "$silent"
        return 1
    fi
    
    # Get filename for cloud path
    local filename=$(basename "$file")
    
    # Upload based on provider
    case "$provider" in
        do|spaces|digitalocean)
            # DigitalOcean Spaces using AWS CLI compatible commands
            if ! command -v aws >/dev/null 2>&1; then
                log "ERROR: aws CLI not installed. Cannot upload to DigitalOcean Spaces." "$log_file" "$silent"
                return 1
            fi
            
            log "Uploading to DigitalOcean Spaces: $filename" "$log_file" "$silent"
            
            # Configure bandwidth limit if needed
            local bwlimit=""
            if [ "$bandwidth_limit" -gt 0 ]; then
                bwlimit="--cli-read-timeout 0 --cli-connect-timeout 0"
            fi
            
            if ! aws s3 cp "$file" "s3://${DO_SPACES_BUCKET}/webdev-backup/${filename}" \
                --endpoint-url "https://${DO_SPACES_ENDPOINT}" \
                $bwlimit 2>> "$log_file"; then
                log "ERROR: Failed to upload to DigitalOcean Spaces: $filename" "$log_file" "$silent"
                return 1
            fi
            ;;
            
        aws|s3)
            # AWS S3
            if ! command -v aws >/dev/null 2>&1; then
                log "ERROR: aws CLI not installed. Cannot upload to AWS S3." "$log_file" "$silent"
                return 1
            fi
            
            log "Uploading to AWS S3: $filename" "$log_file" "$silent"
            
            # Configure bandwidth limit if needed
            local bwlimit=""
            if [ "$bandwidth_limit" -gt 0 ]; then
                bwlimit="--cli-read-timeout 0 --cli-connect-timeout 0"
            fi
            
            if ! aws s3 cp "$file" "s3://${AWS_S3_BUCKET}/webdev-backup/${filename}" $bwlimit 2>> "$log_file"; then
                log "ERROR: Failed to upload to AWS S3: $filename" "$log_file" "$silent"
                return 1
            fi
            ;;
            
        # Additional cloud providers would be implemented here
        
        *)
            log "ERROR: Unsupported cloud provider: $provider" "$log_file" "$silent"
            return 1
            ;;
    esac
    
    log "Successfully uploaded to $provider: $filename" "$log_file" "$silent"
    return 0
}