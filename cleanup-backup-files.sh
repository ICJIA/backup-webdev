#!/bin/bash
# cleanup-backup-files.sh - Organizes and cleans up text files in backup directory
# This script will organize structure files and other text files into subdirectories

# Source utility functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/utils.sh"

# Set up colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default backup directory
BACKUP_DIR="${BACKUP_DIR:-$DEFAULT_BACKUP_DIR}"

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--directory)
            BACKUP_DIR="$2"
            shift 2
            ;;
        --all)
            CLEAN_ALL=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -d, --directory DIR   Specify backup directory (default: $BACKUP_DIR)"
            echo "  --all                 Clean up all backup directories, not just the latest"
            echo "  --dry-run             Show what would be done without actually doing it"
            echo "  -h, --help            Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Check if backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    echo -e "${RED}Error: Backup directory does not exist: $BACKUP_DIR${NC}"
    exit 1
fi

# Function to organize files for a specific backup directory
organize_backup_dir() {
    local backup_dir="$1"
    local dry_run="$2"
    
    echo -e "${CYAN}Processing: $backup_dir${NC}"
    
    # Create a structures subdirectory
    local structures_dir="$backup_dir/structures"
    local logs_dir="$backup_dir/logs"
    
    if [ "$dry_run" = true ]; then
        echo "Would create: $structures_dir"
        echo "Would create: $logs_dir"
    else
        mkdir -p "$structures_dir"
        mkdir -p "$logs_dir"
    fi
    
    # Move structure files to structures directory
    echo -e "${YELLOW}Moving structure files...${NC}"
    find "$backup_dir" -maxdepth 1 -name "*_structure.txt" | while read -r file; do
        if [ "$dry_run" = true ]; then
            echo "Would move: $file -> $structures_dir/$(basename "$file")"
        else
            mv "$file" "$structures_dir/"
            echo -e "${GREEN}Moved: $(basename "$file")${NC}"
        fi
    done
    
    # Move log files to logs directory
    echo -e "${YELLOW}Moving log files...${NC}"
    find "$backup_dir" -maxdepth 1 -name "*.log" | while read -r file; do
        if [ "$dry_run" = true ]; then
            echo "Would move: $file -> $logs_dir/$(basename "$file")"
        else
            mv "$file" "$logs_dir/"
            echo -e "${GREEN}Moved: $(basename "$file")${NC}"
        fi
    done
    
    # Create a metadata.json file with info about structure files if it doesn't exist
    local metadata_file="$backup_dir/metadata.json"
    if [ ! -f "$metadata_file" ] || [ "$dry_run" = true ]; then
        echo -e "${YELLOW}Creating metadata file...${NC}"
        
        # Count number of projects
        local project_count=$(find "$backup_dir" -maxdepth 1 -name "*.tar.gz" | wc -l)
        
        # Get total size of backup
        local total_size=$(du -sb "$backup_dir" | cut -f1)
        
        # Get date from directory name if possible
        local date_str=$(basename "$backup_dir" | grep -o "[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}_[0-9]\{2\}-[0-9]\{2\}-[0-9]\{2\}" || date +"%Y-%m-%d_%H-%M-%S")
        
        if [ "$dry_run" = true ]; then
            echo "Would create metadata file: $metadata_file"
            echo "  - Projects: $project_count"
            echo "  - Total size: $(format_size "$total_size")"
            echo "  - Date: $date_str"
        else
            cat > "$metadata_file" << EOF
{
    "backup_date": "$date_str",
    "project_count": $project_count,
    "total_size_bytes": $total_size,
    "structure_files_location": "structures/",
    "log_files_location": "logs/",
    "organized_on": "$(date +"%Y-%m-%d %H:%M:%S")"
}
EOF
            echo -e "${GREEN}Created metadata file: $metadata_file${NC}"
        fi
    fi
    
    echo -e "${GREEN}Completed organizing: $backup_dir${NC}"
    echo ""
}

# Find backup directories
if [ "$CLEAN_ALL" = true ]; then
    # Process all backup directories
    echo -e "${CYAN}Processing all backup directories in: $BACKUP_DIR${NC}"
    find "$BACKUP_DIR" -maxdepth 1 -type d -name "wsl2_backup_*" | while read -r dir; do
        organize_backup_dir "$dir" "$DRY_RUN"
    done
else
    # Find and process only the latest backup directory
    latest_backup_dir=$(find "$BACKUP_DIR" -maxdepth 1 -type d -name "wsl2_backup_*" | sort -r | head -1)
    
    if [ -z "$latest_backup_dir" ]; then
        echo -e "${RED}Error: No backup directories found in $BACKUP_DIR${NC}"
        exit 1
    fi
    
    echo -e "${CYAN}Processing latest backup directory: $latest_backup_dir${NC}"
    organize_backup_dir "$latest_backup_dir" "$DRY_RUN"
fi

# Update the quick-backup.sh script to organize files automatically after backup
if [ "$DRY_RUN" != true ]; then
    echo -e "${CYAN}Checking quick-backup.sh to add automatic organization...${NC}"
    
    if ! grep -q "cleanup-backup-files.sh" "$SCRIPT_DIR/quick-backup.sh"; then
        echo -e "${YELLOW}Updating quick-backup.sh to automatically organize files after backup...${NC}"
        
        # Find where the backup summary is printed
        LINE_NUM=$(grep -n "Backup completed" "$SCRIPT_DIR/quick-backup.sh" | head -1 | cut -d: -f1)
        
        if [ -n "$LINE_NUM" ]; then
            # Insert the cleanup call before the backup summary
            TEMP_FILE=$(mktemp)
            head -n $((LINE_NUM-1)) "$SCRIPT_DIR/quick-backup.sh" > "$TEMP_FILE"
            echo -e "\n# Organize backup files" >> "$TEMP_FILE"
            echo "echo \"Organizing backup files...\"" >> "$TEMP_FILE"
            echo "\"$SCRIPT_DIR/cleanup-backup-files.sh\" --directory \"\$BACKUP_DIR\" > /dev/null" >> "$TEMP_FILE"
            echo "echo -e \"${GREEN}✓ Backup files organized${NC}\"" >> "$TEMP_FILE"
            echo "" >> "$TEMP_FILE"
            tail -n +$LINE_NUM "$SCRIPT_DIR/quick-backup.sh" >> "$TEMP_FILE"
            
            # Backup the original file
            cp "$SCRIPT_DIR/quick-backup.sh" "$SCRIPT_DIR/quick-backup.sh.bak"
            
            # Replace with the new file
            mv "$TEMP_FILE" "$SCRIPT_DIR/quick-backup.sh"
            chmod +x "$SCRIPT_DIR/quick-backup.sh"
            
            echo -e "${GREEN}Updated quick-backup.sh to automatically organize files${NC}"
        else
            echo -e "${YELLOW}Could not find appropriate location to update quick-backup.sh${NC}"
            echo -e "${YELLOW}Please add the following code to quick-backup.sh before the backup summary:${NC}"
            echo -e "# Organize backup files"
            echo -e "echo \"Organizing backup files...\""
            echo -e "\"$SCRIPT_DIR/cleanup-backup-files.sh\" --directory \"\$BACKUP_DIR\" > /dev/null"
            echo -e "echo -e \"${GREEN}✓ Backup files organized${NC}\""
        fi
    else
        echo -e "${GREEN}quick-backup.sh already includes file organization${NC}"
    fi
fi

echo -e "${GREEN}All operations completed successfully.${NC}"
exit 0