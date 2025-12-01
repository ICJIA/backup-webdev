# WebDev Backup Tool

A robust backup solution for web development projects that supports multiple source directories, incremental backups, compression, integrity verification, and cloud storage integration.

## Features

- **Multi-Directory Backup**: Back up projects from multiple source directories
- **Flexible Backup Types**: Full, incremental, or differential backups
- **Quick Backup**: One-click backup using default settings
- **Compression**: Optimized compression with multi-threading support (via pigz)
- **Verification**: Integrity verification of backup archives (during backup and before restore)
- **Exclusion Rules**: Automatically excludes node_modules and other large dependencies
- **Cloud Integration**: Upload backups to AWS S3, DigitalOcean Spaces, Dropbox, or Google Drive
- **Modular Reporting**: Comprehensive reporting system with HTML reports, email notifications, and charts
- **File Structure Visualization**: Interactive modals showing ASCII file structure diagrams
- **Dashboard**: Visual dashboard for backup statistics and forecasting
- **Backup Comparison**: Compare two backups to see what changed (added, deleted, modified files)
- **Restore with Validation**: Automatic backup integrity checks before restore operations
- **Version Checking**: Script compatibility verification to prevent version mismatches
- **Enhanced Error Messages**: Context-aware error messages with actionable troubleshooting tips
- **Standardized Logging**: Consistent log format with log levels (INFO, WARNING, ERROR, DEBUG)
- **Security**: Built-in security features and encryption support

## Installation

### Requirements

- Bash shell (version 4.0 or later)
- tar, gzip (required)
- pigz (optional, for multi-threaded compression)
- gnuplot (optional, for visualization)
- AWS CLI (optional, for cloud storage)

### Setup

#### Automated Installation (Recommended)

Run the installation script for automated setup:

```bash
git clone https://github.com/yourusername/backup-webdev.git
cd backup-webdev
./install.sh
```

The installation script will:
- Check for required tools (bash, tar, gzip)
- Check for optional tools (pigz, gnuplot, aws)
- Make all scripts executable
- Create necessary directories
- Validate configuration
- Optionally set up shell aliases
- Optionally configure security settings

#### Manual Installation

If you prefer manual setup:

1. Clone the repository:

   ```bash
   git clone https://github.com/yourusername/backup-webdev.git
   ```

2. Make the scripts executable:

   ```bash
   cd backup-webdev
   chmod +x *.sh
   ```

3. Set up shell alias for easy access:

   ```bash
   ./setup-alias.sh
   ```

4. Verify installation and configuration:
   ```bash
   ./check-config.sh
   ```

## Basic Usage

### Interactive Mode

Run the tool in interactive mode:

```bash
./webdev-backup.sh
```

### Quick Backup

Use the Quick Backup option for a streamlined experience:

```bash
./webdev-backup.sh
# Then select "1) Quick Backup (Using Default Settings)"
```

Or directly from command line:

```bash
./backup.sh --quick
```

### Command-Line Options

Run a silent backup with default settings:

```bash
./backup.sh --silent
```

Run an incremental backup with verification:

```bash
./backup.sh --incremental --verify
```

Back up a specific directory:

```bash
./backup.sh --source ~/projects
```

## Advanced Usage

### Multi-Directory Backups

Back up multiple source directories:

```bash
./backup.sh --sources ~/webdev,~/projects --verify
```

### Differential Backups

Create differential backups (changes since last full backup):

```bash
./backup.sh --differential
```

### Cloud Storage

Upload backup to cloud storage:

```bash
./backup.sh --cloud do --silent
```

### Restore Backups

Restore the latest backup (with automatic integrity validation):

```bash
./restore.sh --latest
```

Restore a specific project from backup:

```bash
./restore.sh --project myproject --dest ~/restored
```

Restore with integrity validation skipped (not recommended):

```bash
./restore.sh --latest --skip-verify
```

**Note:** By default, the restore process validates backup integrity before extraction. This includes:
- Archive integrity checks (tar validation)
- SHA256 checksum verification (if available)
- File corruption detection

Use `--skip-verify` only if you're certain the backup is valid and need faster restore times.

### Compare Backups

Compare two backups to see what changed:

