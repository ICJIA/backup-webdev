#!/bin/bash
# configure-cron.sh - Sets up automated backups via cron
# This script creates, modifies, or removes the backup cron job

# Source the shared modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/ui.sh"

# Backup script path (absolute path)
BACKUP_SCRIPT="$SCRIPT_DIR/webdev-backup.sh"
TMP_CRONTAB="/tmp/crontab.$$"
CRON_COMMENT="# WebDev Backup Tool automatic backup"
DEFAULT_INTERVAL=72 # Default backup interval in hours

# Banner
echo -e "\n${CYAN}===============================================${NC}"
echo -e "${CYAN}|        WebDev Backup Cron Configuration      |${NC}"
echo -e "${CYAN}===============================================${NC}"
echo -e "${GREEN}Set up automated backups using cron${NC}\n"

# Check if crontab command exists
if ! command -v crontab >/dev/null 2>&1; then
    echo -e "${RED}Error: 'crontab' command not found. Please install cron to use this feature.${NC}"
    exit 1
fi

# Check if the backup script exists and is executable
if [ ! -x "$BACKUP_SCRIPT" ]; then
    echo -e "${RED}Error: Backup script not found or not executable: $BACKUP_SCRIPT${NC}"
    echo "Please check permissions and run 'chmod +x $BACKUP_SCRIPT' if needed."
    exit 1
fi

# Function to get existing backup cron job if any
get_existing_cron() {
    crontab -l 2>/dev/null | grep -F "$BACKUP_SCRIPT" | grep -v "^#"
}

# Function to get the current interval from crontab
get_current_interval() {
    local cron_line=$(get_existing_cron)
    
    if [ -z "$cron_line" ]; then
        # No existing cron job
        echo "none"
        return
    fi
    
    # Extract schedule from cron line
    local schedule=$(echo "$cron_line" | awk '{print $1, $2, $3, $4, $5}')
    
    # Try to determine interval
    if [[ "$schedule" == "0 */72 * * *" ]]; then
        echo "72 hours"
    elif [[ "$schedule" == "0 */24 * * *" ]]; then
        echo "24 hours"
    elif [[ "$schedule" == "0 */12 * * *" ]]; then
        echo "12 hours"
    elif [[ "$schedule" == "0 */6 * * *" ]]; then
        echo "6 hours"
    elif [[ "$schedule" == "0 */3 * * *" ]]; then
        echo "3 hours"
    elif [[ "$schedule" == "0 0 * * *" ]]; then
        echo "Daily at midnight"
    elif [[ "$schedule" == "0 0 * * 0" ]]; then
        echo "Weekly (Sunday midnight)"
    elif [[ "$schedule" == "0 0 1 * *" ]]; then
        echo "Monthly (1st day)"
    else
        echo "Custom ($schedule)"
    fi
}

# Check current cron status
CURRENT_CRON=$(get_existing_cron)
CURRENT_INTERVAL=$(get_current_interval)

# Show current status
if [ -n "$CURRENT_CRON" ]; then
    echo -e "${GREEN}Automatic backup is currently ENABLED${NC}"
    echo -e "Schedule: ${YELLOW}$CURRENT_INTERVAL${NC}"
    echo -e "Command: ${YELLOW}$(echo "$CURRENT_CRON" | awk '{$1=$2=$3=$4=$5=""; print $0}' | sed 's/^[ \t]*//')${NC}"
else
    echo -e "${YELLOW}Automatic backup is currently DISABLED${NC}"
fi

# Menu for cron configuration
echo -e "\n${CYAN}Select an option:${NC}"
echo "1) Enable automatic backup (every 72 hours)"
echo "2) Change backup frequency"
echo "3) Customize backup options"
echo "4) Disable automatic backup"
echo "5) View upcoming backup times"
echo "q) Quit without changes"
echo

# Get user choice
read -p "Enter your choice [1-5/q]: " choice

