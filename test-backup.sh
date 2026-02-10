#!/bin/bash
# test-backup.sh - Test script for WebDev Backup Tool
# This script performs tests to verify the backup functionality

# Get the script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export RUNNING_TESTS=1
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/fs.sh"

# Set defaults
QUICK_TEST=false
VERBOSE=false
TEST_TYPE="all"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --quick)
            QUICK_TEST=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --unit)
            TEST_TYPE="unit"
            shift
            ;;
        --integration)
            TEST_TYPE="integration"
            shift
            ;;
        --help|-h)
            echo "WebDev Backup Test Tool"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --quick              Run minimal tests only"
            echo "  --verbose            Show detailed test output"
            echo "  --unit               Run only unit tests"
            echo "  --integration        Run only integration tests"
            echo "  -h, --help           Show this help message"
            echo ""
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help to see available options"
            exit 1
            ;;
    esac
done

# Set up test environment
TEST_DIR="$SCRIPT_DIR/test"
mkdir -p "$TEST_DIR"
TEST_LOG="$TEST_DIR/test_log_$(date +%Y-%m-%d_%H-%M-%S).log"

# Counter variables
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Banner
echo -e "\n${CYAN}===== WebDev Backup Tool Test Suite =====${NC}"
echo "Started at: $(date)"
echo "Log file: $TEST_LOG"
echo "-------------------------------------------"

# Initialize log file
echo "===== WebDev Backup Tool Test Suite =====" > "$TEST_LOG"
echo "Started at: $(date)" >> "$TEST_LOG"
echo "Test type: $TEST_TYPE" >> "$TEST_LOG"
echo "Quick test: $QUICK_TEST" >> "$TEST_LOG"
echo "-------------------------------------------" >> "$TEST_LOG"

# Function to run a single test
run_test() {
    local test_name="$1"
    local test_cmd="$2"
    local expected_status="${3:-0}"
    
    ((TESTS_TOTAL++))
    
    echo -e "\n${CYAN}Running test: $test_name${NC}"
    echo "Command: $test_cmd"
    echo "Testing $test_name..." >> "$TEST_LOG"
    
    # Run the test command
    if [ "$VERBOSE" = true ]; then
        eval "$test_cmd"
        test_status=$?
    else
        eval "$test_cmd" > /dev/null 2>&1
        test_status=$?
    fi
    
    # Record the result
    echo "Exit status: $test_status" >> "$TEST_LOG"
    
    # Check if test passed or failed
    if [ $test_status -eq $expected_status ]; then
        echo -e "${GREEN}PASSED${NC}"
        echo "RESULT: PASSED" >> "$TEST_LOG"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}FAILED${NC}"
        echo "Expected $expected_status, got $test_status"
        echo "RESULT: FAILED (Expected $expected_status, got $test_status)" >> "$TEST_LOG"
        ((TESTS_FAILED++))
    fi
}

# Run unit tests if specified
if [ "$TEST_TYPE" = "all" ] || [ "$TEST_TYPE" = "unit" ]; then
    echo -e "\n${YELLOW}Running Unit Tests${NC}"
    echo "-------------------------------------------" >> "$TEST_LOG"
    echo "UNIT TESTS" >> "$TEST_LOG"
    echo "-------------------------------------------" >> "$TEST_LOG"
    
    # Test utility functions
    run_test "Format size function" "result=\$(format_size 1024); [[ \"\$result\" == \"1.00 KB\" ]]"
    run_test "Sanitize input function" "result=\$(sanitize_input 'test;rm -rf /'); [[ \"\$result\" == \"testrm -rf /\" ]]"
    run_test "Directory exists check" "verify_directory \"$TEST_DIR\" \"Test\" true"
    
    # Test file system functions
    run_test "Find projects function" "cd $SCRIPT_DIR && find_projects \"$TEST_DIR\" 1"
    
    if [ "$QUICK_TEST" = false ]; then
        # More comprehensive unit tests for non-quick mode
        run_test "Calculate checksum" "calculate_checksum \"$0\""
        run_test "Verify backup" "echo 'test' > \"$TEST_DIR/test.txt\" && tar -czf \"$TEST_DIR/test.tar.gz\" -C \"$TEST_DIR\" test.txt && verify_backup \"$TEST_DIR/test.tar.gz\""
    fi
fi

# Run integration tests if specified
if [ "$TEST_TYPE" = "all" ] || [ "$TEST_TYPE" = "integration" ]; then
    echo -e "\n${YELLOW}Running Integration Tests${NC}"
    echo "-------------------------------------------" >> "$TEST_LOG"
    echo "INTEGRATION TESTS" >> "$TEST_LOG"
    echo "-------------------------------------------" >> "$TEST_LOG"
    
    # Set up test project
    echo "Setting up test project..." >> "$TEST_LOG"
    TEST_PROJECT_DIR="$TEST_DIR/test_project_$(date +%s)"
    mkdir -p "$TEST_PROJECT_DIR/project1/src"
    mkdir -p "$TEST_PROJECT_DIR/project1/node_modules"
    echo "console.log('test');" > "$TEST_PROJECT_DIR/project1/src/app.js"
    echo "test data" > "$TEST_PROJECT_DIR/project1/README.md"
    dd if=/dev/zero of="$TEST_PROJECT_DIR/project1/node_modules/big_file.bin" bs=1K count=10 2>/dev/null
    
    # Test backup command with dry-run
    run_test "Backup dry run" "$SCRIPT_DIR/backup.sh --source \"$TEST_PROJECT_DIR\" --destination \"$TEST_DIR/backup\" --dry-run --silent"
    
    if [ "$QUICK_TEST" = false ]; then
        # Run actual backup for non-quick tests
        run_test "Full backup" "$SCRIPT_DIR/backup.sh --source \"$TEST_PROJECT_DIR\" --destination \"$TEST_DIR/backup\" --silent"
        
        # Verify backup was created
        run_test "Backup file exists" "find \"$TEST_DIR/backup\" -name \"*.tar.gz\" | grep -q \".tar.gz\""
        
        # Test restore with dry-run
        run_test "Restore dry run" "$SCRIPT_DIR/restore.sh --source \"$TEST_DIR/backup\" --dry-run --yes"
    fi
    
    # Clean up test project
    if [ "$VERBOSE" = false ]; then
        rm -rf "$TEST_PROJECT_DIR"
    fi
fi

# Display summary
echo -e "\n${CYAN}===== Test Results =====${NC}"
echo "Total tests: $TESTS_TOTAL"
echo "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo "Failed: ${RED}$TESTS_FAILED${NC}"

echo "-------------------------------------------" >> "$TEST_LOG"
echo "TEST SUMMARY:" >> "$TEST_LOG"
echo "Total tests: $TESTS_TOTAL" >> "$TEST_LOG"
echo "Passed: $TESTS_PASSED" >> "$TEST_LOG"
echo "Failed: $TESTS_FAILED" >> "$TEST_LOG"
echo "Completed at: $(date)" >> "$TEST_LOG"

# Exit with appropriate status code
if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}All tests passed successfully!${NC}"
    exit 0
else
    echo -e "\n${RED}Some tests failed. See log for details: $TEST_LOG${NC}"
    exit 1
fi