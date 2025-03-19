#!/bin/bash
# test-tar-compatibility.sh - Test tar command compatibility across different systems

# Source the shared modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../core/config.sh"
source "$SCRIPT_DIR/../utils/utils.sh"
source "$SCRIPT_DIR/../ui/ui.sh"
source "$SCRIPT_DIR/../core/fs.sh"

# Create test directory
TEST_RUN_DIR="$TEST_DIR/test_tar_$(date +$DATE_FORMAT)"
mkdir -p "$TEST_RUN_DIR"
TEST_LOG="$TEST_RUN_DIR/test-tar.log"
touch "$TEST_LOG"

echo -e "${CYAN}===== WebDev Backup Tar Compatibility Test =====\n${NC}"
echo -e "This test verifies tar command compatibility across different systems"
echo -e "Test log: $TEST_LOG\n"

# Log system information
echo "===== System Information =====" >> "$TEST_LOG"
echo "Date: $(date)" >> "$TEST_LOG"
echo "Hostname: $(hostname)" >> "$TEST_LOG"
echo "Kernel: $(uname -r)" >> "$TEST_LOG"
echo "OS: $(uname -o 2>/dev/null || uname -s)" >> "$TEST_LOG"
echo "Distribution: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'=' -f2 | tr -d '"' || echo "Unknown")" >> "$TEST_LOG"
echo "Tar version: $(tar --version | head -1)" >> "$TEST_LOG"
echo "Gzip version: $(gzip --version | head -1)" >> "$TEST_LOG"
if command -v pigz >/dev/null 2>&1; then
    echo "Pigz version: $(pigz --version 2>&1)" >> "$TEST_LOG"
    PIGZ_AVAILABLE=true
else
    echo "Pigz: Not installed" >> "$TEST_LOG"
    PIGZ_AVAILABLE=false
fi
echo "" >> "$TEST_LOG"

