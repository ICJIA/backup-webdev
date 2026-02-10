# WebDev Backup Tool

<p align="center">
  <img src="assets/og-image.png" alt="WebDev Backup Tool" width="1200" />
</p>

A backup solution for web development projects: multiple source directories, full/incremental/differential backups, compression, integrity verification, and optional cloud (planned).

## Quick Start

**Run directly (from the repo):**

```bash
cd /path/to/backup-webdev
./webdev-backup.sh          # Interactive menu
./backup.sh --quick         # Quick backup with defaults
```

**Run from anywhere via alias** — add to `~/.bashrc` or `~/.zshrc`:

```bash
alias webback='/path/to/backup-webdev/webdev-backup.sh'
```

Use the real path to this cloned repo on your machine (e.g. `$HOME/backup-webdev` or `/Volumes/MyDrive/backup-webdev`). Then either open a new terminal or run `source ~/.zshrc` (or `source ~/.bashrc`) and use:

```bash
webback
```

You can also run `./setup-alias.sh` from the repo to add the alias for you.

## Features

- **Backup**: Multi-directory, full/incremental/differential, quick backup, compression (gzip/pigz), excludes `node_modules`
- **Restore**: With integrity validation (tar + SHA256); optional `--skip-verify`
- **Reporting**: HTML reports, email, charts (gnuplot), backup comparison
- **Security**: Permissions, secrets handling, security audit script
- **Platforms**: macOS, Linux, WSL2 (Bash 3.2+; paths differ by platform)

## Requirements

- **Bash** 3.2+ (macOS-compatible)
- **tar**, **gzip** (required); **pigz**, **gnuplot**, **AWS CLI** (optional)

## Installation

```bash
git clone https://github.com/yourusername/backup-webdev.git
cd backup-webdev
./install.sh
```

Manual: `chmod +x *.sh`, then `./setup-alias.sh` and `./check-config.sh`.

## Usage

- **Menu:** `./webdev-backup.sh`
- **Quick backup:** `./backup.sh --quick` or `./backup.sh --silent`
- **With options:** `./backup.sh --incremental --verify`, `./backup.sh --source ~/projects`, `./backup.sh --sources ~/a,~/b --verify`
- **Restore:** `./restore.sh --latest`, `./restore.sh --project myproject --dest ~/restored`
- **Compare:** `./compare-backups.sh --backup1 latest --backup2 latest` (optional `--project`, `--format json`, `--only-changes`)

## Testing

Tests run with no config (they use `test/` and `test-projects/`).

```bash
./run-tests.sh              # Unit + integration + security audit
./run-tests.sh --unit       # Unit only (6 tests)
./run-tests.sh --integration # Integration only (4 tests)
./run-tests.sh --security   # Security audit only
```

**Coverage:** Unit tests exercise helpers (`format_size`, `sanitize_input`, directory checks, `find_projects`, checksum, `verify_backup`). Integration tests run backup dry-run, full backup, and restore dry-run. The security audit checks permissions, sensitive files in git, hardcoded credentials, eval usage, and temp file handling.

You can also run `./test-backup.sh` (with `--quick`, `--unit`, or `--integration`) or `npm test`.

## Configuration

Edit **`config.sh`**. You must set at least one **source** and one **destination**; no automatic defaults.

- **`DEFAULT_SOURCE_DIRS`** – array of directories to back up
- **`DEFAULT_BACKUP_DIR`** – backup destination
- **Cloud:** Leave `DEFAULT_CLOUD_PROVIDER` blank (reserved for later)

**Paths by platform:**

| Platform | Internal / home | External / mounted |
|----------|------------------|--------------------|
| **macOS** | `$HOME`, `$HOME/Developer` | `/Volumes/VolumeName/...` |
| **Linux** | `$HOME`, `/home/user/...` | `/mnt/...`, `/media/...` |
| **WSL2** | `$HOME` | `/mnt/c`, `/mnt/e`, etc. (no `/media/`) |

First run may show **FIRST TIME SETUP** (config path and prompt). Current config is shown when you run the menu or interactive backup. Run `./check-config.sh` to validate and see OS version.

## Security

1. **`./secure-permissions.sh`** – fix script/config permissions  
2. **`./secure-secrets.sh`** – set up credential storage  
3. **`./security-audit.sh`** – check permissions, credentials, eval, temp files (also runs with `./run-tests.sh`)

Use `mktemp` for temp files; the audit allowlists templates and controlled eval in test/utility scripts.

## Scripts (root)

| Script | Purpose |
|--------|--------|
| `webdev-backup.sh` | Main menu |
| `backup.sh`, `restore.sh`, `quick-backup.sh` | Backup and restore |
| `config.sh`, `utils.sh`, `fs.sh`, `ui.sh` | Config and shared modules |
| `configure-cron.sh` | Cron schedules (uses mktemp) |
| `compare-backups.sh` | Compare two backups |
| `run-tests.sh`, `test-backup.sh` | Tests (unit + integration + security) |
| `check-config.sh`, `security-audit.sh`, `secure-*.sh` | Config and security |

Legacy code: `archive/src.legacy/`. More docs: `docs/`, `test/README.md`.

## Adding a source directory

- Menu: **Manage Source Directories** → Add  
- Or edit `config.sh` (`DEFAULT_SOURCE_DIRS`) or use `--sources path1,path2`

## Troubleshooting

| Issue | What to do |
|-------|------------|
| Permission denied | `chmod +x *.sh` or `./secure-permissions.sh` |
| Path not found | `./check-config.sh`, `./dirs-status.sh`, edit `config.sh` |
| Tests fail | `./run-tests.sh` (no config needed); ensure scripts executable |
| Backup full | `./cleanup.sh --days 30` or change destination |
| Restore validation fails | Try another backup with `./restore.sh --list`; or `--skip-verify` if sure |
| Config issues | `./check-config.sh`, edit `config.sh`, try `./backup.sh --dry-run` |

Logs: `logs/backup_history.log`, `logs/failed_backups.log`. Diagnostics: `./debug-backup.sh`, `./security-audit.sh`.

## NPM scripts

Common: `npm start`, `npm test`, `npm run backup`, `npm run backup:quick`, `npm run backup:dry`, `npm run restore`, `npm run cron`, `npm run cleanup`. Run `npm run` to list all.

## More

- **Architecture:** [ARCHITECTURE.md](ARCHITECTURE.md)  
- **Changelog:** [CHANGELOG.md](CHANGELOG.md)  
- **License:** MIT (see LICENSE)
