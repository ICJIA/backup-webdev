#!/bin/bash
# compare-backups.sh - Compare two backups to show differences
# Shows what files were added, changed, or deleted between backups

# Source the shared modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/ui.sh"

# Default values
BACKUP1=""
BACKUP2=""
PROJECT_NAME=""
OUTPUT_FORMAT="text"  # text, json, csv
SHOW_ONLY_CHANGES=false
SHOW_ONLY_ADDED=false
SHOW_ONLY_DELETED=false
VERBOSE=false

# Show help
show_help() {
    echo "Backup Comparison Tool"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --backup1 PATH      First backup directory to compare"
    echo "  --backup2 PATH      Second backup directory to compare (or 'latest' for most recent)"
    echo "  --project NAME      Compare specific project only"
    echo "  --format FORMAT     Output format: text, json, csv (default: text)"
    echo "  --only-changes      Show only changed files"
    echo "  --only-added        Show only added files"
    echo "  --only-deleted      Show only deleted files"
    echo "  --verbose           Show detailed information"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --backup1 /mnt/e/backups/wsl2_backup_2025-03-29_10-00-00 --backup2 latest"
    echo "  $0 --backup1 latest --backup2 /mnt/e/backups/wsl2_backup_2025-03-28_10-00-00 --project myproject"
    echo "  $0 --backup1 latest --backup2 latest --only-changes --format json"
    echo ""
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --backup1)
            if [[ -n "$2" && "$2" != --* ]]; then
                BACKUP1="$2"
                shift 2
            else
                echo -e "${RED}Error: --backup1 requires a path${NC}"
                exit 1
            fi
            ;;
        --backup2)
            if [[ -n "$2" && "$2" != --* ]]; then
                BACKUP2="$2"
                shift 2
            else
                echo -e "${RED}Error: --backup2 requires a path${NC}"
                exit 1
            fi
            ;;
        --project)
            if [[ -n "$2" && "$2" != --* ]]; then
                PROJECT_NAME="$2"
                shift 2
            else
                echo -e "${RED}Error: --project requires a project name${NC}"
                exit 1
            fi
            ;;
        --format)
            if [[ -n "$2" && "$2" =~ ^(text|json|csv)$ ]]; then
                OUTPUT_FORMAT="$2"
                shift 2
            else
                echo -e "${RED}Error: --format must be text, json, or csv${NC}"
                exit 1
            fi
            ;;
        --only-changes)
            SHOW_ONLY_CHANGES=true
            shift
            ;;
        --only-added)
            SHOW_ONLY_ADDED=true
            shift
            ;;
        --only-deleted)
            SHOW_ONLY_DELETED=true
            shift
            ;;
        --verbose)
            VERBOSE=true
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

# Find latest backup
find_latest_backup() {
    local backup_dir="${1:-$DEFAULT_BACKUP_DIR}"
    if [ ! -d "$backup_dir" ]; then
        return 1
    fi
    
    # Cross-platform find (supports both old wsl2_backup_* and new webdev_backup_* naming)
    if [ "$(uname -s)" = "Darwin" ]; then
        # macOS: Use find + stat instead of -printf
        find "$backup_dir" -maxdepth 1 -type d \( -name "webdev_backup_*" -o -name "wsl2_backup_*" \) -exec stat -f "%m %N" {} \; | \
    else
        # Linux: Use GNU find -printf
        find "$backup_dir" -maxdepth 1 -type d \( -name "webdev_backup_*" -o -name "wsl2_backup_*" \) -printf "%T@ %p\n" | \
    fi
        sort -nr | head -1 | cut -d' ' -f2-
}

# Resolve "latest" keyword
resolve_backup_path() {
    local backup_path="$1"
    
    if [ "$backup_path" = "latest" ]; then
        local latest=$(find_latest_backup)
        if [ -z "$latest" ]; then
            echo -e "${RED}Error: No backups found${NC}" >&2
            return 1
        fi
        echo "$latest"
    else
        echo "$backup_path"
    fi
}

# Validate backup directories
if [ -z "$BACKUP1" ] || [ -z "$BACKUP2" ]; then
    echo -e "${RED}Error: Both --backup1 and --backup2 are required${NC}"
    echo "Use --help for usage information"
    exit 1
fi

# Resolve backup paths
BACKUP1=$(resolve_backup_path "$BACKUP1")
BACKUP2=$(resolve_backup_path "$BACKUP2")

if [ ! -d "$BACKUP1" ]; then
    echo -e "${RED}Error: Backup 1 directory does not exist: $BACKUP1${NC}"
    exit 1
fi

if [ ! -d "$BACKUP2" ]; then
    echo -e "${RED}Error: Backup 2 directory does not exist: $BACKUP2${NC}"
    exit 1
fi

# Extract file list from backup archive
extract_file_list() {
    local backup_file="$1"
    local project_name="$2"
    
    if [ ! -f "$backup_file" ]; then
        return 1
    fi
    
    # List files in archive, excluding metadata
    tar -tzf "$backup_file" 2>/dev/null | grep -v "^\.$" | sort
}

