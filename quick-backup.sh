#!/bin/bash
# quick-backup.sh - A simplified standalone script for quick backups
# Created to resolve freezing issues with the main backup script

# Set up basic variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/utils.sh"

# Define colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Set default paths
BACKUP_DIR="${DEFAULT_BACKUP_DIR:-$SCRIPT_DIR/backups}"
SOURCE_DIRS=("${DEFAULT_SOURCE_DIRS[@]}")
DATE=$(date '+%Y-%m-%d_%H-%M-%S')
BACKUP_NAME="webdev_backup_$DATE"
FULL_BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"

echo -e "${CYAN}===== WebDev Quick Backup =====${NC}"
echo -e "${YELLOW}Starting quick backup at $(date)${NC}"

# Create backup directory
echo "Creating backup directory: $FULL_BACKUP_PATH"
mkdir -p "$FULL_BACKUP_PATH"
if [ ! -d "$FULL_BACKUP_PATH" ]; then
    echo -e "${RED}ERROR: Failed to create backup directory!${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Created backup directory${NC}"

# Create a log file
LOG_FILE="$FULL_BACKUP_PATH/backup_log.log"
touch "$LOG_FILE"
echo "$(date): Starting quick backup" >> "$LOG_FILE"

# Function to find projects quickly
find_projects_quick() {
    local dir="$1"
    echo "Searching for projects in: $dir" | tee -a "$LOG_FILE"
    
    # Set a strict timeout to prevent hanging
    timeout 10s find "$dir" -maxdepth 1 -mindepth 1 -type d \
        -not -path "*/\.*" \
        -not -path "*/node_modules*" 2>/dev/null | sort
}

# Find all projects in source directories
echo "Finding projects in source directories..."
projects=()
for dir in "${SOURCE_DIRS[@]}"; do
    echo "Checking directory: $dir"
    
    # Skip if directory doesn't exist
    if [ ! -d "$dir" ]; then
        echo -e "${YELLOW}Warning: Directory does not exist: $dir${NC}" | tee -a "$LOG_FILE"
        continue
    fi
    
    # Find projects
    echo "Finding projects in $dir..." | tee -a "$LOG_FILE"
    dir_project_output=$(find_projects_quick "$dir")
    
    if [ -n "$dir_project_output" ]; then
        while IFS= read -r project_path; do
            echo "Found project: $project_path" | tee -a "$LOG_FILE"
            projects+=("$project_path")
        done <<< "$dir_project_output"
    else
        echo -e "${YELLOW}No projects found in $dir${NC}" | tee -a "$LOG_FILE"
    fi
done

