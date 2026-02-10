#!/bin/bash
# config.sh - Configuration file for WebDev Backup Tool
#
# ==================================================================================
# SINGLE SOURCE OF TRUTH - Edit the section below to customize your backup.
# Works on both macOS and Linux.
#
# REQUIRED: You must set at least one SOURCE directory and one DESTINATION
# directory. The app will not run until both are configured.
# ==================================================================================


# ==================================================================================
#   USER CONFIGURATION - EDIT THESE SETTINGS
# ==================================================================================
#
#   SOURCE DIRECTORIES (what to back up)
#   ------------------------------------
#   Required: Add at least one directory. The app will not start without it.
#
#   ---------------
#   macOS examples:
#   ---------------
#     $HOME = internal boot disk. /Volumes/VolumeName = external drive (no $HOME).
#     Many devs keep the OS on the internal disk and store code/data on externals.
#
#     Internal disk (home directory):
#       DEFAULT_SOURCE_DIRS=("$HOME/Developer")
#       DEFAULT_SOURCE_DIRS=("$HOME/Developer" "$HOME/Documents/Projects")
#       DEFAULT_SOURCE_DIRS=("$HOME")
#
#     External volume (use your volume name as shown in Finder):
#       DEFAULT_SOURCE_DIRS=("/Volumes/MySSD/Developer")
#       DEFAULT_SOURCE_DIRS=("/Volumes/Code/projects" "/Volumes/Code/repos")
#       Mix of internal + external:
#       DEFAULT_SOURCE_DIRS=("$HOME/Developer" "/Volumes/MySSD/Projects")
#
#   ---------------
#   Linux examples:
#   ---------------
#     $HOME or /home/username = typically boot/internal disk. /mnt/... = mounted
#     drive (external, second disk, WSL2, or network). Many devs keep OS on the
#     main disk and store code/data on a separate drive or mount.
#
#     Internal disk (home directory):
#       DEFAULT_SOURCE_DIRS=("/home/username/projects")
#       DEFAULT_SOURCE_DIRS=("$HOME/projects" "$HOME/repos" "$HOME/code")
#       DEFAULT_SOURCE_DIRS=("$HOME")
#
#     Mounted drive (use your actual mount point under /mnt/ or /media/):
#       DEFAULT_SOURCE_DIRS=("/mnt/data/projects")
#       DEFAULT_SOURCE_DIRS=("/mnt/ssd/developer" "/mnt/ssd/repos")
#       Mix of internal + mounted:
#       DEFAULT_SOURCE_DIRS=("$HOME/projects" "/mnt/data/legacy-code")
#
#     --- WSL2 (Windows Subsystem for Linux) ---
#     In WSL2, Windows drives are under /mnt/<letter>/ (e.g. C: = /mnt/c).
#     External USB drives: Windows assigns a drive letter (e.g. E:); use
#     /mnt/e/ in WSL2. There is no /media/ auto-mount for USB like native
#     Linux—always use /mnt/<letter>/. Drive letters can change if you
#     plug in devices in a different order. Access to /mnt/ is slower than
#     the Linux filesystem; keep sources on $HOME when possible, use /mnt/
#     for backup destination if you want backups on a Windows-visible drive.
#       DEFAULT_SOURCE_DIRS=("/mnt/d/Projects")
#       DEFAULT_SOURCE_DIRS=("$HOME/projects" "/mnt/d/legacy")
#
#   Configure at least one source (replace with your own paths):
#
DEFAULT_SOURCE_DIRS=()


#
#   DESTINATION DIRECTORY (where to store backups)
#   ----------------------------------------------
#   Required: Set a path. The app will not start without it.
#
#   ---------------
#   macOS examples:
#   ---------------
#     $HOME = internal disk. /Volumes/VolumeName = external (no $HOME).
#     Storing backups on an external is recommended to save space on the boot disk.
#
#     Internal disk:
#       DEFAULT_BACKUP_DIR="$HOME/backups"
#
#     External volume (use the exact name shown in Finder under /Volumes/):
#       DEFAULT_BACKUP_DIR="/Volumes/MyExternalDrive/backups"
#       DEFAULT_BACKUP_DIR="/Volumes/Backup/backups"
#       DEFAULT_BACKUP_DIR="/Volumes/MySSD/backups"
#     Internal "Macintosh HD" (not recommended; use external if possible):
#       DEFAULT_BACKUP_DIR="/Volumes/Macintosh HD/Backups"
#
#   ---------------
#   Linux examples:
#   ---------------
#     $HOME or /home/username = internal disk. /mnt/... = mounted drive (no $HOME).
#     Storing backups on a separate drive or mount is recommended when possible.
#
#     Internal disk:
#       DEFAULT_BACKUP_DIR="$HOME/backups"
#       DEFAULT_BACKUP_DIR="/home/username/backups"
#
#     Mounted drive (native Linux; use your mount point under /mnt/ or /media/):
#       DEFAULT_BACKUP_DIR="/mnt/backup/backups"
#       DEFAULT_BACKUP_DIR="/mnt/external/backups"
#       DEFAULT_BACKUP_DIR="/media/username/ExternalDrive/backups"
#
#     --- WSL2: backing up to an external or Windows drive ---
#     Use /mnt/<letter>/ only. Windows assigns letters (C:, D:, E: = /mnt/c,
#     /mnt/d, /mnt/e). External USB = whatever letter Windows gives it (e.g.
#     E: → /mnt/e/backups). Ensure the drive is visible in Windows Explorer
#     first; then use that letter under /mnt/. No /media/ in WSL2.
#       DEFAULT_BACKUP_DIR="/mnt/e/backups"
#       DEFAULT_BACKUP_DIR="/mnt/d/Backups"
#
#   Configure your destination (replace with your own path):
#
DEFAULT_BACKUP_DIR=""