# Compare two file lists
compare_file_lists() {
    local list1_file="$1"
    local list2_file="$2"
    
    # Find added files (in list2 but not in list1)
    local added=$(comm -13 "$list1_file" "$list2_file")
    
    # Find deleted files (in list1 but not in list2)
    local deleted=$(comm -23 "$list1_file" "$list2_file")
    
    # Find common files (in both)
    local common=$(comm -12 "$list1_file" "$list2_file")
    
    # For common files, check if they changed (compare checksums if available)
    local changed=""
    while IFS= read -r file; do
        # This is a simplified check - in a real implementation, you'd compare checksums
        # For now, we'll mark all common files as potentially changed
        # A full implementation would extract and compare file contents
        changed+="$file"$'\n'
    done <<< "$common"
    
    echo "$added" > /tmp/added_$$
    echo "$deleted" > /tmp/deleted_$$
    echo "$changed" > /tmp/changed_$$
}

# Main comparison logic
echo -e "${CYAN}===== Backup Comparison Tool =====${NC}"
echo -e "Backup 1: $BACKUP1"
echo -e "Backup 2: $BACKUP2"
echo ""

# Find project backups
if [ -n "$PROJECT_NAME" ]; then
    PROJECTS=("$PROJECT_NAME")
else
    # Find all projects in backup1
    PROJECTS=()
    for backup_file in "$BACKUP1"/*.tar.gz; do
        if [ -f "$backup_file" ]; then
            project=$(basename "$backup_file" | sed 's/_[0-9]\{4\}-.*\.tar\.gz$//')
            PROJECTS+=("$project")
        fi
    done
fi

if [ ${#PROJECTS[@]} -eq 0 ]; then
    echo -e "${RED}Error: No projects found in backup 1${NC}"
    exit 1
fi

# Compare each project
TOTAL_ADDED=0
TOTAL_DELETED=0
TOTAL_CHANGED=0

for project in "${PROJECTS[@]}"; do
    echo -e "${YELLOW}Comparing project: $project${NC}"
    
    # Find backup files
    backup1_file=$(find "$BACKUP1" -maxdepth 1 -type f -name "${project}_*.tar.gz" | head -1)
    backup2_file=$(find "$BACKUP2" -maxdepth 1 -type f -name "${project}_*.tar.gz" | head -1)
    
    if [ -z "$backup1_file" ]; then
        echo -e "  ${YELLOW}⚠ Project not found in backup 1${NC}"
        continue
    fi
    
    if [ -z "$backup2_file" ]; then
        echo -e "  ${YELLOW}⚠ Project not found in backup 2${NC}"
        continue
    fi
    
    # Extract file lists
    temp_dir=$(mktemp -d)
    list1_file="$temp_dir/list1.txt"
    list2_file="$temp_dir/list2.txt"
    
    extract_file_list "$backup1_file" "$project" > "$list1_file"
    extract_file_list "$backup2_file" "$project" > "$list2_file"
    
    # Compare
    added_count=$(comm -13 "$list1_file" "$list2_file" | wc -l)
    deleted_count=$(comm -23 "$list1_file" "$list2_file" | wc -l)
    common_count=$(comm -12 "$list1_file" "$list2_file" | wc -l)
    
    TOTAL_ADDED=$((TOTAL_ADDED + added_count))
    TOTAL_DELETED=$((TOTAL_DELETED + deleted_count))
    TOTAL_CHANGED=$((TOTAL_CHANGED + common_count))
    
    # Display results
    if [ "$OUTPUT_FORMAT" = "text" ]; then
        echo -e "  ${GREEN}✓ Added: $added_count files${NC}"
        echo -e "  ${RED}✗ Deleted: $deleted_count files${NC}"
        echo -e "  ${YELLOW}~ Common: $common_count files${NC}"
        
        if [ "$VERBOSE" = true ]; then
            if [ "$added_count" -gt 0 ] && ([ "$SHOW_ONLY_ADDED" = true ] || [ "$SHOW_ONLY_CHANGES" = false ]); then
                echo -e "  ${CYAN}Added files:${NC}"
                comm -13 "$list1_file" "$list2_file" | head -20 | sed 's/^/    + /'
                if [ "$added_count" -gt 20 ]; then
                    echo -e "    ... and $((added_count - 20)) more"
                fi
            fi
            
            if [ "$deleted_count" -gt 0 ] && ([ "$SHOW_ONLY_DELETED" = true ] || [ "$SHOW_ONLY_CHANGES" = false ]); then
                echo -e "  ${CYAN}Deleted files:${NC}"
                comm -23 "$list1_file" "$list2_file" | head -20 | sed 's/^/    - /'
                if [ "$deleted_count" -gt 20 ]; then
                    echo -e "    ... and $((deleted_count - 20)) more"
                fi
            fi
        fi
    elif [ "$OUTPUT_FORMAT" = "json" ]; then
        echo "{"
        echo "  \"project\": \"$project\","
        echo "  \"backup1\": \"$(basename "$BACKUP1")\","
        echo "  \"backup2\": \"$(basename "$BACKUP2")\","
        echo "  \"added\": $added_count,"
        echo "  \"deleted\": $deleted_count,"
        echo "  \"common\": $common_count"
        echo "}"
    elif [ "$OUTPUT_FORMAT" = "csv" ]; then
        echo "project,backup1,backup2,added,deleted,common"
        echo "$project,$(basename "$BACKUP1"),$(basename "$BACKUP2"),$added_count,$deleted_count,$common_count"
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
done

# Summary
if [ "$OUTPUT_FORMAT" = "text" ]; then
    echo ""
    echo -e "${CYAN}===== Summary =====${NC}"
    echo -e "Total added: ${GREEN}$TOTAL_ADDED${NC} files"
    echo -e "Total deleted: ${RED}$TOTAL_DELETED${NC} files"
    echo -e "Total common: ${YELLOW}$TOTAL_CHANGED${NC} files"
fi

exit 0

