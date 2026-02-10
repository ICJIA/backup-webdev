# Platform Verification: macOS, Linux, and Linux (WSL2)

This document records verification that the WebDev Backup Tool is designed and tested for **macOS**, **native Linux (e.g. Ubuntu)**, and **Linux under WSL2 (Ubuntu)**.

---

## 1. macOS

### Verified (2026-02-10)

| Check | Result |
|-------|--------|
| Config validation (empty source/dest) | ✅ Exits with clear error and config file path |
| Config validation (valid source + dest) | ✅ Proceeds; `check-config.sh` passes |
| OS display | ✅ Shows "macOS 26.2 (Darwin 25.2.0)" |
| Install hints | ✅ Suggests `brew install` for optional tools |
| Dry-run backup | ✅ Completes (e.g. `./backup.sh --dry-run --silent --source ./test-projects`) |
| Path conventions | ✅ `$HOME` = internal; `/Volumes/VolumeName` = external (documented in config.sh) |

### Code paths used on macOS

- **OS detection:** `uname -s` = `Darwin` → `detect_os()` = "macOS", `IS_MACOS=true`
- **OS version:** `get_os_version_display()` uses `sw_vers` → e.g. "macOS 26.2 (Darwin 25.2.0)"
- **File size:** `get_file_size_bytes()` uses `stat -f %z` (not `du -b`)
- **Directory size:** `get_directory_size()` uses `find` + `du -k` (no `du --exclude`)
- **Find/modtime:** `find` + `stat -f "%m %N"` (no GNU `find -printf`)
- **Checksums:** `shasum -a 256` (no `sha256sum`)
- **Timeout:** `run_with_timeout()` runs command without timeout if `timeout`/`gtimeout` not installed

---

## 2. Linux (native, e.g. Ubuntu 22.x)

### Design (not run on real hardware in this verification)

The same codebase is used. Behavior differs only where **`uname -s`** is **`Linux`**:

| Area | Behavior |
|------|----------|
| OS detection | `detect_os()` = "Linux", `IS_LINUX=true` |
| OS version | `get_os_version_display()` reads `/etc/os-release` or `lsb_release` → e.g. "Ubuntu 22.04.x LTS (Linux 5.15.x)" |
| Install hints | `check-config.sh` suggests `apt install` (not brew) |
| File size | `get_file_size_bytes()` uses `du -b` |
| Directory size | `get_directory_size()` uses `du -sb --exclude=...` |
| Find/modtime | GNU `find -printf "%T@ %p\n"` |
| Checksums | `sha256sum` (or `shasum` fallback) |
| Timeout | `run_with_timeout()` uses `timeout` if available |

Path conventions (documented in config.sh and README):

- Internal: `$HOME`, `/home/username`
- Mounted: `/mnt/name`, `/media/username/...`

### How to verify on native Ubuntu

1. Set in `config.sh`: at least one `DEFAULT_SOURCE_DIRS`, one `DEFAULT_BACKUP_DIR`.
2. Run: `./check-config.sh` → expect "Ubuntu … (Linux …)" and `apt install` hints.
3. Run: `./backup.sh --dry-run --silent --source ./test-projects` → expect dry-run to complete.

---

## 3. Linux (WSL2, Ubuntu)

### Design

WSL2 reports **`uname -s`** = **`Linux`**, so **exactly the same Linux code paths** as native Ubuntu are used. There is no separate "WSL2" branch in the code.

Differences are only **where you point the app** (paths), not how the app runs:

| Topic | WSL2-specific note |
|-------|---------------------|
| Drives | Windows drives (and external USB) appear under `/mnt/<letter>/` (e.g. C: = `/mnt/c`, E: = `/mnt/e`). |
| No /media/ | USB/external do not appear under `/media/`; use `/mnt/<letter>/` only. |
| Drive letters | Assigned by Windows; can change with plug order. Use the letter shown in Windows Explorer. |
| Performance | Access under `/mnt/` is slower than the WSL2 Linux filesystem; common pattern: sources on `$HOME`, destination on `/mnt/e/backups` (or similar). |

Config and README already describe:

- Use `/mnt/<letter>/` for any Windows drive (including external).
- Ensure the drive is visible in Windows first.
- Examples: `DEFAULT_SOURCE_DIRS=("/mnt/d/Projects")`, `DEFAULT_BACKUP_DIR="/mnt/e/backups"`.

### How to verify on WSL2 (Ubuntu)

1. In `config.sh`, set paths using `/mnt/<letter>/` (e.g. `DEFAULT_SOURCE_DIRS=("$HOME")`, `DEFAULT_BACKUP_DIR="/mnt/e/backups"` if E: is your backup drive).
2. Run: `./check-config.sh` → expect "Ubuntu … (Linux …)" and `apt install` hints.
3. Run: `./backup.sh --dry-run --silent` (or with `--source` as needed) → expect dry-run to complete.

---

## 4. Summary

| Platform | Status | Notes |
|----------|--------|--------|
| **macOS** | ✅ Verified | Validation, check-config, dry-run, OS display, and path docs checked. |
| **Linux (native Ubuntu)** | ✅ Designed / code-reviewed | Same code as WSL2; only path examples differ. Recommend running the 3 steps above on real Ubuntu when possible. |
| **Linux (WSL2 / Ubuntu)** | ✅ Designed / code-reviewed | Same as native Linux; path conventions for `/mnt/<letter>/` documented. Recommend running the 3 steps above in WSL2 when possible. |

All three platforms use the same `config.sh` (single source of truth) and the same scripts; only OS detection (`uname -s`) and path conventions (documented for each platform) differ.
