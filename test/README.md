# Test Directory

This directory contains test results and logs for the WebDev Backup Tool.

## Contents

- **Test History**: A chronological log of all test runs in `test_history.log`
- **Backup Test Results**: Individual backup test runs in `test_project_*` directories (created and cleaned up by integration tests)
- **Cron Test Results**: Cron functionality test runs (from `npm run test:cron`) in `cron_test_*` directories
- **Test Logs**: Results from the full test suite in `test_log_*.log` files
- **Test Configuration**: Default test settings for the backup tool (uses `test/` and `test/backup_out` when RUNNING_TESTS=1)

## Running Tests

### Backup Testing

To run the backup functionality tests:

```bash
../test-backup.sh
```

Integration tests create their own source directories. For manual backup testing with a custom source, run `../backup.sh --source /path/to/projects --destination ../test/backup --dry-run`.

### Cron Testing

To test the cron functionality (without modifying your actual crontab):

```bash
npm run test:cron
# or: ../archive/src.legacy/test/test-cron.sh
```

### Full Test Suite (unit + integration + security)

To run all tests at once (48 tests; does not include cron or tar tests):

```bash
../run-tests.sh
```

For cron or tar compatibility tests: `npm run test:cron`, `npm run test:tar`

## Test Log

The test history log is stored in reverse chronological order, with the most recent tests at the top of the file. This makes it easy to see the latest test results first.

Each test entry includes:
- Timestamp
- Test type (TEST RUN, CRON TEST, COMPREHENSIVE TEST)
- Test status (PASSED/FAILED)
- Source directory used (for backup tests)
- Test project details (for backup tests)
- Compression statistics (for backup tests)
- Error codes (for failed tests)

## Test Types

1. **Backup Tests**: Validate the core backup functionality
   - Project detection
   - Exclusion patterns 
   - Compression
   - File integrity

2. **Cron Tests**: Verify automated scheduling in dry-run mode
   - Schedule setup
   - Cron syntax validation
   - Backup options integration
   - Schedule modification

3. **Comprehensive Tests**: Run all test types plus additional validation
   - Script syntax and permissions
   - Edge case handling
   - CLI options validation
   - Cleanup functionality

## Notes

- Test files are automatically cleaned up after tests complete
- The test directory itself is preserved for history
- Failed tests are clearly marked in the log
- All tests are designed to be non-destructive and can be run on any system