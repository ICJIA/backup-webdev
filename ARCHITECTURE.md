# WebDev Backup Tool - Architecture

**Version:** 1.7.0  
**Last Updated:** 2025-03-30

## System Overview

The WebDev Backup Tool is a modular bash-based backup solution organized into core modules, utilities, and specialized scripts.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    WebDev Backup Tool v1.7.0                     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
        ┌─────────────────────────────────────────┐
        │      webdev-backup.sh (Main Entry)      │
        │      - Interactive menu system          │
        │      - Routes to other scripts          │
        └─────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  backup.sh   │    │  restore.sh  │    │  cleanup.sh  │
│  (Core)      │    │  (Restore)   │    │  (Maintain)  │
└──────────────┘    └──────────────┘    └──────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────┐
│                    Core Modules                         │
├─────────────────────────────────────────────────────────┤
│  config.sh      - Configuration & paths                 │
│  utils.sh       - Shared utilities & helpers            │
│  fs.sh          - Filesystem operations                 │
│  ui.sh          - User interface components             │
│  reporting.sh   - HTML reports & email                  │
│  error-handling.sh - Error management                   │
└─────────────────────────────────────────────────────────┘
        │
        ├─────────────────┬─────────────────┬──────────────┐
        ▼                 ▼                 ▼              ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│   Cloud      │ │  Encryption  │ │  Security    │ │   Testing    │
│  Storage     │ │   (OpenSSL)  │ │   Audit      │ │    Suite     │
│              │ │              │ │              │ │              │
│ - AWS S3     │ │ - AES-256-GCM│ │ - Permissions│ │ - test-backup│
│ - DO Spaces  │ │ - PBKDF2     │ │ - Secrets    │ │ - test-cron  │
│ - Dropbox    │ │ - Key mgmt   │ │ - Validation │ │ - test-tar   │
│ - GDrive     │ │              │ │              │ │ - run-tests  │
└──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘
```

## Module Dependencies

### Core Flow

```
User Input
    │
    ▼
webdev-backup.sh (Menu/Launcher)
    │
    ├──► backup.sh
    │       │
    │       ├──► config.sh (paths, settings)
    │       ├──► utils.sh (helpers, logging)
    │       ├──► fs.sh (file operations)
    │       ├──► ui.sh (progress display)
    │       └──► reporting.sh (generate reports)
    │
    ├──► restore.sh
    │       │
    │       ├──► utils.sh
    │       ├──► fs.sh
    │       └──► ui.sh
    │
    └──► Other scripts...
```

## Key Components

### 1. Entry Point (`webdev-backup.sh`)
- **Purpose:** Main launcher with interactive menu
- **Responsibilities:**
  - Display menu options
  - Route to appropriate scripts
  - Show configuration summary
  - Handle command-line arguments

### 2. Core Backup (`backup.sh`)
- **Purpose:** Primary backup execution
- **Responsibilities:**
  - Discover projects in source directories
  - Create compressed archives
  - Handle full/incremental/differential backups
  - Upload to cloud (optional)
  - Generate reports
  - Log operations

### 3. Configuration (`config.sh`)
- **Purpose:** Centralized configuration
- **Key Variables:**
  - `DEFAULT_SOURCE_DIRS` - Source directories to backup
  - `DEFAULT_BACKUP_DIR` - Backup destination
  - `DEFAULT_CLOUD_PROVIDER` - Cloud storage preference
  - `DATE_FORMAT` - Backup naming format

### 4. Utilities (`utils.sh`)
- **Purpose:** Shared helper functions
- **Key Functions:**
  - `format_size()` - Human-readable file sizes
  - `log()` - Logging with timestamps
  - `verify_backup()` - Integrity checking
  - `sanitize_input()` - Security validation
  - `send_email_notification()` - Email reports

### 5. Filesystem (`fs.sh`)
- **Purpose:** File and directory operations
- **Key Functions:**
  - `create_backup_archive()` - Create compressed backups
  - `find_projects()` - Discover projects
  - `upload_to_cloud()` - Cloud storage upload
  - `download_from_cloud()` - Cloud storage download
  - `extract_backup()` - Restore operations

### 6. User Interface (`ui.sh`)
- **Purpose:** User interaction and display
- **Key Functions:**
  - `print_dashboard_header()` - Progress display
  - `display_backup_summary()` - Results summary
  - `show_backup_help()` - Help text
  - `select_projects()` - Interactive selection

### 7. Reporting (`reporting.sh`)
- **Purpose:** Generate reports and visualizations
- **Key Functions:**
  - `create_backup_report()` - HTML reports
  - `create_email_report()` - Email summaries
  - `generate_history_chart()` - Visualizations
  - `create_visual_dashboard()` - Dashboard HTML

## Data Flow

### Backup Process

```
1. User runs backup.sh
   │
2. Load config.sh → Get source dirs, backup dir
   │
3. Find projects in source directories
   │
4. For each project:
   │   ├── Get project size
   │   ├── Create tar.gz archive
   │   ├── Verify archive (optional)
   │   ├── Upload to cloud (optional)
   │   └── Log results
   │
5. Generate HTML report
   │
6. Send email notification (optional)
   │
7. Update backup history log
```

### Restore Process

```
1. User runs restore.sh
   │
2. List available backups
   │
3. User selects backup
   │
4. Extract archive to destination
   │
5. Verify extraction
   │
6. Report results
```

## File Organization

### Root Level (Active)
```
backup-webdev/
├── webdev-backup.sh      # Main entry point
├── backup.sh             # Core backup
├── restore.sh            # Restoration
├── config.sh             # Configuration
├── utils.sh              # Utilities
├── fs.sh                 # Filesystem ops
├── ui.sh                 # User interface
├── reporting.sh          # Reports
├── error-handling.sh     # Error management
├── quick-backup.sh       # Quick backup
├── cleanup.sh            # Maintenance
└── [other scripts...]
```

### Archived Structure
```
archive/
└── src.legacy/           # Archived alternative structure
    ├── core/
    ├── utils/
    ├── ui/
    ├── reports/
    ├── security/
    ├── test/             # Still referenced
    └── setup/
```

## Security Architecture

### Security Layers

1. **Input Validation**
   - `sanitize_input()` - Command injection prevention
   - `validate_path()` - Path traversal prevention

2. **File Permissions**
   - `umask 027` - Restrictive defaults
   - `secure-permissions.sh` - Permission management

3. **Encryption**
   - AES-256-GCM encryption
   - PBKDF2 key derivation
   - Secure key management

4. **Archive Safety**
   - Path traversal detection
   - Filename validation
   - Safe extraction flags

## Extension Points

### Adding New Features

1. **New Backup Type:**
   - Add function to `backup.sh`
   - Update `webdev-backup.sh` menu
   - Add to `config.sh` if needed

2. **New Cloud Provider:**
   - Add case to `upload_to_cloud()` in `fs.sh`
   - Add case to `download_from_cloud()` in `fs.sh`
   - Update documentation

3. **New Report Format:**
   - Add function to `reporting.sh`
   - Call from `backup.sh` or `restore.sh`

## Performance Considerations

- **Parallel Compression:** Uses `pigz` when available
- **Progress Monitoring:** Real-time file size tracking
- **Incremental Backups:** Only changed files
- **Exclusion Rules:** Skips `node_modules` automatically
- **Timeout Protection:** Prevents hanging on large directories

## Error Handling

- Centralized error handling via `error-handling.sh`
- Logging to files and console
- Graceful degradation (fallbacks)
- User-friendly error messages

---

**For detailed component documentation, see individual script headers and README.md**

