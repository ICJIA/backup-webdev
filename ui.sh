#!/bin/bash
# ui.sh - User interface functions for backup-webdev
# This file contains UI-related functions used across scripts

# Source the shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Print dashboard header
print_dashboard_header() {
    printf "+------------------------------------------------------------------------------+\n"
    printf "| %-76s |\n" "BACKUP DASHBOARD - $(date '+%Y-%m-%d %H:%M:%S')"
    printf "+------------------------------------------------------------------------------+\n"
    printf "| %-40s | %-10s | %-20s |\n" "PROJECT NAME" "SIZE" "STATUS"
    printf "+------------------------------------------------------------------------------+\n"
}

# Print dashboard row
print_dashboard_row() {
    local project=$1
    local size=$2
    local status=$3
    printf "| %-40s | %-10s | %-20s |\n" "$project" "$size" "$status"
}

# Print dashboard footer
print_dashboard_footer() {
    printf "+------------------------------------------------------------------------------+\n"
    printf "| %-40s | %-10s | %-20s |\n" "TOTAL" "$1" "COMPLETED"
    printf "+------------------------------------------------------------------------------+\n"
}

# Show help text for backup script
show_backup_help() {
    echo "WebDev Backup Tool"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --silent                   Run in silent mode (no user interaction, for cron jobs)"
    echo "  --incremental              Only backup files changed since last backup"
    echo "  --differential             Only backup files changed since last full backup"
    echo "  --verify                   Verify backup integrity after completion"
    echo "  --thorough-verify          Perform comprehensive integrity verification (includes extraction tests)"
    echo "  --compression LEVEL        Set compression level (1-9, default: 6)"
    echo "  --email EMAIL              Send notification email to specified address"
    echo "  --external                 Use external backup (cloud storage)"
    echo "  --cloud PROVIDER           Upload backup to cloud storage (aws, do, dropbox, gdrive)"
    echo "  --bandwidth LIMIT          Limit bandwidth usage in KB/s"
    echo "  --parallel NUM             Use parallel compression with NUM threads"
    echo "  --dry-run                  Simulate backup without making any changes"
    echo "  -d, --dest, --destination DIR  Set custom backup destination directory"
    echo "  -s, --source DIR           Set custom source directory to backup"
    echo "  -h, --help                 Show this help message"
    echo ""
    echo "Default values:"
    echo "  Source directory:           $DEFAULT_SOURCE_DIR"
    echo "  Backup destination:         $DEFAULT_BACKUP_DIR"
    echo ""
    echo "Examples:"
    echo "  $0                        # Run interactive backup with default paths"
    echo "  $0 --silent               # Run silent backup with default paths"
    echo "  $0 --incremental          # Only backup changed files"
    echo "  $0 --verify               # Verify backup integrity"
    echo "  $0 --thorough-verify      # Complete verification with extraction test"
    echo "  $0 --compression 9        # Use maximum compression"
    echo "  $0 -d /path/to/backup     # Custom destination directory"
    echo "  $0 -s /path/to/source     # Custom source directory"
    echo "  $0 --email user@example.com # Send email notification"
    echo "  $0 --parallel 4           # Use 4 threads for compression"
    echo ""
    exit 0
}

# Show help text for cleanup script
show_cleanup_help() {
    echo "WebDev Backup Cleanup Tool"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -b, --backup-logs       Backup logs before removing them"
    echo "  -a, --all-logs          Remove all logs (default: keeps last 5 runs)"
    echo "  -d, --days DAYS         Remove logs older than DAYS days"
    echo "  -s, --source DIR        Use custom source directory"
    echo "  -t, --target DIR        Use custom backup target directory"
    echo "  -y, --yes               Skip confirmation prompts"
    echo "  --dry-run               Show what would be done without doing it"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Default values:"
    echo "  Source directory:      $DEFAULT_SOURCE_DIR"
    echo "  Backup destination:    $DEFAULT_BACKUP_DIR"
    echo ""
    echo "Examples:"
    echo "  $0                     # Standard cleanup (keeps recent logs)"
    echo "  $0 -a                  # Remove all logs"
    echo "  $0 -d 30               # Remove logs older than 30 days"
    echo "  $0 -b -a               # Backup all logs before removing them"
    echo "  $0 -t /mnt/backups     # Use custom backup target"
    echo ""
    exit 0
}

# Show help text for restore script
show_restore_help() {
    echo "WebDev Backup Restore Tool"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --list                  List available backups"
    echo "  --backup-date DATE      Restore from specific backup date (YYYY-MM-DD_HH-MM-SS)"
    echo "  --latest                Restore from latest backup (default)"
    echo "  --project PROJECT       Restore specific project only"
    echo "  --file FILE             Restore specific file only"
    echo "  --test                  Test restore without actually extracting files"
    echo "  -d, --dest DIR          Set custom restore destination directory"
    echo "  -s, --source DIR        Set custom backup source directory"
    echo "  -y, --yes               Skip confirmation prompts"
    echo "  --dry-run               Show what would be done without doing it"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Default values:"
    echo "  Backup source:         $DEFAULT_BACKUP_DIR"
    echo "  Restore destination:   $DEFAULT_SOURCE_DIR"
    echo ""
    echo "Examples:"
    echo "  $0 --list              # List available backups"
    echo "  $0                     # Restore latest backup interactively"
    echo "  $0 --backup-date 2025-03-15_14-30-00  # Restore specific backup"
    echo "  $0 --project myproject # Restore only myproject"
    echo "  $0 --project myproject --file src/index.js # Restore specific file"
    echo "  $0 --test              # Test restore without extracting files"
    echo ""
    exit 0
}