```bash
# Compare latest backup with previous one
./compare-backups.sh --backup1 latest --backup2 latest

# Compare specific backups
./compare-backups.sh --backup1 /mnt/e/backups/wsl2_backup_2025-03-29_10-00-00 --backup2 /mnt/e/backups/wsl2_backup_2025-03-28_10-00-00

# Compare specific project only
./compare-backups.sh --backup1 latest --backup2 latest --project myproject

# Output in JSON format
./compare-backups.sh --backup1 latest --backup2 latest --format json

# Show only changed files
./compare-backups.sh --backup1 latest --backup2 latest --only-changes
```

The comparison tool shows:
- **Added files**: Files present in backup2 but not in backup1
- **Deleted files**: Files present in backup1 but not in backup2
- **Common files**: Files present in both backups
- **Summary statistics**: Total counts of changes

### Run Tests

Run all tests to verify system:

```bash
./run-all-tests.sh
```

Run specific tests:

```bash
./test-backup.sh --quick
```

## Configuration

The configuration is stored in `config.sh`. You can modify default settings:

- Source directories (`DEFAULT_SOURCE_DIRS`)
- Backup destination (`DEFAULT_BACKUP_DIR`)
- Compression level
- Email notification settings
- Cloud storage preferences
- Version information (`VERSION`)

### Version Management

The tool includes version checking to ensure script compatibility:

- Version is defined in `config.sh` as `VERSION="1.7.0"`
- Scripts can check version compatibility using `check_version_compatibility()` from `utils.sh`
- Version mismatches are detected and reported with warnings

### Logging Configuration

The tool uses standardized logging with the following features:

- **Log Format**: `[TIMESTAMP] [LEVEL] MESSAGE`
- **Log Levels**: INFO, WARNING, ERROR, DEBUG
- **Color Coding**: Logs are color-coded by level for better readability
- **Debug Mode**: Set `DEBUG_MODE=true` environment variable to enable debug logging

## File Structure

**Note:** The active scripts are located in the root directory. The `src/` directory has been archived to `archive/src.legacy/`. All package.json scripts and main entry points reference root-level scripts.

### Script Types

Scripts are categorized as:

- **Entry Point Scripts** (Executable): These are standalone scripts that can be run directly:
  - `webdev-backup.sh` - Main launcher
  - `backup.sh` - Core backup
  - `restore.sh` - Restoration
  - `quick-backup.sh` - Quick backup
  - `cleanup.sh` - Maintenance
  - `encryption.sh` - Encryption utilities
  - `configure-cron.sh` - Cron setup
  - All test scripts (`test-*.sh`, `run-*.sh`)

- **Module Scripts** (Sourced): These are library scripts that provide functions to other scripts:
  - `config.sh` - Configuration variables and version information
  - `utils.sh` - Utility functions including version checking
  - `fs.sh` - Filesystem operations
  - `ui.sh` - User interface functions
  - `reporting.sh` - Main reporting interface (sources specialized modules)
  - `reporting-html.sh` - HTML report generation module
  - `reporting-email.sh` - Email report generation module
  - `reporting-charts.sh` - Chart and visualization generation module
  - `error-handling.sh` - Error handling with enhanced messages

Below is a comprehensive list of all files in the project and their purposes:

