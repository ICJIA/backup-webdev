# WebDev Backup Tool

A robust backup solution for web development projects that supports multiple source directories, incremental backups, compression, integrity verification, and cloud storage integration.

## Features

- **Multi-Directory Backup**: Back up projects from multiple source directories
- **Flexible Backup Types**: Full, incremental, or differential backups
- **Quick Backup**: One-click backup using default settings
- **Compression**: Optimized compression with multi-threading support (via pigz)
- **Verification**: Integrity verification of backup archives
- **Exclusion Rules**: Automatically excludes node_modules and other large dependencies
- **Cloud Integration**: Upload backups to AWS S3, DigitalOcean Spaces, Dropbox, or Google Drive
- **Reporting**: Detailed HTML reports with directory grouping and email notifications
- **File Structure Visualization**: Interactive modals showing ASCII file structure diagrams
- **Dashboard**: Visual dashboard for backup statistics and forecasting
- **Restore**: Simple project restoration with preview capability
- **Security**: Built-in security features and encryption support

## Installation

### Requirements

- Bash shell (version 4.0 or later)
- tar, gzip (required)
- pigz (optional, for multi-threaded compression)
- gnuplot (optional, for visualization)
- AWS CLI (optional, for cloud storage)

### Setup

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

Restore the latest backup:

```bash
./restore.sh --latest
```

Restore a specific project from backup:

```bash
./restore.sh --project myproject --dest ~/restored
```

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

## File Structure

**Note:** The active scripts are located in the root directory. The `src/` directory contains an alternative organizational structure that is not currently in use. All package.json scripts and main entry points reference root-level scripts.

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
| reporting.sh          | Reporting functions               | Creates backup reports and summaries                   |
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

The backup tool generates comprehensive HTML reports with several advanced features:

### Project Directory Grouping

Projects are now organized by their source directories in reports, making it easier to understand which projects come from which locations. Within each directory group, projects are alphabetically sorted for easy reference.

### Interactive Project Details

Each project in the HTML report is interactive:

1. Click on any project row to open a modal with detailed information
2. View the project's complete file structure in an ASCII tree format
3. See detailed statistics including compression ratio and file counts
4. Navigate between projects using a tabbed interface

### Quick Backup Feature

The main menu now includes a Quick Backup option that:

1. Uses all default settings configured in `config.sh`
2. Shows a summary of what will be backed up before proceeding
3. Provides a streamlined experience with minimal user interaction
4. Skips verification to maximize speed and performance

## Testing

The project includes a comprehensive test suite:

```bash
./run-all-tests.sh  # Run all tests
./run-tests.sh --unit  # Run only unit tests
```

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

## License

This project is licensed under MIT License - see LICENSE file for details.
