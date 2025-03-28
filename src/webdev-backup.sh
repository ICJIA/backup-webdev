#!/bin/bash
# webdev-backup.sh - Main launcher for WebDev Backup Tool
# Provides a menu to run various components of the system

# Source the shared modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../core/config.sh"
source "$SCRIPT_DIR/../utils/utils.sh"
source "$SCRIPT_DIR/../ui/ui.sh"
source "$SCRIPT_DIR/../reports/reporting.sh"

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
if [ ${#DEFAULT_SOURCE_DIRS[@]} -gt 0 ]; then
    echo -e "Source directories:"
    for ((i=0; i<${#DEFAULT_SOURCE_DIRS[@]}; i++)); do
        echo -e "- [${i}] ${DEFAULT_SOURCE_DIRS[$i]} ($(realpath "${DEFAULT_SOURCE_DIRS[$i]}"))"
        
        # Check if projects exist in source directory
        if [ -d "${DEFAULT_SOURCE_DIRS[$i]}" ]; then
            PROJECT_COUNT=$(find "${DEFAULT_SOURCE_DIRS[$i]}" -maxdepth 1 -type d | wc -l)
            PROJECT_COUNT=$((PROJECT_COUNT - 1)) # Subtract 1 for the directory itself
            
            if [ "$PROJECT_COUNT" -eq 0 ]; then
                echo -e "  ${RED}No projects found in this directory${NC}"
            else
                echo -e "  ${GREEN}$PROJECT_COUNT projects found${NC}"
            fi
        else
            echo -e "  ${RED}Directory does not exist${NC}"
        fi
    done
else
    echo -e "${RED}No source directories configured!${NC}"
fi

echo -e "- Backup destination:    ${BACKUP_DIR:-$DEFAULT_BACKUP_DIR} (Absolute: $(realpath "${BACKUP_DIR:-$DEFAULT_BACKUP_DIR}"))"
echo -e "- Logs directory:        $LOGS_DIR (Absolute: $(realpath "$LOGS_DIR"))"
echo -e "- Test directory:        $TEST_DIR (Absolute: $(realpath "$TEST_DIR"))"

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
echo "9) Manage Source Directories"
echo "0) Advanced Options"
echo "q) Quit"
echo

# Get user choice
read -p "Enter your choice [0-9/q]: " choice

case "$choice" in
    1)
        echo -e "\n${CYAN}Select backup storage type:${NC}"
        echo "1) Local Project Storage (Default: $(realpath "${BACKUP_DIR:-$DEFAULT_BACKUP_DIR}"))"
        echo "2) External Volume Storage (Custom local path)"
        echo "3) Cloud Storage (DigitalOcean, AWS, etc.)"
        read -p "Enter your choice [1/2/3]: " storage_choice
        
        case "$storage_choice" in
            1)
                echo -e "\n${GREEN}Using Local Project Storage${NC}"
                echo -e "Path: ${DEFAULT_BACKUP_DIR}\n"
                sleep 1
                "$SCRIPT_DIR/backup.sh" "$@"
                ;;
            2)
                echo -e "\n${CYAN}Using External Volume Storage${NC}"
                read -p "Enter external volume path: " custom_path
                if [[ -n "$custom_path" ]]; then
                    echo -e "\n${GREEN}Using external volume: $custom_path${NC}\n"
                    sleep 1
                    "$SCRIPT_DIR/backup.sh" --dest "$custom_path" "$@"
                else
                    echo -e "\n${YELLOW}No path entered. Using default path: ${GREEN}$DEFAULT_BACKUP_DIR${NC}\n"
                    sleep 1
                    "$SCRIPT_DIR/backup.sh" "$@"
                fi
                ;;
            3)
                echo -e "\n${CYAN}Select cloud provider:${NC}"
                echo "1) DigitalOcean Spaces (default)"
                echo "2) AWS S3"
                echo "3) Dropbox"
                echo "4) Google Drive"
                read -p "Enter your choice [1-4]: " cloud_choice
                
                case "$cloud_choice" in
                    1|"")
                        echo -e "\n${CYAN}Using CLOUD STORAGE (DigitalOcean Spaces)${NC}\n"
                        sleep 1
                        "$SCRIPT_DIR/backup.sh" --external --cloud do "$@"
                        ;;
                    2)
                        echo -e "\n${CYAN}Using CLOUD STORAGE (AWS S3)${NC}\n"
                        sleep 1
                        "$SCRIPT_DIR/backup.sh" --external --cloud aws "$@"
                        ;;
                    3)
                        echo -e "\n${CYAN}Using CLOUD STORAGE (Dropbox)${NC}\n"
                        sleep 1
                        "$SCRIPT_DIR/backup.sh" --external --cloud dropbox "$@"
                        ;;
                    4)
                        echo -e "\n${CYAN}Using CLOUD STORAGE (Google Drive)${NC}\n"
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
                echo -e "\n${YELLOW}Invalid choice. Using Local Project Storage.${NC}\n"
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
            # Fix the backup size extraction to handle multiline output properly
            backup_size=$(echo "$recent_backup" | grep -A1 "Total Size:" | tr -d '\n' | grep -o "Total Size: [^ ]* [A-Z]*" | cut -d':' -f2- | xargs)
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
            
            # Create simplified dashboard without gnuplot
            DASHBOARD_FILE="$SCRIPT_DIR/logs/dashboard/backup_dashboard.html"
            
            # Create dashboard with ultra-minimal HTML (no CSS, no complex styling)
            cat > "$DASHBOARD_FILE" << EOL