| Filename              | Purpose                           | Notes                                                  |
| --------------------- | --------------------------------- | ------------------------------------------------------ |
| webdev-backup.sh      | Main launcher for the backup tool | Provides interactive menu interface                    |
| backup.sh             | Core backup script                | Performs full, incremental, or differential backups    |
| restore.sh            | Restoration utility               | Restores full or partial backups from any backup point |
| config.sh             | Configuration file                | Defines paths, directories, and default settings       |
| find-projects.sh      | Project discovery tool            | Locates valid projects in source directories           |
| encryption.sh         | Encryption utilities              | Encrypts/decrypts backups using OpenSSL                |
| configure-cron.sh     | Cron job manager                  | Sets up automated backup schedules                     |
| cleanup.sh            | Maintenance utility               | Removes old backups and temporary files                |
| ui.sh                 | User interface functions          | Contains UI components for the interactive interface   |
| utils.sh              | Utility functions                 | Shared helper functions used across scripts            |
| fs.sh                 | Filesystem utilities              | Functions for file and directory operations            |
| error-handling.sh     | Error management                  | Standardized error handling and reporting              |
| reporting.sh          | Reporting functions               | Main reporting interface (sources specialized modules)   |
| reporting-html.sh     | HTML report module                | HTML report generation (sourced by reporting.sh)         |
| reporting-email.sh    | Email report module               | Email report generation (sourced by reporting.sh)        |
| reporting-charts.sh   | Chart generation module           | Chart and visualization generation (sourced by reporting.sh) |
| compare-backups.sh    | Backup comparison tool            | Compare two backups to show differences                  |
| security-audit.sh     | Security checker                  | Analyzes permissions and security issues               |
| secure-permissions.sh | Permission manager                | Sets appropriate permissions on backup files           |
| secure-secrets.sh     | Secret management                 | Handles encryption keys and sensitive data             |
| setup-alias.sh        | Command alias setup               | Creates shell aliases for easy tool access             |
| check-config.sh       | Configuration validator           | Verifies configuration correctness                     |
| dirs-status.sh        | Directory status tool             | Reports on source/destination directories              |
| quick-backup.sh       | Quick backup script               | Standalone quick backup with default settings          |
| cleanup-backup-files.sh | Backup file organizer            | Organizes structure files and logs in backup directories |
| run-tests.sh          | Test runner                       | Executes specific test suites                          |
| run-all-tests.sh      | Comprehensive test suite          | Runs all tests to verify functionality                 |
| test-backup.sh        | Backup tester                     | Tests backup functionality specifically                |
| test-vars.sh          | Variable tester                   | Tests environment variables and configuration          |
| update-changelog.sh   | Changelog manager                 | Updates CHANGELOG.md with git commits                   |
| debug-backup.sh       | Debug utility                     | Debugging tool for backup operations                   |
| set-permissions.sh    | Permission setter                 | Sets file permissions (legacy, use secure-permissions.sh) |

## Adding a New Source Directory

You can easily add new source directories:

1. Through the menu system: Select "m) Manage Source Directories" and "1) Add new source directory"
2. Directly edit `config.sh` and add to the `DEFAULT_SOURCE_DIRS` array
3. Use the `--sources` command-line option with comma-separated paths

## Security

For secure operations:

1. Run `secure-permissions.sh` to set proper file permissions
2. Run `secure-secrets.sh` to set up secure credential storage
3. Run `security-audit.sh` periodically to check for issues

### Security Features

The backup tool includes multiple security enhancements:

#### Encryption Security
✅ **Authenticated Encryption Mode**: Uses AES-256-GCM with authentication instead of insecure CBC mode.  
✅ **Strong Key Derivation**: Implements PBKDF2 with 10,000 iterations for password-based encryption.  
✅ **Improved Password Hashing**: Uses a stronger key stretching approach instead of simple SHA-256.  
✅ **Secure Key Management**: Adds SHA-256 digest for more secure key derivation.

#### File Permissions
✅ **Restrictive umask**: Sets `umask 027` across scripts to ensure secure default permissions.  
✅ **Private Configuration**: Config files use 640 permissions (group-readable only).  
✅ **Protected Directories**: Directories use 750 permissions (no world access).  
✅ **Race Condition Protection**: Uses temporary files with proper permissions for secure file operations.  
✅ **Secure Cleanup**: Implements secure deletion of temporary files containing sensitive data.

#### Command Injection Protection
✅ **Path Sanitization**: Complete protection against directory traversal attacks.  
✅ **Input Sanitization**: Comprehensive input validation with configurable strictness levels.  
✅ **Shell Command Safety**: Proper escaping in all shell commands to prevent injection.  
✅ **Safer Email Handling**: Email notifications designed to prevent command injection.  
✅ **Direct Command Execution**: Eliminates potentially unsafe temporary script creation.

#### Secure Archive Handling
✅ **Archive Validation**: Checks for path traversal and absolute paths in archives.  
✅ **Filename Validation**: Detects malicious characters in extracted filenames.  
✅ **Safe Extraction**: Uses `--no-same-owner` and `--no-absolute-names` for safer tar extraction.

## Maintenance and Development

The backup tool includes scripts to help with maintenance and development:

### Organizing Backup Files

The `cleanup-backup-files.sh` script organizes the text files generated during backup:

```bash
./cleanup-backup-files.sh           # Clean up the latest backup directory
./cleanup-backup-files.sh --all     # Clean up all backup directories
./cleanup-backup-files.sh --dry-run # Show what would be done without making changes
```

