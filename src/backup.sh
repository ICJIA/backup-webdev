#!/bin/bash
# backup.sh - Main backup script for backup-webdev
# Performs full, incremental, or differential backups of web development projects

# Source the shared modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../core/config.sh"
source "$SCRIPT_DIR/../utils/utils.sh"
source "$SCRIPT_DIR/../ui/ui.sh"
source "$SCRIPT_DIR/../core/fs.sh"
source "$SCRIPT_DIR/../reports/reporting.sh"

# Default values
SILENT_MODE=false
INCREMENTAL_BACKUP=false
DIFFERENTIAL_BACKUP=false
VERIFY_BACKUP=false
THOROUGH_VERIFY=false
COMPRESSION_LEVEL=6
EMAIL_NOTIFICATION=""
CLOUD_PROVIDER=""
BANDWIDTH_LIMIT=0
PARALLEL_THREADS=1
CUSTOM_BACKUP_DIR=""
CUSTOM_SOURCE_DIRS=()
DRY_RUN=false
EXTERNAL_BACKUP=false  # Track if this is an external (cloud) backup

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --silent)
            SILENT_MODE=true
            shift
            ;;
        --incremental)
            INCREMENTAL_BACKUP=true
            DIFFERENTIAL_BACKUP=false
            shift
            ;;
        --differential)
            DIFFERENTIAL_BACKUP=true
            INCREMENTAL_BACKUP=false
            shift
            ;;
        --verify)
            VERIFY_BACKUP=true
            shift
            ;;
        --thorough-verify)
            VERIFY_BACKUP=true
            THOROUGH_VERIFY=true
            shift
            ;;
        --compression)
            if [[ -n "$2" && "$2" =~ ^[1-9]$ ]]; then
                COMPRESSION_LEVEL="$2"
                shift 2
            else
                echo -e "${RED}Error: Compression argument requires a number between 1 and 9${NC}"
                exit 1
            fi
            ;;
        --email)
            if [[ -n "$2" && "$2" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
                EMAIL_NOTIFICATION="$2"
                shift 2
            else
                echo -e "${RED}Error: Email argument requires a valid email address${NC}"
                exit 1
            fi
            ;;
        --cloud)
            if [[ -n "$2" && "$2" =~ ^(aws|s3|do|spaces|digitalocean|dropbox|gdrive|google)$ ]]; then
                CLOUD_PROVIDER="$2"
                EXTERNAL_BACKUP=true
                shift 2
            else
                echo -e "${RED}Error: Cloud provider must be one of: aws, s3, do, spaces, digitalocean, dropbox, gdrive, google${NC}"
                exit 1
            fi
            ;;
        --external)
            EXTERNAL_BACKUP=true
            CLOUD_PROVIDER="${CLOUD_PROVIDER:-$DEFAULT_CLOUD_PROVIDER}"
            shift
            ;;
        --bandwidth)
            if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
                BANDWIDTH_LIMIT="$2"
                shift 2
            else
                echo -e "${RED}Error: Bandwidth argument requires a number in KB/s${NC}"
                exit 1
            fi
            ;;
        --parallel)
            if [[ -n "$2" && "$2" =~ ^[1-8]$ ]]; then
                PARALLEL_THREADS="$2"
                shift 2
            else
                echo -e "${RED}Error: Parallel threads argument requires a number between 1 and 8${NC}"
                exit 1
            fi
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --destination|--dest|-d)
            if [[ -n "$2" && "$2" != --* ]]; then
                CUSTOM_BACKUP_DIR="$2"
                shift 2
            else
                echo -e "${RED}Error: Destination argument requires a directory path${NC}"
                exit 1
            fi
            ;;
        --sources)
            if [[ -n "$2" ]]; then
                IFS=',' read -ra custom_dirs <<< "$2"
                for dir in "${custom_dirs[@]}"; do
                    CUSTOM_SOURCE_DIRS+=("$dir")
                done
                shift 2
            else
                echo -e "${RED}Error: --sources requires a comma-separated list of directories${NC}"
                exit 1
            fi
            ;;
        --source|-s)
            if [[ -n "$2" && "$2" != --* ]]; then
                CUSTOM_SOURCE_DIRS+=("$2")
                shift 2
            else
                echo -e "${RED}Error: Source argument requires a directory path${NC}"
                exit 1
            fi
            ;;
        -h|--help)
            show_backup_help
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help to see available options"
            exit 1
            ;;
    esac
done