# Show help text for test script
show_test_help() {
    echo "WebDev Backup Test Tool"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -s, --source DIR        Set custom source directory to test with"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Default values:"
    echo "  Source directory:     $DEFAULT_SOURCE_DIR"
    echo ""
    echo "This script tests the backup functionality without actually transferring files."
    echo "It runs a series of tests to verify that the backup process works correctly."
    echo ""
    exit 0
}

# Interactive project selection
select_projects() {
    local projects=("$@")
    local selected=()
    local excluded=()
    
    echo "Projects to backup:"
    for ((i=0; i<${#projects[@]}; i++)); do
        echo "[$i] ${projects[$i]}"
    done
    
    echo -e "\nTo exclude projects from backup, enter their numbers separated by spaces."
    echo "Press Enter to backup all projects."
    
    read -p "> " response
    
    # Process all projects
    for ((i=0; i<${#projects[@]}; i++)); do
        if [[ "$response" =~ (^|[[:space:]])$i($|[[:space:]]) ]]; then
            # Project is excluded
            excluded+=("${projects[$i]}")
        else
            # Project is selected
            selected+=("${projects[$i]}")
        fi
    done
    
    # Report selection
    if [ ${#excluded[@]} -gt 0 ]; then
        echo -e "\nExcluded projects:"
        for project in "${excluded[@]}"; do
            echo "  - $project"
        done
    fi
    
    echo -e "\nSelected projects (${#selected[@]}):"
    for project in "${selected[@]}"; do
        echo "  + $project"
    done
    
    # Return selected projects
    echo "${selected[@]}"
}

# Display backup summary
display_backup_summary() {
    local successful=$1
    local failed=$2
    local src_size=$3
    local backup_size=$4
    local location=$5
    local is_external=${6:-false}
    local cloud_provider=${7:-}
    
    echo -e "\n${CYAN}===== Backup Summary =====${NC}"
    echo "- Projects processed: $((successful + failed))"
    echo "- Successfully backed up: $successful"
    echo "- Failed backups: $failed"
    echo "- Total source size: $(format_size "$src_size")"
    echo "- Total backup size: $(format_size "$backup_size")"
    
    if [ "$backup_size" -gt 0 ] && [ "$src_size" -gt 0 ]; then
        echo "- Overall compression ratio: $(awk "BEGIN {printf \"%.1f\", ($src_size/$backup_size)}")x"
    fi
    
    echo "- Backup location: $location"
    
    # Add storage type information
    if [ "$is_external" = true ]; then
        echo -e "- Storage type: ${CYAN}EXTERNAL${NC} (${cloud_provider} cloud provider)"
    else
        echo -e "- Storage type: ${GREEN}INTERNAL${NC} (local storage)"
    fi
    
    # Add timestamp
    echo "- Completed at: $(date '+%Y-%m-%d %H:%M:%S')"
}

# Show advanced options menu
show_advanced_options() {
    echo -e "\n${CYAN}===== Advanced Backup Options =====${NC}"
    echo "1) Backup Type"
    echo "   - [F]ull: Back up all files (default)"
    echo "   - [I]ncremental: Only back up files changed since last backup"
    echo "   - [D]ifferential: Only back up files changed since last full backup"
    
    echo "2) Compression Level (1-9)"
    echo "   - 1: Fastest, lowest compression"
    echo "   - 6: Balanced (default)"
    echo "   - 9: Slowest, highest compression"
    
    echo "3) Email Notification"
    echo "   - Enter email address to receive backup reports"
    
    echo "4) Verification Options"
    echo "   - [Y]es: Verify backup integrity after completion"
    echo "   - [N]o: Skip verification (default)"
    
    echo "5) Cloud Storage Integration"
    echo "   - [N]one: Local backup only (default)"
    echo "   - [DO]: Upload to DigitalOcean Spaces (recommended)"
    echo "   - [A]WS: Upload to Amazon S3"
    echo "   - [G]Drive: Upload to Google Drive"
    echo "   - [D]ropbox: Upload to Dropbox"
    
    echo "6) Performance Options"
    echo "   - Parallel threads (1-8, default: 1)"
    echo "   - Bandwidth limit (KB/s, 0=unlimited)"
    
    echo "7) Save as Default Configuration"
    
    echo "8) Start Backup with Selected Options"
    
    echo "0) Start Backup with Default Options"
    
    read -p "Select option (0-8): " option
    
    # Handle option selection
    case "$option" in
        0)
            echo "Starting backup with default options..."
            return 0
            ;;
        1)
            read -p "Select backup type (F/I/D): " backup_type
            # Process backup type selection
            ;;
        # Additional options handling would go here
        *)
            echo "Invalid option. Using default settings."
            return 0
            ;;
    esac
}

# Display restore options
display_restore_options() {
    local backups=("$@")
    
    echo -e "\n${CYAN}===== Available Backups =====${NC}"
    
    if [ ${#backups[@]} -eq 0 ]; then
        echo "No backups found."
        return 1
    fi
    
    for ((i=0; i<${#backups[@]}; i++)); do
        echo "[$i] ${backups[$i]}"
    done
    
    echo -e "\nEnter the number of the backup to restore, or press Enter for latest:"
    read -p "> " selection
    
    if [[ -z "$selection" ]]; then
        # Default to latest backup (first in the list)
        echo "${backups[0]}"
    elif [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -lt "${#backups[@]}" ]; then
        echo "${backups[$selection]}"
    else
        echo "Invalid selection."
        return 1
    fi
}

# End of UI functions