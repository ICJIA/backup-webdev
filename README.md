# WebDev Backup Tool

## Origin

I built this tool because I needed a reliable way to back up all my repositories from my local `/webdev/` directory. After losing work due to a hard drive failure, I realized I needed a backup solution (in addition to Github) that understood backing up a web development project - what files to include, what files to exclude. This app is my attempt to make regular local or external backupsof my web development projects.

This tool helps safeguard your web development projects by creating efficient, space-optimized backups while intelligently handling common web development patterns like excluding the resource-intensive `node_modules` directories.

With support for both local and cloud storage (including DigitalOcean Spaces, AWS S3, Google Drive, and Dropbox), incremental and differential backup strategies, and automated scheduling, WebDev Backup Tool ensures that your code is protected against data loss, corrupted files, or accidental deletions. In today's fast-paced development environment, where a single project can represent hundreds of hours of work, having a reliable, automated backup strategy isn't just convenient—it's essential.

## Features

### Core Features

- **Smart Project Selection**: Choose which projects to backup (defaults to all)
- **Node Modules Exclusion**: Automatically excludes `node_modules` directories to save space
- **Individual Project Compression**: Each project is compressed into a separate .tar.gz file
- **Interactive Dashboard**: Real-time progress display with project sizes and compression ratios
- **Silent Mode**: Can run without interaction for cron jobs or automated backups
- **Comprehensive Logging**: Detailed logs with statistics and backup history
- **Test Mode**: Test all functionality without performing actual backups
- **Auto-discovery**: Automatically detects source directory based on installation location
- **Custom Paths**: Specify custom source and destination directories with command-line options
- **Robust Error Handling**: Early detection of permission and filesystem issues
- **Detailed Diagnostics**: Clear error messages with specific failure reasons

### Advanced Backup Options

- **Incremental Backups**: Only back up files that have changed since the last backup
- **Differential Backups**: Only back up files that have changed since the last full backup
- **Custom Compression Levels**: Adjust compression ratio for space/speed tradeoffs (1-9)
- **Backup Verification**: Automatically verify integrity of backups after creation
- **Parallel Compression**: Use multiple threads for faster compression (with pigz)

### Cloud Integration

- **Cloud Storage Upload**: Automatically upload backups to cloud providers:
  - DigitalOcean Spaces (default)
  - Amazon S3 (AWS)
  - Google Drive
  - Dropbox
- **Bandwidth Limiting**: Control upload speeds to avoid network saturation
- **Multi-Location Backups**: Store backups in multiple locations for redundancy

### Reporting and Notifications

- **Email Notifications**: Get automated email reports after backups complete
- **HTML Reports**: Detailed HTML backup reports with project statistics
- **Visual Dashboard**: Web-based dashboard with charts and statistics
- **Backup Size Forecasting**: Predict future backup sizes based on trends
- **Storage Usage Visualization**: Graphical representation of backup history

### Restore Capabilities

- **One-Click Restore**: Easily restore entire backups
- **Selective Restore**: Restore specific projects or files
- **Point-in-Time Recovery**: Restore from any backup point
- **Backup Integrity Testing**: Verify backups without actually restoring
- **Restore Preview**: See what would be restored before executing

## Installation and Setup Guide

### Basic Installation

1. Clone this repository to your local machine:

   ```bash
   git clone https://github.com/yourusername/webdev-backup.git
   cd webdev-backup
   ```

2. Make all scripts executable:

   ```bash
   chmod +x *.sh
   ```

3. Create your credentials file for cloud storage and email notifications:

   ```bash
   cp secrets.sh.example secrets.sh
   ```

4. Edit your credentials file with your preferred text editor:
   ```bash
   nano secrets.sh   # or vim, code, etc.
   ```

### Cloud Storage Setup

For DigitalOcean Spaces (recommended external storage):

1. Create a Spaces bucket in your DigitalOcean account
2. Generate API credentials from the "API" section in your DigitalOcean dashboard
3. Add your credentials to the `secrets.sh` file:

   ```bash
   DO_SPACES_KEY="your-digitalocean-spaces-key"
   DO_SPACES_SECRET="your-digitalocean-spaces-secret"
   DO_SPACES_ENDPOINT="nyc3.digitaloceanspaces.com"  # Change region if needed
   DO_SPACES_BUCKET="your-spaces-bucket"
   DO_SPACES_REGION="nyc3"  # Change region if needed
   ```