# Set source directories (use custom if provided, otherwise default)
SOURCE_DIRS=()
if [ ${#CUSTOM_SOURCE_DIRS[@]} -gt 0 ]; then
    SOURCE_DIRS=("${CUSTOM_SOURCE_DIRS[@]}")
else
    SOURCE_DIRS=("${DEFAULT_SOURCE_DIRS[@]}")
fi

# For backward compatibility
SOURCE_DIR="${SOURCE_DIRS[0]}"

# Verify source directories exist
for dir in "${SOURCE_DIRS[@]}"; do
    if [[ ! -d "$dir" ]]; then
        echo -e "${RED}ERROR: Source directory does not exist: $dir${NC}"
        echo "Please specify a valid source directory using the -s option"
        exit 1
    fi
done

# Verify backup directory and create if needed
if ! verify_directory "$BACKUP_DIR" "Backup destination" true; then
    echo "No files were backed up. Please check directory permissions."
    exit 1
fi

# Set backup type string for reporting
if [ "$INCREMENTAL_BACKUP" = true ]; then
    BACKUP_TYPE="incremental"
elif [ "$DIFFERENTIAL_BACKUP" = true ]; then
    BACKUP_TYPE="differential"
else
    BACKUP_TYPE="full"
fi

# Set dependent paths
BACKUP_NAME="webdev_backup_$DATE"
FULL_BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"
LOG_FILE="$FULL_BACKUP_PATH/backup_log.log"
STATS_FILE="$FULL_BACKUP_PATH/backup_stats.txt"
METADATA_FILE="$FULL_BACKUP_PATH/backup_metadata.json"

# Create backup directory
if ! mkdir -p "$FULL_BACKUP_PATH"; then
    echo -e "${RED}ERROR: Failed to create backup directory: $FULL_BACKUP_PATH${NC}"
    echo "No files were backed up. Please check directory permissions."
    exit 1
fi

# Create necessary files
for file in "$LOG_FILE" "$STATS_FILE" "$METADATA_FILE"; do
    if ! touch "$file"; then
        echo -e "${RED}ERROR: Failed to create file: $file${NC}"
        echo "No files were backed up. The filesystem may be read-only or full."
        exit 1
    fi
done

# Record start time
START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
# Also record the start time in seconds since epoch for duration calculation
START_TIME_SECONDS=$(date +%s)

# Start logging
log "Starting backup script" "$LOG_FILE" "$SILENT_MODE"
log "Source directories: ${SOURCE_DIRS[*]}" "$LOG_FILE" "$SILENT_MODE"
if [ "${SOURCE_DIRS[*]}" = "${DEFAULT_SOURCE_DIRS[*]}" ]; then
    log "Using default source directories: ${DEFAULT_SOURCE_DIRS[*]}" "$LOG_FILE" "$SILENT_MODE"
fi
log "Backup destination: $FULL_BACKUP_PATH" "$LOG_FILE" "$SILENT_MODE"
if [ "$BACKUP_DIR" = "$DEFAULT_BACKUP_DIR" ]; then
    log "Using default backup directory: $DEFAULT_BACKUP_DIR" "$LOG_FILE" "$SILENT_MODE"
fi
log "Backup type: $BACKUP_TYPE" "$LOG_FILE" "$SILENT_MODE"
log "Compression level: $COMPRESSION_LEVEL" "$LOG_FILE" "$SILENT_MODE"

if [ "$PARALLEL_THREADS" -gt 1 ]; then
    log "Using parallel compression with $PARALLEL_THREADS threads" "$LOG_FILE" "$SILENT_MODE"
fi

if [ "$SILENT_MODE" = true ]; then
    log "Running in silent mode (non-interactive)" "$LOG_FILE" "$SILENT_MODE"
fi

if [ "$DRY_RUN" = true ]; then
    log "Running in dry-run mode (no actual backups will be created)" "$LOG_FILE" "$SILENT_MODE"
    echo -e "\n${YELLOW}DRY RUN MODE: Simulating backup operations without making changes${NC}"
fi

# Verify required tools are installed
check_required_tools tar gzip || handle_error 3 "Required tools not installed" "$LOG_FILE" "$SILENT_MODE"

# Check for pigz if parallel compression requested
if [ "$PARALLEL_THREADS" -gt 1 ] && ! command -v pigz >/dev/null 2>&1; then
    log "Warning: pigz not found, parallel compression not available. Using standard compression." "$LOG_FILE" "$SILENT_MODE"
fi

# Get list of projects
projects=()
for dir in "${SOURCE_DIRS[@]}"; do
    mapfile -t dir_projects < <(find_projects "$dir" 1)
    projects+=("${dir_projects[@]}")
done

if [ ${#projects[@]} -eq 0 ]; then
    handle_error 2 "No projects found in ${SOURCE_DIRS[*]}" "$LOG_FILE" "$SILENT_MODE"
fi

# Create a temporary file for excluded projects
EXCLUDE_FILE=$(mktemp)

# Handle project selection based on mode
log "Found ${#projects[@]} projects in ${SOURCE_DIRS[*]}" "$LOG_FILE" "$SILENT_MODE"

if [ "$SILENT_MODE" = false ]; then
    # Interactive mode - show project list and ask for exclusions
    echo -e "\n${CYAN}===== WebDev Backup Tool =====${NC}"
    echo -e "${CYAN}Started at: $(date)${NC}\n"
    
    # Extract just the project names from full paths
    project_names=()
    for project_path in "${projects[@]}"; do
        project_names+=($(basename "$project_path"))
    done
    
    # Interactive project selection
    if [ "$SILENT_MODE" = false ]; then
        echo "Projects to backup (all selected by default):"
        for ((i=0; i<${#project_names[@]}; i++)); do
            echo "[$i] ${project_names[$i]}"
        done

        echo -e "\nTo exclude projects from backup, enter their numbers separated by spaces."
        echo "Press Enter to backup all projects."
        
        read -p "> " response
        
        for num in $response; do
            if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -lt "${#project_names[@]}" ]; then
                log "Excluding project: ${project_names[$num]}" "$LOG_FILE" "$SILENT_MODE"
                echo "${project_names[$num]}" >> "$EXCLUDE_FILE"
            else
                log "Warning: Invalid project number: $num" "$LOG_FILE" "$SILENT_MODE"
                echo -e "${YELLOW}Warning: Invalid project number: $num${NC}"
            fi
        done
    fi
else
    # Silent mode - backup everything, no interaction
    log "Silent mode: Backing up all projects" "$LOG_FILE" "$SILENT_MODE"
fi

# Get excluded projects list
EXCLUDED_PROJECTS=()
while IFS= read -r line; do
    EXCLUDED_PROJECTS+=("$line")
done < "$EXCLUDE_FILE"

# Prepare for backup
log "Starting backup process..." "$LOG_FILE" "$SILENT_MODE"

# Initialize dashboard in interactive mode
if [ "$SILENT_MODE" = false ]; then
    print_dashboard_header
    # Add a note about compression and backup type
    echo -e "Backup Type: ${BACKUP_TYPE^}"
    echo -e "Compression Level: $COMPRESSION_LEVEL"
    
    # Show storage information and path in a more visible way
    echo -e "${YELLOW}=============================================${NC}"
    if [ "$EXTERNAL_BACKUP" = true ]; then
        echo -e "${CYAN}STORAGE TYPE: CLOUD ($CLOUD_PROVIDER)${NC}"
        echo -e "${CYAN}BACKUP PATH:  Cloud provider: $CLOUD_PROVIDER${NC}"
    else
        if [ "$BACKUP_DIR" = "$DEFAULT_BACKUP_DIR" ]; then
            echo -e "${GREEN}STORAGE TYPE: LOCAL PROJECT STORAGE (Default)${NC}"
        else
            echo -e "${GREEN}STORAGE TYPE: EXTERNAL VOLUME STORAGE${NC}"
        fi
        echo -e "${GREEN}BACKUP PATH:  $FULL_BACKUP_PATH${NC}"
    fi
    echo -e "${YELLOW}=============================================${NC}"
    
    echo -e "Note: Each project's node_modules directory will be excluded"
    if [ "$VERIFY_BACKUP" = true ]; then
        echo -e "Backup verification will be performed after completion"
    fi
    echo ""
fi

# Track total sizes
TOTAL_SRC_SIZE=0
TOTAL_BACKUP_SIZE=0
SUCCESSFUL_PROJECTS=0
FAILED_PROJECTS=0

# Process each project
for project_path in "${projects[@]}"; do
    project=$(basename "$project_path")
    
    # Skip excluded projects
    if [[ " ${EXCLUDED_PROJECTS[*]} " == *" $project "* ]]; then
        log "Skipping excluded project: $project" "$LOG_FILE" "$SILENT_MODE"
        continue
    fi
    
    PROJECT_BACKUP_FILE="$FULL_BACKUP_PATH/${project}_${DATE}.tar.gz"
    
    # Get source project size (excluding node_modules)
    PROJECT_SRC_SIZE=$(get_directory_size "$project_path" "node_modules")
    TOTAL_SRC_SIZE=$((TOTAL_SRC_SIZE + PROJECT_SRC_SIZE))
    
    # Format size for display
    FORMATTED_SRC_SIZE=$(format_size "$PROJECT_SRC_SIZE")
    
    log "Processing project: $project (Size: $FORMATTED_SRC_SIZE)" "$LOG_FILE" "$SILENT_MODE"
    
    if [ "$SILENT_MODE" = false ]; then
        print_dashboard_row "$project" "$FORMATTED_SRC_SIZE" "COMPRESSING..."
    fi
    
    # Determine backup type and execute
    if [ "$DRY_RUN" = true ]; then
        # Simulate backup for dry run
        log "DRY RUN: Would create backup of $project to $PROJECT_BACKUP_FILE" "$LOG_FILE" "$SILENT_MODE"
        
        if [ "$SILENT_MODE" = false ]; then
            echo -e "${YELLOW}DRY RUN: Would create backup of $project (Size: $FORMATTED_SRC_SIZE)${NC}"
        fi
        
        # Simulate success
        success=true
        # Use a random but reasonable compression ratio for simulation
        RATIO=$(awk "BEGIN {printf \"%.1f\", 2.0 + rand()}")
        ARCHIVE_SIZE=$(awk "BEGIN {printf \"%.0f\", $PROJECT_SRC_SIZE / $RATIO}")
    elif [ "$INCREMENTAL_BACKUP" = true ]; then
        # Find the latest snapshot if any
        SNAPSHOT_DIR="$BACKUP_DIR/snapshots"
        mkdir -p "$SNAPSHOT_DIR"
        SNAPSHOT_FILE="$SNAPSHOT_DIR/${project}_snapshot.snar"
        
        # Create incremental backup
        if create_incremental_backup \
            "$(dirname "$project_path")" \
            "$project" \
            "$PROJECT_BACKUP_FILE" \
            "$SNAPSHOT_FILE" \
            "$LOG_FILE" \
            "$COMPRESSION_LEVEL"; then
            success=true
        else
            success=false
        fi
    elif [ "$DIFFERENTIAL_BACKUP" = true ]; then
        # Find the base snapshot if any
        SNAPSHOT_DIR="$BACKUP_DIR/snapshots"
        mkdir -p "$SNAPSHOT_DIR"
        BASE_SNAPSHOT="$SNAPSHOT_DIR/${project}_base_snapshot.snar"
        
        # Create differential backup
        if create_differential_backup \
            "$(dirname "$project_path")" \
            "$project" \
            "$PROJECT_BACKUP_FILE" \
            "$BASE_SNAPSHOT" \
            "$LOG_FILE" \
            "$COMPRESSION_LEVEL"; then
            success=true
        else
            success=false
        fi
    else
        # Create standard full backup
        if create_backup_archive \
            "$(dirname "$project_path")" \
            "$project" \
            "$PROJECT_BACKUP_FILE" \
            "$LOG_FILE" \
            "$COMPRESSION_LEVEL" \
            "*/node_modules/*" \
            "$PARALLEL_THREADS" \
            "$SILENT_MODE"; then
            success=true
        else
            success=false
        fi
    fi
    
    # Process the result
    if [ "$success" = true ]; then
        # Get archive size (unless we're in dry-run mode, where we already set it)
        if [ "$DRY_RUN" != true ]; then
            ARCHIVE_SIZE=$(du -b "$PROJECT_BACKUP_FILE" | cut -f1)
        fi
        FORMATTED_ARCHIVE_SIZE=$(format_size "$ARCHIVE_SIZE")
        TOTAL_BACKUP_SIZE=$((TOTAL_BACKUP_SIZE + ARCHIVE_SIZE))
        
        # Calculate compression ratio (safely)
        if [ "$ARCHIVE_SIZE" -gt 0 ] && [ "$PROJECT_SRC_SIZE" -gt 0 ]; then
            RATIO=$(awk "BEGIN {printf \"%.1f\", ($PROJECT_SRC_SIZE/$ARCHIVE_SIZE)}")
        else
            RATIO="1.0" 
        fi
        
        log "Project $project backed up successfully (Compressed: $FORMATTED_ARCHIVE_SIZE, Ratio: ${RATIO}x)" "$LOG_FILE" "$SILENT_MODE"
        
        # Add to stats file
        echo "$project,$PROJECT_SRC_SIZE,$ARCHIVE_SIZE,$RATIO" >> "$STATS_FILE"
        
        # Verify backup if requested
        if [ "$VERIFY_BACKUP" = true ]; then
            # Start verification with appropriate level of checking
            log "Starting backup verification for $project" "$LOG_FILE" "$SILENT_MODE"
            if [ "$SILENT_MODE" = false ]; then
                printf "\033[1A"
                print_dashboard_row "$project" "$FORMATTED_ARCHIVE_SIZE" "VERIFYING..."
            fi
            
            # If thorough verification was requested, we'll do a more comprehensive check
            if verify_backup "$PROJECT_BACKUP_FILE" "$LOG_FILE" "$SILENT_MODE" "$THOROUGH_VERIFY"; then
                if [ "$THOROUGH_VERIFY" = true ]; then
                    log "Thorough backup verification passed for $project" "$LOG_FILE" "$SILENT_MODE"
                    
                    if [ "$SILENT_MODE" = false ]; then
                        printf "\033[1A"
                        print_dashboard_row "$project" "$FORMATTED_ARCHIVE_SIZE" "✓ FULLY VERIFIED (${RATIO}x)"
                    fi
                else
                    log "Backup verification passed for $project" "$LOG_FILE" "$SILENT_MODE"
                    
                    if [ "$SILENT_MODE" = false ]; then
                        printf "\033[1A"
                        print_dashboard_row "$project" "$FORMATTED_ARCHIVE_SIZE" "✓ VERIFIED (${RATIO}x)"
                    fi
                fi
            else
                log "Backup verification FAILED for $project" "$LOG_FILE" "$SILENT_MODE"
                
                if [ "$SILENT_MODE" = false ]; then
                    printf "\033[1A"
                    print_dashboard_row "$project" "$FORMATTED_ARCHIVE_SIZE" "⚠ VERIFY FAILED"
                fi
                
                FAILED_PROJECTS=$((FAILED_PROJECTS + 1))
                continue
            fi
        elif [ "$SILENT_MODE" = false ]; then
            printf "\033[1A"
            print_dashboard_row "$project" "$FORMATTED_ARCHIVE_SIZE" "✓ DONE (${RATIO}x)"
        fi
        
        # Upload to cloud if requested
        if [ -n "$CLOUD_PROVIDER" ]; then
            if [ "$SILENT_MODE" = false ]; then
                printf "\033[1A"
                print_dashboard_row "$project" "$FORMATTED_ARCHIVE_SIZE" "UPLOADING..."
            fi
            
            if upload_to_cloud "$PROJECT_BACKUP_FILE" "$CLOUD_PROVIDER" "$LOG_FILE" "$BANDWIDTH_LIMIT" "$SILENT_MODE"; then
                log "Project $project uploaded to $CLOUD_PROVIDER" "$LOG_FILE" "$SILENT_MODE"
                
                if [ "$SILENT_MODE" = false ]; then
                    printf "\033[1A"
                    print_dashboard_row "$project" "$FORMATTED_ARCHIVE_SIZE" "✓ UPLOADED (${RATIO}x)"
                fi
            else
                log "Failed to upload project $project to $CLOUD_PROVIDER" "$LOG_FILE" "$SILENT_MODE"
                
                if [ "$SILENT_MODE" = false ]; then
                    printf "\033[1A"
                    print_dashboard_row "$project" "$FORMATTED_ARCHIVE_SIZE" "⚠ UPLOAD FAILED"
                fi
            fi
        fi
        
        SUCCESSFUL_PROJECTS=$((SUCCESSFUL_PROJECTS + 1))
    else
        # Record detailed error information
        local error_details="Failed to back up project: $project (Path: $PROJECT_BACKUP_FILE)"
        log "$error_details" "$LOG_FILE" "$SILENT_MODE"
        
        if [ "$SILENT_MODE" = false ]; then
            printf "\033[1A"
            print_dashboard_row "$project" "$FORMATTED_SRC_SIZE" "❌ FAILED"
            # Show error details for interactive mode
            echo -e "${RED}ERROR: Backup failed for $project${NC}"
            echo -e "${YELLOW}File: $PROJECT_BACKUP_FILE${NC}"
        fi
        
        # Create a record of failed backups for easier troubleshooting
        local failed_log="${LOGS_DIR}/failed_backups.log"
        mkdir -p "$(dirname "$failed_log")"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - FAILED BACKUP: $project" >> "$failed_log"
        echo "  Source: $PROJECT_SRC_PATH" >> "$failed_log"
        echo "  Target: $PROJECT_BACKUP_FILE" >> "$failed_log"
        echo "  Backup Time: $(date)" >> "$failed_log"
        echo "--------------------------------------------------" >> "$failed_log"
        
        FAILED_PROJECTS=$((FAILED_PROJECTS + 1))
    fi
done

# Record end time
END_TIME=$(date '+%Y-%m-%d %H:%M:%S')
# Also record the end time in seconds since epoch for duration calculation
END_TIME_SECONDS=$(date +%s)

# Calculate duration in seconds
DURATION_SECONDS=$((END_TIME_SECONDS - START_TIME_SECONDS))

# Format duration in human-readable form
DURATION_FORMATTED=$(printf "%02d:%02d:%02d" $((DURATION_SECONDS/3600)) $((DURATION_SECONDS%3600/60)) $((DURATION_SECONDS%60)))

# Format total size
TOTAL_FORMATTED_SIZE=$(format_size "$TOTAL_BACKUP_SIZE")

# Create metadata file
cat > "$METADATA_FILE" << EOF
{
  "backup_type": "$BACKUP_TYPE",
  "backup_date": "$DATE",
  "start_time": "$START_TIME",
  "end_time": "$END_TIME",
  "source_directory": "${SOURCE_DIRS[*]}",
  "backup_directory": "$FULL_BACKUP_PATH",
  "storage_type": "$([ "$EXTERNAL_BACKUP" = true ] && echo "external" || echo "internal")",
  "cloud_provider": "${CLOUD_PROVIDER}",
  "compression_level": $COMPRESSION_LEVEL,
  "parallel_threads": $PARALLEL_THREADS,
  "projects_total": ${#projects[@]},
  "projects_successful": $SUCCESSFUL_PROJECTS,
  "projects_failed": $FAILED_PROJECTS,
  "source_size_bytes": $TOTAL_SRC_SIZE,
  "backup_size_bytes": $TOTAL_BACKUP_SIZE,
  "verified": $VERIFY_BACKUP,
  "thorough_verification": $THOROUGH_VERIFY,
  "dry_run": $DRY_RUN
}
EOF

# Display summary in interactive mode
if [ "$SILENT_MODE" = false ]; then
    print_dashboard_footer "$TOTAL_FORMATTED_SIZE"
    
    # Calculate overall ratio
    if [ "$TOTAL_BACKUP_SIZE" -gt 0 ] && [ "$TOTAL_SRC_SIZE" -gt 0 ]; then
        OVERALL_RATIO=$(awk "BEGIN {printf \"%.1f\", ($TOTAL_SRC_SIZE/$TOTAL_BACKUP_SIZE)}")
    else
        OVERALL_RATIO="1.0"
    fi
    
    display_backup_summary \
        "$SUCCESSFUL_PROJECTS" \
        "$FAILED_PROJECTS" \
        "$TOTAL_SRC_SIZE" \
        "$TOTAL_BACKUP_SIZE" \
        "$FULL_BACKUP_PATH" \
        "$EXTERNAL_BACKUP" \
        "$CLOUD_PROVIDER" \
        "$START_TIME" \
        "$END_TIME" \
        "$DURATION_SECONDS" \
        "$DURATION_FORMATTED"
fi

# At the end of the process, also display the backup path clearly
if [ "$SILENT_MODE" = false ]; then
    # After the summary, emphasize the backup location
    echo -e "\n${YELLOW}=============================================${NC}"
    echo -e "${GREEN}BACKUP COMPLETE${NC}"
    if [ "$EXTERNAL_BACKUP" = true ]; then
        echo -e "${CYAN}STORAGE TYPE: CLOUD ($CLOUD_PROVIDER)${NC}"
    else
        if [ "$BACKUP_DIR" = "$DEFAULT_BACKUP_DIR" ]; then
            echo -e "${GREEN}STORAGE TYPE: LOCAL PROJECT STORAGE (Default)${NC}"
        else
            echo -e "${GREEN}STORAGE TYPE: EXTERNAL VOLUME STORAGE${NC}"
        fi
    fi
    echo -e "${GREEN}BACKUP PATH:  $FULL_BACKUP_PATH${NC}"
    echo -e "${YELLOW}TIME INFORMATION:${NC}"
    echo -e "  Started:  $START_TIME"
    echo -e "  Finished: $END_TIME"
    echo -e "  Duration: $DURATION_FORMATTED ($DURATION_SECONDS seconds)"
    echo -e "${YELLOW}=============================================${NC}"
fi

# Generate HTML report
if [ "$SILENT_MODE" = false ] || [ -n "$EMAIL_NOTIFICATION" ]; then
    REPORT_FILE=$(create_backup_report \
        "$FULL_BACKUP_PATH" \
        "$SUCCESSFUL_PROJECTS" \
        "$FAILED_PROJECTS" \
        "$TOTAL_SRC_SIZE" \
        "$TOTAL_BACKUP_SIZE" \
        "$START_TIME" \
        "$END_TIME" \
        "$BACKUP_TYPE")
    
    if [ "$SILENT_MODE" = false ]; then
        echo -e "Detailed report saved to: $REPORT_FILE"
    fi
fi

# Send email notification if requested
if [ -n "$EMAIL_NOTIFICATION" ]; then
    log "Sending email notification to $EMAIL_NOTIFICATION" "$LOG_FILE" "$SILENT_MODE"
    
    EMAIL_SUBJECT="WebDev Backup Report - $BACKUP_TYPE backup $(date '+%Y-%m-%d')"
    EMAIL_BODY=$(create_email_report \
        "$FULL_BACKUP_PATH" \
        "$SUCCESSFUL_PROJECTS" \
        "$FAILED_PROJECTS" \
        "$TOTAL_SRC_SIZE" \
        "$TOTAL_BACKUP_SIZE" \
        "$START_TIME" \
        "$END_TIME" \
        "$BACKUP_TYPE")
    
    if send_email_notification "$EMAIL_SUBJECT" "$EMAIL_BODY" "$EMAIL_NOTIFICATION" "$REPORT_FILE"; then
        log "Email notification sent successfully" "$LOG_FILE" "$SILENT_MODE"
        if [ "$SILENT_MODE" = false ]; then
            echo -e "${GREEN}✓ Email notification sent to $EMAIL_NOTIFICATION${NC}"
        fi
    else
        log "Failed to send email notification" "$LOG_FILE" "$SILENT_MODE"
        if [ "$SILENT_MODE" = false ]; then
            echo -e "${RED}Failed to send email notification${NC}"
        fi
    fi
fi

# Generate backup history chart
if [ "$SILENT_MODE" = false ]; then
    if command -v gnuplot >/dev/null 2>&1; then
        HISTORY_CHART=$(generate_history_chart "$BACKUP_HISTORY_LOG" "$FULL_BACKUP_PATH/backup_history_chart.png" 10)
        if [ -n "$HISTORY_CHART" ]; then
            echo -e "Backup history chart saved to: $HISTORY_CHART"
        fi
    fi
fi

# Update dashboard if not in silent mode
if [ "$SILENT_MODE" = false ] && command -v gnuplot >/dev/null 2>&1; then
    DASHBOARD_FILE=$(create_visual_dashboard "$FULL_BACKUP_PATH" "$BACKUP_HISTORY_LOG")
    if [ -n "$DASHBOARD_FILE" ]; then
        echo -e "Visual dashboard available at: $DASHBOARD_FILE"
    fi
fi

# Cleanup
rm -f "$EXCLUDE_FILE"

# Create logs directory if it doesn't exist
mkdir -p "$(dirname "$BACKUP_HISTORY_LOG")"

# Add backup record to history log (in reverse chronological order)
BACKUP_ENTRY="$(date '+%Y-%m-%d %H:%M:%S') - BACKUP: "
if [ "$FAILED_PROJECTS" -eq 0 ]; then
    BACKUP_ENTRY+="SUCCESS\n"
else
    BACKUP_ENTRY+="PARTIAL (WITH ERRORS)\n"
fi

BACKUP_ENTRY+="  Type: ${BACKUP_TYPE^}\n"
BACKUP_ENTRY+="  Storage: $([ "$EXTERNAL_BACKUP" = true ] && echo "EXTERNAL (${CLOUD_PROVIDER})" || echo "INTERNAL")\n"
BACKUP_ENTRY+="  Projects: ${SUCCESSFUL_PROJECTS} succeeded, ${FAILED_PROJECTS} failed\n"
BACKUP_ENTRY+="  Total Size: ${TOTAL_FORMATTED_SIZE}\n"
BACKUP_ENTRY+="  Source: ${SOURCE_DIRS[*]}\n"
BACKUP_ENTRY+="  Destination: ${FULL_BACKUP_PATH}\n"
BACKUP_ENTRY+="  Started: ${START_TIME}\n"
BACKUP_ENTRY+="  Finished: ${END_TIME}\n" 
BACKUP_ENTRY+="  Duration: ${DURATION_FORMATTED} (${DURATION_SECONDS} seconds)\n"

# Add more details for failed backups
if [ "$FAILED_PROJECTS" -gt 0 ]; then
    BACKUP_ENTRY+="  Failed Projects Log: ${LOGS_DIR}/failed_backups.log\n"
    
    # Add a summary of failed projects if available
    if [ -f "${LOGS_DIR}/failed_backups.log" ]; then
        BACKUP_ENTRY+="  Failed Projects Summary:\n"
        RECENT_FAILURES=$(grep "FAILED BACKUP:" "${LOGS_DIR}/failed_backups.log" | tail -${FAILED_PROJECTS} | sed 's/.*FAILED BACKUP: /    - /')
        BACKUP_ENTRY+="$RECENT_FAILURES\n"
    fi
fi

BACKUP_ENTRY+="--------------------------------------------------\n\n"

# Update history log in reverse chronological order
if [ -f "$BACKUP_HISTORY_LOG" ]; then
    # Read existing log and prepend new entry
    TEMP_LOG=$(mktemp)
    echo -e "$BACKUP_ENTRY" > "$TEMP_LOG"
    cat "$BACKUP_HISTORY_LOG" >> "$TEMP_LOG"
    mv "$TEMP_LOG" "$BACKUP_HISTORY_LOG"
else
    # Create new log
    echo -e "$BACKUP_ENTRY" > "$BACKUP_HISTORY_LOG"
fi

log "Backup record added to history log at $BACKUP_HISTORY_LOG" "$LOG_FILE" "$SILENT_MODE"

# Final status for silent mode
if [ "$SILENT_MODE" = true ]; then
    if [ "$DRY_RUN" = true ]; then
        echo "DRY RUN COMPLETED: Would backup $SUCCESSFUL_PROJECTS projects, Estimated size $TOTAL_FORMATTED_SIZE"
        echo "Source: ${SOURCE_DIRS[*]}"
        echo "Destination: $FULL_BACKUP_PATH"
    elif [ $FAILED_PROJECTS -eq 0 ]; then
        echo "BACKUP SUCCESSFUL: $SUCCESSFUL_PROJECTS projects, Size $TOTAL_FORMATTED_SIZE"
        echo "Source: ${SOURCE_DIRS[*]}"
        echo "Destination: $FULL_BACKUP_PATH"
    else
        echo "BACKUP COMPLETED WITH ERRORS: $FAILED_PROJECTS failed, $SUCCESSFUL_PROJECTS succeeded"
        echo "Source: ${SOURCE_DIRS[*]}"
        echo "Destination: $FULL_BACKUP_PATH"
        echo "Failed projects log: ${LOGS_DIR}/failed_backups.log"
        
        # List recent failed backups
        if [ -f "${LOGS_DIR}/failed_backups.log" ]; then
            echo "Recent failures:"
            tail -n 20 "${LOGS_DIR}/failed_backups.log" | grep "FAILED BACKUP:" | cut -d':' -f2-
        fi
    fi
else
    if [ "$DRY_RUN" = true ]; then
        echo -e "\n${YELLOW}DRY RUN COMPLETED: No actual backups were created${NC}"
        echo -e "${YELLOW}Would have backed up $SUCCESSFUL_PROJECTS projects, Estimated size $TOTAL_FORMATTED_SIZE${NC}"
        echo -e "${YELLOW}Source: ${GREEN}${SOURCE_DIRS[*]}${NC}"
        echo -e "${YELLOW}Destination: ${GREEN}$FULL_BACKUP_PATH${NC}"
    elif [ $FAILED_PROJECTS -gt 0 ]; then
        echo -e "\n${RED}BACKUP COMPLETED WITH ERRORS: $FAILED_PROJECTS failed, $SUCCESSFUL_PROJECTS succeeded${NC}"
        echo -e "${YELLOW}Path details:${NC}"
        echo -e "  Source: ${GREEN}${SOURCE_DIRS[*]}${NC}"
        echo -e "  Destination: ${GREEN}$FULL_BACKUP_PATH${NC}"
        echo -e "  Failed projects log: ${GREEN}${LOGS_DIR}/failed_backups.log${NC}"
        
        # Show failed backups details directly in the output
        if [ -f "${LOGS_DIR}/failed_backups.log" ]; then
            echo -e "\n${RED}Recent failures:${NC}"
            tail -n 6 "${LOGS_DIR}/failed_backups.log" | grep -A3 "FAILED BACKUP:" | head -6 | sed 's/^/  /'
            echo -e "\n${YELLOW}For complete list of failures, check:${NC}"
            echo -e "  ${GREEN}less ${LOGS_DIR}/failed_backups.log${NC}"
        fi
    fi
    echo -e "${CYAN}Finished at: $(date)${NC}\n"
    
    # Exit gracefully
    echo -e "\n${GREEN}Backup operation completed. Thanks for using WebDev Backup Tool!${NC}"
fi

exit 0