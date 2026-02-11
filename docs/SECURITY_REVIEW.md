# Security Review: WebDev Backup Tool

**Platforms reviewed:** macOS, Linux (Ubuntu), Linux under WSL2 (Ubuntu).  
**Last updated:** 2026-02-10

## Summary

The app is sound for desktop/CLI use. Path sanitization, archive traversal checks, `mktemp`, safe permissions, and `umask 027` are used consistently. All `/tmp/` predictable-path usage has been eliminated from active code. The security audit (`./security-audit.sh`) passes with no issues.

---

## Issues Found and Fixed

### 1. Unsafe temp file: `/tmp/email_message_$$` (utils.sh) — FIXED

**Risk:** Predictable path. On multi-user or shared systems, another process could pre-create it as a symlink.  
**Fix:** Replaced with `mktemp`, `chmod 600`, then `rm -f` after use.

### 2. Unsafe temp files in compare-backups.sh — FIXED

**Risk:** Dead code wrote to `/tmp/added_$$`, `/tmp/deleted_$$`, `/tmp/changed_$$`.  
**Fix:** Removed the three writes. The function's output variables were unused; the main loop uses `mktemp -d` and `comm` directly.

### 3. Syntax error in compare-backups.sh — FIXED

**Issue:** `find_latest_backup()` had a broken if/else with a pipe split across the block.  
**Fix:** Inlined the full pipeline on each branch so macOS and Linux use the correct `find`/`stat` variant.

### 4. Tar extract missing `--no-same-owner` (fs.sh) — FIXED

**Risk:** `extract_backup()` in `fs.sh` used plain `tar -xzf`. On Linux, if run as root, tar would restore original file ownership, which could create root-owned files in user directories. The verification extract in `utils.sh` already used `--no-same-owner`.  
**Fix:** Added `--no-same-owner` to `extract_backup()` on Linux. Skipped on macOS (BSD tar doesn't support it; macOS tar already ignores ownership by default for non-root).

### 5. Overly permissive script permissions — FIXED

**Risk:** Scripts could be set to world-writable (e.g. `chmod 777`), allowing any user to modify them.  
**Fix:** Use `./secure-permissions.sh` to set proper permissions (755 scripts, 640 config, 750 dirs). `umask 027` is used in utils, encryption, and setup scripts.

---

## Noted (No Change Required)

### 6. `run_cmd` uses `eval` (cleanup.sh)

**Risk:** Low. All call sites pass literal strings with config-derived variables (e.g. `run_cmd "mkdir -p \"$BACKUP_DIR\""`). No network/untrusted inputs. Config is user-owned.  
**Recommendation:** Consider refactoring to avoid `eval` if CLI args ever become untrusted.

### 7. Restore history temp file (restore.sh)

**Observation:** `TEMP_LOG=$(mktemp)` used correctly; `mv` to final path. If killed before `mv`, a temp file is left. No symlink/injection risk.  
**Recommendation:** Optional: add a trap for cleanup.

### 8. CLI path validation

**Observation:** `--source` / `--destination` are checked with `verify_directory` or `-d` / `-w` tests but not passed through `validate_path()`. Acceptable for single-user CLI. Recommend adding validation if inputs ever come from untrusted sources.

---

## What's in Good Shape

- **No `/tmp/` in active code.** All temp files use `mktemp` / `mktemp -d`.
- **Path sanitization:** `validate_path()` and `sanitize_input()` used for email, browser, and sensitive contexts.
- **Archive safety:** Traversal checks (`../`, absolute paths) before extraction; `--no-same-owner` on extract.
- **Permissions:** `umask 027` in utils/encryption/setup; `secure-permissions.sh` sets 755/640/750.
- **Secrets:** `secrets.sh` gitignored; mail credentials wiped with `shred` or `dd` + `rm`.
- **Security audit:** Portable (`-perm -0002`), excludes archive, allowlists templates and controlled eval. Passes clean.
- **Platform:** Same code paths on macOS, Linux, WSL2. `--no-same-owner` skipped on macOS (not needed). No platform-specific gaps.

---

## Test Results

All tests pass. Security audit reports 0 issues.

```
Unit Tests:       38/38 PASSED
Integration Tests: 10/10 PASSED
Security Audit:   0 issues found
```

---

## All Changes Made

1. **utils.sh** — `mktemp` for basic-email message file (was `/tmp/email_message_$$`)
2. **compare-backups.sh** — Removed dead `/tmp/..._$$` writes; fixed `find_latest_backup()` syntax
3. **fs.sh** — Added `--no-same-owner` to `extract_backup()` on Linux
4. **Permissions** — Use `secure-permissions.sh` for 755/640/750; `umask 027` in key scripts