<!DOCTYPE html>
<html>
<head>
    <title>WebDev Backup Dashboard</title>
</head>
<body>
    <h1>WebDev Backup Dashboard</h1>
    <p>Generated on $(date)</p>
    
    <hr>
    <h2>Last Backup Summary</h2>
    <ul>
        <li><strong>Date:</strong> $backup_date</li>
        <li><strong>Projects:</strong> $projects_count</li>
        <li><strong>Total Size:</strong> $backup_size</li>
        <li><strong>Location:</strong> <code>$backup_location</code></li>
    </ul>
    
    <hr>
    <h2>Recent Backup History</h2>
    <pre>
$(grep -A2 "BACKUP: SUCCESS" "$BACKUP_HISTORY_LOG" | head -9)
    </pre>
    
    <hr>
    <h2>Failed Backups</h2>
    <pre>
$(if grep -q "BACKUP: FAILED\|BACKUP: PARTIAL" "$BACKUP_HISTORY_LOG"; then
  echo "<strong>WARNING: Failed backups detected!</strong>"
  echo ""
  grep -A6 "BACKUP: FAILED\|BACKUP: PARTIAL" "$BACKUP_HISTORY_LOG" | head -16 | \
    sed 's/Destination: \(.*\)/<strong>Full path:<\/strong> \1/'
  
  # Get a list of potential failed projects if available
  if grep -q "failed" "$BACKUP_HISTORY_LOG"; then
    echo ""
    echo "<strong>Projects with errors:</strong>"
    grep -B3 "failed," "$BACKUP_HISTORY_LOG" | grep "Projects:" | \
      sed 's/Projects: \([0-9]*\) succeeded, \([0-9]*\) failed/\2 project(s) had errors/'
  fi
else
  echo "No failed backups found in the history log."
fi)
    </pre>
    
    <hr>
    <h3>All Backup Locations (Most Recent First)</h3>
    <ul>
$(grep "Destination:" "$BACKUP_HISTORY_LOG" | head -10 | sed 's/.*Destination: \(.*\)/<li><code>\1<\/code><\/li>/')
    </ul>
    
    <hr>
    <p>WebDev Backup Tool - Backup report</p>
