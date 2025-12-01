# Changelog

All notable changes to the WebDev Backup Tool will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

## [1.7.0] - 2025-03-30

### Added
- Quick Backup feature with dedicated `quick-backup.sh` script
- Backup file organization script (`cleanup-backup-files.sh`)
- Changelog management script (`update-changelog.sh`)
- Enhanced HTML reporting with interactive project details
- Project directory grouping in reports
- File structure visualization in HTML reports
- Comprehensive test suite improvements

### Changed
- Improved Quick Backup performance and reliability
- Enhanced HTML report table layout and data accuracy
- Optimized backup process with better progress indicators
- Improved dashboard display with fallback options
- Better handling of projects with same name as parent directory

### Fixed
- Quick Backup freezing issue
- HTML reporting display issues
- Session report HTML display
- Conflicting backup locations
- External/local backup path handling
- Dashboard generation without gnuplot dependency
- Test timeout issues to prevent hanging
- Security/encryption improvements
- Backup deletion issues
- Default paths for backup target

### Security
- Enhanced encryption security (AES-256-GCM)
- Improved input sanitization
- Better path validation
- Secure file operations

## [1.0.0] - 2025-03-30

### Added
- Initial release of WebDev Backup Tool
- Full, incremental, and differential backup support
- Multi-directory backup capability
- Cloud storage integration (AWS S3, DigitalOcean Spaces, Dropbox, Google Drive)
- HTML reporting with directory grouping
- Interactive project details in reports
- File structure visualization
- Security features (encryption, secure permissions)
- Restore functionality
- Automated testing suite
- Comprehensive documentation