4. Install the AWS CLI (required for DigitalOcean Spaces integration):

   ```bash
   # For Debian/Ubuntu
   sudo apt update && sudo apt install -y awscli

   # For Red Hat/CentOS/Fedora
   sudo yum install -y awscli

   # For macOS with Homebrew
   brew install awscli
   ```

### Additional Cloud Provider Setup

For AWS S3:

1. Create an S3 bucket in your AWS account
2. Create IAM credentials with appropriate S3 access
3. Add your AWS credentials to the `secrets.sh` file

For Google Drive:

1. Create a Google Cloud project and enable the Drive API
2. Create OAuth credentials and download the client configuration
3. Add your Google Drive credentials to the `secrets.sh` file
4. Install the gdrive CLI tool

For Dropbox:

1. Create a Dropbox app in the Dropbox developer portal
2. Generate an access token
3. Add your Dropbox token to the `secrets.sh` file
4. Install the dropbox-uploader script

### Email Notification Setup

To enable email notifications:

1. Add your SMTP server details to the `secrets.sh` file:

   ```bash
   EMAIL_SMTP_SERVER="smtp.example.com"
   EMAIL_SMTP_PORT="587"
   EMAIL_USERNAME="your-username@example.com"
   EMAIL_PASSWORD="your-email-password"
   EMAIL_FROM="backups@example.com"
   ```

2. Install the required mail utilities:
   ```bash
   # For Debian/Ubuntu
   sudo apt update && sudo apt install -y mailutils
   ```

### Directory Configuration

The script automatically detects the source directory:

- It looks for a "webdev" directory one level up from where the script is located
- If not found, it uses the parent directory of where the script is located
- You can always override this with the `--source` option

To view the current default paths:

```bash
./backup.sh --help
```

To customize paths permanently, edit the `config.sh` file:

```bash
# Edit DEFAULT_SOURCE_DIR and DEFAULT_BACKUP_DIR in config.sh
nano config.sh
```

### Quick Start Guide

After installation, you can quickly get started with these commands:

1. **Run the interactive launcher** (recommended for first-time users):

   ```bash
   ./webdev-backup.sh
   ```

   This will guide you through all available options, including internal/external backup.

2. **Run a direct backup** with default settings:

   ```bash
   ./backup.sh
   ```

   This performs an internal backup to your local filesystem.

3. **Run an external backup** to DigitalOcean Spaces:

   ```bash
   ./backup.sh --external
   ```

   Requires setting up your credentials in `secrets.sh` first.

4. **Test the system** without actually creating backups:
   ```bash
   ./run-tests.sh
   ```
   This confirms all functionality is working correctly.

### Backing Up Your Web Development Projects

This tool was specifically created to back up web development projects typically found in a `/webdev/` directory structure. For example:

```
/webdev/
├── client-project-1/        # React frontend for Client 1
├── client-project-2/        # Next.js application for Client 2
├── personal-blog/           # Gatsby blog
├── portfolio-site/          # Vue.js personal portfolio
├── nodejs-api/              # Express API server
└── wordpress-theme/         # Custom WordPress theme
```

The tool will:

1. Automatically detect your project directories
2. Intelligently exclude `node_modules` and other large, regenerable directories
3. Create compressed archives for each project
4. Store them either locally or in the cloud (DigitalOcean Spaces recommended)

You can back up everything with a single command, or choose specific projects to include or exclude. This is perfect for preserving your code while avoiding the waste of backing up dependencies that can be reinstalled with `npm install`.

### Recommended Workflow for First-Time Setup

1. Set up your credentials in `secrets.sh`
2. Run `./test-backup.sh` to verify your configuration
3. Make a test backup with `./backup.sh --dry-run`
4. Configure automated backups with `./configure-cron.sh`
5. Create your first real backup with `./webdev-backup.sh`

## Usage

### Using the Interactive Launcher

The easiest way to use the WebDev Backup Tool is through the interactive launcher:

