# Test Directory

This directory contains test results and logs for the WebDev Backup Tool.

## Contents

- **Test History**: A chronological log of all test runs in `test_history.log`
- **Backup Test Results**: Individual backup test runs in `webdev_test_*` directories
- **Cron Test Results**: Cron functionality test runs in `cron_test_*` directories
- **Comprehensive Test Logs**: Results from the full test suite in `test_run_*.log` files
- **Test Configuration**: Default test settings for the backup tool

## Running Tests

### Backup Testing

To run the backup functionality tests:

```bash
../test-backup.sh
```

You can specify a custom source directory for testing:

```bash
../test-backup.sh --source /path/to/custom/source
```

### Cron Testing

To test the cron functionality (without modifying your actual crontab):

```bash
../test-cron.sh
```

### Comprehensive Testing

To run all tests at once, including backup tests, cron tests, and more:

```bash
../run-tests.sh
```

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