# Check if we found any projects
total_projects=${#projects[@]}
echo "Total projects found: $total_projects" | tee -a "$LOG_FILE"

if [ $total_projects -eq 0 ]; then
    echo -e "${RED}ERROR: No projects found to backup!${NC}" | tee -a "$LOG_FILE"
    echo "Please check your source directories:"
    for dir in "${SOURCE_DIRS[@]}"; do
        echo "  - $dir"
    done
    exit 1
fi

# Display projects that will be backed up
echo -e "${CYAN}The following projects will be backed up:${NC}"
for ((i=0; i<${#projects[@]}; i++)); do
    project_name=$(basename "${projects[$i]}")
    echo "  ($((i+1))/$total_projects) $project_name"
done

# Start backup process
echo -e "\n${CYAN}Starting backup process...${NC}"
echo "Backup location: $FULL_BACKUP_PATH"
echo "Started at: $(date)" | tee -a "$LOG_FILE"

# Print a header for the progress display
echo -e "\n${YELLOW}Project backup progress:${NC}"
echo -e "----------------------------------------------"

# Create a stats file
STATS_FILE="$FULL_BACKUP_PATH/backup_stats.txt"
touch "$STATS_FILE"
# First line should be a comment/header to match the expected format
echo "project,full_project_path,src_size,archive_size,ratio,structure_file" > "$STATS_FILE"

# Track successes and failures
successful=0
failed=0
total_src_size=0
total_backup_size=0

# Backup each project
for project_path in "${projects[@]}"; do
    project_name=$(basename "$project_path")
    echo -e "\n${CYAN}Backing up project: $project_name${NC}" | tee -a "$LOG_FILE"
    
    # Create backup file path
    backup_file="$FULL_BACKUP_PATH/${project_name}_${DATE}.tar.gz"
    
    # Get source size (excluding node_modules) - with a timeout
    src_dir=$(dirname "$project_path")
    echo "Calculating size of $project_name..." | tee -a "$LOG_FILE"
    project_size=$(timeout 10s du -sb --exclude="node_modules" "$project_path" 2>/dev/null | cut -f1)
    
    # If size calculation times out or fails, use a default value
    if [ -z "$project_size" ]; then
        echo "Size calculation timed out, using estimate" | tee -a "$LOG_FILE"
        project_size=1000000  # Default size of 1MB
    fi
    
    formatted_size=$(numfmt --to=iec-i --suffix=B --format="%.1f" $project_size 2>/dev/null || echo "$project_size bytes")
    total_src_size=$((total_src_size + project_size))
    
    echo "Project size: $formatted_size" | tee -a "$LOG_FILE"
    echo "Creating backup: $backup_file" | tee -a "$LOG_FILE"
    
    # Add visual progress indicator
    echo -n "Compressing: " | tee -a "$LOG_FILE"
    
    # Special handling for projects with the same name as their parent directory
    # This fixes the issue with "webdev" and "inform6" projects
    project_basename=$(basename "$project_path")
    dir_basename=$(basename "$src_dir")
    
    if [ "$project_basename" = "$dir_basename" ]; then
        echo "Special handling for $project_basename (same name as parent dir)" | tee -a "$LOG_FILE"
        
        # Create a temporary directory
        tmp_dir=$(mktemp -d)
        
        # Run tar with timeout and show progress - using parent directory approach
        (
            # Special approach: First copy to temp dir, then tar from there
            echo -n "Copying... " | tee -a "$LOG_FILE"
            
            # Copy project to temp dir (excluding node_modules)
            timeout 60s rsync -a --exclude="node_modules" "$project_path/" "$tmp_dir/" 2>> "$LOG_FILE"
            
            if [ $? -eq 0 ]; then
                echo -n "Compressing... " | tee -a "$LOG_FILE"
                # Create tar archive from temp dir
                timeout 300s tar -czf "$backup_file" -C "$tmp_dir" . 2>> "$LOG_FILE" &
                
                # Get PID of tar process
                tar_pid=$!
                
                # Show activity while tar is running
                c=0
                spin='-\|/'
                while kill -0 $tar_pid 2>/dev/null; do
                    echo -ne "\b${spin:c++%4:1}"
                    sleep 0.5
                done
                
                # Wait for tar to finish
                wait $tar_pid
                tar_status=$?
                
                # Clean up temp dir
                rm -rf "$tmp_dir"
                
                # Return the status
                exit $tar_status
            else
                echo "Failed to copy project" | tee -a "$LOG_FILE"
                rm -rf "$tmp_dir"
                exit 1
            fi
        )
    else
        # Run tar with timeout and show progress - normal case
        (
            # Create tar archive, excluding node_modules
            timeout 300s tar -czf "$backup_file" --exclude="*/node_modules/*" -C "$src_dir" "$project_basename" 2>> "$LOG_FILE" &
            
            # Get PID of tar process
            tar_pid=$!
            
            # Show activity while tar is running
            c=0
            spin='-\|/'
            while kill -0 $tar_pid 2>/dev/null; do
                echo -ne "\b${spin:c++%4:1}"
                sleep 0.5
            done
            
            # Wait for tar to finish
            wait $tar_pid
            tar_status=$?
            
            # Return the status
            exit $tar_status
        )
    fi
    
    # Check tar result
    if [ $? -eq 0 ]; then
        # Get archive size
        archive_size=$(du -sb "$backup_file" 2>/dev/null | cut -f1)
        formatted_archive_size=$(numfmt --to=iec-i --suffix=B --format="%.1f" $archive_size 2>/dev/null || echo "$archive_size bytes")
        total_backup_size=$((total_backup_size + archive_size))
        
        # Calculate compression ratio safely
        if [ "$archive_size" -gt 0 ] && [ "$project_size" -gt 0 ]; then
            ratio=$(awk "BEGIN {printf \"%.1f\", ($project_size/$archive_size)}")
        else
            ratio="1.0"
        fi
        
        echo -e "${GREEN}✓ Successfully backed up $project_name (Compressed: $formatted_archive_size, Ratio: ${ratio}x)${NC}" | tee -a "$LOG_FILE"
        
        # Add to stats - ensure all fields are present and valid
        # Make sure numeric values are actual numbers for the report generator
        if ! [[ "$project_size" =~ ^[0-9]+$ ]]; then
            project_size=0
        fi
        
        if ! [[ "$archive_size" =~ ^[0-9]+$ ]]; then
            archive_size=0
        fi
        
        if ! [[ "$ratio" =~ ^[0-9]*\.?[0-9]+$ ]]; then
            ratio="1.0"
        fi
        
        echo "$project_name,$project_path,$project_size,$archive_size,$ratio,$structure_file" >> "$STATS_FILE"
        
        # Generate focused file structure for the project - only for smaller projects
        # Skip structure generation for large projects
        if [ "$project_size" -lt 100000000 ]; then  # Skip for projects larger than 100MB
            echo "Generating file structure..." | tee -a "$LOG_FILE"
            structure_file="$FULL_BACKUP_PATH/${project_name}_structure.txt"
            echo "Structure of $project_name ($project_path):" > "$structure_file"
            echo "----------------------------------------" >> "$structure_file"
            
            # Create a nicely formatted directory structure that:
            # - Excludes node_modules, .git, and other non-essential directories
            # - Focuses on code files and project structure
            # - Limits depth to keep it manageable
            # - Uses a tree-like display format for readability
            
            {
                echo "Project root: $project_name/"
                # Create directory structure tree with find, filtering out noise
                timeout 5s find "$project_path" -type d -maxdepth 3 \
                    -not -path "*/node_modules*" \
                    -not -path "*/\.*" \
                    -not -path "*/dist*" \
                    -not -path "*/build*" \
                    -not -path "*/coverage*" \
                    -not -path "*/tmp*" \
                    -not -path "*/temp*" \
                    -not -path "*/logs*" \
                    -not -path "*/public/vendor*" \
                    -not -path "*/vendor*" \
                    -not -path "*/cache*" 2>/dev/null | sort | while read -r dir; do
                    if [ "$dir" = "$project_path" ]; then 
                        continue; # Skip the root project directory
                    fi
                    
                    # Get the relative path and calculate depth
                    rel_path="${dir#$project_path/}"
                    depth=$(echo "$rel_path" | tr -cd '/' | wc -c)
                    indent=""
                    
                    # Create nice indentation
                    for ((i=0; i<depth; i++)); do
                        indent="$indent  "
                    done
                    
                    # Print directory with trailing slash
                    echo "$indent├── $(basename "$dir")/"
                done
                
                # List key files in root directory to give flavor of the project
                echo -e "\nKey files in root:"
                timeout 3s find "$project_path" -maxdepth 1 -type f \
                    -not -path "*/\.*" \
                    -name "*.json" -o -name "*.js" -o -name "*.html" -o -name "*.py" \
                    -o -name "*.md" -o -name "Makefile" -o -name "Dockerfile" \
                    -o -name "README*" -o -name "package.json" -o -name "composer.json" \
                    -o -name "*.toml" -o -name "*.yaml" -o -name "*.yml" \
                    -o -name "*.tsx" -o -name "*.ts" 2>/dev/null | sort | while read -r file; do
                    echo "  ├── $(basename "$file")"
                done
                
                echo -e "\nStructure is simplified for clarity (some files/dirs omitted)"
            } >> "$structure_file"
            
            if [ $? -ne 0 ]; then
                echo "Structure generation timed out, creating minimal structure" | tee -a "$LOG_FILE"
                echo "Project is too large for detailed structure" >> "$structure_file"
            fi
        else
            echo "Skipping detailed structure generation for large project" | tee -a "$LOG_FILE"
            structure_file="$FULL_BACKUP_PATH/${project_name}_structure.txt"
            echo "Structure of $project_name ($project_path):" > "$structure_file"
            echo "----------------------------------------" >> "$structure_file"
            
            # For large projects, just show top-level directories
            {
                echo "Project root: $project_name/"
                echo "Top-level directories:"
                timeout 3s find "$project_path" -maxdepth 1 -type d \
                    -not -path "$project_path" \
                    -not -path "*/node_modules*" \
                    -not -path "*/\.*" \
                    -not -path "*/dist*" \
                    -not -path "*/build*" 2>/dev/null | sort | while read -r dir; do
                    echo "  ├── $(basename "$dir")/"
                done
                
                echo -e "\nKey files in root:"
                timeout 2s find "$project_path" -maxdepth 1 -type f \
                    -not -path "*/\.*" \
                    -name "*.json" -o -name "README*" -o -name "Makefile" \
                    -o -name "package.json" -o -name "composer.json" 2>/dev/null | sort | while read -r file; do
                    echo "  ├── $(basename "$file")"
                done
                
                echo -e "\nNote: This is a simplified structure for a large project"
            } >> "$structure_file"
        fi
        
        successful=$((successful + 1))
    else
        echo -e "${RED}✗ Failed to backup $project_name${NC}" | tee -a "$LOG_FILE"
        failed=$((failed + 1))
    fi
    
    # Give a progress update
    percent=$((100 * (successful + failed) / total_projects))
    bar_size=30
    completed_size=$((bar_size * (successful + failed) / total_projects))
    bar="["
    for ((i=0; i<bar_size; i++)); do
        if [ $i -lt $completed_size ]; then
            bar+="="
        else
            bar+=" "
        fi
    done
    bar+="]"
    
    echo -ne "\r${CYAN}Progress: $bar $percent% ($successful/$total_projects complete, $failed failed)${NC}"
done

# Make sure we move to a new line after the progress bar
echo

# Backup completed
echo -e "\n${CYAN}===== Backup Summary =====${NC}"
echo "Total projects backed up: $successful"
echo "Failed backups: $failed"
echo "Total source size: $(numfmt --to=iec-i --suffix=B --format="%.1f" $total_src_size 2>/dev/null || echo "$total_src_size bytes")"
echo "Total backup size: $(numfmt --to=iec-i --suffix=B --format="%.1f" $total_backup_size 2>/dev/null || echo "$total_backup_size bytes")"

if [ $successful -gt 0 ] && [ $total_backup_size -gt 0 ] && [ $total_src_size -gt 0 ]; then
    overall_ratio=$(awk "BEGIN {printf \"%.1f\", ($total_src_size/$total_backup_size)}")
    echo "Overall compression ratio: ${overall_ratio}x"
fi

echo "Backup location: $FULL_BACKUP_PATH"
echo "Finished at: $(date)"

# Add completion message to log
echo "$(date): Backup completed. $successful successful, $failed failed" >> "$LOG_FILE"

# Display final message
if [ $failed -eq 0 ]; then
    echo -e "\n${GREEN}Backup completed successfully!${NC}"
else
    echo -e "\n${YELLOW}Backup completed with $failed failures.${NC}"
    echo "Check the log file for details: $LOG_FILE"
fi

# Exit with appropriate status code
if [ $failed -eq 0 ]; then
    exit 0
else
    exit 1
fi