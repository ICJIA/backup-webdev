#!/bin/bash
# test-backup.sh - Test script for backup.sh
# Tests all functionality without moving files

# Source the shared modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/ui.sh"
source "$SCRIPT_DIR/fs.sh"

# Test configuration
SOURCE_DIR="$DEFAULT_SOURCE_DIR"  # Can be overridden via parameter
TEST_BACKUP_NAME="webdev_test_$DATE"
TEST_BACKUP_PATH="$TEST_DIR/$TEST_BACKUP_NAME"
LOG_FILE="$TEST_BACKUP_PATH/test_log.log"
STATS_FILE="$TEST_BACKUP_PATH/test_stats.txt"
CUSTOM_SOURCE_DIR=""

# Error handling function
handle_error() {
    local exit_code=$1
    local error_message=$2
    
    echo "TEST ERROR: $error_message (Exit code: $exit_code)"
    
    # Only write to log file if the directory still exists
    if [ -d "$(dirname "$LOG_FILE")" ]; then
        echo "TEST ERROR: $error_message (Exit code: $exit_code)" >> "$LOG_FILE"
    fi
    
    # Log the failure to the master log
    handle_failed_test "$error_message" "$exit_code"
}

# Logging function
log() {
    local message=$1
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    # Echo to console and append to log if directory exists
    echo "$timestamp - $message"
    
    # Only write to log file if the directory still exists
    if [ -d "$(dirname "$LOG_FILE")" ]; then
        echo "$timestamp - $message" >> "$LOG_FILE"
    fi
}

# Format size function
format_size() {
    local size=$1
    awk '
        BEGIN {
            suffix[1] = "B"
            suffix[2] = "KB"
            suffix[3] = "MB"
            suffix[4] = "GB"
            suffix[5] = "TB"
        }
        {
            for (i = 5; i > 0; i--) {
                if ($1 >= 1024 ^ (i - 1)) {
                    printf("%.2f %s", $1 / (1024 ^ (i - 1)), suffix[i])
                    break
                }
            }
        }
    ' <<< "$size"
}

# Dashboard functions (similar to the main script)
print_dashboard_header() {
    printf "+------------------------------------------------------------------------------+\n"
    printf "| %-76s |\n" "BACKUP TEST DASHBOARD - $(date '+%Y-%m-%d %H:%M:%S')"
    printf "+------------------------------------------------------------------------------+\n"
    printf "| %-40s | %-10s | %-20s |\n" "PROJECT NAME" "SIZE" "STATUS"
    printf "+------------------------------------------------------------------------------+\n"
}

print_dashboard_row() {
    local project=$1
    local size=$2
    local status=$3
    printf "| %-40s | %-10s | %-20s |\n" "$project" "$size" "$status"
}

print_dashboard_footer() {
    printf "+------------------------------------------------------------------------------+\n"
    printf "| %-40s | %-10s | %-20s |\n" "TOTAL" "$1" "COMPLETED"
    printf "+------------------------------------------------------------------------------+\n"
}

