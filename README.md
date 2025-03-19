# WebDev Backup Tool

A bash-based backup solution specifically designed for web development projects. It creates efficient, space-optimized backups while intelligently excluding resource-intensive directories like `node_modules`.

## Origin

This tool was built after losing work due to a hard drive failure. It provides a reliable way to back up repositories from a `/webdev/` directory, understanding what files to include and exclude in web development projects. It supports both local and cloud storage options.

## Features

- **Smart Project Selection**: Choose which projects to backup
- **Node Modules Exclusion**: Automatically excludes `node_modules` directories to save space
- **Local and Cloud Storage**: Back up locally or to cloud providers (DigitalOcean Spaces, AWS S3, Google Drive, Dropbox)
- **Incremental Backups**: Only back up files that have changed since the last backup
- **Interactive Dashboard**: Real-time progress display with project sizes
- **Automated Scheduling**: Configure recurring backups with cron
- **Restore Capabilities**: Easily restore complete backups or specific files

## ⚡️ Quick Run

1. **Setup**:

   ```bash
   # Clone the repository
   git clone https://github.com/yourusername/webdev-backup.git
   cd webdev-backup

   # Make scripts executable
   chmod +x *.sh

   # Copy and edit the secrets template for cloud storage
   cp secrets.sh.example secrets.sh
   nano secrets.sh
   ```

2. **Run**:

   ```bash
   # Interactive launcher (recommended for first use)
   ./webdev-backup.sh

   # Direct backup to local storage
   ./backup.sh

   # Direct backup to cloud (requires configured secrets.sh)
   ./backup.sh --external
   ```

That's it! The tool will automatically:

- Detect your web projects
- Exclude `node_modules` directories
- Create compressed backups in `./backups/` (created automatically)

## Installation

### Basic Configuration

- **Local storage**: By default, backups are stored in `./backups/` within the project directory
- **External storage**: Configure cloud provider credentials in `secrets.sh`
- **Source directory**: Automatically detected, or specify with `--source` option

### Cloud Storage Setup

For DigitalOcean Spaces (recommended):

1. Create a Spaces bucket in your DigitalOcean account
2. Generate API credentials in your DigitalOcean dashboard
3. Add to `secrets.sh`:
   ```bash
   DO_SPACES_KEY="your-key"
   DO_SPACES_SECRET="your-secret"
   DO_SPACES_ENDPOINT="nyc3.digitaloceanspaces.com"
   DO_SPACES_BUCKET="your-bucket"
   DO_SPACES_REGION="nyc3"
   ```
4. Install AWS CLI: `sudo apt install -y awscli` (or equivalent)

## Storage Options

WebDev Backup Tool offers three storage options:

1. **Local Project Storage**: Backups stored in the default `./backups/` directory within the project (fastest)

   - Command: `./backup.sh`
   - Current default path: `/mnt/d/backups`

2. **External Volume Storage**: Backups stored on an external drive or network volume (good for archiving)

   - Command: `./backup.sh --destination /path/to/external/storage`
   - Example: `./backup.sh --destination /mnt/backup_drive/webdev_backups`

3. **Cloud Storage**: Backups stored on cloud services (best for offsite disaster recovery)
   - Command: `./backup.sh --external --cloud [provider]`
   - Supported providers: DigitalOcean Spaces (do), AWS S3 (aws), Dropbox, Google Drive (gdrive)
   - Example: `./backup.sh --external --cloud do`

Choose the option that best fits your backup strategy. Many users implement multiple tiers by using local backups for daily use and cloud storage for weekly archives.

## Usage

### Interactive Launcher

```bash
./webdev-backup.sh
```

This displays a menu with options:

- Run Backup (Internal/External)
- Run Tests
- Configure Automated Backups
- View Backup History
- And more...

### Direct Commands

```bash
# Local backup
./backup.sh

# Cloud backup
./backup.sh --external

# Specify source and destination
./backup.sh --source /path/to/webdev --destination /path/to/backups

# Silent mode (for cron jobs)
./backup.sh --silent

# Incremental backup
./backup.sh --incremental

# Test functionality
./run-tests.sh
```

### Internal vs External Backup

**Internal Backup**: Stores backups locally on your system

- Fast and convenient
- No internet connection required
- Good for daily development backups
- Command: `./backup.sh`

**External Backup**: Stores backups in the cloud

- Uses DigitalOcean Spaces (or other configured provider)
- Provides off-site backup for disaster recovery
- Requires configured credentials
- Command: `./backup.sh --external`

## Automated Backups

Set up recurring backups with:

```bash
./configure-cron.sh
```

Or select the option from the launcher menu.

## Restore Functionality

```bash
# List available backups
./restore.sh --list

# Restore the latest backup
./restore.sh

# Restore a specific project
./restore.sh --project myproject
```

## Maintenance

Use the cleanup utility to manage backup storage:

```bash
# Standard cleanup (keeps 5 most recent backups)
./cleanup.sh

# Remove logs older than 30 days
./cleanup.sh --days 30

# Clear all backup folders (with confirmation)
./cleanup.sh --clear-backups

# Skip confirmation prompts (use carefully!)
./cleanup.sh --clear-backups --yes
```

### Backup Cleanup Options

- **Standard Cleanup**: By default, keeps the 5 most recent backups and cleans up old log files
- **Age-based Cleanup**: Remove logs older than a specified number of days
- **Complete Backup Removal**: The `--clear-backups` option allows complete removal of all backup folders
  - Each backup folder will require individual confirmation
  - Default answer is "No" for safety (you must explicitly type "y" to confirm deletion)
  - Useful when you need to reclaim disk space or start fresh
  - WARNING: This permanently deletes all backup data - make sure you have copies if needed

For safety, the script will always:

- Confirm before deletion (unless `--yes` option is used)
- Show you which files will be affected before proceeding
- Allow cancellation at any point during the process

## Troubleshooting

### Common Issues

- **"Source directory does not exist"**: Verify path or use `--source`
- **"Cannot write to backup directory"**: Check permissions
- **"Failed to upload to cloud"**: Verify credentials in `secrets.sh`

### Diagnostics

1. Run tests: `./run-tests.sh`
2. Check logs: `logs/backup_history.log`
3. Test in dry-run mode: `./backup.sh --dry-run`

> **Note:** For safety, all test files are always stored in the internal test directories,
> even when a custom backup destination is specified. This prevents tests from writing
> to external drives or network storage.

## License

This project is licensed under the MIT License.