case "$choice" in
    1)
        # Enable automatic backup with default interval
        echo -e "\n${CYAN}Setting up automatic backup every 72 hours...${NC}"
        
        # Create new crontab
        (crontab -l 2>/dev/null | grep -v "$BACKUP_SCRIPT"; echo "$CRON_COMMENT"; echo "0 */72 * * * $BACKUP_SCRIPT --silent") > "$TMP_CRONTAB"
        crontab "$TMP_CRONTAB"
        rm -f "$TMP_CRONTAB"
        
        echo -e "${GREEN}✓ Automatic backup enabled. Backups will run every 72 hours in silent mode.${NC}"
        ;;
    2)
        # Change backup frequency
        echo -e "\n${CYAN}Select backup frequency:${NC}"
        echo "1) Every 3 hours"
        echo "2) Every 6 hours"
        echo "3) Every 12 hours"
        echo "4) Every 24 hours (daily)"
        echo "5) Every 72 hours (every 3 days)"
        echo "6) Weekly (Sunday at midnight)"
        echo "7) Monthly (1st day of month)"
        echo "8) Custom schedule (advanced)"
        echo
        
        read -p "Enter your choice [1-8]: " freq_choice
        
        # Set schedule based on choice
        case "$freq_choice" in
            1) SCHEDULE="0 */3 * * *" && INTERVAL="3 hours" ;;
            2) SCHEDULE="0 */6 * * *" && INTERVAL="6 hours" ;;
            3) SCHEDULE="0 */12 * * *" && INTERVAL="12 hours" ;;
            4) SCHEDULE="0 */24 * * *" && INTERVAL="24 hours" ;;
            5) SCHEDULE="0 */72 * * *" && INTERVAL="72 hours" ;;
            6) SCHEDULE="0 0 * * 0" && INTERVAL="weekly (Sunday midnight)" ;;
            7) SCHEDULE="0 0 1 * *" && INTERVAL="monthly (1st day)" ;;
            8)
                echo -e "\n${CYAN}Enter custom cron schedule (in crontab format):${NC}"
                echo "Format: minute hour day-of-month month day-of-week"
                echo "Example: 30 2 * * * (runs at 2:30 AM every day)"
                read -p "Schedule: " SCHEDULE
                INTERVAL="custom ($SCHEDULE)"
                ;;
            *)
                echo -e "${RED}Invalid choice. Using default schedule (every 72 hours).${NC}"
                SCHEDULE="0 */72 * * *"
                INTERVAL="72 hours"
                ;;
        esac
        
        # Create new crontab
        (crontab -l 2>/dev/null | grep -v "$BACKUP_SCRIPT"; echo "$CRON_COMMENT"; echo "$SCHEDULE $BACKUP_SCRIPT --silent") > "$TMP_CRONTAB"
        crontab "$TMP_CRONTAB"
        rm -f "$TMP_CRONTAB"
        
        echo -e "${GREEN}✓ Automatic backup enabled with $INTERVAL interval.${NC}"
        ;;
    3)
        # Customize backup options
        echo -e "\n${CYAN}Customize backup options:${NC}"
        echo -e "${YELLOW}Default: $BACKUP_SCRIPT --silent${NC}"
        echo "Available options:"
        echo "  --incremental              Only backup files changed since last backup"
        echo "  --differential             Only backup files changed since last full backup"
        echo "  --verify                   Verify backup integrity after completion"
        echo "  --compression LEVEL        Set compression level (1-9, default: 6)"
        echo "  --email EMAIL              Send notification email to specified address"
        echo "  --cloud PROVIDER           Upload backup to cloud storage (aws, dropbox, gdrive)"
        echo "  --source DIR               Set custom source directory to backup"
        echo "  --destination DIR          Set custom backup destination directory"
        echo
        read -p "Enter additional options: " custom_options
        
        # Ask for schedule if not already set
        if [ -z "$SCHEDULE" ]; then
            echo -e "\n${CYAN}Select backup frequency:${NC}"
            echo "1) Every 72 hours (default)"
            echo "2) Daily (midnight)"
            echo "3) Weekly (Sunday)"
            echo "4) Custom"
            read -p "Enter your choice [1-4]: " sched_choice
            
            case "$sched_choice" in
                2) SCHEDULE="0 0 * * *" && INTERVAL="daily (midnight)" ;;
                3) SCHEDULE="0 0 * * 0" && INTERVAL="weekly (Sunday)" ;;
                4)
                    echo -e "\n${CYAN}Enter custom cron schedule (in crontab format):${NC}"
                    echo "Format: minute hour day-of-month month day-of-week"
                    read -p "Schedule: " SCHEDULE
                    INTERVAL="custom ($SCHEDULE)"
                    ;;
                *) SCHEDULE="0 */72 * * *" && INTERVAL="72 hours" ;;
            esac
        fi
        
        # Create new crontab with custom options
        (crontab -l 2>/dev/null | grep -v "$BACKUP_SCRIPT"; echo "$CRON_COMMENT"; echo "$SCHEDULE $BACKUP_SCRIPT --silent $custom_options") > "$TMP_CRONTAB"
        crontab "$TMP_CRONTAB"
        rm -f "$TMP_CRONTAB"
        
        echo -e "${GREEN}✓ Automatic backup enabled with custom options.${NC}"
        echo -e "${GREEN}✓ Schedule: $INTERVAL${NC}"
        echo -e "${GREEN}✓ Command: $BACKUP_SCRIPT --silent $custom_options${NC}"
        ;;
    4)
        # Disable automatic backup
        echo -e "\n${CYAN}Disabling automatic backup...${NC}"
        
        # Remove backup entries from crontab
        (crontab -l 2>/dev/null | grep -v "$BACKUP_SCRIPT" | grep -v "$CRON_COMMENT") > "$TMP_CRONTAB"
        crontab "$TMP_CRONTAB"
        rm -f "$TMP_CRONTAB"
        
        echo -e "${GREEN}✓ Automatic backup disabled.${NC}"
        ;;
    5)
        # View upcoming backup times
        echo -e "\n${CYAN}Upcoming scheduled backups:${NC}"
        
        if [ -z "$CURRENT_CRON" ]; then
            echo -e "${YELLOW}No automatic backups currently scheduled.${NC}"
        else
            # Extract cron schedule part
            CRON_SCHEDULE=$(echo "$CURRENT_CRON" | awk '{print $1, $2, $3, $4, $5}')
            
            # Try to predict the next few runs
            if command -v ncal >/dev/null 2>&1 && command -v date >/dev/null 2>&1; then
                CURRENT_MONTH=$(date +%m)
                CURRENT_YEAR=$(date +%Y)
                # Simple prediction based on current schedule
                # Note: This is a simplified approach and won't work for all cron schedules
                if [[ "$CRON_SCHEDULE" == "0 */72 * * *" ]]; then
                    echo "Next backup in approximately 72 hours"
                    NEXT_DATE=$(date -d "now + 72 hours" "+%Y-%m-%d %H:%M")
                    echo "  $NEXT_DATE"
                    NEXT_DATE=$(date -d "now + 144 hours" "+%Y-%m-%d %H:%M")
                    echo "  $NEXT_DATE"
                    NEXT_DATE=$(date -d "now + 216 hours" "+%Y-%m-%d %H:%M")
                    echo "  $NEXT_DATE"
                elif [[ "$CRON_SCHEDULE" == "0 0 * * *" ]]; then
                    echo "Backups will run daily at midnight"
                    NEXT_DATE=$(date -d "tomorrow 00:00" "+%Y-%m-%d %H:%M")
                    echo "  $NEXT_DATE"
                    NEXT_DATE=$(date -d "tomorrow + 1 day 00:00" "+%Y-%m-%d %H:%M")
                    echo "  $NEXT_DATE"
                    NEXT_DATE=$(date -d "tomorrow + 2 day 00:00" "+%Y-%m-%d %H:%M")
                    echo "  $NEXT_DATE"
                elif [[ "$CRON_SCHEDULE" == "0 0 * * 0" ]]; then
                    echo "Backups will run weekly on Sunday at midnight"
                    NEXT_SUNDAY=$(date -d "next Sunday 00:00" "+%Y-%m-%d %H:%M")
                    echo "  $NEXT_SUNDAY"
                    NEXT_SUNDAY=$(date -d "next Sunday + 7 days 00:00" "+%Y-%m-%d %H:%M")
                    echo "  $NEXT_SUNDAY"
                else
                    echo -e "${YELLOW}Cannot predict exact times for current schedule: $CRON_SCHEDULE${NC}"
                    echo "Current schedule: $CURRENT_INTERVAL"
                fi
            else
                echo -e "${YELLOW}Cannot predict exact times - required tools not available${NC}"
                echo "Current schedule: $CURRENT_INTERVAL"
            fi
        fi
        ;;
    q|Q)
        echo -e "\n${CYAN}Exiting without changes.${NC}"
        exit 0
        ;;
    *)
        echo -e "\n${RED}Invalid option. No changes made.${NC}"
        exit 1
        ;;
esac

echo -e "\n${CYAN}Cron configuration completed.${NC}"

# Exit gracefully
echo -e "\n${GREEN}Cron configuration completed. Thanks for using WebDev Backup Tool!${NC}"

exit 0