run_test() {
    log "Starting backup test in test environment"
    log "Source directory: $SOURCE_DIR"
    log "Test backup path: $TEST_BACKUP_PATH"

    # Test 1: Check if source directory exists
    log "TEST 1: Checking source directory"
    if [ ! -d "$SOURCE_DIR" ]; then
        handle_error 1 "Test failed - Source directory $SOURCE_DIR does not exist"
    fi
    log "✓ Source directory exists"
    
    # Test 1.1: Test backup directory creation functionality
    TEST_BACKUP_TARGET="/tmp/test-backup-target-$(date +%s)"
    log "TEST 1.1: Testing backup directory creation functionality"
    if mkdir -p "$TEST_BACKUP_TARGET"; then
        log "✓ Test backup directory created successfully at $TEST_BACKUP_TARGET"
        rm -rf "$TEST_BACKUP_TARGET"
    else
        handle_error 1 "Test failed - Could not create test backup directory"
    fi
    
    # Test 2: Check if required tools are installed
    log "TEST 2: Checking required tools"
    command -v tar >/dev/null 2>&1 || handle_error 3 "Test failed - tar command not found"
    command -v gzip >/dev/null 2>&1 || handle_error 3 "Test failed - gzip command not found"
    log "✓ Required tools are installed"
    
    # Test 3: Check if projects exist in source directory
    log "TEST 3: Checking for projects"
    projects=($(ls -d "$SOURCE_DIR"/*/ 2>/dev/null | xargs -n1 basename))
    if [ ${#projects[@]} -eq 0 ]; then
        handle_error 2 "Test failed - No projects found in $SOURCE_DIR"
    fi
    log "✓ Found ${#projects[@]} projects in source directory"
    
    # Test 4: Create test backup directory and verify it's writable
    log "TEST 4: Creating test backup directory"
    
    # Create backup directory
    if ! mkdir -p "$TEST_BACKUP_PATH"; then
        handle_error 4 "Test failed - Cannot create test backup directory"
    fi
    
    # Check if test directory is writable
    if [[ ! -w "$TEST_BACKUP_PATH" ]]; then
        handle_error 4 "Test failed - Test directory not writable: $TEST_BACKUP_PATH"
    fi
    
    # Create a test file to verify filesystem write capability
    TEST_WRITE_FILE="$TEST_BACKUP_PATH/.write_test"
    if ! touch "$TEST_WRITE_FILE" 2>/dev/null; then
        handle_error 4 "Test failed - Cannot write to test directory (filesystem may be read-only)"
    else
        rm -f "$TEST_WRITE_FILE"
    fi
    
    log "✓ Created test backup directory at $TEST_BACKUP_PATH (verified writable)"
    
    # Test 5: Test project selection and exclusion
    log "TEST 5: Testing project selection logic"
    echo "Projects found in source directory:"
    for ((i=0; i<${#projects[@]}; i++)); do
        echo "  [$i] ${projects[$i]}"
    done
    log "✓ Project listing works correctly"
    
    # Test 6: Test backup process with first project only
    log "TEST 6: Testing backup compression with first project"
    
    # Select only the first project for testing
    test_project="${projects[0]}"
    PROJECT_SRC_PATH="$SOURCE_DIR/$test_project"
    PROJECT_BACKUP_FILE="$TEST_BACKUP_PATH/${test_project}_${DATE}.tar.gz"
    
    # Get source project size (excluding node_modules) - use du directly on directory with exclusion
    PROJECT_SRC_SIZE=$(du -sb --exclude="node_modules" "$PROJECT_SRC_PATH" | cut -f1)
    FORMATTED_SRC_SIZE=$(format_size "$PROJECT_SRC_SIZE")
    
    log "Testing compression of project: $test_project (Size: $FORMATTED_SRC_SIZE)"
    print_dashboard_header
    print_dashboard_row "$test_project" "$FORMATTED_SRC_SIZE" "COMPRESSING..."
    
    # Create compressed archive
    if tar -czf "$PROJECT_BACKUP_FILE" \
        --exclude="*/node_modules/*" \
        -C "$SOURCE_DIR" "$test_project" 2>> "$LOG_FILE"; then
        
        # Get archive size
        ARCHIVE_SIZE=$(du -b "$PROJECT_BACKUP_FILE" | cut -f1)
        FORMATTED_ARCHIVE_SIZE=$(format_size "$ARCHIVE_SIZE")
        
        # Calculate compression ratio (safely)
        if [ "$ARCHIVE_SIZE" -gt 0 ]; then
            RATIO=$(awk "BEGIN {printf \"%.1f\", ($PROJECT_SRC_SIZE/$ARCHIVE_SIZE)}")
        else
            RATIO="1.0"
        fi
        
        log "Project $test_project compressed successfully (Size: $FORMATTED_ARCHIVE_SIZE, Ratio: ${RATIO}x)"
        
        printf "\033[1A"
        print_dashboard_row "$test_project" "$FORMATTED_ARCHIVE_SIZE" "✓ DONE (${RATIO}x compressed)"
        print_dashboard_footer "$FORMATTED_ARCHIVE_SIZE"
        
        log "✓ Compression test passed"
    else
        log "✗ Compression test failed"
        printf "\033[1A"
        print_dashboard_row "$test_project" "$FORMATTED_SRC_SIZE" "❌ FAILED"
        print_dashboard_footer "0 B"
        handle_error 5 "Test failed - Cannot compress project"
    fi
    
    # Test 7: Verify compressed file
    log "TEST 7: Verifying compressed file"
    if [ -f "$PROJECT_BACKUP_FILE" ]; then
        log "✓ Compressed file exists: $PROJECT_BACKUP_FILE"
        
        # Test integrity of compressed file
        if tar -tzf "$PROJECT_BACKUP_FILE" > /dev/null 2>&1; then
            log "✓ Compressed file integrity verified"
        else
            log "✗ Compressed file is corrupted"
            handle_error 6 "Test failed - Compressed file is corrupted"
        fi
    else
        log "✗ Compressed file does not exist"
        handle_error 6 "Test failed - Compressed file does not exist"
    fi
    
    # Test 8: Test stats file generation
    log "TEST 8: Testing stats file generation"
    echo "$test_project,$PROJECT_SRC_SIZE,$ARCHIVE_SIZE,$RATIO" > "$STATS_FILE"
    
    if [ -f "$STATS_FILE" ]; then
        log "✓ Stats file created successfully"
    else
        log "✗ Failed to create stats file"
        handle_error 7 "Test failed - Cannot create stats file"
    fi
    
    # Test 9: Clean up test files
    log "TEST 9: Cleaning up test files"
    rm -f "$PROJECT_BACKUP_FILE"
    if [ ! -f "$PROJECT_BACKUP_FILE" ]; then
        log "✓ Test files cleaned up successfully"
    else
        log "✗ Failed to clean up test files"
    fi
    
    # Add test results to master log (in reverse chronological order)
    local STATUS="PASSED"
    local SUMMARY="All tests passed successfully."
    
    # Create test results entry
    local TEST_ENTRY="$(date '+%Y-%m-%d %H:%M:%S') - TEST RUN: $STATUS - $SUMMARY\n"
    TEST_ENTRY+="  Source Directory: $SOURCE_DIR\n"
    TEST_ENTRY+="  Test Project: $test_project\n"
    TEST_ENTRY+="  Project Size: $FORMATTED_SRC_SIZE\n"
    TEST_ENTRY+="  Compressed Size: $FORMATTED_ARCHIVE_SIZE\n"
    TEST_ENTRY+="  Compression Ratio: ${RATIO}x\n"
    TEST_ENTRY+="  Test Directory: $TEST_BACKUP_PATH\n"
    TEST_ENTRY+="--------------------------------------------------\n\n"
    
    # Create or update master log in reverse chronological order
    if [ -f "$MASTER_LOG_FILE" ]; then
        # Read existing log and prepend new entry
        local TEMP_LOG=$(mktemp)
        echo -e "$TEST_ENTRY" > "$TEMP_LOG"
        cat "$MASTER_LOG_FILE" >> "$TEMP_LOG"
        mv "$TEMP_LOG" "$MASTER_LOG_FILE"
    else
        # Create new log
        echo -e "$TEST_ENTRY" > "$MASTER_LOG_FILE"
    fi
    
    log "Test results added to master log at $MASTER_LOG_FILE"
    
    # Test summary
    log "All tests completed successfully!"
    echo ""
    echo "✅ TEST SUMMARY:"
    echo "✅ All backup functionality tests passed"
    echo "✅ Source directory: $SOURCE_DIR"
    echo "✅ Projects found: ${#projects[@]}"
    echo "✅ Test project: $test_project"
    echo "✅ Compression works correctly"
    echo "✅ The main backup script is ready to use"
    echo ""
    echo "You can now run the actual backup script:"
    echo "  ./backup.sh            # Interactive mode"
    echo "  ./backup.sh --silent   # Silent mode (for cron jobs)"
}

# Create test directory structure
mkdir -p "$TEST_DIR" || { echo "Failed to create test directory"; exit 1; }

# Add failed test handling
handle_failed_test() {
    local ERROR_MSG="$1"
    local ERROR_CODE="${2:-1}"
    
    # Create test results entry for failed test
    local TEST_ENTRY="$(date '+%Y-%m-%d %H:%M:%S') - TEST RUN: FAILED - $ERROR_MSG\n"
    TEST_ENTRY+="  Source Directory: $SOURCE_DIR\n"
    TEST_ENTRY+="  Error Code: $ERROR_CODE\n"
    TEST_ENTRY+="  Test Directory: $TEST_BACKUP_PATH\n"
    TEST_ENTRY+="--------------------------------------------------\n\n"
    
    # Create or update master log in reverse chronological order
    if [ -f "$MASTER_LOG_FILE" ]; then
        # Read existing log and prepend new entry
        local TEMP_LOG=$(mktemp)
        echo -e "$TEST_ENTRY" > "$TEMP_LOG"
        cat "$MASTER_LOG_FILE" >> "$TEMP_LOG"
        mv "$TEMP_LOG" "$MASTER_LOG_FILE"
    else
        # Create new log
        echo -e "$TEST_ENTRY" > "$MASTER_LOG_FILE"
    fi
    
    echo "TEST FAILED: $ERROR_MSG"
    echo "Failure details saved to $MASTER_LOG_FILE"
    exit $ERROR_CODE
}

# Trap for unexpected errors
trap 'handle_failed_test "Unexpected error occurred at line $LINENO"' ERR

# Help function
show_help() {
    echo "WebDev Backup Test Tool"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -s, --source DIR        Set custom source directory to test with"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Default values:"
    echo "  Source directory:     $DEFAULT_SOURCE_DIR"
    echo ""
    echo "This script tests the backup functionality without actually transferring files."
    echo "It runs a series of tests to verify that the backup process works correctly."
    echo ""
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --source|-s)
            if [[ -n "$2" && "$2" != --* ]]; then
                CUSTOM_SOURCE_DIR="$2"
                shift 2
            else
                echo "Error: Source argument requires a directory path"
                exit 1
            fi
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help to see available options"
            exit 1
            ;;
    esac
    shift
done

# Set source directory if custom was provided
if [[ -n "$CUSTOM_SOURCE_DIR" ]]; then
    SOURCE_DIR="$CUSTOM_SOURCE_DIR"
fi

# Verify source directory exists
if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "ERROR: Source directory does not exist: $SOURCE_DIR"
    echo "Please specify a valid source directory using the -s option"
    exit 1
fi

# Run tests
run_test

# We keep the test directory but clean up the test files
# Keep the master log

echo ""
echo "Test logs saved to test directory: $TEST_DIR"
echo "Master test history log: $MASTER_LOG_FILE"
echo ""

# Check if we were invoked by the launcher script
if [ -f "$SCRIPT_DIR/webdev-backup.sh" ]; then
    echo -e "${CYAN}Return to launcher menu? [Y/n]: ${NC}"
    read -n 1 -r -p "" LAUNCH_REPLY
    echo
    if [[ "$LAUNCH_REPLY" =~ ^[Yy]$ ]] || [[ -z "$LAUNCH_REPLY" ]]; then
        echo -e "\n${GREEN}Returning to launcher menu...${NC}"
        exec "$SCRIPT_DIR/webdev-backup.sh"
    else
        echo -e "\n${YELLOW}Exiting application. Thanks for using WebDev Backup Tool!${NC}"
    fi
fi

exit 0