```bash
./webdev-backup.sh
```

This will display a menu with the following options:

1. **Run Backup (Interactive Mode)** - Run the main backup process
2. **Run Comprehensive Tests** - Execute all tests to verify functionality
3. **Run Cleanup Tool** - Clean up logs and temporary files
4. **Restore Backups** - Restore files from previous backups
5. **View Backup Dashboard** - See visual backup statistics and trends
6. **View Project Documentation** - Display this README file
7. **View Backup History** - Show history of previous backups
8. **Configure Automated Backups (Cron)** - Set up scheduled automated backups
9. **Advanced Options** - Access additional backup modes and settings

The launcher automatically displays your current configuration and last backup date.

#### Internal vs External Backup

When you select "Run Backup" from the menu, you'll be prompted to choose between:

1. **Internal Backup**: Stores backups locally on your system

   - Fast and convenient for quick backups
   - Uses your local filesystem at the configured destination path
   - No Internet connection required
   - Good for daily development backups
   - Example command: `./backup.sh` or `./webdev-backup.sh` and select option 1

2. **External Backup**: Stores backups in the cloud
   - By default uses DigitalOcean Spaces for reliable cloud storage
   - Also supports AWS S3, Google Drive, and Dropbox
   - Provides off-site backup for disaster recovery
   - Requires proper credentials in your `secrets.sh` file
   - Ideal for important milestones and long-term storage
   - Additional protection against hardware failures, theft, or disasters
   - Example command: `./backup.sh --external` or `./webdev-backup.sh` and select option 2

The dashboard and backup reports will clearly indicate whether a backup is internal or external. You can see this information in:

- The real-time dashboard during backup
- The backup summary displayed on completion
- The backup history log (`logs/backup_history.log`)
- The JSON metadata file in each backup directory

##### When to Use Internal vs External Backups

**Use Internal Backups for:**

- Daily development work
- Quick iterations and frequent checkpoints
- When you need the fastest backup/restore time
- When you have limited internet connectivity

**Use External Backups for:**

- Major project milestones or releases
- End-of-week or end-of-sprint backups
- When working with particularly valuable or irreplaceable code
- Implementing a 3-2-1 backup strategy (3 copies, 2 different media, 1 off-site)

Both backup types use the same compression and organization format, making it easy to switch between them based on your needs.

### Silent Mode with Launcher

If you want to run in silent mode, simply add the `--silent` flag:

```bash
./webdev-backup.sh --silent
```

This will bypass the menu and run the backup directly in silent mode, making it suitable for cron jobs.

### Getting Help

You can view all available options by using the help flag:

```bash
./backup.sh --help
```

This displays usage information, available options, and examples.

### Interactive Mode

Run the backup script with no arguments for interactive mode:

```bash
./backup.sh
```

This will display:

- List of available projects
- Option to exclude specific projects
- Real-time progress dashboard
- Detailed backup statistics

### Silent Mode (for cron jobs)

Run with the `--silent` flag for non-interactive operation:

```bash
./backup.sh --silent
```

This mode:

- Backs up all projects without user interaction
- Only outputs success/failure messages
- Still logs everything to the history file
- Perfect for scheduled backups with cron

### Custom Source and Destination Paths

You can specify a custom source directory with the `--source` (or `-s`) flag:

```bash
./backup.sh --source /path/to/custom/source
```

You can specify a custom backup destination with the `--destination` (or `-d`) flag:

```bash
./backup.sh --destination /path/to/custom/backup/location
```

You can combine these options with each other and with silent mode:

```bash
./backup.sh --silent --source /path/to/src --destination /path/to/backup
```

The script will:

- Validate that the source directory exists
- Create the destination directory if it doesn't exist
- Use the specified paths instead of the defaults
- Still organize backups by date within the destination

### Advanced Backup Options

The backup script supports several advanced options for flexibility and performance:

#### Backup Types

```bash
# Only back up files changed since last backup
./backup.sh --incremental

# Only back up files changed since last full backup
./backup.sh --differential
```

#### Compression and Performance

