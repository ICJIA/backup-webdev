#!/bin/bash
# run-all-tests.sh - Comprehensive test suite for WebDev Backup Tool
# This script tests all components of the backup system

# Get the script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../core/config.sh"
source "$SCRIPT_DIR/../utils/utils.sh"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Create test log directory
TEST_LOG_DIR="$SCRIPT_DIR/logs/tests"
mkdir -p "$TEST_LOG_DIR"
TEST_LOG="$TEST_LOG_DIR/all_tests_$(date +%Y-%m-%d_%H-%M-%S).log"

# Initialize counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_cmd="$2"
    local expected_status="${3:-0}"  # Default to expecting success (status 0)
    
    echo -e "\n${CYAN}Running test: $test_name${NC}"
    echo "Command: $test_cmd"
    echo "Testing $test_name..." >> "$TEST_LOG"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    # Run the command and capture its output and status
    TEST_OUTPUT=$(eval "$test_cmd" 2>&1)
    TEST_STATUS=$?
    
    # Log the output
    echo "OUTPUT:" >> "$TEST_LOG"
    echo "$TEST_OUTPUT" >> "$TEST_LOG"
    echo "EXIT STATUS: $TEST_STATUS" >> "$TEST_LOG"
    
    # Check if the status matches expected
    if [ "$TEST_STATUS" -eq "$expected_status" ]; then
        echo -e "${GREEN}✓ PASSED${NC}"
        echo "RESULT: PASSED" >> "$TEST_LOG"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAILED${NC}"
        echo "Expected status: $expected_status, Got: $TEST_STATUS" 
        echo "$TEST_OUTPUT"
        echo "RESULT: FAILED" >> "$TEST_LOG"
        echo "Expected status: $expected_status, Got: $TEST_STATUS" >> "$TEST_LOG"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    echo "-------------------------------------------" >> "$TEST_LOG"
}

# Print header
echo -e "${CYAN}===== WebDev Backup Tool: Comprehensive Test Suite =====${NC}"
echo "Starting tests at $(date)"
echo "Log file: $TEST_LOG"

# Log header
echo "===== WebDev Backup Tool: Comprehensive Test Suite =====" > "$TEST_LOG"
echo "Started at: $(date)" >> "$TEST_LOG"
echo "-------------------------------------------" >> "$TEST_LOG"

echo -e "\n${CYAN}1. Checking Environment${NC}"

