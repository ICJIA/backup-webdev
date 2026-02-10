#!/bin/bash
# set-permissions.sh - Sets permissions on all shell scripts to be executable
# NOTE: For stricter permissions use ./secure-permissions.sh instead.

# Set restrictive umask
umask 027

# Get the script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "\033[0;36m===== WebDev Backup Tool Permission Setup =====\033[0m"
echo "This script will set all .sh files to be executable (755)"
echo ""

# Find all .sh files in the project directory and its subdirectories
SHELL_SCRIPTS=$(find "$SCRIPT_DIR" -type f -name "*.sh")

# Count the scripts
SCRIPT_COUNT=$(echo "$SHELL_SCRIPTS" | wc -l)
echo -e "\033[0;33mFound $SCRIPT_COUNT shell scripts to update permissions\033[0m"

# Set permissions for each script (owner rwx, group/other rx)
for script in $SHELL_SCRIPTS; do
    chmod 755 "$script"
    echo -e "\033[0;32m✓ Set permissions for: $(basename "$script")\033[0m"
done

# Set permissions on this script too
chmod 755 "$0"

echo ""
echo -e "\033[0;32mAll script permissions have been updated successfully!\033[0m"
echo "Each script now has permission mode 755:"
echo "  - Owner: Read, Write, Execute"
echo "  - Group: Read, Execute"
echo "  - Other: Read, Execute"
echo ""
echo -e "\033[0;33mFor stricter permissions (640/750), run ./secure-permissions.sh instead.\033[0m"
echo ""

exit 0