This script:
- Moves structure files to a `structures/` subdirectory
- Moves log files to a `logs/` subdirectory
- Creates a metadata.json file with information about the backup
- Can be configured to run automatically after each backup

### Changelog Management

The `update-changelog.sh` script helps manage the project's git repository and changelog:

```bash
./update-changelog.sh  # Updates CHANGELOG.md with commits and pushes to git
```

This script:
- Pulls the latest changes from the remote repository
- Pushes local commits to the remote
- Updates CHANGELOG.md with commit messages and SHAs
- Optionally creates version tags with semantic versioning
- Organizes the changelog into released and unreleased sections

## Enhanced Reporting

The backup tool uses a modular reporting system for better maintainability and extensibility. The reporting functionality is split into specialized modules:

### Modular Reporting Architecture

- **`reporting.sh`**: Main reporting interface that sources specialized modules
- **`reporting-html.sh`**: HTML report generation (650+ lines)
- **`reporting-email.sh`**: Email report generation
- **`reporting-charts.sh`**: Chart and visualization generation (450+ lines)

This modular structure makes the codebase more maintainable and allows for easier testing and updates.

### HTML Reports

The backup tool generates comprehensive HTML reports with several advanced features:

#### Project Directory Grouping

Projects are organized by their source directories in reports, making it easier to understand which projects come from which locations. Within each directory group, projects are alphabetically sorted for easy reference.

#### Interactive Project Details

Each project in the HTML report is interactive:

1. Click on any project row to open a modal with detailed information
2. View the project's complete file structure in an ASCII tree format
3. See detailed statistics including compression ratio and file counts
4. Navigate between projects using a tabbed interface

#### Email Reports

Email reports provide concise summaries suitable for email notifications:

```bash
# Email reports are automatically generated and can be sent via:
# - Email notification functions in utils.sh
# - Integration with sendmail or mail commands
```

#### Charts and Visualizations

The reporting system can generate charts and visualizations (requires gnuplot):

- Backup size history charts
- Storage forecast predictions
- Visual dashboard with statistics

All chart generation includes safe fallbacks if gnuplot is not available.

### Quick Backup Feature

The main menu now includes a Quick Backup option that:

1. Uses all default settings configured in `config.sh`
2. Shows a summary of what will be backed up before proceeding
3. Provides a streamlined experience with minimal user interaction
4. Skips verification to maximize speed and performance

## Troubleshooting

### Common Issues and Solutions

#### Permission Errors

**Problem:** Scripts fail with "Permission denied" errors.

**Solutions:**
```bash
# Make all scripts executable
chmod +x *.sh

# Or use the provided script
./secure-permissions.sh
```

#### Path Not Found Errors

**Problem:** Scripts can't find source directories or backup destination.

**Solutions:**
1. Check your configuration:
   ```bash
   ./check-config.sh
   ```

2. Verify source directories exist:
   ```bash
   ./dirs-status.sh
   ```

3. Update `config.sh` with correct paths:
   ```bash
   # Edit DEFAULT_SOURCE_DIRS and DEFAULT_BACKUP_DIR
   nano config.sh
   ```

#### Cloud Upload Failures

**Problem:** Backups fail to upload to cloud storage.

**Solutions:**
1. Verify credentials are set in `secrets.sh`:
   ```bash
   # Copy example and add your credentials
   cp secrets.sh.example secrets.sh
   nano secrets.sh
   ```

2. Check AWS CLI is installed (for S3/Spaces):
   ```bash
   aws --version
   # If not installed: sudo apt-get install awscli
   ```

3. Test connection manually:
   ```bash
   aws s3 ls  # For S3
   ```

#### Test Script Failures

**Problem:** `npm run test:cron` or `npm run test:tar` fail.

**Solutions:**
1. Verify test scripts exist:
   ```bash
   ls -la archive/src.legacy/test/
   ```

2. Check script permissions:
   ```bash
   chmod +x archive/src.legacy/test/*.sh
   ```

3. Run with verbose output:
   ```bash
   bash -x archive/src.legacy/test/test-cron.sh
   ```

#### Backup Directory Full

**Problem:** Backup fails due to insufficient disk space.

