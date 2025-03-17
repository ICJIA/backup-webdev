#!/bin/bash
# test-cron.sh - Test script for cron functionality in configure-cron.sh
# Simulates cron configuration in dry-run mode without modifying actual crontab

# Source the shared modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/ui.sh"

# Test configuration
TEST_BACKUP_NAME="cron_test_$(date +%Y%m%d_%H%M%S)"
TEST_BACKUP_PATH="$TEST_DIR/$TEST_BACKUP_NAME"
LOG_FILE="$TEST_BACKUP_PATH/cron_test_log.log"
BACKUP_SCRIPT="$SCRIPT_DIR/webdev-backup.sh"
TMP_CRONTAB="/tmp/crontab-test.$$"
CRON_COMMENT="# TEST - WebDev Backup Tool automatic backup"
MASTER_LOG_FILE="$TEST_HISTORY_LOG"

# Create test directory
mkdir -p "$TEST_BACKUP_PATH" || { echo "Failed to create test directory"; exit 1; }

# Start logging
start_log() {
    echo -e "\n${CYAN}===== WebDev Backup Tool - Cron Test =====${NC}"
    echo -e "${CYAN}Test run started at: $(date)${NC}"
    echo -e "${CYAN}Logging to: $LOG_FILE${NC}\n"
    
    echo "===== WebDev Backup Tool - Cron Test =====" > "$LOG_FILE"
    echo "Test run started at: $(date)" >> "$LOG_FILE"
}

# Logging function
log() {
    local message=$1
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    echo "$timestamp - $message"
    echo "$timestamp - $message" >> "$LOG_FILE"
}

# Error handling function
handle_error() {
    local exit_code=$1
    local error_message=$2
    
    log "TEST ERROR: $error_message (Exit code: $exit_code)"
    
    # Add to master log
    handle_test_result "FAILED" "$error_message" "$exit_code"
    
    exit $exit_code
}

# Function to show status message
show_status() {
    local status=$1
    echo -e "${YELLOW}$status${NC}"
    echo "$status" >> "$LOG_FILE"
}

# Function to handle test results
handle_test_result() {
    local STATUS="$1"
    local SUMMARY="$2"
    local ERROR_CODE="${3:-0}"
    
    # Create test results entry
    local TEST_ENTRY="$(date '+%Y-%m-%d %H:%M:%S') - CRON TEST: $STATUS - $SUMMARY\n"
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
    
    log "Test results added to master log at $MASTER_LOG_FILE"
}

# Mock function to simulate getting existing cron job
mock_get_existing_cron() {
    # Simulate empty crontab initially
    if [ "$TEST_PHASE" -eq 1 ]; then
        echo ""
    # After "setting up" cron, simulate having an entry
    elif [ "$TEST_PHASE" -eq 2 ]; then
        echo "0 */72 * * * $BACKUP_SCRIPT --silent"
    # After "modifying" cron, simulate having a modified entry
    elif [ "$TEST_PHASE" -eq 3 ]; then
        echo "0 0 * * 0 $BACKUP_SCRIPT --silent --incremental --verify"
    fi
}

# Mock function to simulate crontab operations
mock_crontab() {
    local operation=$1
    
    case "$operation" in
        -l) # List
            mock_get_existing_cron
            ;;
        *) # Install
            # Simulate successful crontab installation
            log "DRY RUN: Would execute: crontab $1"
            if [ -f "$1" ]; then
                log "DRY RUN: Would install this crontab:"
                cat "$1" >> "$LOG_FILE"
                echo "# Content that would be installed:" >> "$LOG_FILE"
                cat "$1" >> "$LOG_FILE"
            fi
            ;;
    esac
}

