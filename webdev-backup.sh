#!/bin/bash
# webdev-backup.sh - Main launcher for WebDev Backup Tool
# Provides a menu to run various components of the system

# Source the shared modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/ui.sh"

# Get passed arguments to forward to other scripts if needed
ARGS="$@"

# Check if silent mode or dry-run is requested - pass through to backup script
if [[ "$*" == *"--silent"* ]] || [[ "$*" == *"--dry-run"* ]]; then
    # Skip menu in silent/dry-run mode and directly run backup
    exec "$SCRIPT_DIR/backup.sh" "$@"
    exit $?
fi

# Display header
clear
echo -e "${CYAN}===============================================${NC}"
echo -e "${CYAN}|          WebDev Backup Tool v1.6.0         |${NC}"
echo -e "${CYAN}===============================================${NC}"
echo -e "${GREEN}A robust backup solution for web development projects${NC}"
echo -e "Current date: $(date '+%Y-%m-%d %H:%M:%S')\n"

# Show configuration summary
echo -e "${YELLOW}Current Configuration:${NC}"
echo -e "- Source directory:      ${SOURCE_DIR:-$DEFAULT_SOURCE_DIR}"
echo -e "- Backup destination:    ${BACKUP_DIR:-$DEFAULT_BACKUP_DIR}"
echo -e "- Logs directory:        $LOGS_DIR"
echo -e "- Test directory:        $TEST_DIR"

# Check if projects exist in source directory
if [ -d "${SOURCE_DIR:-$DEFAULT_SOURCE_DIR}" ]; then
    PROJECT_COUNT=$(find "${SOURCE_DIR:-$DEFAULT_SOURCE_DIR}" -maxdepth 1 -type d | wc -l)
    PROJECT_COUNT=$((PROJECT_COUNT - 1)) # Subtract 1 for the directory itself
    
    if [ "$PROJECT_COUNT" -eq 0 ]; then
        echo -e "${RED}WARNING: No web projects found in source directory!${NC}"
    else
        echo -e "- Projects found:        $PROJECT_COUNT"
    fi
else
    echo -e "${RED}WARNING: Source directory does not exist!${NC}"
fi

echo

# Show last backup if available
if [ -f "$BACKUP_HISTORY_LOG" ]; then
    LAST_BACKUP=$(head -1 "$BACKUP_HISTORY_LOG" | grep -o "[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\} [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}")
    echo -e "${GREEN}Last backup: $LAST_BACKUP${NC}"
    echo
fi

# Main menu
echo -e "${CYAN}Select an option:${NC}"
echo "1) Run Backup (Interactive Mode)"
echo "2) Run Comprehensive Tests"
echo "3) Run Cleanup Tool"
echo "4) Restore Backups"
echo "5) View Backup Dashboard"
echo "6) View Project Documentation"
echo "7) View Backup History"
echo "8) Configure Automated Backups (Cron)"
echo "9) Advanced Options"
echo "q) Quit"
echo

# Get user choice
read -p "Enter your choice [1-9/q]: " choice

