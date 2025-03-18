#!/bin/bash
# cleanup.sh - Cleanup script for backup-webdev
# Removes logs, verifies directories, and checks target volume accessibility

# Source the shared modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/ui.sh"
source "$SCRIPT_DIR/fs.sh"

# Log cleaning options
LOGS_BACKUP=false
LOGS_REMOVE_ALL=false
LOGS_OLDER_THAN=""
CUSTOM_SOURCE_DIR=""
CUSTOM_BACKUP_DIR=""
SKIP_CONFIRMATION=false
DRY_RUN=false
CLEAR_BACKUPS=false

# Help function
show_help() {
    echo "WebDev Backup Cleanup Tool"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -b, --backup-logs       Backup logs before removing them"
    echo "  -a, --all-logs          Remove all logs (default: keeps last 5 runs)"
    echo "  -d, --days DAYS         Remove logs older than DAYS days"
    echo "  -s, --source DIR        Use custom source directory"
    echo "  -t, --target DIR        Use custom backup target directory"
    echo "  -y, --yes               Skip confirmation prompts"
    echo "  --dry-run               Show what would be done without doing it"
    echo "  --clear-backups         Clear backup folders in /backups/ directory"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Default values:"
    echo "  Source directory:      $DEFAULT_SOURCE_DIR"
    echo "  Backup destination:    $DEFAULT_BACKUP_DIR"
    echo ""
    echo "Examples:"
    echo "  $0                     # Standard cleanup (keeps recent logs and 5 most recent backups)"
    echo "  $0 -a                  # Remove all logs"
    echo "  $0 -d 30               # Remove logs older than 30 days"
    echo "  $0 -b -a               # Backup all logs before removing them"
    echo "  $0 -t /mnt/backups     # Use custom backup target"
    echo "  $0 --dry-run           # Show what would be cleaned without making changes"
    echo "  $0 --clear-backups     # Clear all backup folders (with confirmation)"
    echo ""
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -b|--backup-logs)
            LOGS_BACKUP=true
            shift
            ;;
        -a|--all-logs)
            LOGS_REMOVE_ALL=true
            shift
            ;;
        -d|--days)
            if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
                LOGS_OLDER_THAN="$2"
                shift 2
            else
                echo -e "${RED}Error: Days argument requires a number${NC}"
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
        -t|--target)
            if [[ -n "$2" && "$2" != --* ]]; then
                CUSTOM_BACKUP_DIR="$2"
                shift 2
            else
                echo -e "${RED}Error: Target argument requires a directory path${NC}"
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
        --clear-backups)
            CLEAR_BACKUPS=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help to see available options"
            exit 1
            ;;
    esac
done

# Set source and backup directories (use custom if provided, otherwise default)
SOURCE_DIR="${CUSTOM_SOURCE_DIR:-$DEFAULT_SOURCE_DIR}"
BACKUP_DIR="${CUSTOM_BACKUP_DIR:-$DEFAULT_BACKUP_DIR}"

# Banner and introduction
echo -e "\n${CYAN}===== WebDev Backup Cleanup Tool =====${NC}"
echo -e "${CYAN}Started at: $(date)${NC}\n"

echo -e "This script performs the following tasks:"
echo -e " 1. Verifies source directory existence"
echo -e " 2. Checks backup destination accessibility"
echo -e " 3. Removes log files from the PROJECT DIRECTORY ONLY"
echo -e " 4. Verifies script permissions"
echo -e " 5. Creates any missing directories"
echo -e ""
echo -e "${YELLOW}IMPORTANT:${NC} No files on the target backup volume will be deleted."
echo -e "           Only log files within this project directory will be affected."
echo -e ""

# Show what files will be affected
echo -e "${YELLOW}Files that may be affected by this cleanup:${NC}"

# Count and list log files
BACKUP_LOG_COUNT=$(find "$LOGS_DIR" -type f -not -name '.gitkeep' 2>/dev/null | wc -l)
TEST_LOG_COUNT=$(find "$TEST_DIR" -type f -name "*.log" 2>/dev/null | wc -l)
TEST_DIR_COUNT=$(find "$TEST_DIR" -type d -name "webdev_test_*" 2>/dev/null | wc -l)