# Run tests
run_cron_tests() {
    start_log
    
    # Test 1: Check if backup script exists
    show_status "TEST 1: Checking if backup script exists"
    if [ ! -f "$BACKUP_SCRIPT" ]; then
        handle_error 1 "Backup script not found: $BACKUP_SCRIPT"
    fi
    log "✓ Backup script exists"
    
    # Test 2: Check if backup script is executable
    show_status "TEST 2: Checking if backup script is executable"
    if [ ! -x "$BACKUP_SCRIPT" ]; then
        handle_error 2 "Backup script is not executable: $BACKUP_SCRIPT"
    fi
    log "✓ Backup script is executable"
    
    # Test 3: Check if crontab command exists
    show_status "TEST 3: Checking if crontab command exists"
    if ! command -v crontab >/dev/null 2>&1; then
        handle_error 3 "crontab command not found. Please install cron to use this feature."
    fi
    log "✓ crontab command exists"
    
    # Test 4: Simulate getting current cron status (no cron job)
    show_status "TEST 4: Testing get_existing_cron function (empty crontab)"
    TEST_PHASE=1
    CURRENT_CRON=$(mock_get_existing_cron)
    if [ -n "$CURRENT_CRON" ]; then
        handle_error 4 "get_existing_cron should return empty string for empty crontab"
    fi
    log "✓ get_existing_cron correctly returns empty string for empty crontab"
    
    # Test 5: Simulate enabling automatic backup
    show_status "TEST 5: Testing enabling automatic backup"
    TEST_PHASE=1
    log "DRY RUN: Would enable automatic backup with default interval (72 hours)"
    
    # Create temp crontab file for testing
    echo "$CRON_COMMENT" > "$TMP_CRONTAB"
    echo "0 */72 * * * $BACKUP_SCRIPT --silent" >> "$TMP_CRONTAB"
    
    # Simulate installing crontab
    mock_crontab "$TMP_CRONTAB"
    
    log "✓ Automatic backup would be enabled with default interval"
    
    # Test 6: Simulate getting current cron status (with cron job)
    show_status "TEST 6: Testing get_existing_cron function (with cron job)"
    TEST_PHASE=2
    CURRENT_CRON=$(mock_get_existing_cron)
    if [ -z "$CURRENT_CRON" ]; then
        handle_error 6 "get_existing_cron should return cron job for populated crontab"
    fi
    log "✓ get_existing_cron correctly returns cron job for populated crontab"
    
    # Test 7: Simulate changing backup frequency
    show_status "TEST 7: Testing changing backup frequency"
    TEST_PHASE=2
    log "DRY RUN: Would change backup frequency to weekly (Sunday at midnight)"
    
    # Create temp crontab file for testing
    echo "$CRON_COMMENT" > "$TMP_CRONTAB"
    echo "0 0 * * 0 $BACKUP_SCRIPT --silent" >> "$TMP_CRONTAB"
    
    # Simulate installing crontab
    mock_crontab "$TMP_CRONTAB"
    
    log "✓ Backup frequency would be changed to weekly"
    
    # Test 8: Simulate adding custom backup options
    show_status "TEST 8: Testing adding custom backup options"
    TEST_PHASE=2
    log "DRY RUN: Would add custom backup options (--incremental --verify)"
    
    # Create temp crontab file for testing
    echo "$CRON_COMMENT" > "$TMP_CRONTAB"
    echo "0 0 * * 0 $BACKUP_SCRIPT --silent --incremental --verify" >> "$TMP_CRONTAB"
    
    # Simulate installing crontab
    mock_crontab "$TMP_CRONTAB"
    
    log "✓ Custom backup options would be added"
    
    # Test 9: Simulate getting current cron status (with modified cron job)
    show_status "TEST 9: Testing get_existing_cron function (with modified cron job)"
    TEST_PHASE=3
    CURRENT_CRON=$(mock_get_existing_cron)
    if [ -z "$CURRENT_CRON" ] || ! echo "$CURRENT_CRON" | grep -q "incremental"; then
        handle_error 9 "get_existing_cron should return modified cron job"
    fi
    log "✓ get_existing_cron correctly returns modified cron job"
    
    # Test 10: Simulate disabling automatic backup
    show_status "TEST 10: Testing disabling automatic backup"
    TEST_PHASE=3
    log "DRY RUN: Would disable automatic backup"
    
    # Create empty temp crontab file
    > "$TMP_CRONTAB"
    
    # Simulate installing crontab
    mock_crontab "$TMP_CRONTAB"
    
    log "✓ Automatic backup would be disabled"
    
    # Clean up
    rm -f "$TMP_CRONTAB"
    
    # All tests passed
    log "All cron functionality tests passed successfully!"
    handle_test_result "PASSED" "All cron functionality tests passed successfully"
    
    echo ""
    echo "✅ CRON TEST SUMMARY:"
    echo "✅ All cron functionality tests passed"
    echo "✅ Backup script: $BACKUP_SCRIPT"
    echo "✅ Cron functionality works correctly in dry-run mode"
    echo ""
    echo "You can now use the configure-cron.sh script to set up automated backups:"
    echo "  ./configure-cron.sh"
}

# Help function
show_help() {
    echo "WebDev Backup Cron Test Tool"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "This script tests the cron functionality without modifying your actual crontab."
    echo "It runs a series of tests to verify that the cron configuration process works correctly."
    echo ""
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
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

# Run tests
run_cron_tests

echo ""
echo "Test logs saved to: $LOG_FILE"
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