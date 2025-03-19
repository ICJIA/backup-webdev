# WebDev Backup Tool

A robust backup solution for web development projects that supports multiple source directories, incremental backups, compression, integrity verification, and cloud storage integration.

## Features

- **Multi-Directory Backup**: Back up projects from multiple source directories
- **Flexible Backup Types**: Full, incremental, or differential backups
- **Compression**: Optimized compression with multi-threading support (via pigz)
- **Verification**: Integrity verification of backup archives
- **Exclusion Rules**: Automatically excludes node_modules and other large dependencies
- **Cloud Integration**: Upload backups to AWS S3, DigitalOcean Spaces, Dropbox, or Google Drive
- **Reporting**: Detailed HTML reports and email notifications
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
./backup.sh --sources ~/webdev,~/inform6 --verify
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

- `backup.sh` - Main backup script
- `webdev-backup.sh` - Interactive launcher interface
- `restore.sh` - Backup restoration script
- `config.sh` - Configuration settings
- `utils.sh` - Utility functions
- `ui.sh` - User interface functions
- `fs.sh` - Filesystem operations
- `reporting.sh` - Reporting functions
- `check-config.sh` - Configuration verification
- `security-audit.sh` - Security audit script
- `encryption.sh` - Optional encryption functions
- `run-all-tests.sh` - Comprehensive test suite
- `dirs-status.sh` - Source directory status report

## Adding a New Source Directory

You can easily add new source directories:

1. Through the menu system: Select "9) Manage Source Directories" and "1) Add new source directory"
2. Directly edit `config.sh` and add to the `DEFAULT_SOURCE_DIRS` array
3. Use the `--sources` command-line option with comma-separated paths

## Security

For secure operations:

1. Run `secure-permissions.sh` to set proper file permissions
2. Run `secure-secrets.sh` to set up secure credential storage
3. Run `security-audit.sh` periodically to check for issues

## Testing

The project includes a comprehensive test suite:

```bash
./run-all-tests.sh  # Run all tests
./run-tests.sh --unit  # Run only unit tests
```

## License

This project is licensed under MIT License - see LICENSE file for details.

## Credits

WebDev Backup Tool - Created by Your Name