```bash
# Set compression level (1-9, default is 6)
./backup.sh --compression 9  # Maximum compression

# Use parallel compression with multiple threads
./backup.sh --parallel 4     # Use 4 threads for compression

# Verify backup integrity after completion
./backup.sh --verify
```

#### Cloud Integration

WebDev Backup Tool supports multiple cloud storage providers, with DigitalOcean Spaces being the recommended and default option for external backups. The tool uses native APIs or CLI tools to securely upload your backups to your chosen cloud provider.

```bash
# Quick way to use external backup (uses DigitalOcean Spaces by default)
./backup.sh --external

# Upload backup to specific cloud storage
./backup.sh --cloud do       # Upload to DigitalOcean Spaces (recommended)
./backup.sh --cloud aws      # Upload to Amazon S3
./backup.sh --cloud gdrive   # Upload to Google Drive
./backup.sh --cloud dropbox  # Upload to Dropbox

# Limit bandwidth usage (in KB/s)
./backup.sh --cloud do --bandwidth 1024  # Limit to 1MB/s
```

##### DigitalOcean Spaces Advantages

DigitalOcean Spaces is recommended as the primary cloud storage provider for several reasons:

- **S3-compatible API**: Uses the familiar AWS S3 API but with simpler pricing
- **Cost-effective**: Fixed, predictable pricing for storage and bandwidth
- **Global CDN**: Easy integration with DigitalOcean's CDN for fast downloads
- **Simple setup**: Straightforward credential management and bucket creation
- **Regional storage**: Multiple regions available for compliance or performance needs

