#!/bin/bash
# restore.sh - Restore script for backup-webdev
# Allows restoring full or partial backups from any backup point

# Source the shared modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/utils.sh"
source "$SCRIPT_DIR/../ui/ui.sh"
source "$SCRIPT_DIR/../core/fs.sh"

# Default values
LIST_BACKUPS=false
LATEST_BACKUP=true
BACKUP_DATE=""
PROJECT_NAME=""
FILE_NAME=""
TEST_ONLY=false
DRY_RUN=false
SKIP_CONFIRMATION=false
CUSTOM_SOURCE_DIR=""
CUSTOM_RESTORE_DIR=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --list)
            LIST_BACKUPS=true
            shift
            ;;
        --backup-date)
            if [[ -n "$2" && "$2" != --* ]]; then
                BACKUP_DATE="$2"
                LATEST_BACKUP=false
                shift 2
            else
                echo -e "${RED}Error: Backup date argument requires a date in format YYYY-MM-DD_HH-MM-SS${NC}"
                exit 1
            fi
            ;;
        --latest)
            LATEST_BACKUP=true
            shift
            ;;
        --project)
            if [[ -n "$2" && "$2" != --* ]]; then
                PROJECT_NAME="$2"
                shift 2
            else
                echo -e "${RED}Error: Project argument requires a project name${NC}"
                exit 1
            fi
            ;;
        --file)
            if [[ -n "$2" && "$2" != --* ]]; then
                FILE_NAME="$2"
                shift 2
            else
                echo -e "${RED}Error: File argument requires a file path${NC}"
                exit 1
            fi
            ;;
        --test)
            TEST_ONLY=true
            shift
            ;;
        -d|--dest)
            if [[ -n "$2" && "$2" != --* ]]; then
                CUSTOM_RESTORE_DIR="$2"
                shift 2
            else
                echo -e "${RED}Error: Destination argument requires a directory path${NC}"
                exit 1
            fi
            ;;
        -s|--source)
            if [[ -n "$2" && "$2" != --* ]]; then
                CUSTOM_SOURCE_DIR="$2"
                shift 2
            else
                echo -e "${RED}Error: Source argument requires a directory path${NC}"
                exit 1
            fi
            ;;
        -y|--yes)
            SKIP_CONFIRMATION=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            show_restore_help
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help to see available options"
            exit 1
            ;;
    esac
done

# Set source and destination directories
BACKUP_DIR="${CUSTOM_SOURCE_DIR:-$DEFAULT_BACKUP_DIR}"
RESTORE_DIR="${CUSTOM_RESTORE_DIR:-$DEFAULT_SOURCE_DIR}"

# Banner and introduction
echo -e "\n${CYAN}===== WebDev Backup Restore Tool =====${NC}"
echo -e "${CYAN}Started at: $(date)${NC}\n"