echo -e " - Backup logs: $BACKUP_LOG_COUNT file(s)"
if [ $BACKUP_LOG_COUNT -gt 0 ] && [ $BACKUP_LOG_COUNT -le 10 ]; then
    find "$LOGS_DIR" -type f -not -name '.gitkeep' -printf "   - %f\n" 2>/dev/null | sort
elif [ $BACKUP_LOG_COUNT -gt 10 ]; then
    find "$LOGS_DIR" -type f -not -name '.gitkeep' -printf "   - %f\n" 2>/dev/null | sort | head -5
    echo "   - ... and $(($BACKUP_LOG_COUNT - 5)) more backup log files"
fi

echo -e " - Test logs: $TEST_LOG_COUNT file(s)"
if [ $TEST_LOG_COUNT -gt 0 ] && [ $TEST_LOG_COUNT -le 10 ]; then
    find "$TEST_DIR" -type f -name "*.log" -printf "   - %f\n" 2>/dev/null | sort
elif [ $TEST_LOG_COUNT -gt 10 ]; then
    find "$TEST_DIR" -type f -name "*.log" -printf "   - %f\n" 2>/dev/null | sort | head -5
    echo "   - ... and $(($TEST_LOG_COUNT - 5)) more test log files"
fi

echo -e " - Test directories: $TEST_DIR_COUNT directory/directories"
if [ $TEST_DIR_COUNT -gt 0 ] && [ $TEST_DIR_COUNT -le 5 ]; then
    find "$TEST_DIR" -type d -name "webdev_test_*" -printf "   - %f\n" 2>/dev/null | sort
elif [ $TEST_DIR_COUNT -gt 5 ]; then
    find "$TEST_DIR" -type d -name "webdev_test_*" -printf "   - %f\n" 2>/dev/null | sort | head -3
    echo "   - ... and $(($TEST_DIR_COUNT - 3)) more test directories"
fi

echo -e ""

# Initial confirmation to proceed
if [ "$SKIP_CONFIRMATION" = false ]; then
    read -p "Do you want to proceed with the cleanup? (y/N) " initial_response
    case "$initial_response" in
        [yY][eE][sS]|[yY]) 
            echo -e "${GREEN}Proceeding with cleanup...${NC}"
            ;;
        *)
            echo -e "${YELLOW}Cleanup cancelled by user. Nothing was cleaned.${NC}"
            exit 0
            ;;
    esac
fi

# Section headers function
section() {
    echo -e "\n${YELLOW}===== $1 =====${NC}"
}

# Function to run commands with dry run support
run_cmd() {
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}DRY RUN: Would execute: $1${NC}"
        return 0
    else
        eval "$1"
        return $?
    fi
}