**Solutions:**
1. Check available space:
   ```bash
   df -h /mnt/e/backups  # Or your backup directory
   ```

2. Clean up old backups:
   ```bash
   ./cleanup.sh --days 30  # Remove backups older than 30 days
   ```

3. Change backup location:
   ```bash
   ./backup.sh --destination /path/to/larger/volume
   ```

#### Quick Backup Freezing

**Problem:** Quick backup appears to hang or freeze.

**Solutions:**
1. Check if it's actually running (may take time for large projects):
   ```bash
   ps aux | grep backup
   ```

2. Use standard backup with progress:
   ```bash
   ./backup.sh  # Interactive mode shows progress
   ```

3. Check logs:
   ```bash
   tail -f logs/backup_history.log
   ```

#### Restore Validation Failures

**Problem:** Restore fails with "Backup validation failed" or "Checksum mismatch".

**Solutions:**
1. The backup may be corrupted - try another backup:
   ```bash
   ./restore.sh --list  # List all available backups
   ./restore.sh --backup-date <different-date>
   ```

2. If you're certain the backup is valid, skip validation (not recommended):
   ```bash
   ./restore.sh --latest --skip-verify
   ```

3. Re-verify the backup archive manually:
   ```bash
   tar -tzf /path/to/backup.tar.gz > /dev/null
   ```

4. Check for checksum file:
   ```bash
   ls -la /path/to/backup.tar.gz.sha256
   ```

#### NPM Scripts Not Working

**Problem:** `npm run <script>` fails.

**Solutions:**
1. Verify script exists in package.json:
   ```bash
   npm run
   ```

2. Check file permissions:
   ```bash
   ls -la <script-name>.sh
   chmod +x <script-name>.sh
   ```

3. Run script directly:
   ```bash
   ./<script-name>.sh
   ```

#### Configuration Issues

**Problem:** Default configuration doesn't work for your setup.

**Solutions:**
1. Run configuration checker:
   ```bash
   ./check-config.sh
   ```

2. Review and update `config.sh`:
   ```bash
   nano config.sh
   ```

3. Test with dry-run:
   ```bash
   ./backup.sh --dry-run
   ```

### Getting Help

If you encounter issues not covered here:

1. Check the logs:
   - `logs/backup_history.log` - Backup history
   - `logs/failed_backups.log` - Failed backup details
   - Individual backup logs in backup directories

2. Run diagnostics:
   ```bash
   ./debug-backup.sh
   ./security-audit.sh
   ```

3. Review the codebase review:
   - See `CODEBASE_REVIEW.md` for detailed analysis

## Testing

The project includes a comprehensive test suite to verify functionality and catch issues early.

### Running Tests

#### Run All Tests
```bash
./run-all-tests.sh
# Or using npm:
npm test
```

This runs the complete test suite including:
- Backup functionality tests
- Configuration validation
- File operations
- Test environment setup

#### Run Specific Test Suites

**Backup Functionality:**
```bash
./test-backup.sh
# Or:
npm run test:backup
```

**Cron Configuration:**
```bash
npm run test:cron
# Tests cron job setup without modifying actual crontab
```

**Tar Compatibility:**
```bash
npm run test:tar
# Tests tar command compatibility across different systems
```

**Variable Testing:**
```bash
./test-vars.sh
# Tests environment variables and configuration
```

#### Test Options

**Quick Test (Fast):**
```bash
./test-backup.sh --quick
# Runs minimal tests for faster feedback
```

**Dry Run Tests:**
```bash
./backup.sh --dry-run
# Simulates backup without creating files
```

### Test Coverage

The test suite covers:

| Area | Coverage | Script |
|------|----------|--------|
| Backup Operations | Full, incremental, differential | `test-backup.sh` |
| Configuration | Paths, directories, settings | `test-vars.sh`, `check-config.sh` |
| Cron Setup | Job scheduling, syntax | `test-cron.sh` |
| Tar Compatibility | Cross-system compatibility | `test-tar-compatibility.sh` |
| File Operations | Permissions, paths, validation | Various test scripts |
| Cloud Storage | Upload/download (if configured) | `test-backup.sh` |

### Test Environment

Tests use a dedicated test directory (`test/`) and test projects (`test-projects/`) to avoid affecting production data.

