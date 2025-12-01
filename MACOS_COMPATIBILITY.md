# macOS Compatibility Guide

## Overview

This document outlines the compatibility status of the WebDev Backup Tool on macOS and the changes made to ensure cross-platform support.

## Compatibility Status

✅ **The backup tool is compatible with macOS** with the following considerations:

### Working Features
- All core backup functionality (full, incremental, differential)
- Compression (gzip and pigz if installed)
- Cloud storage integration (AWS S3, DigitalOcean Spaces, etc.)
- Restore operations
- HTML reporting
- Email notifications
- Browser opening (uses macOS `open` command)

### Platform-Specific Differences

#### 1. Command Differences

**stat command:**
- Linux: `stat -c %Y` (modification time), `stat -c %s` (size), `stat -c %a` (permissions)
- macOS: `stat -f %m` (modification time), `stat -f %z` (size), `stat -f %OLp` (permissions)
- **Status:** ✅ Fixed - Code includes fallbacks for both systems

**du command:**
- Linux: `du -sb --exclude="pattern"` (supports --exclude)
- macOS: `du -sb` (does NOT support --exclude flag)
- **Status:** ✅ Fixed - Uses alternative method on macOS (find + du)

**find command:**
- Linux (GNU find): Supports `-printf` option
- macOS (BSD find): Does NOT support `-printf` option
- **Status:** ✅ Fixed - Uses alternative method on macOS (find + stat)

**sha256sum:**
- Linux: `sha256sum` command
- macOS: `shasum -a 256` command
- **Status:** ✅ Already handled - Code checks for both

#### 2. Path Differences

**Default Backup Directory:**
- WSL2/Ubuntu: `/mnt/e/backups` (always uses this path on WSL2/Windows)
- macOS: First external volume found at `/Volumes/VolumeName/backups` (to save space on main drive), falls back to `~/backups` if no external volume is available
- **Status:** ✅ Fixed - Auto-detects OS and uses appropriate default

**Backup Naming:**
- Previous: `wsl2_backup_YYYY-MM-DD_HH-MM-SS`
- Current: `webdev_backup_YYYY-MM-DD_HH-MM-SS` (OS-agnostic)
- **Status:** ✅ Fixed - Uses generic prefix

#### 3. Optional Dependencies

**Installation on macOS:**

```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install optional dependencies
brew install pigz        # For parallel compression
brew install gnuplot     # For chart generation
brew install awscli      # For cloud storage
```

## Testing on macOS

To verify compatibility on macOS:

1. **Run configuration check:**
   ```bash
   ./check-config.sh
   ```

2. **Run test suite:**
   ```bash
   ./run-all-tests.sh
   ```

3. **Test a quick backup:**
   ```bash
   ./backup.sh --quick
   ```

## Known Limitations

1. **Cron Jobs:** macOS uses `launchd` instead of cron. The `configure-cron.sh` script may need adjustments for macOS users. Consider using `launchd` plist files instead.

2. **File Permissions:** macOS handles file permissions slightly differently. The `stat -f %OLp` format may differ from Linux `stat -c %a` in some edge cases.

3. **Path Lengths:** macOS has a 1024 character path limit (vs Linux's 4096), though this is unlikely to be an issue for typical web development projects.

## Migration from WSL2/Ubuntu to macOS

If you're migrating from WSL2/Ubuntu to macOS:

1. **Update config.sh:**
   - Change `DEFAULT_BACKUP_DIR` from `/mnt/e/backups` to `~/backups` or your preferred location
   - The backup prefix will automatically change from `wsl2_backup` to `webdev_backup`

2. **Existing Backups:**
   - Backups created on WSL2 with `wsl2_backup_*` naming will still be recognized
   - The restore script can handle both naming conventions

3. **Test First:**
   - Run `./check-config.sh` to verify all dependencies
   - Run a test backup before backing up important data

## Reporting Issues

If you encounter macOS-specific issues:

1. Check the logs in `logs/backup_history.log`
2. Run `./check-config.sh` to verify dependencies
3. Check that you're using the latest version of the tool
4. Report issues with:
   - macOS version (e.g., macOS 14.5)
   - Error messages from logs
   - Output from `./check-config.sh`

## Summary

The backup tool is **fully compatible with macOS** after the compatibility fixes. All core functionality works identically on both Linux/WSL2 and macOS. The main differences are in low-level command syntax, which have been abstracted away with OS detection and fallback mechanisms.

