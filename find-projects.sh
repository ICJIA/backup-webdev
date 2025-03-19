#!/bin/bash
# find-projects.sh - Script to find valid projects in source directories

# Source the shared modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../core/config.sh"
source "$SCRIPT_DIR/../utils/utils.sh"

# Terminal colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Print header
echo -e "${CYAN}===== WebDev Backup Tool - Project Finder =====${NC}"
echo -e "${CYAN}Started at: $(date)${NC}\n"

# Check for custom source directory
if [ $# -gt 0 ]; then
    SOURCE_DIRS=("$1")
    echo -e "${YELLOW}Using custom source directory: $1${NC}"
else
    SOURCE_DIRS=("${DEFAULT_SOURCE_DIRS[@]}")
    echo -e "${GREEN}Using default source directories (${#SOURCE_DIRS[@]})${NC}"
fi

# Display each source directory and its projects
for dir in "${SOURCE_DIRS[@]}"; do
    # Verify source directory exists
    if [ ! -d "$dir" ]; then
        echo -e "${RED}ERROR: Source directory does not exist: $dir${NC}"
        continue
    fi

    # Check if source directory is readable
    if [ ! -r "$dir" ]; then
        echo -e "${RED}ERROR: Source directory is not readable: $dir${NC}"
        continue
    fi

    # Get directory name for display
    dir_name=$(basename "$dir")
    echo -e "\n${CYAN}=== Directory: $dir (${dir_name}) ===${NC}"

    # Find projects in this directory
    mapfile -t projects < <(find "$dir" -maxdepth 1 -mindepth 1 -type d -not -path "*/\.*" | sort)

    # Display projects
    if [ ${#projects[@]} -gt 0 ]; then
        echo -e "${GREEN}Found ${#projects[@]} projects:${NC}"
        for ((i=0; i<${#projects[@]}; i++)); do
            project_name=$(basename "${projects[$i]}")
            
            # Get project size excluding node_modules
            size=$(get_directory_size "${projects[$i]}" "node_modules")
            formatted_size=$(format_size "$size")
            
            # Count files in project
            file_count=$(find "${projects[$i]}" -type f -not -path "*/node_modules/*" -not -path "*/\.*" | wc -l)
            
            # Check for common project files
            has_git=$([ -d "${projects[$i]}/.git" ] && echo "✓" || echo "✗")
            has_package=$([ -f "${projects[$i]}/package.json" ] && echo "✓" || echo "✗")
            has_readme=$(find "${projects[$i]}" -maxdepth 1 -name "README*" | wc -l)
            has_readme=$([ "$has_readme" -gt 0 ] && echo "✓" || echo "✗")
            
            echo -e "[$i] ${GREEN}${project_name}${NC}"
            echo -e "    Size: ${formatted_size}, Files: ${file_count}"
            echo -e "    Git: ${has_git}, Package.json: ${has_package}, README: ${has_readme}"
        done
    else
        echo -e "${YELLOW}No projects found in $dir${NC}"
    fi
done

echo -e "\n${CYAN}===== Summary =====${NC}"
echo "Total directories scanned: ${#SOURCE_DIRS[@]}"

# Calculate total projects across all directories
total_projects=0
for dir in "${SOURCE_DIRS[@]}"; do
    if [ -d "$dir" ] && [ -r "$dir" ]; then
        dir_projects=$(find "$dir" -maxdepth 1 -mindepth 1 -type d -not -path "*/\.*" | wc -l)
        total_projects=$((total_projects + dir_projects))
    fi
done

echo "Total projects found: $total_projects"
echo -e "${CYAN}Finished at: $(date)${NC}\n"

exit 0
