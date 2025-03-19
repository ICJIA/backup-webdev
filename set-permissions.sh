#!/bin/bash
# set-permissions.sh - Sets permissions on all shell scripts to be executable by any user

# Get the script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "\033[0;36m===== WebDev Backup Tool Permission Setup =====\033[0m"
echo "This script will set all .sh files to be executable, writable, and readable by any user"
echo ""

# Find all .sh files in the project directory and its subdirectories
SHELL_SCRIPTS=$(find "$SCRIPT_DIR" -type f -name "*.sh")

# Count the scripts
SCRIPT_COUNT=$(echo "$SHELL_SCRIPTS" | wc -l)
echo -e "\033[0;33mFound $SCRIPT_COUNT shell scripts to update permissions\033[0m"

# Set permissions for each script
for script in $SHELL_SCRIPTS; do
    chmod 777 "$script"
    echo -e "\033[0;32m✓ Set permissions for: $(basename "$script")\033[0m"
done

# Set permissions on this script too
chmod 777 "$0"

echo ""
echo -e "\033[0;32mAll script permissions have been updated successfully!\033[0m"
echo "Each script now has permission mode 777:"
echo "  - Owner: Read, Write, Execute"
echo "  - Group: Read, Write, Execute"
echo "  - Other: Read, Write, Execute"
echo ""
echo -e "\033[0;33mNote: While these broad permissions make the scripts easier to use,\033[0m"
echo -e "\033[0;33mthey may present security concerns in shared environments.\033[0m"
echo ""

exit 0
