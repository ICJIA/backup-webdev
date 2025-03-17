#!/bin/bash
# run-tests.sh - Comprehensive test suite for WebDev Backup Tool
# This script runs all tests for the backup tool in a single command

# Source the shared modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/ui.sh"
source "$SCRIPT_DIR/fs.sh"

# Test configuration
LOG_FILE="$TEST_DIR/test_run_$DATE.log"
TEST_RESULT=0

# Create test directory if it doesn't exist
mkdir -p "$TEST_DIR"

# Start logging
echo -e "\n${CYAN}===== WebDev Backup Tool - Comprehensive Test Suite =====${NC}"
echo -e "${CYAN}Test run started at: $(date)${NC}"
echo -e "${CYAN}Logging to: $LOG_FILE${NC}\n"

# Function for section headers
section() {
    echo -e "\n${YELLOW}===== $1 =====${NC}"
    echo -e "===== $1 =====" >> "$LOG_FILE"
}

# Function to run a test and capture its result
run_test() {
    local test_name="$1"
    local test_command="$2"
    local timeout_seconds="${3:-120}"  # Default timeout of 2 minutes
    local temp_log=$(mktemp)
    
    echo -e "${YELLOW}Running test: ${test_name}${NC}"
    echo "Running test: ${test_name}" >> "$LOG_FILE"
    echo "Command: ${test_command}" >> "$LOG_FILE"
    echo "Timeout: ${timeout_seconds} seconds" >> "$LOG_FILE"
    echo "----------------------------------------" >> "$LOG_FILE"
    
    # Run the test with timeout and capture output and exit code
    timeout $timeout_seconds bash -c "$test_command" > "$temp_log" 2>&1
    local result=$?
    
    # Check if timeout occurred (exit code 124)
    if [ $result -eq 124 ]; then
        echo -e "${RED}⏱️ Test timed out after ${timeout_seconds} seconds: ${test_name}${NC}"
        echo "RESULT: TIMEOUT after ${timeout_seconds} seconds" >> "$LOG_FILE"
        echo "Command was: $test_command" >> "$LOG_FILE"
        TEST_RESULT=1
    else
        # Append the output to the log file
        cat "$temp_log" >> "$LOG_FILE"
        echo "----------------------------------------" >> "$LOG_FILE"
        
        # Display result
        if [ $result -eq 0 ]; then
            echo -e "${GREEN}✓ Test passed: ${test_name}${NC}"
            echo "RESULT: PASSED (Exit code: $result)" >> "$LOG_FILE"
        else
            echo -e "${RED}✗ Test failed: ${test_name} (Exit code: $result)${NC}"
            echo "RESULT: FAILED (Exit code: $result)" >> "$LOG_FILE"
            TEST_RESULT=1
            
            # Show the output for failed tests
            echo -e "${RED}--- Error output: ---${NC}"
            cat "$temp_log"
            echo -e "${RED}-------------------${NC}"
        fi
    fi
    
    rm -f "$temp_log"
    echo "" >> "$LOG_FILE"
    return $result
}

# Start the tests
section "Basic Validation Tests"

# Test 1: Check if the main script exists
run_test "Script existence check" "test -f \"$SCRIPT_DIR/backup.sh\""

# Test 2: Check if the test script exists
run_test "Test script existence check" "test -f \"$SCRIPT_DIR/test-backup.sh\""

# Test 3: Check script permissions
run_test "Script permissions check" "test -x \"$SCRIPT_DIR/backup.sh\" && test -x \"$SCRIPT_DIR/test-backup.sh\""

# Test 4: Check help output
run_test "Help output check" "$SCRIPT_DIR/backup.sh --help | grep -q 'WebDev Backup Tool'"

section "Script Syntax Tests"

# Test 5: Shell syntax check for main script
run_test "Main script syntax check" "bash -n \"$SCRIPT_DIR/backup.sh\""

# Test 6: Shell syntax check for test script
run_test "Test script syntax check" "bash -n \"$SCRIPT_DIR/test-backup.sh\""

section "Functional Tests"

# Test 7: Run the test script (with SKIP_INTERACTIVE to prevent hanging on prompts and 3-minute timeout)
run_test "Comprehensive functionality test" "SKIP_INTERACTIVE=1 $SCRIPT_DIR/test-backup.sh" 180

section "Command-line Options Tests"

# Test 8: Test help flag
run_test "Help flag test" "$SCRIPT_DIR/backup.sh -h"

# Test 9: Test destination flag validation
run_test "Destination flag validation" "$SCRIPT_DIR/backup.sh --help | grep -q 'destination'"

# Test 10: Test source flag validation
run_test "Source flag validation" "$SCRIPT_DIR/backup.sh --help | grep -q 'source'"

# Test 11: Test external flag validation
run_test "External flag test" "$SCRIPT_DIR/backup.sh --help | grep -q 'external'"

# Test 12: Test cloud provider option with DigitalOcean
run_test "DigitalOcean Spaces cloud option" "$SCRIPT_DIR/backup.sh --help | grep -q 'do' && $SCRIPT_DIR/backup.sh --dry-run --cloud do --silent | grep -q 'DRY RUN'"