To use DigitalOcean Spaces, make sure your `secrets.sh` file is correctly configured with your Spaces credentials. See the [Installation and Setup Guide](#installation-and-setup-guide) section for details.

Example credentials configuration:

```bash
DO_SPACES_KEY="your-access-key"
DO_SPACES_SECRET="your-secret-key"
DO_SPACES_ENDPOINT="nyc3.digitaloceanspaces.com"
DO_SPACES_BUCKET="my-webdev-backups"
DO_SPACES_REGION="nyc3"
```

#### Notifications

```bash
# Send email notification after backup completes
./backup.sh --email user@example.com
```

### Restore Functionality

The restore script provides easy recovery options:

```bash
# List available backups
./restore.sh --list

# Restore the latest backup (interactive mode)
./restore.sh

# Restore a specific backup by date
./restore.sh --backup-date 2025-03-15_14-30-00

# Restore just a specific project
./restore.sh --project myproject

# Restore a specific file from a project
./restore.sh --project myproject --file src/index.js

# Test restore without actually extracting files
./restore.sh --test

# Preview what would be restored without doing it
./restore.sh --dry-run
```

### Testing the Backup Process

#### Running All Tests

To run a comprehensive test suite with a single command:

```bash
./run-tests.sh
```

This runs all tests for the application and provides:

- Color-coded success/failure indicators
- Detailed test logs
- Proper exit codes for CI/CD integration
- Test history in reverse chronological order
- Coverage of all utilities including backup, test, and cleanup tools
- Dry-run tests for cleanup functionality (no files are deleted)

#### Running Specific Tests

To test only the backup functionality without actually moving files:

```bash
./test-backup.sh
```

The test script:

- Verifies all system requirements
- Tests the compression process
- Validates compressed file integrity
- Generates detailed test logs

## Logs and Output

- **Backup History**: All backups are logged to `logs/backup_history.log`
- **Test History**: All tests are logged to `test/test_history.log`
- **Individual Backup Logs**: Each backup creates its own detailed log file

## Directory Structure

```
backup-webdev/
├── backup.sh           # Main backup script
├── test-backup.sh      # Test script for validating functionality
├── test-cron.sh        # Test script for cron functionality
├── run-tests.sh        # Comprehensive test suite runner
├── cleanup.sh          # Cleanup utility for logs and verifying setup
├── restore.sh          # Restore utility for recovering backups
├── configure-cron.sh   # Cron job configuration utility
├── webdev-backup.sh    # Interactive launcher for all functionality
├── config.sh           # Shared configuration for all scripts
├── utils.sh            # Shared utility functions
├── ui.sh               # User interface functions
├── fs.sh               # Filesystem operation functions
├── reporting.sh        # Reporting and visualization functions
├── secrets.sh.example  # Template for secure credential storage
├── LICENSE             # MIT license
├── README.md           # Main documentation
├── logs/               # Backup logs directory
│   ├── .gitkeep        # Placeholder to maintain directory in git
│   ├── README.md       # Logs directory documentation
│   ├── backup_history.log # Backup history log
│   ├── restore_history.log # Restore history log
│   └── *.log           # Log files (ignored by git)
└── test/               # Test directory
    ├── .gitkeep        # Placeholder to maintain directory in git
    ├── README.md       # Test directory documentation
    ├── test_history.log # Test log (kept locally, ignored by git)
    ├── test_run_*.log  # Comprehensive test run logs
    ├── cron_test_*     # Cron test directories
    └── webdev_test_*   # Test backup directories (ignored by git)
```

## Error Handling

The script performs several validations before starting the backup process:

1. **Source Directory Validation**:

   - Verifies the source directory exists
   - Ensures there are projects to backup

2. **Destination Directory Validation**:
   - Checks if the backup directory exists and creates it if needed
   - Verifies write permissions on the backup directory
   - Tests filesystem write capability with a temporary file
3. **Backup Process Validation**:
   - Validates compression tools availability
   - Monitors backup success and failures
   - Provides detailed error messages for each failure point

## Automated Backups

### Using the Cron Configuration Utility

The easiest way to set up automated backups is to use the built-in cron configuration utility:

```bash
./configure-cron.sh
```

Or select "Configure Automated Backups (Cron)" from the main launcher menu.

This utility provides a user-friendly interface to:

1. **Enable automatic backups** with a default schedule (every 72 hours)
2. **Change backup frequency** with options for:
   - Every 3, 6, 12, 24, or 72 hours
   - Weekly (Sunday at midnight)
   - Monthly (1st day of month)
   - Custom schedule (using standard crontab format)
3. **Customize backup options** such as:
   - Incremental or differential backups
   - Backup verification
   - Email notifications
   - Cloud storage integration
4. **Disable automated backups** when no longer needed
5. **View upcoming backup times** based on your schedule

The utility automatically configures your crontab without you having to remember cron syntax.

### Testing Cron Functionality

To test the cron functionality without modifying your actual crontab, use the cron test script:

```bash
./test-cron.sh
```

Or run the comprehensive test suite which includes cron tests:

```bash
./run-tests.sh
```

These tests:

- Verify that cron configuration would work correctly
- Simulate creating, modifying, and removing cron jobs
- Test all cron features in a safe, dry-run mode
- Log all results for validation

### Cron Tips and Best Practices

#### 1. Frequency Selection Tips

- **For active development**: Every 24 hours (daily) is recommended
- **For less active projects**: Every 72 hours (3 days) is a good balance
- **For long-term archiving**: Weekly or monthly backups are sufficient

#### 2. Dealing with Sleep/Shutdown

If your computer isn't always on:

- Consider using `anacron` instead of `cron` for workstations that aren't always powered on
- For laptops, prefer schedules that run early in the day when the computer is likely to be on
- Use the `@reboot` schedule to run a backup after each system restart

#### 3. Email Notification Setup

When configuring email notifications for cron jobs:

- Ensure `mail` or `mailx` is installed on your system
- Test the email notification manually before enabling in cron
- Consider using the `--verify` option together with `--email` to get notified of backup integrity

#### 4. Resource Usage Considerations

To minimize impact on system performance:

- Use the `nice` command to lower the backup process priority
- Schedule backups during off-hours when the system is less busy
- Limit bandwidth usage with the `--bandwidth` option for cloud backups

Example of a nice'd cron job:

```bash
# Run at 2 AM with reduced priority
0 2 * * * nice -n 19 /path/to/backup-webdev/webdev-backup.sh --silent
```

#### 5. Logging and Monitoring

For effective monitoring of automated backups:

- Check the `logs/backup_history.log` file regularly
- Consider setting up log rotation for long-term use
- Use the `View Backup History` option in the launcher to review past runs

### Manual Crontab Configuration

If you prefer to manually configure crontab, you can use the following examples:

```bash
# Every 72 hours (default)
0 */72 * * * /path/to/backup-webdev/webdev-backup.sh --silent

# Daily at midnight
0 0 * * * /path/to/backup-webdev/webdev-backup.sh --silent

# Weekly on Sunday at midnight
0 0 * * 0 /path/to/backup-webdev/webdev-backup.sh --silent

# With custom options
0 0 * * * /path/to/backup-webdev/webdev-backup.sh --silent --incremental --email admin@example.com

# Advanced: Combined incremental (daily) and full (weekly) backups
# Run incremental backup daily
0 0 1-6 * * /path/to/backup-webdev/webdev-backup.sh --silent --incremental
# Run full backup on Sunday
0 0 0 * * /path/to/backup-webdev/webdev-backup.sh --silent
```

#### Crontab Syntax Reference

```
┌───────────── minute (0 - 59)
│ ┌───────────── hour (0 - 23)
│ │ ┌───────────── day of the month (1 - 31)
│ │ │ ┌───────────── month (1 - 12)
│ │ │ │ ┌───────────── day of the week (0 - 6) (Sunday to Saturday)
│ │ │ │ │
│ │ │ │ │
│ │ │ │ │
* * * * * command to execute
```

Common crontab patterns:

- `*/5 * * * *` - Every 5 minutes
- `0 * * * *` - Every hour at minute 0
- `0 */12 * * *` - Every 12 hours
- `0 0 * * *` - Every day at midnight
- `0 0 * * 0` - Every Sunday at midnight
- `0 0 1 * *` - First day of every month at midnight
- `@reboot` - Run once after system reboot

It's recommended to test the command manually with `--silent` first to ensure it works as expected.

## Maintenance

### Cleanup Utility

The project includes a cleanup utility for maintaining the backup tool:

```bash
./cleanup.sh [OPTIONS]
```

Options:

- `--backup-logs`: Backup logs before removing them
- `--all-logs`: Remove all logs (default: keeps last 5 runs)
- `--days N`: Remove logs older than N days
- `--source DIR`: Use custom source directory
- `--target DIR`: Use custom backup target directory
- `--yes`: Skip confirmation prompts
- `--dry-run`: Show what would be done without doing it

Examples:

```bash
# Standard cleanup (keeps recent logs)
./cleanup.sh

# Remove all logs
./cleanup.sh --all-logs

# Remove logs older than 30 days
./cleanup.sh --days 30

# Backup logs before removing
./cleanup.sh --backup-logs --all-logs
```

The cleanup script:

1. Verifies source directory existence
2. Verifies backup destination accessibility
3. Tests target volume write permission
4. Asks for confirmation before deleting each log file (defaults to Yes)
5. Cleans up log files based on specified options
6. Verifies script permissions
7. Creates any missing directories

### Modular Architecture

The project is built with a modular architecture that separates functionality into specialized components:

- **config.sh**: Central configuration for paths and global settings
- **utils.sh**: Common utility functions used across all scripts
- **ui.sh**: User interface functions for interactive display
- **fs.sh**: Filesystem operations including backup, restore, and cloud operations
- **reporting.sh**: Reporting and visualization functions

This modular design provides several benefits:

- Easier maintenance and updates
- Consistent behavior across all tools
- Reduced code duplication
- Better organized codebase
- Simpler addition of new features

Any changes to common functionality should be made in the appropriate module to ensure all tools benefit from the improvements.

### API Keys and Secrets

The project supports secure storage of API keys and sensitive information:

1. Create a copy of the example secrets file:

   ```bash
   cp secrets.sh.example secrets.sh
   ```

2. Edit the secrets.sh file to add your API keys and credentials:

   ```bash
   nano secrets.sh
   ```

3. The secrets.sh file is automatically gitignored to prevent accidental exposure.

Available secret types:

- Email SMTP credentials for notifications
- AWS S3 access keys for cloud backups
- Google Drive OAuth credentials
- Dropbox access tokens

Your API keys and sensitive information will be automatically loaded when running any script, but will never be committed to version control.

## Troubleshooting

### Common Issues

#### General Issues

- **"Source directory does not exist"**: Verify the source path or specify a custom one with `--source`
- **"Cannot write to backup directory"**: Check permissions on the destination directory
- **"Failed to create backup directory"**: Ensure the parent directory exists and has write permissions
- **"Filesystem may be read-only or full"**: Check disk space and mount permissions

#### Cloud Storage Issues

- **"AWS CLI not installed"**: Install the AWS CLI with `apt install awscli` or equivalent
- **"DigitalOcean Spaces credentials not found in secrets file"**: Check your `secrets.sh` file
- **"Failed to upload to DigitalOcean Spaces"**: Verify credentials and bucket permissions
- **"Access denied"**: Check that your API keys have the correct permissions

#### Internal/External Backup Issues

- **"Error: No cloud provider specified"**: When using `--external`, ensure you have a default cloud provider in `config.sh` or specify one with `--cloud`
- **"Using internal storage"**: If you intended to use external storage, use the `--external` flag
- **"Cloud provider invalid"**: Use one of the supported providers: do, aws, gdrive, dropbox

### Diagnosing Problems

1. **Run the cleanup script**:

   ```bash
   ./cleanup.sh --dry-run
   ```

   This will check all prerequisites without making changes.

2. **Run the test suite**:

   ```bash
   ./run-tests.sh
   ```

   This will verify all components of the application and identify any issues.

3. **Test cloud connectivity**:

   ```bash
   # For DigitalOcean Spaces
   aws s3 ls --endpoint-url https://nyc3.digitaloceanspaces.com

   # For AWS S3
   aws s3 ls
   ```

4. **Check the logs**:

   - For backup issues: `logs/backup_history.log`
   - For test failures: `test/test_history.log`
   - For detailed test output: `test/test_run_*.log`

5. **Verify permissions**:

   ```bash
   ls -la /path/to/backup/destination
   ```

   Make sure the user running the script has write permissions.

6. **Test in dry-run mode**:

   ```bash
   # Test internal backup
   ./backup.sh --dry-run

   # Test external backup
   ./backup.sh --external --dry-run
   ```

### Cloud Storage Troubleshooting

#### DigitalOcean Spaces

- Ensure the AWS CLI is installed and properly configured
- Verify that your spaces bucket exists and is accessible
- Check that your API keys have read/write permissions
- Try running with the `--verbose` flag for more detailed error messages

#### Issues with External/Internal Switch

If you're having trouble with the internal/external backup feature:

1. Make sure you've set up your cloud provider credentials correctly
2. Check that the credentials have the correct permissions
3. Try specifying the provider explicitly with `--cloud do`
4. Verify connectivity to the cloud provider independently
5. Check the logs for any connection errors

## Best Practices and Tips

### Effective Backup Strategy

For the most comprehensive backup strategy, consider these best practices:

1. **Use the 3-2-1 backup rule**:

   - Maintain at least 3 copies of your data
   - Store copies on 2 different storage media
   - Keep 1 copy offsite (using DigitalOcean Spaces or another cloud provider)

2. **Schedule Regular Backups**:

   - **Daily internal backups** for active development projects
   - **Weekly external backups** to cloud storage for disaster recovery
   - **Monthly full backups** for archival purposes

3. **Balance Storage and Performance**:

   - Use incremental backups for frequent internal snapshots
   - Use differential backups for weekly external backups
   - Use full backups for monthly archiving
   - Set compression level based on your needs (higher = smaller files but slower)

4. **Verify Your Backups**:
   - Periodically restore backups to test the recovery process
   - Use the `--verify` flag to automatically check backup integrity
   - Run automated tests with `./run-tests.sh` regularly

### Storage Management

To optimize your backup storage and performance:

1. **Choose the right cloud provider**:

   - DigitalOcean Spaces (default) for simple, cost-effective storage
   - AWS S3 for advanced features and global presence
   - Google Drive or Dropbox for easy sharing and desktop integration

2. **Clean up old backups**:

   - Use `./cleanup.sh` to manage disk space
   - Set up automated cleanup with cron
   - Consider a rotation policy (keeping daily backups for 1 week, weekly for 1 month, etc.)

3. **Protect your credentials**:
   - Never commit `secrets.sh` to version control
   - Regularly rotate your API keys and credentials
   - Use the principle of least privilege for your API keys

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