case "$choice" in
    1)
        echo -e "\n${CYAN}Select backup storage type:${NC}"
        echo "1) Internal (Local Storage)"
        echo "2) External (Cloud Storage)"
        read -p "Enter your choice [1/2]: " storage_choice
        
        case "$storage_choice" in
            1)
                echo -e "\n${GREEN}Using INTERNAL storage (local backup)${NC}"
                echo -e "Default path: ${DEFAULT_BACKUP_DIR}\n"
                read -p "Use custom backup path? [y/N] " custom_path_choice
                
                if [[ "$custom_path_choice" =~ ^[Yy]$ ]]; then
                    read -p "Enter custom backup path: " custom_path
                    if [[ -n "$custom_path" ]]; then
                        echo -e "\n${GREEN}Using custom backup path: $custom_path${NC}\n"
                        sleep 1
                        "$SCRIPT_DIR/backup.sh" --dest "$custom_path" "$@"
                    else
                        echo -e "\n${YELLOW}No path entered. Using default path.${NC}\n"
                        sleep 1
                        "$SCRIPT_DIR/backup.sh" "$@"
                    fi
                else
                    echo -e "\n${GREEN}Using default backup path${NC}\n"
                    sleep 1
                    "$SCRIPT_DIR/backup.sh" "$@"
                fi
                ;;
            2)
                echo -e "\n${CYAN}Select cloud provider:${NC}"
                echo "1) DigitalOcean Spaces (default)"
                echo "2) AWS S3"
                echo "3) Dropbox"
                echo "4) Google Drive"
                read -p "Enter your choice [1-4]: " cloud_choice
                
                case "$cloud_choice" in
                    1|"")
                        echo -e "\n${CYAN}Using EXTERNAL storage (DigitalOcean Spaces)${NC}\n"
                        sleep 1
                        "$SCRIPT_DIR/backup.sh" --external --cloud do "$@"
                        ;;
                    2)
                        echo -e "\n${CYAN}Using EXTERNAL storage (AWS S3)${NC}\n"
                        sleep 1
                        "$SCRIPT_DIR/backup.sh" --external --cloud aws "$@"
                        ;;
                    3)
                        echo -e "\n${CYAN}Using EXTERNAL storage (Dropbox)${NC}\n"
                        sleep 1
                        "$SCRIPT_DIR/backup.sh" --external --cloud dropbox "$@"
                        ;;
                    4)
                        echo -e "\n${CYAN}Using EXTERNAL storage (Google Drive)${NC}\n"
                        sleep 1
                        "$SCRIPT_DIR/backup.sh" --external --cloud gdrive "$@"
                        ;;
                    *)
                        echo -e "\n${RED}Invalid choice. Using default (DigitalOcean Spaces)${NC}\n"
                        sleep 1
                        "$SCRIPT_DIR/backup.sh" --external --cloud do "$@"
                        ;;
                esac
                ;;
            *)
                echo -e "\n${YELLOW}Invalid choice. Using internal storage.${NC}\n"
                sleep 1
                "$SCRIPT_DIR/backup.sh" "$@"
                ;;
        esac
        ;;
    2)
        echo -e "\n${CYAN}Running comprehensive tests...${NC}\n"
        sleep 1
        "$SCRIPT_DIR/run-tests.sh"
        ;;
    3)
        echo -e "\n${CYAN}Starting cleanup tool...${NC}\n"
        sleep 1
        "$SCRIPT_DIR/cleanup.sh"
        ;;
    4)
        echo -e "\n${CYAN}Starting restore utility...${NC}\n"
        sleep 1
        "$SCRIPT_DIR/restore.sh"
        ;;
    5)
        # Show dashboard if available, otherwise generate one
        echo -e "\n${CYAN}===== WebDev Backup Dashboard =====${NC}\n"
        
        if [ -f "$BACKUP_HISTORY_LOG" ]; then
            # Extract information from backup history for text-based dashboard
            recent_backup=$(grep -A7 "BACKUP: SUCCESS" "$BACKUP_HISTORY_LOG" | head -7)
            backup_date=$(echo "$recent_backup" | grep -o "[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\} [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}")
            projects_count=$(echo "$recent_backup" | grep "Projects:" | grep -o "[0-9]* succeeded" | grep -o "[0-9]*")
            backup_size=$(echo "$recent_backup" | grep "Total Size:" | grep -o "[^ ]* [A-Z]*")
            backup_location=$(echo "$recent_backup" | grep "Destination:" | cut -d':' -f2- | xargs)
            
            echo -e "${YELLOW}Last Backup Summary:${NC}"
            echo -e "  Date:        ${GREEN}$backup_date${NC}"
            echo -e "  Projects:    ${GREEN}$projects_count${NC}"
            echo -e "  Total Size:  ${GREEN}$backup_size${NC}"
            echo -e "  Location:    ${GREEN}$backup_location${NC}"
            
            # Show last few backups
            echo -e "\n${YELLOW}Recent Backup History:${NC}"
            grep -A2 "BACKUP: SUCCESS" "$BACKUP_HISTORY_LOG" | head -9 | sed 's/^/  /'
            
            # Check if there are any failed backups
            failed_count=$(grep -c "BACKUP: FAILED\|BACKUP: PARTIAL" "$BACKUP_HISTORY_LOG")
            if [ "$failed_count" -gt 0 ]; then
                echo -e "\n${RED}Failed Backups in History: $failed_count${NC}"
                grep -A2 "BACKUP: FAILED\|BACKUP: PARTIAL" "$BACKUP_HISTORY_LOG" | head -6 | sed 's/^/  /'
            fi
            
            # Try to generate HTML dashboard as well
            DASHBOARD_FILE=""
            echo -e "\n${CYAN}Generating HTML dashboard...${NC}"
            mkdir -p "$SCRIPT_DIR/logs/dashboard"
            DASHBOARD_FILE=$(create_visual_dashboard "$SCRIPT_DIR/logs/dashboard" "$BACKUP_HISTORY_LOG")
            
            # Try to open the dashboard
            if [ -n "$DASHBOARD_FILE" ] && [ -f "$DASHBOARD_FILE" ]; then
                echo -e "\n${GREEN}✓ HTML Dashboard generated successfully!${NC}"
                if command -v xdg-open >/dev/null 2>&1; then
                    echo -e "${CYAN}Opening in browser...${NC}"
                    xdg-open "$DASHBOARD_FILE" &
                elif command -v open >/dev/null 2>&1; then
                    echo -e "${CYAN}Opening in browser...${NC}"
                    open "$DASHBOARD_FILE" &
                else
                    echo -e "${YELLOW}HTML Dashboard saved to: $DASHBOARD_FILE${NC}"
                    echo -e "${YELLOW}Please open it manually in your browser.${NC}"
                fi
            fi
            
            # Check for gnuplot
            if ! command -v gnuplot >/dev/null 2>&1; then
                echo -e "\n${YELLOW}Note: Install gnuplot for better graphical dashboards${NC}"
                echo -e "${GREEN}sudo apt-get install gnuplot${NC} (Debian/Ubuntu)"
                echo -e "${GREEN}sudo yum install gnuplot${NC} (Red Hat/CentOS)"
                echo -e "${GREEN}brew install gnuplot${NC} (macOS with Homebrew)"
            fi
        else
            echo -e "${YELLOW}No backup history found. Run a backup first.${NC}"
        fi
        
        echo -e "\n${CYAN}Press Enter to return to menu...${NC}"
        read
        exec "$0" "$@"  # Restart menu
        ;;
    6)
        # Display README
        if command -v less >/dev/null 2>&1; then
            less "$SCRIPT_DIR/README.md"
        else
            cat "$SCRIPT_DIR/README.md" | more
        fi
        sleep 1
        exec "$0" "$@"  # Restart menu
        ;;
    7)
        # View backup history
        echo -e "\n${CYAN}Backup History:${NC}\n"
        if [ -f "$BACKUP_HISTORY_LOG" ]; then
            if command -v less >/dev/null 2>&1; then
                less "$BACKUP_HISTORY_LOG"
            else
                cat "$BACKUP_HISTORY_LOG" | more
            fi
        else
            echo -e "${YELLOW}No backup history available. Run a backup first.${NC}"
            sleep 2
        fi
        exec "$0" "$@"  # Restart menu
        ;;
    8)
        # Automated backups configuration
        echo -e "\n${CYAN}Starting cron configuration utility...${NC}\n"
        sleep 1
        "$SCRIPT_DIR/configure-cron.sh"
        
        # Ask if user wants to return to the main menu
        echo ""
        read -p "Press Enter to return to the main menu..." dummy
        exec "$0" "$@"  # Restart menu
        ;;
    9)
        # Advanced options submenu
        clear
        echo -e "${CYAN}===============================================${NC}"
        echo -e "${CYAN}|          Advanced Options Menu             |${NC}"
        echo -e "${CYAN}===============================================${NC}"
        echo
        echo "1) Run Incremental Backup"
        echo "2) Run Differential Backup"
        echo "3) Run Backup with Verification"
        echo "4) Run Backup with Thorough Verification"
        echo "5) Run Backup with Cloud Upload"
        echo "6) Run Backup with Email Notification"
        echo "7) Run Backup with Maximum Compression"
        echo "8) Run Backup with Parallel Processing"
        echo "9) Run Backup in Dry-Run Mode (simulation)"
        echo "0) Run Custom Backup Command..."
        echo "b) Back to Main Menu"
        echo
        read -p "Enter your choice [0-9/b]: " adv_choice
        
        case "$adv_choice" in
            1)
                echo -e "\n${CYAN}Starting incremental backup...${NC}\n"
                sleep 1
                "$SCRIPT_DIR/backup.sh" --incremental "$@"
                ;;
            2)
                echo -e "\n${CYAN}Starting differential backup...${NC}\n"
                sleep 1
                "$SCRIPT_DIR/backup.sh" --differential "$@"
                ;;
            3)
                echo -e "\n${CYAN}Starting backup with verification...${NC}\n"
                sleep 1
                "$SCRIPT_DIR/backup.sh" --verify "$@"
                ;;
            4)
                echo -e "\n${CYAN}Starting backup with thorough verification...${NC}\n"
                sleep 1
                "$SCRIPT_DIR/backup.sh" --thorough-verify "$@"
                ;;
            5)
                echo "Available cloud providers:"
                echo "1) Amazon S3"
                echo "2) Google Drive"
                echo "3) Dropbox"
                read -p "Select cloud provider [1-3]: " cloud_choice
                
                case "$cloud_choice" in
                    1) CLOUD="aws" ;;
                    2) CLOUD="gdrive" ;;
                    3) CLOUD="dropbox" ;;
                    *) CLOUD="aws" ;;
                esac
                
                echo -e "\n${CYAN}Starting backup with $CLOUD upload...${NC}\n"
                sleep 1
                "$SCRIPT_DIR/backup.sh" --cloud "$CLOUD" "$@"
                ;;
            6)
                read -p "Enter email for notification: " email
                if [[ -n "$email" ]]; then
                    echo -e "\n${CYAN}Starting backup with email notification...${NC}\n"
                    sleep 1
                    "$SCRIPT_DIR/backup.sh" --email "$email" "$@"
                else
                    echo -e "${YELLOW}No email provided. Returning to menu.${NC}"
                    sleep 2
                    exec "$0" "$@"  # Restart menu
                fi
                ;;
            7)
                echo -e "\n${CYAN}Starting backup with maximum compression...${NC}\n"
                sleep 1
                "$SCRIPT_DIR/backup.sh" --compression 9 "$@"
                ;;
            8)
                read -p "Enter number of threads [1-8]: " threads
                if [[ "$threads" =~ ^[1-8]$ ]]; then
                    echo -e "\n${CYAN}Starting backup with $threads threads...${NC}\n"
                    sleep 1
                    "$SCRIPT_DIR/backup.sh" --parallel "$threads" "$@"
                else
                    echo -e "${YELLOW}Invalid thread count. Using default.${NC}"
                    sleep 1
                    "$SCRIPT_DIR/backup.sh" "$@"
                fi
                ;;
            9)
                echo -e "\n${CYAN}Starting backup in dry-run mode (simulation)...${NC}\n"
                sleep 1
                "$SCRIPT_DIR/backup.sh" --dry-run "$@"
                ;;
            0)
                echo -e "\n${CYAN}Enter custom backup command:${NC}"
                echo -e "${YELLOW}Base command: ./backup.sh ${NC}"
                read -p "Options: " custom_opts
                echo -e "\n${CYAN}Executing: ./backup.sh $custom_opts${NC}\n"
                sleep 1
                "$SCRIPT_DIR/backup.sh" $custom_opts
                ;;
            b|*)
                exec "$0" "$@"  # Restart menu
                ;;
        esac
        ;;
    q|Q)
        echo -e "\n${CYAN}Exiting WebDev Backup Tool. Goodbye!${NC}\n"
        exit 0
        ;;
    *)
        echo -e "\n${YELLOW}Invalid option. Please try again.${NC}\n"
        sleep 1
        exec "$0" "$@"  # Restart menu
        ;;
esac

exit 0