section "Edge Case Tests"

# Test 13: Create a directory that doesn't exist
NON_EXISTENT_DIR="/tmp/nonexistent_$(date +%s)"
run_test "Non-existent source directory test" "$SCRIPT_DIR/backup.sh -s $NON_EXISTENT_DIR 2>&1 | grep -q 'ERROR: Source directory does not exist'"

# Test 14: Invalid flag test
run_test "Invalid flag test" "$SCRIPT_DIR/backup.sh --invalid-flag 2>&1 | grep -q 'Unknown option'"

# Test 15: External backup with no provider (should default to DigitalOcean)
run_test "External backup default provider test" "$SCRIPT_DIR/backup.sh --external --dry-run --silent | grep -q 'DRY RUN'"

section "Cleanup Utility Tests"

# Test 16: Cleanup help output
run_test "Cleanup help test" "$SCRIPT_DIR/cleanup.sh --help | grep -q 'WebDev Backup Cleanup Tool'"

# Test 17: Cleanup dry run mode
run_test "Cleanup dry run test" "$SCRIPT_DIR/cleanup.sh --dry-run --yes | grep -q 'DRY RUN COMPLETED'"

# Test 18: Cleanup all logs dry run mode
run_test "Cleanup all logs dry run test" "$SCRIPT_DIR/cleanup.sh --dry-run --all-logs --yes | grep -q 'DRY RUN: Would ask for confirmation'"

# Test 19: Cleanup older logs dry run mode
run_test "Cleanup older logs dry run test" "$SCRIPT_DIR/cleanup.sh --dry-run --days 30 --yes | grep -q 'DRY RUN: Would ask for confirmation'"

# Test 20: Cleanup with backup dry run mode
run_test "Cleanup with backup dry run test" "$SCRIPT_DIR/cleanup.sh --dry-run --backup-logs --yes | grep -q 'DRY RUN: Would execute'"

# Test 21: Custom paths in cleanup
run_test "Cleanup with custom paths test" "$SCRIPT_DIR/cleanup.sh --dry-run --source \"$SCRIPT_DIR\" --target \"$SCRIPT_DIR/test\" --yes | grep -q 'Verifying Source Directory'"

section "Cron Functionality Tests"

# Test 22: Verify cron test script exists
run_test "Cron test script existence check" "test -f \"$SCRIPT_DIR/test-cron.sh\""

# Test 23: Check cron test script permissions
run_test "Cron test script permissions check" "test -x \"$SCRIPT_DIR/test-cron.sh\""

# Test 24: Check cron test script syntax
run_test "Cron test script syntax check" "bash -n \"$SCRIPT_DIR/test-cron.sh\""

# Test 25: Run cron tests in dry-run mode (with 3-minute timeout)
run_test "Cron functionality dry-run test" "SKIP_INTERACTIVE=1 $SCRIPT_DIR/test-cron.sh" 180

section "Tar Compatibility Tests"

# Test 26: Verify tar compatibility test script exists
run_test "Tar compatibility test script existence check" "test -f \"$SCRIPT_DIR/test-tar-compatibility.sh\""

# Test 27: Check tar compatibility test script permissions
run_test "Tar compatibility test script permissions check" "test -x \"$SCRIPT_DIR/test-tar-compatibility.sh\""

# Test 28: Check tar compatibility test script syntax
run_test "Tar compatibility test script syntax check" "bash -n \"$SCRIPT_DIR/test-tar-compatibility.sh\""

# Test 29: Run tar compatibility tests (with 3-minute timeout)
run_test "Tar compatibility test" "SKIP_INTERACTIVE=1 $SCRIPT_DIR/test-tar-compatibility.sh" 180

# Print summary
echo -e "\n${CYAN}===== Test Summary =====${NC}"
if [ $TEST_RESULT -eq 0 ]; then
    echo -e "${GREEN}All tests passed successfully!${NC}"
else
    echo -e "${RED}Some tests failed. Check the log file for details: $LOG_FILE${NC}"
fi

echo -e "${CYAN}Test run completed at: $(date)${NC}\n"

# Record in the test history log (in reverse chronological order)
HISTORY_LOG="$SCRIPT_DIR/test/test_history.log"
TEMP_LOG=$(mktemp)

{
    echo "$(date '+%Y-%m-%d %H:%M:%S') - COMPREHENSIVE TEST RUN: $([ $TEST_RESULT -eq 0 ] && echo "SUCCESS" || echo "FAILED")"
    echo "  Log file: $LOG_FILE"
    echo "  Result: $([ $TEST_RESULT -eq 0 ] && echo "All tests passed" || echo "Some tests failed")"
    echo "--------------------------------------------------"
    echo ""
    if [ -f "$HISTORY_LOG" ]; then
        cat "$HISTORY_LOG"
    fi
} > "$TEMP_LOG"

mv "$TEMP_LOG" "$HISTORY_LOG"

echo

# Check if we were invoked by the launcher script
# Skip interactive prompt if running from test suite
if [ -f "$SCRIPT_DIR/webdev-backup.sh" ] && [ -z "$SKIP_INTERACTIVE" ]; then
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

exit $TEST_RESULT