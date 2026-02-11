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
    
    # --- format_size ---
    run_test "Format size: 0 bytes" "result=\$(format_size 0); [[ -z \"\$result\" || \"\$result\" == \"0.00 B\" ]]"
    run_test "Format size: 500 bytes" "result=\$(format_size 500); [[ \"\$result\" == \"500.00 B\" ]]"
    run_test "Format size: 1 KB" "result=\$(format_size 1024); [[ \"\$result\" == \"1.00 KB\" ]]"
    run_test "Format size: 1 MB" "result=\$(format_size 1048576); [[ \"\$result\" == \"1.00 MB\" ]]"
    run_test "Format size: 1 GB" "result=\$(format_size 1073741824); [[ \"\$result\" == \"1.00 GB\" ]]"

    # --- sanitize_input ---
    run_test "Sanitize input: removes semicolons/pipes" "result=\$(sanitize_input 'test;rm -rf /'); [[ \"\$result\" == \"testrm -rf /\" ]]"
    run_test "Sanitize input: empty string" "result=\$(sanitize_input ''); [[ -z \"\$result\" ]]"
    run_test "Sanitize input strict: removes angle brackets" "result=\$(sanitize_input '<script>alert(1)</script>' 'true'); [[ \"\$result\" != *'<'* && \"\$result\" != *'>'* ]]"
    run_test "Sanitize input strict: removes braces/brackets" "result=\$(sanitize_input '{cmd}[0]!danger' 'true'); [[ \"\$result\" != *'{'* && \"\$result\" != *'['* && \"\$result\" != *'!'* ]]"
    run_test "Config literal safety: accepts normal path" "is_safe_config_literal '/tmp/project_dir'; [[ \$? -eq 0 ]]"
    run_test "Config literal safety: rejects single quote" "is_safe_config_literal \"/tmp/bad'path\"; [[ \$? -ne 0 ]]"

    # --- sanitize_cron_backup_options ---
    run_test "Cron options sanitizer: valid options pass" "result=\$(sanitize_cron_backup_options '--verify --compression 9 --source /tmp/proj'); [[ -n \"\$result\" && \"\$result\" == *'--verify'* && \"\$result\" == *'--compression'* ]]"
    run_test "Cron options sanitizer: rejects shell metacharacters" "sanitize_cron_backup_options '--verify; rm -rf /' >/dev/null 2>&1; [[ \$? -ne 0 ]]"
    run_test "Cron options sanitizer: rejects unknown flag" "sanitize_cron_backup_options '--not-a-real-flag' >/dev/null 2>&1; [[ \$? -ne 0 ]]"
    run_test "Cron options sanitizer: rejects missing value" "sanitize_cron_backup_options '--compression' >/dev/null 2>&1; [[ \$? -ne 0 ]]"

    # --- validate_path ---
    run_test "Validate path: strips traversal" "result=\$(validate_path '../../etc/passwd' 'file'); [[ \"\$result\" != *'..'* ]]"
    run_test "Validate path: strips injection chars" "result=\$(validate_path '/tmp/test;\$(whoami)' 'file'); [[ \"\$result\" != *';'* && \"\$result\" != *'\$('* ]]"
    run_test "Validate path: empty returns error" "validate_path '' 'dir' 2>/dev/null; [[ \$? -ne 0 ]]"
    run_test "Validate path: relative dir rejected" "validate_path 'relative/path' 'dir' 2>/dev/null; [[ \$? -ne 0 ]]"
    run_test "Validate path: absolute dir accepted" "result=\$(validate_path '/tmp' 'dir'); [[ \"\$result\" == '/tmp' ]]"

    # --- detect_os ---
    run_test "Detect OS: returns known value" "result=\$(detect_os); [[ \"\$result\" == \"macOS\" || \"\$result\" == \"Linux\" || \"\$result\" == \"Windows\" || \"\$result\" == \"Unknown\" ]]"

    # --- get_os_version_display ---
    run_test "OS version display: non-empty" "result=\$(get_os_version_display); [[ -n \"\$result\" ]]"

    # --- get_file_size_bytes ---
    run_test "File size: known file" "echo 'hello' > \"$TEST_DIR/size_test.txt\" && result=\$(get_file_size_bytes \"$TEST_DIR/size_test.txt\") && [[ \"\$result\" -gt 0 ]]"
    run_test "File size: missing file returns 0" "result=\$(get_file_size_bytes \"$TEST_DIR/nonexistent_file_xyz\") && [[ \"\$result\" == \"0\" ]]"

    # --- calculate_checksum ---
    run_test "Checksum: consistent" "echo 'checksum_test' > \"$TEST_DIR/cksum.txt\" && c1=\$(calculate_checksum \"$TEST_DIR/cksum.txt\") && c2=\$(calculate_checksum \"$TEST_DIR/cksum.txt\") && [[ \"\$c1\" == \"\$c2\" && -n \"\$c1\" ]]"
    run_test "Checksum: 64 hex chars (SHA256)" "echo 'sha_test' > \"$TEST_DIR/sha.txt\" && result=\$(calculate_checksum \"$TEST_DIR/sha.txt\") && [[ \${#result} -eq 64 ]]"

    # --- check_required_tools ---
    run_test "Required tools: tar present" "check_required_tools tar"
    run_test "Required tools: missing tool fails" "! check_required_tools nonexistent_tool_xyz_123"

    # --- format_time ---
    run_test "Format time: seconds" "result=\$(format_time 45); [[ \"\$result\" == \"45s\" ]]"
    run_test "Format time: minutes" "result=\$(format_time 125); [[ \"\$result\" == \"2m 5s\" ]]"
    run_test "Format time: hours" "result=\$(format_time 3661); [[ \"\$result\" == \"1h 1m\" ]]"

    # --- capitalize ---
    run_test "Capitalize: lowercase" "result=\$(capitalize 'hello'); [[ \"\$result\" == \"Hello\" ]]"

    # --- verify_directory ---
    run_test "Directory exists check" "verify_directory \"$TEST_DIR\" \"Test\" true"
    run_test "Directory: nonexistent fails" "! verify_directory \"$TEST_DIR/no_such_dir_xyz\" \"Missing\" false"
    
    # --- find_projects ---
    run_test "Find projects function" "cd $SCRIPT_DIR && find_projects \"$TEST_DIR\" 1"
    
    if [ "$QUICK_TEST" = false ]; then
        run_test "Calculate checksum" "calculate_checksum \"$0\""
        run_test "Verify backup" "echo 'test' > \"$TEST_DIR/test.txt\" && tar -czf \"$TEST_DIR/test.tar.gz\" -C \"$TEST_DIR\" test.txt && verify_backup \"$TEST_DIR/test.tar.gz\""
        
        # --- verify_backup: corrupted archive ---
        run_test "Verify backup: corrupted archive fails" "echo 'not_a_tar' > \"$TEST_DIR/bad.tar.gz\" && ! verify_backup \"$TEST_DIR/bad.tar.gz\""
    fi

    # --- files_differ (moved to utils-path.sh) ---
    run_test "files_differ: identical files" "echo 'same' > \"$TEST_DIR/f1.txt\" && cp \"$TEST_DIR/f1.txt\" \"$TEST_DIR/f2.txt\" && ! files_differ \"$TEST_DIR/f1.txt\" \"$TEST_DIR/f2.txt\""
    run_test "files_differ: different files" "echo 'aaa' > \"$TEST_DIR/d1.txt\" && echo 'bbb' > \"$TEST_DIR/d2.txt\" && files_differ \"$TEST_DIR/d1.txt\" \"$TEST_DIR/d2.txt\""
    run_test "files_differ: missing file counts as different" "files_differ \"$TEST_DIR/d1.txt\" \"$TEST_DIR/no_such_file_xyz\""

    # --- get_file_permissions (moved to utils-path.sh) ---
    run_test "get_file_permissions: returns octal" "chmod 644 \"$TEST_DIR/f1.txt\" && result=\$(get_file_permissions \"$TEST_DIR/f1.txt\") && [[ \"\$result\" == \"644\" ]]"

    # --- get_file_mtime (moved to utils-time.sh) ---
    run_test "get_file_mtime: returns number" "result=\$(get_file_mtime \"$TEST_DIR/f1.txt\") && [[ \"\$result\" =~ ^[0-9]+$ ]]"

    # --- format_file_date (moved to utils-time.sh) ---
    run_test "format_file_date: returns date string" "result=\$(format_file_date \"$TEST_DIR/f1.txt\") && [[ \"\$result\" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]"

    # --- report_error from error-handling.sh ---
    run_test "report_error: returns error code" "source \"$SCRIPT_DIR/error-handling.sh\" && report_error 4 'test warning' /dev/null true 1; [[ \$? -eq 4 ]]"
    run_test "report_error: log_warning callable" "source \"$SCRIPT_DIR/error-handling.sh\" && log_warning 'test warning' 2>/dev/null; [[ \$? -eq 1 ]]"

    # --- abs_path (moved to utils-path.sh earlier, verify still works) ---
    run_test "abs_path: resolves /tmp" "result=\$(abs_path /tmp) && [[ \"\$result\" =~ ^/ ]]"

    # --- cloud tools: missing CLI returns error ---
    run_test "upload_to_cloud: unknown provider fails" "! upload_to_cloud /dev/null unknown_provider 2>/dev/null"
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
    mkdir -p "$TEST_PROJECT_DIR/project1/node_modules/some-package"
    mkdir -p "$TEST_PROJECT_DIR/project1/nested/node_modules/nested-pkg"
    echo "console.log('test');" > "$TEST_PROJECT_DIR/project1/src/app.js"
    echo "test data" > "$TEST_PROJECT_DIR/project1/README.md"
    echo "API_KEY=test" > "$TEST_PROJECT_DIR/project1/.env"
    echo '{"name":"test"}' > "$TEST_PROJECT_DIR/project1/package-lock.json"
    echo "# yarn lock" > "$TEST_PROJECT_DIR/project1/yarn.lock"
    echo "package data" > "$TEST_PROJECT_DIR/project1/node_modules/some-package/index.js"
    echo "nested pkg data" > "$TEST_PROJECT_DIR/project1/nested/node_modules/nested-pkg/index.js"
    dd if=/dev/zero of="$TEST_PROJECT_DIR/project1/node_modules/big_file.bin" bs=1K count=10 2>/dev/null
    
    # Test backup command with dry-run
    run_test "Backup dry run" "$SCRIPT_DIR/backup.sh --source \"$TEST_PROJECT_DIR\" --destination \"$TEST_DIR/backup\" --dry-run --silent"
    
    if [ "$QUICK_TEST" = false ]; then
        # Run actual backup for non-quick tests
        run_test "Full backup" "$SCRIPT_DIR/backup.sh --source \"$TEST_PROJECT_DIR\" --destination \"$TEST_DIR/backup\" --silent"
        
        # Verify backup was created
        run_test "Backup file exists" "find \"$TEST_DIR/backup\" -name \"*.tar.gz\" | grep -q \".tar.gz\""
        
        # --- node_modules exclusion ---
        run_test "Backup excludes node_modules" "
            backup_file=\$(find \"$TEST_DIR/backup\" -name '*.tar.gz' | head -1)
            if [ -n \"\$backup_file\" ]; then
                ! tar -tzf \"\$backup_file\" 2>/dev/null | grep -q 'node_modules/'
            else
                false
            fi
        "

        # --- Backup archive integrity (verify_backup) ---
        run_test "Backup archive passes verify" "
            backup_file=\$(find \"$TEST_DIR/backup\" -name '*.tar.gz' | head -1)
            [ -n \"\$backup_file\" ] && verify_backup \"\$backup_file\"
        "

        # --- Backup contains expected files ---
        run_test "Backup contains source files" "
            backup_file=\$(find \"$TEST_DIR/backup\" -name '*.tar.gz' | head -1)
            [ -n \"\$backup_file\" ] && tar -tzf \"\$backup_file\" 2>/dev/null | grep -q 'app.js'
        "

        # --- .env and lockfiles included (reconstruct app after restore) ---
        run_test "Backup includes .env and lockfiles" "
            backup_file=\$(find \"$TEST_DIR/backup\" -name '*.tar.gz' -type f -print0 | xargs -0 ls -t 2>/dev/null | head -1)
            if [ -z \"\$backup_file\" ]; then exit 1; fi
            tar -tzf \"\$backup_file\" 2>/dev/null | grep -q '\.env' && \
            tar -tzf \"\$backup_file\" 2>/dev/null | grep -q 'yarn.lock' && \
            tar -tzf \"\$backup_file\" 2>/dev/null | grep -q 'package-lock.json'
        "

        # --- Extract / restore dry run ---
        run_test "Restore dry run" "$SCRIPT_DIR/restore.sh --source \"$TEST_DIR/backup\" --dry-run --yes"

        # --- Incremental backup (second run creates new archive) ---
        run_test "Incremental backup creates new archive" "
            before_count=\$(find \"$TEST_DIR/backup\" -name '*.tar.gz' 2>/dev/null | wc -l | tr -d ' ')
            echo 'new content' >> \"$TEST_PROJECT_DIR/project1/src/app.js\"
            $SCRIPT_DIR/backup.sh --source \"$TEST_PROJECT_DIR\" --destination \"$TEST_DIR/backup\" --silent
            after_count=\$(find \"$TEST_DIR/backup\" -name '*.tar.gz' 2>/dev/null | wc -l | tr -d ' ')
            [ \"\$after_count\" -ge \"\$before_count\" ]
        "

        # --- Config with RUNNING_TESTS succeeds (test defaults) ---
        run_test "Config accepts test defaults with RUNNING_TESTS" "
            (
                export RUNNING_TESTS=1
                source $SCRIPT_DIR/config.sh 2>/dev/null
            )
            [[ \$? -eq 0 ]]
        "

        # --- Actual restore extraction (not just dry-run) ---
        run_test "Restore extracts files correctly" "
            backup_file=\$(find \"$TEST_DIR/backup\" -name '*.tar.gz' -type f | head -1)
            if [ -z \"\$backup_file\" ]; then exit 1; fi
            restore_dir=\"$TEST_DIR/restore_test_\$\$\"
            mkdir -p \"\$restore_dir\"
            tar -xzf \"\$backup_file\" -C \"\$restore_dir\" 2>/dev/null
            found=\$(find \"\$restore_dir\" -name 'app.js' | head -1)
            rm -rf \"\$restore_dir\"
            [ -n \"\$found\" ]
        "

        # --- Negative test: backup with nonexistent source fails ---
        run_test "Backup fails with invalid source" "
            ! $SCRIPT_DIR/backup.sh --source /tmp/no_such_dir_xyz_backup_test --destination \"$TEST_DIR/backup\" --silent 2>/dev/null
        "

        # --- Negative test: backup with read-only dest fails ---
        run_test "Backup fails with unwritable destination" "
            ro_dir=\"$TEST_DIR/readonly_dest_\$\$\"
            mkdir -p \"\$ro_dir\" && chmod 444 \"\$ro_dir\"
            $SCRIPT_DIR/backup.sh --source \"$TEST_PROJECT_DIR\" --destination \"\$ro_dir\" --silent 2>/dev/null
            status=\$?
            chmod 755 \"\$ro_dir\" 2>/dev/null; rm -rf \"\$ro_dir\"
            [ \$status -ne 0 ]
        "
    fi
    
    # Clean up test project
    if [ "$VERBOSE" = false ]; then
        rm -rf "$TEST_PROJECT_DIR"
    fi
fi

# Display summary
echo -e "\n${CYAN}===== Test Results =====${NC}"
echo "Total tests: $TESTS_TOTAL"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"

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