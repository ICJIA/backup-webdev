#!/bin/bash
# dirs-status.sh - Report on backup source directories

# Source the shared modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../core/config.sh"
source "$SCRIPT_DIR/../utils/utils.sh"

# Header
echo -e "${CYAN}===== WebDev Backup Tool - Source Directories Report =====${NC}"
echo "Generated: $(date)"
echo

# Check all directories
echo -e "${YELLOW}Source Directories:${NC}"
echo

if [ ${#DEFAULT_SOURCE_DIRS[@]} -eq 0 ]; then
    echo -e "${RED}No source directories configured!${NC}"
    exit 1
fi

# Total counts
TOTAL_PROJECTS=0
TOTAL_SIZE=0
VALID_DIRS=0
INVALID_DIRS=0

# Track project counts per directory
declare -A PROJECT_COUNTS

# Process each directory
for ((i=0; i<${#DEFAULT_SOURCE_DIRS[@]}; i++)); do
    DIR="${DEFAULT_SOURCE_DIRS[$i]}"
    DIR_NAME=$(basename "$DIR")
    
    echo -e "${GREEN}[$i] $DIR${NC}"
    
    # Check if directory exists and is readable
    if [ -d "$DIR" ] && [ -r "$DIR" ]; then
        # Find all projects (subdirs)
        readarray -t PROJECTS < <(find "$DIR" -maxdepth 1 -mindepth 1 -type d -not -path "*/\.*" | sort)
        PROJECT_COUNT=${#PROJECTS[@]}
        PROJECT_COUNTS["$DIR_NAME"]=$PROJECT_COUNT
        
        TOTAL_PROJECTS=$((TOTAL_PROJECTS + PROJECT_COUNT))
        VALID_DIRS=$((VALID_DIRS + 1))
        
        echo "  Status: ${GREEN}✓ Valid${NC}"
        echo "  Projects found: $PROJECT_COUNT"
        
        # If projects found, calculate total size (excluding node_modules)
        if [ $PROJECT_COUNT -gt 0 ]; then
            DIR_SIZE=0
            echo "  Projects:"
            
            for PROJECT in "${PROJECTS[@]}"; do
                PROJECT_NAME=$(basename "$PROJECT")
                PROJECT_SIZE=$(get_directory_size "$PROJECT" "node_modules")
                DIR_SIZE=$((DIR_SIZE + PROJECT_SIZE))
                TOTAL_SIZE=$((TOTAL_SIZE + PROJECT_SIZE))
                
                FORMATTED_SIZE=$(format_size "$PROJECT_SIZE")
                echo "    - $PROJECT_NAME ($FORMATTED_SIZE)"
            done
            
            FORMATTED_DIR_SIZE=$(format_size "$DIR_SIZE")
            echo "  Total directory size (excluding node_modules): $FORMATTED_DIR_SIZE"
        else
            echo "  ${YELLOW}No projects found in this directory${NC}"
        fi
    else
        INVALID_DIRS=$((INVALID_DIRS + 1))
        echo "  Status: ${RED}✗ Invalid - Directory does not exist or is not readable${NC}"
    fi
    
    echo
done

# Summary
echo -e "${CYAN}===== Summary =====${NC}"
echo "Valid directories: $VALID_DIRS"
echo "Invalid directories: $INVALID_DIRS"
echo "Total projects found: $TOTAL_PROJECTS"
echo "Total size (excluding node_modules): $(format_size "$TOTAL_SIZE")"

echo
echo -e "${CYAN}Projects by directory:${NC}"
for DIR_NAME in "${!PROJECT_COUNTS[@]}"; do
    echo "  $DIR_NAME: ${PROJECT_COUNTS[$DIR_NAME]} projects"
done

exit 0