</body>
</html>
EOL
            
            echo -e "${GREEN}✓ Simple HTML Dashboard created: $DASHBOARD_FILE${NC}"
            
            # Try to open the dashboard, preferring text-based browsers first
            if [ -n "$DASHBOARD_FILE" ] && [ -f "$DASHBOARD_FILE" ]; then
                echo -e "\n${GREEN}✓ HTML Dashboard generated successfully!${NC}"
                
                # Try text-based browsers first to avoid GPU issues
                if command -v lynx >/dev/null 2>&1; then
                    echo -e "${CYAN}Opening in text browser (lynx)...${NC}"
                    lynx "$DASHBOARD_FILE"
                    return_to_menu=true
                elif command -v w3m >/dev/null 2>&1; then
                    echo -e "${CYAN}Opening in text browser (w3m)...${NC}"
                    w3m "$DASHBOARD_FILE"
                    return_to_menu=true
                elif command -v links >/dev/null 2>&1; then
                    echo -e "${CYAN}Opening in text browser (links)...${NC}"
                    links "$DASHBOARD_FILE"
                    return_to_menu=true
                # Fall back to graphical browsers if text browsers aren't available
                elif command -v xdg-open >/dev/null 2>&1; then
                    echo -e "${CYAN}Opening in browser...${NC}"
                    echo -e "${YELLOW}Note: You can also view the file directly: less $DASHBOARD_FILE${NC}"
                    xdg-open "$DASHBOARD_FILE" &
                elif command -v open >/dev/null 2>&1; then
                    echo -e "${CYAN}Opening in browser...${NC}"
                    echo -e "${YELLOW}Note: You can also view the file directly: less $DASHBOARD_FILE${NC}"
                    open "$DASHBOARD_FILE" &
                else
                    # If no browser is available, display the file with less
                    echo -e "${YELLOW}Opening dashboard with less:${NC}"
                    less "$DASHBOARD_FILE"
                    return_to_menu=true
                fi
                
                echo -e "${GREEN}Dashboard saved to: $DASHBOARD_FILE${NC}"
                
                # Offer to display plain text version
                echo -e "${CYAN}Would you like to see a plain text version of the dashboard? [y/N] ${NC}"
                read -n 1 -r display_text
                echo
                if [[ "$display_text" =~ ^[Yy]$ ]]; then
                    echo -e "\n${CYAN}===== DASHBOARD TEXT VERSION =====${NC}\n"
                    echo "WEBDEV BACKUP DASHBOARD"
                    echo "Generated on: $(date)"
                    echo "-------------------------------------"
                    echo "LAST BACKUP SUMMARY:"
                    echo "  Date:       $backup_date"
                    echo "  Projects:   $projects_count"
                    echo "  Total Size: $backup_size"
                    echo -e "  Location:   ${GREEN}$backup_location${NC}"
                    echo "-------------------------------------"
                    echo "RECENT BACKUP HISTORY:"
                    grep -A2 "BACKUP: SUCCESS" "$BACKUP_HISTORY_LOG" | head -9 | sed 's/^/  /'
                    echo "-------------------------------------"
                    # Show failed backups with detailed information
                    echo "FAILED BACKUPS:"
                    if grep -q "BACKUP: FAILED\|BACKUP: PARTIAL" "$BACKUP_HISTORY_LOG"; then
                        echo -e "  ${RED}WARNING: Failed backups detected!${NC}"
                        echo
                        grep -A6 "BACKUP: FAILED\|BACKUP: PARTIAL" "$BACKUP_HISTORY_LOG" | head -16 | \
                          sed -E "s/^(.*(FAILED|PARTIAL).*)/${RED}\1${NC}/" | \
                          sed -E "s/.*Destination: (.*)/${GREEN}  Full path: \1${NC}/" | \
                          sed 's/^/  /'
                    else
                        echo "  No failed backups found in the history log."
                    fi
                    echo "-------------------------------------"
                    echo "ALL BACKUP LOCATIONS (MOST RECENT FIRST):"
                    grep "Destination:" "$BACKUP_HISTORY_LOG" | head -5 | \
                      sed -E "s/.*Destination: (.*)/${GREEN}  \1${NC}/"
                    echo "-------------------------------------"
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
        # New option to manage source directories
        clear
        echo -e "${CYAN}===== Manage Source Directories =====${NC}"
        echo -e "Current source directories:"
        
        for ((i=0; i<${#DEFAULT_SOURCE_DIRS[@]}; i++)); do
            if [ -d "${DEFAULT_SOURCE_DIRS[$i]}" ]; then
                STATUS="${GREEN}(exists)${NC}"
                PROJECT_COUNT=$(find "${DEFAULT_SOURCE_DIRS[$i]}" -maxdepth 1 -type d | wc -l)
                PROJECT_COUNT=$((PROJECT_COUNT - 1))
                STATUS="$STATUS ${CYAN}$PROJECT_COUNT projects${NC}"
            else
                STATUS="${RED}(not found)${NC}"
            fi
            echo -e "[$i] ${DEFAULT_SOURCE_DIRS[$i]} $STATUS"
        done
        
        echo -e "\n${CYAN}Select action:${NC}"
        echo "1) Add new source directory"
        echo "2) Remove source directory"
        echo "3) Back to main menu"
        
        read -p "Enter your choice [1-3]: " dir_choice
        
        case "$dir_choice" in
            1)
                read -p "Enter path to new source directory: " new_dir
                
                if [ -n "$new_dir" ]; then
                    # Expand ~ in path if present
                    new_dir="${new_dir/#\~/$HOME}"
                    
                    if [ -d "$new_dir" ]; then
                        # Check if already in the list
                        ALREADY_EXISTS=false
                        for dir in "${DEFAULT_SOURCE_DIRS[@]}"; do
                            if [ "$dir" = "$new_dir" ]; then
                                ALREADY_EXISTS=true
                                break
                            fi
                        done
                        
                        if [ "$ALREADY_EXISTS" = false ]; then
                            # Add to the array in config.sh
                            TEMP_CONFIG=$(mktemp)
                            # Extract the part before and after the DEFAULT_SOURCE_DIRS array
                            awk '/^DEFAULT_SOURCE_DIRS=\(\)/{flag=1} flag && /^\)/{flag=0; print "DEFAULT_SOURCE_DIRS=("; for(i=0; i<dir_count; i++) print "    \"" dirs[i] "\""; print "    \"'$new_dir'\""; print ")" ; next} flag{dirs[dir_count++]=$0; next} {print}' dir_count=0 "$SCRIPT_DIR/config.sh" > "$TEMP_CONFIG"
                            
                            # Backup the current config
                            cp "$SCRIPT_DIR/config.sh" "$SCRIPT_DIR/config.sh.bak"
                            
                            # Replace the config with the new one
                            mv "$TEMP_CONFIG" "$SCRIPT_DIR/config.sh"
                            
                            echo -e "${GREEN}Added new source directory: $new_dir${NC}"
                            echo -e "${YELLOW}Please restart the tool to see the new directory.${NC}"
                        else
                            echo -e "${YELLOW}Directory already exists in the source list.${NC}"
                        fi
                    else
                        echo -e "${RED}Error: Directory does not exist: $new_dir${NC}"
                        echo -e "${YELLOW}Would you like to create it? [y/N]${NC}"
                        read create_dir
                        
                        if [[ "$create_dir" =~ ^[Yy]$ ]]; then
                            if mkdir -p "$new_dir"; then
                                echo -e "${GREEN}Directory created: $new_dir${NC}"
                                
                                # Add to the array in config.sh
                                TEMP_CONFIG=$(mktemp)
                                awk '/^DEFAULT_SOURCE_DIRS=\(\)/{flag=1} flag && /^\)/{flag=0; print "DEFAULT_SOURCE_DIRS=("; for(i=0; i<dir_count; i++) print "    \"" dirs[i] "\""; print "    \"'$new_dir'\""; print ")" ; next} flag{dirs[dir_count++]=$0; next} {print}' dir_count=0 "$SCRIPT_DIR/config.sh" > "$TEMP_CONFIG"
                                
                                # Backup the current config
                                cp "$SCRIPT_DIR/config.sh" "$SCRIPT_DIR/config.sh.bak"
                                
                                # Replace the config with the new one
                                mv "$TEMP_CONFIG" "$SCRIPT_DIR/config.sh"
                                
                                echo -e "${GREEN}Added new source directory: $new_dir${NC}"
                                echo -e "${YELLOW}Please restart the tool to see the new directory.${NC}"
                            else
                                echo -e "${RED}Failed to create directory: $new_dir${NC}"
                            fi
                        fi
                    fi
                fi
                ;;
            2)
                if [ ${#DEFAULT_SOURCE_DIRS[@]} -gt 0 ]; then
                    read -p "Enter the number of the directory to remove [0-$((${#DEFAULT_SOURCE_DIRS[@]}-1))]: " remove_idx
                    
                    if [[ "$remove_idx" =~ ^[0-9]+$ ]] && [ "$remove_idx" -lt "${#DEFAULT_SOURCE_DIRS[@]}" ]; then
                        dir_to_remove="${DEFAULT_SOURCE_DIRS[$remove_idx]}"
                        
                        # Remove from the array in config.sh
                        TEMP_CONFIG=$(mktemp)
                        awk -v remove_idx="$remove_idx" '/^DEFAULT_SOURCE_DIRS=\(\)/{flag=1} flag && /^\)/{flag=0; print "DEFAULT_SOURCE_DIRS=("; for(i=0; i<dir_count; i++) if(i != remove_idx) print "    \"" dirs[i] "\""; print ")" ; next} flag{dirs[dir_count++]=$0; next} {print}' dir_count=0 "$SCRIPT_DIR/config.sh" > "$TEMP_CONFIG"
                        
                        # Backup the current config
                        cp "$SCRIPT_DIR/config.sh" "$SCRIPT_DIR/config.sh.bak"
                        
                        # Replace the config with the new one
                        mv "$TEMP_CONFIG" "$SCRIPT_DIR/config.sh"
                        
                        echo -e "${GREEN}Removed source directory: $dir_to_remove${NC}"
                        echo -e "${YELLOW}Please restart the tool to see the changes.${NC}"
                    else
                        echo -e "${RED}Invalid directory number.${NC}"
                    fi
                else
                    echo -e "${RED}No source directories to remove.${NC}"
                fi
                ;;
            *)
                # Back to main menu
                exec "$0" "$@"  # Restart menu
                ;;
        esac
        
        read -p "Press Enter to return to the main menu..."
        exec "$0" "$@"  # Restart menu
        ;;
    0)
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