**Test Directory Structure:**
```
test/
├── test_history.log      # Test execution history
└── test_*/               # Individual test run directories

test-projects/
├── project1/             # Sample project for testing
└── project2/             # Additional test projects
```

### Interpreting Test Results

**Success Indicators:**
- All tests pass with exit code 0
- No error messages in output
- Test logs show "PASS" or "SUCCESS"

**Failure Indicators:**
- Exit code non-zero
- Error messages in output
- Test logs show "FAIL" or "ERROR"

**Common Test Failures:**
1. **Permission Errors:** Run `chmod +x *.sh` or `./secure-permissions.sh`
2. **Path Issues:** Check `config.sh` and run `./check-config.sh`
3. **Missing Dependencies:** Install required tools (tar, gzip, etc.)

### Continuous Testing

For development, run tests frequently:
```bash
# Watch mode (if available)
./run-tests.sh --watch

# Before commits
npm test

# In CI/CD pipeline
./run-all-tests.sh
```

### Test Documentation

For detailed test documentation, see:
- `test/README.md` - Test suite documentation
- Individual test script headers - Script-specific documentation

## NPM Scripts

You can also use the following npm scripts for common operations:

| Script | Description | Example |
|--------|-------------|--------|
| `npm start` | Launch the interactive backup interface | `npm start` |
| `npm run backup` | Run a standard backup | `npm run backup` |
| `npm run backup:quick` | Run a Quick Backup with default settings | `npm run backup:quick` |
| `npm run backup:cloud` | Backup to the cloud storage | `npm run backup:cloud` |
| `npm run backup:dry` | Perform a dry run (without making changes) | `npm run backup:dry` |
| `npm run backup:incremental` | Run an incremental backup | `npm run backup:incremental` |
| `npm run backup:differential` | Run a differential backup | `npm run backup:differential` |
| `npm run backup:external` | Backup to external location | Edit in package.json first |
| `npm test` | Run all tests | `npm test` |
| `npm run test:backup` | Test backup functionality | `npm run test:backup` |
| `npm run test:cron` | Test cron setup | `npm run test:cron` |
| `npm run test:tar` | Test tar compatibility across systems | `npm run test:tar` |
| `npm run cleanup` | Run the cleanup script | `npm run cleanup` |
| `npm run cleanup:dry` | Preview cleanup without changes | `npm run cleanup:dry` |
| `npm run cleanup:all` | Clear all backups | `npm run cleanup:all` |
| `npm run cleanup:logs` | Clear all log files | `npm run cleanup:logs` |
| `npm run restore` | Restore from backup | `npm run restore` |
| `npm run restore:list` | List available backups | `npm run restore:list` |
| `npm run cron` | Configure cron jobs | `npm run cron` |
| `npm run compare` | Compare two backups | `npm run compare` (add to package.json) |

**Note:** To add the compare script to package.json:
```json
"compare": "./compare-backups.sh"
```

## Recent Improvements (Version 1.7.0+)

### Code Quality Enhancements

- **Modular Reporting System**: Split large `reporting.sh` (1,150 lines) into specialized modules for better maintainability
- **Version Checking**: Added script compatibility verification to prevent version mismatches
- **Enhanced Error Messages**: Context-aware error messages with actionable troubleshooting tips
- **Standardized Logging**: Consistent log format with log levels and color coding
- **Backup Validation**: Automatic integrity checks before restore operations

### New Features

- **Backup Comparison Tool**: Compare two backups to see what changed (`compare-backups.sh`)
- **Restore Validation**: Validates backup integrity before extraction (with `--skip-verify` option)
- **Improved Error Handling**: Error messages now include context-specific solutions
- **Debug Mode**: Set `DEBUG_MODE=true` to enable detailed debug logging

### Documentation Updates

- **Script Type Documentation**: Clear distinction between entry point scripts and module scripts
- **Archived Code Documentation**: Documented legacy code in `archive/src.legacy/`
- **Troubleshooting Section**: Comprehensive troubleshooting guide with common issues and solutions

## Architecture

For a detailed overview of the system architecture, component relationships, and data flow, see [ARCHITECTURE.md](ARCHITECTURE.md).

## Version History

See [CHANGELOG.md](CHANGELOG.md) for a complete history of changes, improvements, and bug fixes.

## License

This project is licensed under MIT License - see LICENSE file for details.