#
#   Cloud storage provider (reserved for a later iteration)
#   Leave blank for now. Cloud backup will be supported in a future release.
#
DEFAULT_CLOUD_PROVIDER=""


# ==================================================================================
#   END OF USER CONFIGURATION
# ==================================================================================
#
#   Do not change anything below unless you know what you are doing.
#
# ==================================================================================


# ==================================================================================
#   INTERNAL CONFIGURATION - DO NOT EDIT UNLESS YOU KNOW WHAT YOU ARE DOING
# ==================================================================================

# Version and paths (required by scripts)
VERSION="1.7.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIRST_RUN_MARKER="$SCRIPT_DIR/.configured"

# Backup naming and date format
BACKUP_PREFIX="webdev_backup"
DATE_FORMAT="%Y-%m-%d_%H-%M-%S"

# When running the test suite, use test defaults if user has not configured source/dest
if [ -n "${RUNNING_TESTS:-}" ]; then
    if [ ${#DEFAULT_SOURCE_DIRS[@]} -eq 0 ]; then
        DEFAULT_SOURCE_DIRS=("$SCRIPT_DIR/test-projects")
    fi
    if [ -z "$DEFAULT_BACKUP_DIR" ]; then
        DEFAULT_BACKUP_DIR="$SCRIPT_DIR/test/backup_out"
    fi
fi

# ----------------------------------------------------------------------------------
# Validation: require at least one source and one destination (manual config required)
# ----------------------------------------------------------------------------------
_config_file="${SCRIPT_DIR}/config.sh"

if [ ${#DEFAULT_SOURCE_DIRS[@]} -eq 0 ]; then
    echo ""
    echo "ERROR: No source directory configured."
    echo ""
    echo "  You must set at least one SOURCE in:"
    echo "    ${_config_file}"
    echo ""
    echo "  Edit DEFAULT_SOURCE_DIRS=() and add your folder(s). Examples:"
    echo "    macOS:   DEFAULT_SOURCE_DIRS=(\"\$HOME/Developer\")"
    echo "    Linux:   DEFAULT_SOURCE_DIRS=(\"/home/username/projects\")"
    echo ""
    exit 1
fi

if [ -z "$DEFAULT_BACKUP_DIR" ]; then
    echo ""
    echo "ERROR: No destination directory configured."
    echo ""
    echo "  You must set DESTINATION in:"
    echo "    ${_config_file}"
    echo ""
    echo "  Edit DEFAULT_BACKUP_DIR=\"\" and set a path. Examples:"
    echo "    macOS:   DEFAULT_BACKUP_DIR=\"\$HOME/backups\""
    echo "    Linux:   DEFAULT_BACKUP_DIR=\"\$HOME/backups\""
    echo ""
    exit 1
fi

# Derived defaults (only reached when config is valid)
DEFAULT_SOURCE_DIR="${DEFAULT_SOURCE_DIRS[0]}"

# Ensure backup directory exists and is writable
if [ ! -d "$DEFAULT_BACKUP_DIR" ]; then
    if ! mkdir -p "$DEFAULT_BACKUP_DIR" 2>/dev/null; then
        echo ""
        echo "ERROR: Could not create backup directory: $DEFAULT_BACKUP_DIR"
        echo "  Check permissions or choose a different path in: ${_config_file}"
        echo ""
        exit 1
    fi
elif [ ! -w "$DEFAULT_BACKUP_DIR" ]; then
    echo ""
    echo "ERROR: Backup directory is not writable: $DEFAULT_BACKUP_DIR"
    echo "  Fix permissions or choose a different path in: ${_config_file}"
    echo ""
    exit 1
fi

# Runtime paths and exports
DATE=$(date +$DATE_FORMAT)
LOGS_DIR="$SCRIPT_DIR/logs"
TEST_DIR="$SCRIPT_DIR/test"
mkdir -p "$LOGS_DIR" "$TEST_DIR"
BACKUP_HISTORY_LOG="$LOGS_DIR/backup_history.log"
TEST_HISTORY_LOG="$TEST_DIR/test_history.log"
BACKUP_DIR="$DEFAULT_BACKUP_DIR"

export SCRIPT_DIR DEFAULT_SOURCE_DIRS DEFAULT_SOURCE_DIR DEFAULT_BACKUP_DIR BACKUP_DIR DEFAULT_CLOUD_PROVIDER
export LOGS_DIR TEST_DIR DATE_FORMAT DATE BACKUP_PREFIX
export BACKUP_HISTORY_LOG TEST_HISTORY_LOG VERSION FIRST_RUN_MARKER