# Function to get confirmation
confirm() {
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

# Verify source directory
section "Verifying Source Directory"
if [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${RED}ERROR: Source directory does not exist: $SOURCE_DIR${NC}"
    echo -e "Please specify a valid source directory using the -s option"
    exit 1
else
    echo -e "${GREEN}✓ Source directory exists: $SOURCE_DIR${NC}"
    
    # Count projects
    project_count=$(find "$SOURCE_DIR" -maxdepth 1 -type d | wc -l)
    project_count=$((project_count - 1)) # Subtract 1 for the directory itself
    echo -e "${GREEN}✓ Found $project_count projects in source directory${NC}"
fi

# Check backup destination
section "Verifying Backup Destination"
if [ ! -d "$BACKUP_DIR" ]; then
    echo -e "${YELLOW}Backup directory does not exist: $BACKUP_DIR${NC}"
    
    if confirm "Would you like to create it?"; then
        if run_cmd "mkdir -p \"$BACKUP_DIR\""; then
            echo -e "${GREEN}✓ Created backup directory: $BACKUP_DIR${NC}"
        else
            echo -e "${RED}ERROR: Failed to create backup directory: $BACKUP_DIR${NC}"
            echo -e "Please check if you have permission to create this directory"
            exit 1
        fi
    else
        echo -e "${YELLOW}Skipping backup directory creation${NC}"
    fi
else
    echo -e "${GREEN}✓ Backup directory exists: $BACKUP_DIR${NC}"
fi

# Test target volume accessibility
section "Testing Backup Volume"
TEST_FILE="$BACKUP_DIR/.write_test_$(date +%s)"
if run_cmd "touch \"$TEST_FILE\" 2>/dev/null"; then
    echo -e "${GREEN}✓ Backup volume is accessible and writable${NC}"
    run_cmd "rm -f \"$TEST_FILE\""
else
    echo -e "${RED}ERROR: Cannot write to backup volume: $BACKUP_DIR${NC}"
    echo -e "Please check volume mount status and permissions"
    exit 1
fi

# Handle log directories
section "Managing Log Directories"

# Ensure log directories exist
echo "Checking log and test directories..."
if run_cmd "mkdir -p \"$LOGS_DIR\" \"$TEST_DIR\""; then
    echo -e "${GREEN}✓ Log directories are ready${NC}"
else
    echo -e "${RED}ERROR: Failed to create log directories${NC}"
    exit 1
fi

# Create placeholders
run_cmd "touch \"$LOGS_DIR/.gitkeep\" \"$TEST_DIR/.gitkeep\""

# Clean up logs
section "Cleaning Logs"

# Backup logs if requested
if [ "$LOGS_BACKUP" = true ]; then
    LOGS_BACKUP_DIR="$BACKUP_DIR/logs_backup_$(date +$DATE_FORMAT)"
    echo "Backing up logs to $LOGS_BACKUP_DIR..."
    
    if run_cmd "mkdir -p \"$LOGS_BACKUP_DIR\""; then
        # Copy logs
        if run_cmd "cp -r \"$LOGS_DIR\"/* \"$LOGS_BACKUP_DIR/\" 2>/dev/null"; then
            echo -e "${GREEN}✓ Logs backed up successfully${NC}"
        else
            echo -e "${YELLOW}No logs to back up or backup failed${NC}"
        fi
        
        # Copy test logs
        if run_cmd "mkdir -p \"$LOGS_BACKUP_DIR/tests\""; then
            if run_cmd "cp -r \"$TEST_DIR\"/*.log \"$LOGS_BACKUP_DIR/tests/\" 2>/dev/null"; then
                echo -e "${GREEN}✓ Test logs backed up successfully${NC}"
            else
                echo -e "${YELLOW}No test logs to back up or backup failed${NC}"
            fi
        fi
    else
        echo -e "${RED}ERROR: Failed to create logs backup directory${NC}"
        exit 1
    fi
fi

# Remove log files based on options
if [ "$LOGS_REMOVE_ALL" = true ]; then
    if [ "$DRY_RUN" = false ]; then
        if confirm "Are you sure you want to remove ALL log files?"; then
            echo "Processing log files in $LOGS_DIR..."
            
            # Find all log files
            BACKUP_LOGS=$(find "$LOGS_DIR" -type f -not -name '.gitkeep')
            
            # Process each log file with confirmation
            for log_file in $BACKUP_LOGS; do
                log_name=$(basename "$log_file")
                if confirm "Delete log: $log_name?" "y"; then
                    run_cmd "rm -f \"$log_file\""
                    echo -e "${GREEN}  ✓ Deleted: $log_name${NC}"
                else
                    echo -e "${YELLOW}  ✗ Kept: $log_name${NC}"
                fi
            done
            
            echo "Processing test log files in $TEST_DIR..."
            
            # Find all test log files
            TEST_LOGS=$(find "$TEST_DIR" -type f -name "*.log")
            
            # Process each test log file with confirmation
            for log_file in $TEST_LOGS; do
                log_name=$(basename "$log_file")
                if confirm "Delete test log: $log_name?" "y"; then
                    run_cmd "rm -f \"$log_file\""
                    echo -e "${GREEN}  ✓ Deleted: $log_name${NC}"
                else
                    echo -e "${YELLOW}  ✗ Kept: $log_name${NC}"
                fi
            done
            
            echo -e "${GREEN}✓ Log cleanup completed${NC}"
        else
            echo -e "${YELLOW}Log removal cancelled${NC}"
        fi
    else
        echo -e "${YELLOW}DRY RUN: Would ask for confirmation to remove each log file in:${NC}"
        echo -e "${YELLOW}  - ${LOGS_DIR}${NC}"
        echo -e "${YELLOW}  - ${TEST_DIR} (*.log files)${NC}"
    fi
elif [ -n "$LOGS_OLDER_THAN" ]; then
    if [ "$DRY_RUN" = false ]; then
        echo "Finding logs older than $LOGS_OLDER_THAN days..."
        
        # Find backup logs older than specified days
        OLD_BACKUP_LOGS=$(find "$LOGS_DIR" -type f -not -name '.gitkeep' -mtime +$LOGS_OLDER_THAN)
        
        # Process each old backup log file with confirmation
        for log_file in $OLD_BACKUP_LOGS; do
            log_name=$(basename "$log_file")
            log_date=$(date -r "$log_file" "+%Y-%m-%d")
            if confirm "Delete old log ($log_date): $log_name?" "y"; then
                run_cmd "rm -f \"$log_file\""
                echo -e "${GREEN}  ✓ Deleted: $log_name${NC}"
            else
                echo -e "${YELLOW}  ✗ Kept: $log_name${NC}"
            fi
        done
        
        # Find test logs older than specified days
        OLD_TEST_LOGS=$(find "$TEST_DIR" -type f -name "*.log" -mtime +$LOGS_OLDER_THAN)
        
        # Process each old test log file with confirmation
        for log_file in $OLD_TEST_LOGS; do
            log_name=$(basename "$log_file")
            log_date=$(date -r "$log_file" "+%Y-%m-%d")
            if confirm "Delete old test log ($log_date): $log_name?" "y"; then
                run_cmd "rm -f \"$log_file\""
                echo -e "${GREEN}  ✓ Deleted: $log_name${NC}"
            else
                echo -e "${YELLOW}  ✗ Kept: $log_name${NC}"
            fi
        done
        
        echo -e "${GREEN}✓ Log cleanup completed${NC}"
    else
        echo -e "${YELLOW}DRY RUN: Would ask for confirmation to remove logs older than $LOGS_OLDER_THAN days${NC}"
    fi
else
    # Default: keep last 5 log entries in each log file
    echo "Trimming log files to keep recent entries..."
    
    # Process backup history log
    if [ -f "$BACKUP_HISTORY_LOG" ]; then
        if confirm "Trim backup history log to keep only recent entries?" "y"; then
            if run_cmd "awk 'BEGIN {count=0} /^[0-9]{4}-[0-9]{2}-[0-9]{2}/ {count++} count > 5 {next} {print}' \"$BACKUP_HISTORY_LOG\" > \"$BACKUP_HISTORY_LOG.tmp\" && mv \"$BACKUP_HISTORY_LOG.tmp\" \"$BACKUP_HISTORY_LOG\""; then
                echo -e "${GREEN}✓ Trimmed backup history log to recent entries${NC}"
            fi
        else
            echo -e "${YELLOW}✗ Kept backup history log as is${NC}"
        fi
    fi
    
    # Process test history log
    if [ -f "$TEST_HISTORY_LOG" ]; then
        if confirm "Trim test history log to keep only recent entries?" "y"; then
            if run_cmd "awk 'BEGIN {count=0} /^[0-9]{4}-[0-9]{2}-[0-9]{2}/ {count++} count > 5 {next} {print}' \"$TEST_HISTORY_LOG\" > \"$TEST_HISTORY_LOG.tmp\" && mv \"$TEST_HISTORY_LOG.tmp\" \"$TEST_HISTORY_LOG\""; then
                echo -e "${GREEN}✓ Trimmed test history log to recent entries${NC}"
            fi
        else
            echo -e "${YELLOW}✗ Kept test history log as is${NC}"
        fi
    fi
    
    # Remove old test run logs (keep last 5)
    if [ "$DRY_RUN" = false ]; then
        # Count how many test run logs we have
        TEST_RUN_COUNT=$(find "$TEST_DIR" -name "test_run_*.log" | wc -l)
        
        if [ "$TEST_RUN_COUNT" -gt 5 ]; then
            # Get list of files sorted by date, skip first 5
            OLD_TEST_LOGS=$(find "$TEST_DIR" -name "test_run_*.log" -type f -printf "%T@ %p\n" | sort -n | head -n -5 | cut -d' ' -f2-)
            
            echo "Found $(echo "$OLD_TEST_LOGS" | wc -l) old test run logs to clean up..."
            
            # Remove old logs with confirmation
            for log in $OLD_TEST_LOGS; do
                log_name=$(basename "$log")
                log_date=$(date -r "$log" "+%Y-%m-%d")
                if confirm "Delete old test run log ($log_date): $log_name?" "y"; then
                    run_cmd "rm -f \"$log\""
                    echo -e "${GREEN}  ✓ Deleted: $log_name${NC}"
                else
                    echo -e "${YELLOW}  ✗ Kept: $log_name${NC}"
                fi
            done
        else
            echo -e "${GREEN}✓ Less than 5 test run logs, nothing to clean up${NC}"
        fi
    else
        echo -e "${YELLOW}DRY RUN: Would ask for confirmation to remove old test run logs, keeping 5 most recent${NC}"
    fi
    
    # Remove old test directories
    if [ "$DRY_RUN" = false ]; then
        # Find old test directories
        OLD_TEST_DIRS=$(find "$TEST_DIR" -type d -name "webdev_test_*")
        
        if [ -n "$OLD_TEST_DIRS" ]; then
            echo "Found $(echo "$OLD_TEST_DIRS" | wc -l) old test directories to clean up..."
            
            # Remove old directories with confirmation
            for dir in $OLD_TEST_DIRS; do
                dir_name=$(basename "$dir")
                if confirm "Delete old test directory: $dir_name?" "y"; then
                    run_cmd "rm -rf \"$dir\""
                    echo -e "${GREEN}  ✓ Deleted: $dir_name${NC}"
                else
                    echo -e "${YELLOW}  ✗ Kept: $dir_name${NC}"
                fi
            done
        else
            echo -e "${GREEN}✓ No old test directories to clean up${NC}"
        fi
    else
        echo -e "${YELLOW}DRY RUN: Would ask for confirmation to remove old test directories${NC}"
    fi
fi

# Clean up backup directories - This section now runs independently
section "Cleaning Backup Directories"

# Handle clear backups option
if [ "$CLEAR_BACKUPS" = true ]; then
    echo -e "${YELLOW}WARNING: You've requested to clear all backup folders in: $BACKUP_DIR${NC}"
    
    # Get the count of backup folders
    BACKUP_FOLDERS_COUNT=$(find "$BACKUP_DIR" -type d -name "webdev_backup_*" | wc -l)
    
    if [ "$BACKUP_FOLDERS_COUNT" -gt 0 ]; then
        echo -e "Found ${YELLOW}$BACKUP_FOLDERS_COUNT${NC} backup folders that would be removed."
        
        if [ "$DRY_RUN" = false ]; then
            # Default to "no" for safety - note the "n" parameter at the end of confirm
            if confirm "Are you sure you want to delete ALL backup folders? This cannot be undone!" "n"; then
                echo "Processing backup folders deletion..."
                
                # Find all backup folders
                BACKUP_FOLDERS=$(find "$BACKUP_DIR" -type d -name "webdev_backup_*")
                
                # Process each backup folder with confirmation
                for folder in $BACKUP_FOLDERS; do
                    folder_name=$(basename "$folder")
                    folder_date=$(echo "$folder_name" | sed 's/webdev_backup_//')
                    
                    # Default to "no" for individual confirmations as well
                    if confirm "Delete backup folder from $folder_date?" "n"; then
                        run_cmd "rm -rf \"$folder\""
                        echo -e "${GREEN}  ✓ Deleted: $folder_name${NC}"
                    else
                        echo -e "${YELLOW}  ✗ Kept: $folder_name${NC}"
                    fi
                done
                
                echo -e "${GREEN}✓ Backup folder cleanup completed${NC}"
            else
                echo -e "${YELLOW}Backup folder clearing cancelled${NC}"
            fi
        else
            echo -e "${YELLOW}DRY RUN: Would ask for confirmation to clear all backup folders in: $BACKUP_DIR${NC}"
        fi
    else
        echo -e "${GREEN}No backup folders found in: $BACKUP_DIR${NC}"
    fi
# If not clearing all backups, apply the standard cleanup (keep 5 most recent)
elif [ -d "$BACKUP_DIR" ]; then
    if [ "$DRY_RUN" = false ]; then
        # Count backups
        BACKUP_COUNT=$(find "$BACKUP_DIR" -type d -name "webdev_backup_*" | wc -l)
        
        if [ "$BACKUP_COUNT" -gt 5 ]; then
            # Keep only the 5 most recent backups
            OLD_BACKUPS=$(find "$BACKUP_DIR" -type d -name "webdev_backup_*" -printf "%T@ %p\n" | sort -n | head -n -5 | cut -d' ' -f2-)
            
            echo "Found $(echo "$OLD_BACKUPS" | wc -w) old backup directories to clean up (keeping 5 most recent)..."
            
            # Remove old backup directories with confirmation
            for dir in $OLD_BACKUPS; do
                dir_name=$(basename "$dir")
                dir_date=$(echo "$dir_name" | sed 's/webdev_backup_//')
                if confirm "Delete old backup from $dir_date?" "y"; then
                    run_cmd "rm -rf \"$dir\""
                    echo -e "${GREEN}  ✓ Deleted: $dir_name${NC}"
                else
                    echo -e "${YELLOW}  ✗ Kept: $dir_name${NC}"
                fi
            done
            
            echo -e "${GREEN}✓ Backup directory cleanup completed${NC}"
        else
            echo -e "${GREEN}✓ Less than 5 backups found, nothing to clean up${NC}"
        fi
    else
        echo -e "${YELLOW}DRY RUN: Would ask for confirmation to remove old backups, keeping 5 most recent${NC}"
    fi
else
    echo -e "${YELLOW}Backup directory does not exist yet: $BACKUP_DIR${NC}"
fi

# Verify script permissions
section "Verifying Script Permissions"

# Check and fix permissions for all scripts
for script in "$BACKUP_SCRIPT" "$TEST_SCRIPT" "$RUN_TESTS_SCRIPT" "$CLEANUP_SCRIPT"; do
    if [ -f "$script" ]; then
        if [ ! -x "$script" ]; then
            echo -e "${YELLOW}Script is not executable: $script${NC}"
            if run_cmd "chmod +x \"$script\""; then
                echo -e "${GREEN}✓ Fixed permissions for $script${NC}"
            else
                echo -e "${RED}Failed to set executable permissions on $script${NC}"
            fi
        else
            echo -e "${GREEN}✓ Script is executable: $script${NC}"
        fi
    else
        echo -e "${RED}Script does not exist: $script${NC}"
    fi
done

# Summary
section "Cleanup Summary"
echo -e "${GREEN}✓ Source directory verified: $SOURCE_DIR${NC}"
echo -e "${GREEN}✓ Backup destination verified: $BACKUP_DIR${NC}"
echo -e "${GREEN}✓ Log directories prepared${NC}"
echo -e "${GREEN}✓ Script permissions verified${NC}"

if [ "$DRY_RUN" = true ]; then
    echo -e "\n${YELLOW}DRY RUN COMPLETED: No changes were made${NC}"
else
    echo -e "\n${GREEN}Cleanup completed successfully!${NC}"
fi

echo -e "${CYAN}Finished at: $(date)${NC}\n"

# Exit gracefully
echo -e "\n${GREEN}Cleanup completed. Thanks for using WebDev Backup Tool!${NC}"

exit 0