# Initialize test results
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test function to run a tar command and check result
test_tar_command() {
    local name=$1
    local command=$2
    local expected_result=${3:-0}  # 0 = success by default
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    echo -e "\n${CYAN}Running test: ${name}${NC}"
    echo "===== Test: $name =====" >> "$TEST_LOG"
    echo "Command: $command" >> "$TEST_LOG"
    
    # Use a subshell to capture output and status
    (eval "$command") >> "$TEST_LOG" 2>&1
    local result=$?
    
    if [ "$result" -eq "$expected_result" ]; then
        echo -e "${GREEN}✓ Test passed${NC}"
        echo "Result: PASSED (exit code: $result, expected: $expected_result)" >> "$TEST_LOG"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ Test failed${NC}"
        echo "Result: FAILED (exit code: $result, expected: $expected_result)" >> "$TEST_LOG"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Create test data
echo "Creating test data..." | tee -a "$TEST_LOG"
mkdir -p "$TEST_RUN_DIR/test-src/project1/src"
mkdir -p "$TEST_RUN_DIR/test-src/project1/node_modules"
mkdir -p "$TEST_RUN_DIR/test-src/project2/src"
mkdir -p "$TEST_RUN_DIR/test-src/project2/node_modules"

# Create some test files
echo "console.log('Hello world');" > "$TEST_RUN_DIR/test-src/project1/src/index.js"
echo '{"name": "project1"}' > "$TEST_RUN_DIR/test-src/project1/package.json"
dd if=/dev/urandom of="$TEST_RUN_DIR/test-src/project1/node_modules/large-file.bin" bs=1M count=1 2>> "$TEST_LOG"

echo "console.log('Hello again');" > "$TEST_RUN_DIR/test-src/project2/src/app.js"
echo '{"name": "project2"}' > "$TEST_RUN_DIR/test-src/project2/package.json"
dd if=/dev/urandom of="$TEST_RUN_DIR/test-src/project2/node_modules/large-file.bin" bs=1M count=1 2>> "$TEST_LOG"

# Test directory
mkdir -p "$TEST_RUN_DIR/test-dest"

echo -e "\n${CYAN}Starting tar compatibility tests...${NC}"

# Test 1: Basic GNU tar functionality
test_tar_command "Basic tar create" "tar -cf $TEST_RUN_DIR/test-dest/basic.tar -C $TEST_RUN_DIR/test-src ."

# Test 2: Basic GNU tar with gzip
test_tar_command "Basic tar with gzip" "tar -czf $TEST_RUN_DIR/test-dest/basic.tar.gz -C $TEST_RUN_DIR/test-src ."

# Test 3: Tar with exclusion pattern
test_tar_command "Tar with exclusion" "tar -czf $TEST_RUN_DIR/test-dest/exclude.tar.gz --exclude='*/node_modules/*' -C $TEST_RUN_DIR/test-src ."

# Test 4: Tar extract
test_tar_command "Tar extract" "mkdir -p $TEST_RUN_DIR/test-extract && tar -xf $TEST_RUN_DIR/test-dest/basic.tar -C $TEST_RUN_DIR/test-extract"

# Test 5: Tar list
test_tar_command "Tar list contents" "tar -tf $TEST_RUN_DIR/test-dest/basic.tar > /dev/null"

if [ "$PIGZ_AVAILABLE" = true ]; then
    # Test 6: Tar with pigz
    test_tar_command "Tar with pigz" "tar --use-compress-program=pigz -cf $TEST_RUN_DIR/test-dest/pigz.tar.gz -C $TEST_RUN_DIR/test-src ."
    
    # Test 7: Tar with pigz and compression level
    test_tar_command "Tar with pigz compression level" "tar --use-compress-program='pigz -9' -cf $TEST_RUN_DIR/test-dest/pigz-9.tar.gz -C $TEST_RUN_DIR/test-src ."
fi

# Test 8: Create incremental backup
test_tar_command "Incremental backup" "touch $TEST_RUN_DIR/test-dest/snapshot.snar && tar --listed-incremental=$TEST_RUN_DIR/test-dest/snapshot.snar -czf $TEST_RUN_DIR/test-dest/incremental.tar.gz -C $TEST_RUN_DIR/test-src ."

# Test 9: Create differential backup
test_tar_command "Differential backup" "cp $TEST_RUN_DIR/test-dest/snapshot.snar $TEST_RUN_DIR/test-dest/diff-snapshot.snar && tar --listed-incremental=$TEST_RUN_DIR/test-dest/diff-snapshot.snar -czf $TEST_RUN_DIR/test-dest/differential.tar.gz -C $TEST_RUN_DIR/test-src ."

# Test 10: Our implementation in fs.sh
echo -e "\n${CYAN}Testing our implementation in fs.sh...${NC}"
echo "===== Testing fs.sh Implementation =====" >> "$TEST_LOG"

# Test create_backup_archive function
if create_backup_archive "$TEST_RUN_DIR/test-src" "project1" "$TEST_RUN_DIR/test-dest/fs-backup.tar.gz" "$TEST_LOG" 6 "*/node_modules/*" 1 false; then
    echo -e "${GREEN}✓ create_backup_archive test passed${NC}"
    echo "Result: create_backup_archive PASSED" >> "$TEST_LOG"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ create_backup_archive test failed${NC}"
    echo "Result: create_backup_archive FAILED" >> "$TEST_LOG"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_TOTAL=$((TESTS_TOTAL + 1))

# Test create_incremental_backup function
if create_incremental_backup "$TEST_RUN_DIR/test-src" "project1" "$TEST_RUN_DIR/test-dest/fs-incremental.tar.gz" "$TEST_RUN_DIR/test-dest/fs-snapshot.snar" "$TEST_LOG" 6; then
    echo -e "${GREEN}✓ create_incremental_backup test passed${NC}"
    echo "Result: create_incremental_backup PASSED" >> "$TEST_LOG"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ create_incremental_backup test failed${NC}"
    echo "Result: create_incremental_backup FAILED" >> "$TEST_LOG"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_TOTAL=$((TESTS_TOTAL + 1))

# Test create_differential_backup function
if create_differential_backup "$TEST_RUN_DIR/test-src" "project1" "$TEST_RUN_DIR/test-dest/fs-differential.tar.gz" "$TEST_RUN_DIR/test-dest/fs-snapshot.snar" "$TEST_LOG" 6; then
    echo -e "${GREEN}✓ create_differential_backup test passed${NC}"
    echo "Result: create_differential_backup PASSED" >> "$TEST_LOG"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ create_differential_backup test failed${NC}"
    echo "Result: create_differential_backup FAILED" >> "$TEST_LOG"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_TOTAL=$((TESTS_TOTAL + 1))

# Test thorough verification
echo -e "\n${CYAN}Testing thorough backup verification...${NC}"
echo "===== Testing Thorough Verification =====" >> "$TEST_LOG"

if verify_backup "$TEST_RUN_DIR/test-dest/fs-backup.tar.gz" "$TEST_LOG" false true; then
    echo -e "${GREEN}✓ Thorough verification test passed${NC}"
    echo "Result: thorough verification PASSED" >> "$TEST_LOG"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ Thorough verification test failed${NC}"
    echo "Result: thorough verification FAILED" >> "$TEST_LOG"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_TOTAL=$((TESTS_TOTAL + 1))

# Summary
echo -e "\n${CYAN}===== Tar Compatibility Test Summary =====${NC}"
echo "Total tests: $TESTS_TOTAL"
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"

echo -e "\n===== Test Summary =====" >> "$TEST_LOG"
echo "Total tests: $TESTS_TOTAL" >> "$TEST_LOG"
echo "Tests passed: $TESTS_PASSED" >> "$TEST_LOG"
echo "Tests failed: $TESTS_FAILED" >> "$TEST_LOG"
echo "Completed at: $(date)" >> "$TEST_LOG"

if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "\n${GREEN}All compatibility tests PASSED!${NC}"
    
    # Add to test history
    mkdir -p "$TEST_DIR"
    TEST_ENTRY="$(date '+%Y-%m-%d %H:%M:%S') - TAR COMPATIBILITY TEST: SUCCESS\n"
    TEST_ENTRY+="  Tests: ${TESTS_PASSED} passed, ${TESTS_FAILED} failed\n"
    TEST_ENTRY+="  Tar version: $(tar --version | head -1 | cut -d' ' -f4)\n"
    TEST_ENTRY+="  Log: ${TEST_LOG}\n"
    TEST_ENTRY+="--------------------------------------------------\n\n"
    
    # Update history in reverse chronological order
    if [ -f "$TEST_HISTORY_LOG" ]; then
        TEMP_LOG=$(mktemp)
        echo -e "$TEST_ENTRY" > "$TEMP_LOG"
        cat "$TEST_HISTORY_LOG" >> "$TEMP_LOG"
        mv "$TEMP_LOG" "$TEST_HISTORY_LOG"
    else
        echo -e "$TEST_ENTRY" > "$TEST_HISTORY_LOG"
    fi
    
    exit 0
else
    echo -e "\n${RED}Some compatibility tests FAILED. Check the log for details: $TEST_LOG${NC}"
    
    # Add to test history
    mkdir -p "$TEST_DIR"
    TEST_ENTRY="$(date '+%Y-%m-%d %H:%M:%S') - TAR COMPATIBILITY TEST: FAILED\n"
    TEST_ENTRY+="  Tests: ${TESTS_PASSED} passed, ${TESTS_FAILED} failed\n"
    TEST_ENTRY+="  Tar version: $(tar --version | head -1 | cut -d' ' -f4)\n"
    TEST_ENTRY+="  Log: ${TEST_LOG}\n"
    TEST_ENTRY+="--------------------------------------------------\n\n"
    
    # Update history in reverse chronological order
    if [ -f "$TEST_HISTORY_LOG" ]; then
        TEMP_LOG=$(mktemp)
        echo -e "$TEST_ENTRY" > "$TEMP_LOG"
        cat "$TEST_HISTORY_LOG" >> "$TEMP_LOG"
        mv "$TEMP_LOG" "$TEST_HISTORY_LOG"
    else
        echo -e "$TEST_ENTRY" > "$TEST_HISTORY_LOG"
    fi
    
    exit 1
fi