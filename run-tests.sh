#!/bin/bash
# run-tests.sh - Script to run specific test suites for WebDev Backup Tool

# Get the script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/utils.sh"

# Set defaults
TEST_SUITE="all"
VERBOSE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --unit)
            TEST_SUITE="unit"
            shift
            ;;
        --integration)
            TEST_SUITE="integration"
            shift
            ;;
        --security)
            TEST_SUITE="security"
            shift
            ;;
        --performance)
            TEST_SUITE="performance"
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            echo "WebDev Backup Test Runner"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --unit               Run unit tests"
            echo "  --integration        Run integration tests"
            echo "  --security           Run security tests"
            echo "  --performance        Run performance tests"
            echo "  --verbose            Show detailed test output"
            echo "  -h, --help           Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 --unit            # Run only unit tests"
            echo "  $0 --integration     # Run only integration tests"
            echo "  $0                   # Run all tests"
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

# Set verbosity flag
VERBOSE_FLAG=""
if [ "$VERBOSE" = true ]; then
    VERBOSE_FLAG="--verbose"
fi

# Banner
echo -e "\n${CYAN}===== WebDev Backup Tool Test Runner =====${NC}"
echo "Started at: $(date)"
echo "Running $TEST_SUITE tests..."

case "$TEST_SUITE" in
    unit)
        echo -e "\n${YELLOW}Running Unit Tests${NC}"
        bash "$SCRIPT_DIR/test-backup.sh" --unit $VERBOSE_FLAG
        EXIT_CODE=$?
        ;;
    integration)
        echo -e "\n${YELLOW}Running Integration Tests${NC}"
        bash "$SCRIPT_DIR/test-backup.sh" --integration $VERBOSE_FLAG
        EXIT_CODE=$?
        ;;
    security)
        echo -e "\n${YELLOW}Running Security Tests${NC}"
        bash "$SCRIPT_DIR/security-audit.sh"
        EXIT_CODE=$?
        ;;
    performance)
        echo -e "\n${YELLOW}Running Performance Tests${NC}"
        
        # Create a performance test with multiple project sizes
        echo "Setting up performance test environment..."
        PERF_TEST_DIR="$SCRIPT_DIR/test/perf_test"
        mkdir -p "$PERF_TEST_DIR"
        
        # Create test projects of different sizes
        mkdir -p "$PERF_TEST_DIR/small_project/src"
        mkdir -p "$PERF_TEST_DIR/medium_project/src"
        mkdir -p "$PERF_TEST_DIR/large_project/src"
        
        # Add some files to each project
        for i in {1..5}; do
            echo "console.log('small project test');" > "$PERF_TEST_DIR/small_project/src/file$i.js"
        done
        
        for i in {1..20}; do
            echo "console.log('medium project test');" > "$PERF_TEST_DIR/medium_project/src/file$i.js"
        done
        
        for i in {1..50}; do
            echo "console.log('large project test');" > "$PERF_TEST_DIR/large_project/src/file$i.js"
        done
        
        echo "Running performance tests..."
        
        # Time the backup operations
        echo -e "\n${CYAN}Testing small project backup:${NC}"
        start_time=$(date +%s)
        bash "$SCRIPT_DIR/backup.sh" --source "$PERF_TEST_DIR/small_project" --destination "$PERF_TEST_DIR/backup" --silent
        end_time=$(date +%s)
        echo "Time: $((end_time - start_time)) seconds"
        
        echo -e "\n${CYAN}Testing medium project backup:${NC}"
        start_time=$(date +%s)
        bash "$SCRIPT_DIR/backup.sh" --source "$PERF_TEST_DIR/medium_project" --destination "$PERF_TEST_DIR/backup" --silent
        end_time=$(date +%s)
        echo "Time: $((end_time - start_time)) seconds"
        
        echo -e "\n${CYAN}Testing large project backup:${NC}"
        start_time=$(date +%s)
        bash "$SCRIPT_DIR/backup.sh" --source "$PERF_TEST_DIR/large_project" --destination "$PERF_TEST_DIR/backup" --silent
        end_time=$(date +%s)
        echo "Time: $((end_time - start_time)) seconds"
        
        # Test parallel compression if available
        if command -v pigz >/dev/null 2>&1; then
            echo -e "\n${CYAN}Testing parallel compression (4 threads):${NC}"
            start_time=$(date +%s)
            bash "$SCRIPT_DIR/backup.sh" --source "$PERF_TEST_DIR/large_project" --destination "$PERF_TEST_DIR/backup" --parallel 4 --silent
            end_time=$(date +%s)
            echo "Time: $((end_time - start_time)) seconds"
        fi
        
        # Clean up test files
        echo "Cleaning up test files..."
        rm -rf "$PERF_TEST_DIR"
        
        EXIT_CODE=0
        ;;
    all)
        echo -e "\n${YELLOW}Running All Tests${NC}"
        
        # Run unit tests
        echo -e "\n${CYAN}Unit Tests:${NC}"
        bash "$SCRIPT_DIR/test-backup.sh" --unit $VERBOSE_FLAG
        UNIT_EXIT=$?
        
        # Run integration tests
        echo -e "\n${CYAN}Integration Tests:${NC}"
        bash "$SCRIPT_DIR/test-backup.sh" --integration $VERBOSE_FLAG
        INTEGRATION_EXIT=$?
        
        # Run security audit
        echo -e "\n${CYAN}Security Tests:${NC}"
        bash "$SCRIPT_DIR/security-audit.sh"
        SECURITY_EXIT=$?
        
        # Calculate overall exit code
        if [ $UNIT_EXIT -ne 0 ] || [ $INTEGRATION_EXIT -ne 0 ] || [ $SECURITY_EXIT -ne 0 ]; then
            EXIT_CODE=1
        else
            EXIT_CODE=0
        fi
        ;;
    *)
        echo "Unknown test suite: $TEST_SUITE"
        exit 1
        ;;
esac

echo -e "\n${CYAN}Tests completed at $(date)${NC}"
exit $EXIT_CODE