#!/bin/bash
# Quick debug script to understand why backup isn't proceeding

echo "Starting debug script..."

# Source the shared modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/utils.sh"  # Contains check_required_tools and other utility functions
source "$SCRIPT_DIR/fs.sh"  # Contains find_projects and file operations

# Check relevant directories
echo "Checking directories:"
echo "SCRIPT_DIR: $SCRIPT_DIR"
echo "BACKUP_DIR: ${BACKUP_DIR:-$DEFAULT_BACKUP_DIR}"
echo "SOURCE_DIRS: ${DEFAULT_SOURCE_DIRS[*]}"

# Check if source directories exist
echo "Checking source directories..."
for dir in "${DEFAULT_SOURCE_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "✓ Directory exists: $dir"
        PROJECT_COUNT=$(find "$dir" -maxdepth 1 -type d | wc -l)
        PROJECT_COUNT=$((PROJECT_COUNT - 1)) # Subtract 1 for the directory itself
        echo "  - Contains $PROJECT_COUNT subdirectories"
    else
        echo "✗ Directory MISSING: $dir"
    fi
done

# Check if backup directory exists
BACKUP_DIR="${BACKUP_DIR:-$DEFAULT_BACKUP_DIR}"
if [ -d "$BACKUP_DIR" ]; then
    echo "✓ Backup directory exists: $BACKUP_DIR"
    # Check if it's writable
    if [ -w "$BACKUP_DIR" ]; then
        echo "✓ Backup directory is writable"
    else
        echo "✗ Backup directory is NOT writable"
    fi
else
    echo "✗ Backup directory MISSING: $BACKUP_DIR"
    echo "Trying to create it..."
    if mkdir -p "$BACKUP_DIR"; then
        echo "✓ Successfully created backup directory"
    else
        echo "✗ Failed to create backup directory"
    fi
fi

# Test the find_projects function
echo "Testing project discovery..."
projects=()
for dir in "${DEFAULT_SOURCE_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "Searching for projects in: $dir"
        project_list=$(find_projects "$dir" 1)
        if [ -n "$project_list" ]; then
            echo "Found projects:"
            echo "$project_list" | while read -r project; do
                echo "  - $project"
            done
            dir_projects=()
            while IFS= read -r project; do
                [ -n "$project" ] && dir_projects+=("$project")
            done < <(echo "$project_list")
            projects+=("${dir_projects[@]}")
        else
            echo "No projects found in $dir"
        fi
    fi
done

echo "Total projects found: ${#projects[@]}"

# Test basic tar command
echo "Testing tar command..."
which tar
tar --version | head -1

# Testing backup creation for a small test directory
echo "Creating test directory..."
TEST_DIR="$SCRIPT_DIR/test_backup_dir"
mkdir -p "$TEST_DIR/testproject"
echo "This is a test file" > "$TEST_DIR/testproject/test.txt"

echo "Testing backup creation..."
TEST_BACKUP_FILE="$BACKUP_DIR/test_backup.tar.gz"
if tar -czf "$TEST_BACKUP_FILE" -C "$TEST_DIR" "testproject"; then
    echo "✓ Backup test successful: $TEST_BACKUP_FILE"
    ls -la "$TEST_BACKUP_FILE"
else
    echo "✗ Backup test failed"
fi

# Cleanup
rm -rf "$TEST_DIR"
rm -f "$TEST_BACKUP_FILE"

echo "Debug complete."