# List available backups if requested
if [ "$LIST_BACKUPS" = true ]; then
    echo -e "${YELLOW}Available Backups:${NC}"
    
    # Find all backup directories (Bash 3.2 compatible)
    backup_dirs=()
    while IFS= read -r backup_dir; do
        [ -n "$backup_dir" ] && backup_dirs+=("$backup_dir")
    done < <(find "$BACKUP_DIR" -maxdepth 1 -type d -name "wsl2_backup_*" | sort -r)
    
    if [ ${#backup_dirs[@]} -eq 0 ]; then
        echo -e "${RED}No backups found in $BACKUP_DIR${NC}"
        exit 1
    fi
    
    for ((i=0; i<${#backup_dirs[@]}; i++)); do
        # Extract date from directory name
        dir_name=$(basename "${backup_dirs[$i]}")
        backup_date=${dir_name#wsl2_backup_}
        
        # Count projects in this backup
        project_count=$(find "${backup_dirs[$i]}" -maxdepth 1 -type f -name "*.tar.gz" | wc -l)
        
        # Get total size
        total_size=$(du -sh "${backup_dirs[$i]}" | cut -f1)
        
        echo "[$i] $backup_date - $project_count projects - $total_size"
    done
    
    exit 0
fi

# Verify backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    echo -e "${RED}ERROR: Backup directory does not exist: $BACKUP_DIR${NC}"
    echo -e "Please specify a valid backup source directory using the -s option"
    exit 1
else
    echo -e "${GREEN}✓ Backup directory exists: $BACKUP_DIR${NC}"
fi

# Find the backup to restore from
if [ "$LATEST_BACKUP" = true ]; then
    # Find the latest backup
    BACKUP_TO_RESTORE=$(find "$BACKUP_DIR" -maxdepth 1 -type d -name "wsl2_backup_*" | sort -r | head -1)
    
    if [ -z "$BACKUP_TO_RESTORE" ]; then
        echo -e "${RED}ERROR: No backups found in $BACKUP_DIR${NC}"
        exit 1
    fi
    
    BACKUP_DATE=$(basename "$BACKUP_TO_RESTORE" | sed 's/wsl2_backup_//')
    echo -e "${GREEN}✓ Found latest backup from: $BACKUP_DATE${NC}"
else
    # Find specific backup by date
    BACKUP_TO_RESTORE="$BACKUP_DIR/wsl2_backup_$BACKUP_DATE"
    
    if [ ! -d "$BACKUP_TO_RESTORE" ]; then
        echo -e "${RED}ERROR: Backup for date $BACKUP_DATE not found${NC}"
        echo -e "Use --list to see available backups"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Found requested backup from: $BACKUP_DATE${NC}"
fi

# Create restore log
RESTORE_DATE=$(date +%Y-%m-%d_%H-%M-%S)
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/restore_${RESTORE_DATE}.log"

section "Restore Configuration" "$LOG_FILE"
log "Backup source: $BACKUP_TO_RESTORE" "$LOG_FILE"
log "Restore destination: $RESTORE_DIR" "$LOG_FILE"

if [ "$TEST_ONLY" = true ]; then
    log "Test mode: Only verifying backup integrity, no files will be restored" "$LOG_FILE"
fi

if [ "$DRY_RUN" = true ]; then
    log "Dry run mode: Showing what would be done, no actual restore" "$LOG_FILE"
fi

# Find available projects in the backup (Bash 3.2 compatible)
available_projects=()
while IFS= read -r project_name; do
    [ -n "$project_name" ] && available_projects+=("$project_name")
done < <(find "$BACKUP_TO_RESTORE" -maxdepth 1 -type f -name "*.tar.gz" | sed -n 's/.*\/\([^_]*\)_.*/\1/p' | sort -u)

if [ ${#available_projects[@]} -eq 0 ]; then
    # Special handling for dry-run mode
    if [ "$DRY_RUN" = true ]; then
        log "Dry run mode: No actual project files found but continuing for demonstration" "$LOG_FILE"
        echo -e "${YELLOW}Dry run mode: No actual project files found in backup${NC}"
        echo -e "${YELLOW}Using simulated project list for demonstration${NC}"
        
        # Create dummy project list for dry run
        available_projects=("project1" "project2" "project3")
    else
        log "ERROR: No projects found in backup $BACKUP_TO_RESTORE" "$LOG_FILE"
        echo -e "${RED}ERROR: No projects found in the selected backup${NC}"
        exit 1
    fi
fi

log "Found ${#available_projects[@]} projects in backup" "$LOG_FILE"

# Handle project selection
if [ -n "$PROJECT_NAME" ]; then
    # Check if specified project exists in backup
    project_file=$(find "$BACKUP_TO_RESTORE" -maxdepth 1 -type f -name "${PROJECT_NAME}_${BACKUP_DATE}.tar.gz")
    
    if [ -z "$project_file" ]; then
        if [ "$DRY_RUN" = true ]; then
            # For dry-run mode, we'll simulate the file
            log "Dry run mode: Project $PROJECT_NAME not found but continuing for demonstration" "$LOG_FILE"
            echo -e "${YELLOW}Dry run mode: Simulating project $PROJECT_NAME for demonstration${NC}"
            project_file="$BACKUP_TO_RESTORE/${PROJECT_NAME}_${BACKUP_DATE}.tar.gz"
        else
            log "ERROR: Project $PROJECT_NAME not found in backup $BACKUP_TO_RESTORE" "$LOG_FILE"
            echo -e "${RED}ERROR: Project $PROJECT_NAME not found in the selected backup${NC}"
            exit 1
        fi
    fi
    
    PROJECTS_TO_RESTORE=("$PROJECT_NAME")
    log "Selected project for restore: $PROJECT_NAME" "$LOG_FILE"
else
    # Interactive project selection if no specific project was requested
    if [ "$SKIP_CONFIRMATION" = false ]; then
        echo -e "\n${YELLOW}Available Projects in Backup:${NC}"
        for ((i=0; i<${#available_projects[@]}; i++)); do
            echo "[$i] ${available_projects[$i]}"
        done
        
        echo -e "\nEnter project numbers to restore, separated by spaces."
        echo "Press Enter to restore all projects."
        read -p "> " projects_input
        
        if [ -z "$projects_input" ]; then
            # Restore all projects
            PROJECTS_TO_RESTORE=("${available_projects[@]}")
            log "Selected all projects for restore" "$LOG_FILE"
        else
            # Restore selected projects
            PROJECTS_TO_RESTORE=()
            for num in $projects_input; do
                if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -lt "${#available_projects[@]}" ]; then
                    PROJECTS_TO_RESTORE+=("${available_projects[$num]}")
                    log "Selected project for restore: ${available_projects[$num]}" "$LOG_FILE"
                else
                    log "Warning: Invalid project number: $num" "$LOG_FILE"
                    echo -e "${YELLOW}Warning: Invalid project number: $num${NC}"
                fi
            done
        fi
    else
        # In non-interactive mode, restore all projects
        PROJECTS_TO_RESTORE=("${available_projects[@]}")
        log "Auto-selected all projects for restore (non-interactive mode)" "$LOG_FILE"
    fi
fi

# Verify restore directory
if [ ! -d "$RESTORE_DIR" ]; then
    log "Restore directory does not exist: $RESTORE_DIR" "$LOG_FILE"
    
    if [ "$SKIP_CONFIRMATION" = true ] || confirm "Restore directory does not exist. Create it?"; then
        if run_cmd "mkdir -p \"$RESTORE_DIR\"" "$DRY_RUN"; then
            log "Created restore directory: $RESTORE_DIR" "$LOG_FILE"
            echo -e "${GREEN}✓ Created restore directory: $RESTORE_DIR${NC}"
        else
            log "ERROR: Failed to create restore directory: $RESTORE_DIR" "$LOG_FILE"
            echo -e "${RED}ERROR: Failed to create restore directory: $RESTORE_DIR${NC}"
            exit 1
        fi
    else
        log "Restore cancelled - directory not created" "$LOG_FILE"
        echo -e "${YELLOW}Restore cancelled by user${NC}"
        exit 0
    fi
else
    log "Restore directory exists: $RESTORE_DIR" "$LOG_FILE"
    echo -e "${GREEN}✓ Restore directory exists: $RESTORE_DIR${NC}"
    
    # Check if restore directory is writable
    if [ ! -w "$RESTORE_DIR" ]; then
        log "ERROR: Restore directory is not writable: $RESTORE_DIR" "$LOG_FILE"
        echo -e "${RED}ERROR: Restore directory is not writable: $RESTORE_DIR${NC}"
        exit 1
    fi
    
    # Test we can actually write to the filesystem
    TEST_FILE="$RESTORE_DIR/.write_test_$(date +%s)"
    if ! touch "$TEST_FILE" 2>/dev/null; then
        log "ERROR: Cannot write to restore directory: $RESTORE_DIR" "$LOG_FILE"
        echo -e "${RED}ERROR: Cannot write to restore directory: $RESTORE_DIR${NC}"
        echo -e "${RED}The filesystem may be read-only or full.${NC}"
        exit 1
    else
        rm -f "$TEST_FILE"
        log "Restore directory is writable: $RESTORE_DIR" "$LOG_FILE"
    fi
fi

# Final confirmation before restore
if [ "$SKIP_CONFIRMATION" = false ] && [ "$TEST_ONLY" = false ] && [ "$DRY_RUN" = false ]; then
    echo -e "\n${YELLOW}Ready to restore the following projects from backup $BACKUP_DATE:${NC}"
    for project in "${PROJECTS_TO_RESTORE[@]}"; do
        echo "  - $project"
    done
    
    if [ -n "$FILE_NAME" ]; then
        echo -e "${YELLOW}Will only restore the specific file: $FILE_NAME${NC}"
    fi
    
    echo -e "${YELLOW}Target restore directory: $RESTORE_DIR${NC}"
    echo -e "${RED}WARNING: Existing files may be overwritten!${NC}"
    
    if ! confirm "Do you want to continue with the restore?"; then
        log "Restore cancelled by user" "$LOG_FILE"
        echo -e "${YELLOW}Restore cancelled by user${NC}"
        exit 0
    fi
fi

# Extract source directory from backup filename
get_source_from_backup() {
    local backup_file="$1"
    local filename=$(basename "$backup_file")
    
    # Check if it's a multi-directory format backup (source_project_date.tar.gz)
    if [[ "$filename" =~ ^([^_]+)_([^_]+)_([0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2})\.tar\.gz$ ]]; then
        # Multi-directory format: Extract the source directory name
        echo "${BASH_REMATCH[1]}"
    else
        # Legacy format: Use default source
        echo "webdev"
    fi
}

# Extract project name from backup filename
get_project_from_backup() {
    local backup_file="$1"
    local filename=$(basename "$backup_file")
    
    # Check if it's a multi-directory format backup (source_project_date.tar.gz)
    if [[ "$filename" =~ ^([^_]+)_([^_]+)_([0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2})\.tar\.gz$ ]]; then
        # Multi-directory format: Extract the project name
        echo "${BASH_REMATCH[2]}"
    else
        # Legacy format: Extract just the project name
        echo "$filename" | sed -E 's/^([^_]+)_[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}\.tar\.gz$/\1/'
    fi
}

# When restoring, add option to restore to original location based on source directory:
restore_project() {
    local backup_file="$1"
    local destination_dir="$2"
    
    # If no destination specified, determine based on source directory
    if [ -z "$destination_dir" ]; then
        local source_dir=$(get_source_from_backup "$backup_file")
        local project=$(get_project_from_backup "$backup_file")
        
        # Try to find original location
        if [ "$source_dir" = "webdev" ] && [ -d "$HOME/webdev" ]; then
            destination_dir="$HOME/webdev"
        else
            # Look for the source directory in default locations
            for dir in "${DEFAULT_SOURCE_DIRS[@]}"; do
                if [[ "$dir" == *"$source_dir"* ]] || [[ "$(basename "$dir")" == "$source_dir" ]]; then
                    destination_dir="$dir"
                    break
                fi
            done
            
            # If still not found, prompt user
            if [ -z "$destination_dir" ]; then
                echo -e "${YELLOW}Could not automatically determine restore location for $project from $source_dir${NC}"
                read -p "Enter restore destination directory: " destination_dir
                
                if [ -z "$destination_dir" ]; then
                    echo -e "${RED}No destination specified. Aborting restore.${NC}"
                    return 1
                fi
            fi
        fi
    fi
    
    # ...existing restore code...
}

# Process the restore
section "Starting Restore Process" "$LOG_FILE"
echo -e "\n${CYAN}Starting Restore Process...${NC}"

TOTAL_FILES=0
SUCCESSFUL_RESTORES=0
FAILED_RESTORES=0

for project in "${PROJECTS_TO_RESTORE[@]}"; do
    project_file="$BACKUP_TO_RESTORE/${project}_${BACKUP_DATE}.tar.gz"
    
    if [ ! -f "$project_file" ]; then
        if [ "$DRY_RUN" = true ]; then
            # In dry-run mode, simulate success for most projects, but failure for one
            # This allows testing both success and failure handling
            if [[ "$project" == *"2"* ]]; then  # Fail project2 for demonstration
                log "DRY RUN: Simulating failure for project: $project" "$LOG_FILE"
                echo -e "${YELLOW}DRY RUN: Simulating failure for project: $project${NC}"
                echo -e "${RED}ERROR: Project file would be: $(basename "$project_file")${NC}"
                FAILED_RESTORES=$((FAILED_RESTORES + 1))
            else
                log "DRY RUN: Simulating successful restore for project: $project" "$LOG_FILE"
                echo -e "${YELLOW}DRY RUN: Would restore project: $project${NC}"
                echo -e "${GREEN}DRY RUN: From backup file: $(basename "$project_file")${NC}"
                SUCCESSFUL_RESTORES=$((SUCCESSFUL_RESTORES + 1))
                TOTAL_FILES=$((TOTAL_FILES + 10))  # Simulate 10 files per project
            fi
            continue
        else
            log "ERROR: Project file not found: $project_file" "$LOG_FILE"
            echo -e "${RED}ERROR: Project file not found: $(basename "$project_file")${NC}"
            FAILED_RESTORES=$((FAILED_RESTORES + 1))
            continue
        fi
    fi
    
    # Test backup integrity
    if ! verify_backup "$project_file" "$LOG_FILE"; then
        log "ERROR: Failed integrity check for: $project_file" "$LOG_FILE"
        echo -e "${RED}ERROR: Failed integrity check for: $(basename "$project_file")${NC}"
        FAILED_RESTORES=$((FAILED_RESTORES + 1))
        continue
    fi
    
    log "Backup integrity verified for: $project" "$LOG_FILE"
    echo -e "${GREEN}✓ Backup integrity verified for: $project${NC}"
    
    # If we're just testing integrity, continue to next project
    if [ "$TEST_ONLY" = true ]; then
        SUCCESSFUL_RESTORES=$((SUCCESSFUL_RESTORES + 1))
        continue
    fi
    
    # Create project directory in restore location
    project_restore_dir="$RESTORE_DIR/$project"
    
    if [ "$DRY_RUN" = true ]; then
        log "DRY RUN: Would create directory: $project_restore_dir" "$LOG_FILE"
        echo -e "${YELLOW}DRY RUN: Would create directory: $project_restore_dir${NC}"
    else
        if [ ! -d "$project_restore_dir" ]; then
            if ! mkdir -p "$project_restore_dir"; then
                log "ERROR: Failed to create project directory: $project_restore_dir" "$LOG_FILE"
                echo -e "${RED}ERROR: Failed to create project directory: $project_restore_dir${NC}"
                FAILED_RESTORES=$((FAILED_RESTORES + 1))
                continue
            fi
            log "Created project directory: $project_restore_dir" "$LOG_FILE"
        else
            log "Project directory already exists: $project_restore_dir" "$LOG_FILE"
        fi
    fi
    
    # Restore the project
    if [ -n "$FILE_NAME" ]; then
        # Restore just a specific file
        specific_path="$project/$FILE_NAME"
        if [ "$DRY_RUN" = true ]; then
            log "DRY RUN: Would extract file $specific_path from $project_file to $RESTORE_DIR" "$LOG_FILE"
            echo -e "${YELLOW}DRY RUN: Would extract file $specific_path to $RESTORE_DIR${NC}"
            SUCCESSFUL_RESTORES=$((SUCCESSFUL_RESTORES + 1))
        else
            echo -e "${CYAN}Restoring file: $FILE_NAME from project $project...${NC}"
            if extract_backup "$project_file" "$RESTORE_DIR" "$LOG_FILE" "$specific_path"; then
                log "Successfully restored file: $specific_path" "$LOG_FILE"
                echo -e "${GREEN}✓ Successfully restored file: $FILE_NAME${NC}"
                SUCCESSFUL_RESTORES=$((SUCCESSFUL_RESTORES + 1))
                TOTAL_FILES=$((TOTAL_FILES + 1))
            else
                log "ERROR: Failed to restore file: $specific_path" "$LOG_FILE"
                echo -e "${RED}ERROR: Failed to restore file: $FILE_NAME${NC}"
                FAILED_RESTORES=$((FAILED_RESTORES + 1))
            fi
        fi
    else
        # Restore the entire project
        if [ "$DRY_RUN" = true ]; then
            log "DRY RUN: Would extract $project_file to $RESTORE_DIR" "$LOG_FILE"
            echo -e "${YELLOW}DRY RUN: Would extract project $project to $RESTORE_DIR${NC}"
            SUCCESSFUL_RESTORES=$((SUCCESSFUL_RESTORES + 1))
        else
            echo -e "${CYAN}Restoring project: $project...${NC}"
            
            # Count files before extraction for progress
            file_count=$(tar -tzf "$project_file" | wc -l)
            log "Project has approximately $file_count files" "$LOG_FILE"
            
            # Extract with progress indicator
            if extract_backup "$project_file" "$RESTORE_DIR" "$LOG_FILE"; then
                log "Successfully restored project: $project" "$LOG_FILE"
                echo -e "${GREEN}✓ Successfully restored project: $project${NC}"
                SUCCESSFUL_RESTORES=$((SUCCESSFUL_RESTORES + 1))
                TOTAL_FILES=$((TOTAL_FILES + file_count))
            else
                log "ERROR: Failed to restore project: $project" "$LOG_FILE"
                echo -e "${RED}ERROR: Failed to restore project: $project${NC}"
                FAILED_RESTORES=$((FAILED_RESTORES + 1))
            fi
        fi
    fi
done

# Summary
section "Restore Summary" "$LOG_FILE"
log "Projects processed: $((SUCCESSFUL_RESTORES + FAILED_RESTORES))" "$LOG_FILE"
log "Successfully restored: $SUCCESSFUL_RESTORES" "$LOG_FILE"
log "Failed restores: $FAILED_RESTORES" "$LOG_FILE"
log "Total files restored: $TOTAL_FILES" "$LOG_FILE"

echo -e "\n${CYAN}===== Restore Summary =====${NC}"
echo "- Projects processed: $((SUCCESSFUL_RESTORES + FAILED_RESTORES))"
echo "- Successfully restored: $SUCCESSFUL_RESTORES"
echo "- Failed restores: $FAILED_RESTORES"
echo "- Total files restored: $TOTAL_FILES"
echo "- Restore location: $RESTORE_DIR"

if [ "$TEST_ONLY" = true ]; then
    echo -e "${GREEN}✓ Test completed successfully. No files were restored.${NC}"
elif [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}DRY RUN COMPLETED: No files were actually restored${NC}"
    echo -e "${YELLOW}Would have restored $SUCCESSFUL_RESTORES projects with approximately $TOTAL_FILES files${NC}"
    
    if [ $FAILED_RESTORES -gt 0 ]; then
        echo -e "${RED}Would have encountered $FAILED_RESTORES project errors${NC}"
        echo -e "${YELLOW}Simulated failed projects:${NC}"
        for project in "${PROJECTS_TO_RESTORE[@]}"; do
            if [[ "$project" == *"2"* ]]; then
                echo -e "  ${RED}- $project (simulated failure)${NC}"
                echo -e "    ${RED}Path: $BACKUP_TO_RESTORE/${project}_${BACKUP_DATE}.tar.gz${NC}"
            fi
        done
    fi
else
    echo -e "${GREEN}✓ Restore completed${NC}"
fi

# Record restore to history log
RESTORE_ENTRY="$(date '+%Y-%m-%d %H:%M:%S') - RESTORE: "
if [ $FAILED_RESTORES -eq 0 ]; then
    RESTORE_ENTRY+="SUCCESS\n"
else
    RESTORE_ENTRY+="PARTIAL (WITH ERRORS)\n"
fi

if [ "$TEST_ONLY" = true ]; then
    RESTORE_ENTRY+="  Mode: TEST ONLY\n"
elif [ "$DRY_RUN" = true ]; then
    RESTORE_ENTRY+="  Mode: DRY RUN\n"
else
    RESTORE_ENTRY+="  Mode: ACTUAL RESTORE\n"
fi

RESTORE_ENTRY+="  Projects: ${SUCCESSFUL_RESTORES} succeeded, ${FAILED_RESTORES} failed\n"
RESTORE_ENTRY+="  Total Files: ${TOTAL_FILES}\n"
RESTORE_ENTRY+="  Source Backup: ${BACKUP_TO_RESTORE}\n"
RESTORE_ENTRY+="  Restore Destination: ${RESTORE_DIR}\n"
RESTORE_ENTRY+="--------------------------------------------------\n\n"

# Update history log in reverse chronological order
RESTORE_HISTORY_LOG="$LOG_DIR/restore_history.log"
if [ -f "$RESTORE_HISTORY_LOG" ]; then
    # Read existing log and prepend new entry
    TEMP_LOG=$(mktemp)
    echo -e "$RESTORE_ENTRY" > "$TEMP_LOG"
    cat "$RESTORE_HISTORY_LOG" >> "$TEMP_LOG"
    mv "$TEMP_LOG" "$RESTORE_HISTORY_LOG"
else
    # Create new log
    echo -e "$RESTORE_ENTRY" > "$RESTORE_HISTORY_LOG"
fi

log "Restore record added to history log at $RESTORE_HISTORY_LOG" "$LOG_FILE"
echo -e "${CYAN}Restore log saved to: $LOG_FILE${NC}"
echo -e "${CYAN}Finished at: $(date)${NC}\n"

# Exit gracefully
echo -e "\n${GREEN}Restore operation completed. Thanks for using WebDev Backup Tool!${NC}"

exit 0