# Test 1: Check if all required scripts exist
echo -e "\n${CYAN}Checking if all required scripts exist...${NC}"
MISSING_FILES=0
REQUIRED_FILES=(
    "$SCRIPT_DIR/backup.sh"
    "$SCRIPT_DIR/config.sh"
    "$SCRIPT_DIR/utils.sh"
    "$SCRIPT_DIR/ui.sh"
    "$SCRIPT_DIR/fs.sh"
    "$SCRIPT_DIR/webdev-backup.sh"
    "$SCRIPT_DIR/restore.sh"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo -e "${RED}Missing required file: $file${NC}"
        MISSING_FILES=$((MISSING_FILES + 1))
    else
        echo -e "${GREEN}Found file: $(basename "$file")${NC}"
    fi
done

if [ $MISSING_FILES -eq 0 ]; then
    echo -e "${GREEN}✓ All required files found${NC}"
else
    echo -e "${RED}✗ Missing $MISSING_FILES required files${NC}"
fi

# Test 2: Check permissions
echo -e "\n${CYAN}Checking script permissions...${NC}"
PERMISSION_ISSUES=0

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        if [ ! -x "$file" ]; then
            echo -e "${YELLOW}Warning: Script not executable: $file${NC}"
            echo -e "${YELLOW}Fixing permissions...${NC}"
            chmod +x "$file"
            PERMISSION_ISSUES=$((PERMISSION_ISSUES + 1))
        fi
    fi
done

# Check secrets.sh permissions if it exists
if [ -f "$SCRIPT_DIR/secrets.sh" ]; then
    PERMS=$(stat -c "%a" "$SCRIPT_DIR/secrets.sh")
    if [ "$PERMS" != "600" ]; then
        echo -e "${YELLOW}Warning: secrets.sh has incorrect permissions: $PERMS${NC}"
        echo -e "${YELLOW}Fixing permissions...${NC}"
        chmod 600 "$SCRIPT_DIR/secrets.sh"
        PERMISSION_ISSUES=$((PERMISSION_ISSUES + 1))
    fi
fi

if [ $PERMISSION_ISSUES -eq 0 ]; then
    echo -e "${GREEN}✓ All scripts have correct permissions${NC}"
else
    echo -e "${YELLOW}⚠ Fixed $PERMISSION_ISSUES permission issues${NC}"
fi

# Test 3: Check for required tools
echo -e "\n${CYAN}Checking for required dependencies...${NC}"
MISSING_DEPS=0
REQUIRED_TOOLS=(
    "tar"
    "gzip"
    "find"
    "awk"
    "sed"
    "grep"
    "stat"
)

for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
        echo -e "${RED}Missing required tool: $tool${NC}"
        MISSING_DEPS=$((MISSING_DEPS + 1))
    else
        echo -e "${GREEN}Found tool: $tool${NC}"
    fi
done

if [ $MISSING_DEPS -eq 0 ]; then
    echo -e "${GREEN}✓ All required dependencies found${NC}"
else
    echo -e "${RED}✗ Missing $MISSING_DEPS required dependencies${NC}"
    echo -e "${RED}Please install missing dependencies and rerun the tests${NC}"
    exit 1
fi

# Test 4: Check configuration
echo -e "\n${CYAN}Checking configuration...${NC}"

# Verify source directories
if [ ${#DEFAULT_SOURCE_DIRS[@]} -eq 0 ]; then
    echo -e "${YELLOW}Warning: No default source directories configured${NC}"
else
    echo -e "${GREEN}Found ${#DEFAULT_SOURCE_DIRS[@]} configured source directories:${NC}"
    for dir in "${DEFAULT_SOURCE_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            echo -e "${GREEN}  ✓ $dir (exists)${NC}"
        else
            echo -e "${YELLOW}  ⚠ $dir (does not exist)${NC}"
        fi
    done
fi

# Check if backup directory exists and is writable
if [ -d "$DEFAULT_BACKUP_DIR" ]; then
    if [ -w "$DEFAULT_BACKUP_DIR" ]; then
        echo -e "${GREEN}✓ Default backup directory is valid and writable: $DEFAULT_BACKUP_DIR${NC}"
    else
        echo -e "${YELLOW}⚠ Default backup directory exists but is not writable: $DEFAULT_BACKUP_DIR${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Default backup directory does not exist: $DEFAULT_BACKUP_DIR${NC}"
    echo -e "${YELLOW}  Creating backup directory...${NC}"
    
    if mkdir -p "$DEFAULT_BACKUP_DIR"; then
        echo -e "${GREEN}✓ Created default backup directory: $DEFAULT_BACKUP_DIR${NC}"
    else
        echo -e "${RED}✗ Failed to create default backup directory${NC}"
    fi
fi

echo -e "\n${CYAN}2. Unit Testing${NC}"

# Test the validation functions
run_test "Sanitize input test" "sanitize_input 'test;rm -rf /' | grep -v 'rm'" 0
run_test "Format size function" "result=\$(format_size 1024); [[ \"\$result\" == \"1.00 KB\" ]] && echo \"Size formatted correctly\"" 0

# Test file system functions
TEST_DIR="$SCRIPT_DIR/test/temp_test_dir"
mkdir -p "$TEST_DIR"

run_test "Directory creation" "mkdir -p \"$TEST_DIR/test_create\" && [ -d \"$TEST_DIR/test_create\" ]" 0

# Create a test file
echo "test content" > "$TEST_DIR/test_file.txt"
run_test "File creation" "[ -f \"$TEST_DIR/test_file.txt\" ]" 0

# Test checksum function
run_test "Checksum calculation" "checksum=\$(calculate_checksum \"$TEST_DIR/test_file.txt\"); [ -n \"\$checksum\" ] && echo \"Checksum: \$checksum\"" 0

# Test directory size calculation
run_test "Directory size calculation" "size=\$(get_directory_size \"$TEST_DIR\"); [ \"\$size\" -gt 0 ] && echo \"Size: \$size bytes\"" 0

# Clean up test files
rm -rf "$TEST_DIR"

echo -e "\n${CYAN}3. Integration Testing${NC}"

# Create a test project structure
TEST_PROJECT_DIR="$SCRIPT_DIR/test/test_project"
mkdir -p "$TEST_PROJECT_DIR/project1/src"
mkdir -p "$TEST_PROJECT_DIR/project1/node_modules"
echo "console.log('Hello World');" > "$TEST_PROJECT_DIR/project1/src/index.js"
echo "test content" > "$TEST_PROJECT_DIR/project1/README.md"

# Create some large files in node_modules to test exclusion
dd if=/dev/zero of="$TEST_PROJECT_DIR/project1/node_modules/large_file.bin" bs=1M count=1 2>/dev/null

# Run a test backup with dry-run
run_test "Dry-run backup test" "$SCRIPT_DIR/backup.sh --source \"$TEST_PROJECT_DIR\" --dry-run --silent" 0

# Run a real backup to a test location
TEST_BACKUP_DIR="$SCRIPT_DIR/test/test_backup"
mkdir -p "$TEST_BACKUP_DIR"

run_test "Full backup test" "$SCRIPT_DIR/backup.sh --source \"$TEST_PROJECT_DIR\" --destination \"$TEST_BACKUP_DIR\" --silent" 0

# Check if backup was created
run_test "Backup verification" "find \"$TEST_BACKUP_DIR\" -name \"*.tar.gz\" | grep -q \".tar.gz\"" 0

# Test the restore functionality in dry-run mode
run_test "Restore dry-run test" "$SCRIPT_DIR/restore.sh --source \"$TEST_BACKUP_DIR\" --dry-run --yes" 0

echo -e "\n${CYAN}4. Security Testing${NC}"

# Run the security audit script
run_test "Security audit" "$SCRIPT_DIR/security-audit.sh" 0

echo -e "\n${CYAN}===== Test Results =====${NC}"
echo -e "Total tests: $TESTS_TOTAL"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"

# Log test results
echo -e "\n===== Test Results =====" >> "$TEST_LOG"
echo "Total tests: $TESTS_TOTAL" >> "$TEST_LOG"
echo "Passed: $TESTS_PASSED" >> "$TEST_LOG"
echo "Failed: $TESTS_FAILED" >> "$TEST_LOG"
echo "Finished at: $(date)" >> "$TEST_LOG"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}✓ All tests passed!${NC}"
else
    echo -e "\n${RED}✗ Some tests failed. Check the log file for details: $TEST_LOG${NC}"
fi

# Clean up test directories
rm -rf "$SCRIPT_DIR/test/test_project"
rm -rf "$SCRIPT_DIR/test/test_backup"

echo -e "\n${CYAN}Tests completed at $(date)${NC}"

exit $TESTS_FAILED
