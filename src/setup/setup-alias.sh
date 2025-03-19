#!/bin/bash
# setup-alias.sh - Sets up shell aliases for WebDev Backup Tool

# Get the script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_SCRIPT="$SCRIPT_DIR/webdev-backup.sh"

# Banner
echo -e "\033[0;36m===== WebDev Backup Tool Alias Setup =====\033[0m"
echo "This script will add an alias to your ~/.zshrc file"
echo "The alias 'webback' will run the WebDev Backup Tool from any directory"
echo ""

# Check if script exists
if [ ! -f "$MAIN_SCRIPT" ]; then
    echo -e "\033[0;31mERROR: Main script not found at $MAIN_SCRIPT\033[0m"
    exit 1
fi

# Make sure the script is executable
chmod +x "$MAIN_SCRIPT"

# Create alias line
ALIAS_LINE="alias webback='$MAIN_SCRIPT'"

# Check if ~/.zshrc exists
if [ ! -f ~/.zshrc ]; then
    echo -e "\033[0;33mCreating ~/.zshrc file\033[0m"
    touch ~/.zshrc
fi

# Check if alias already exists
if grep -q "alias webback=" ~/.zshrc; then
    echo -e "\033[0;33mAlias already exists in ~/.zshrc\033[0m"
    # Update existing alias
    sed -i "s|alias webback=.*|$ALIAS_LINE|" ~/.zshrc
    echo -e "\033[0;32mUpdated existing alias to point to: $MAIN_SCRIPT\033[0m"
else
    # Add the alias to ~/.zshrc
    echo "" >> ~/.zshrc
    echo "# WebDev Backup Tool alias" >> ~/.zshrc
    echo "$ALIAS_LINE" >> ~/.zshrc
    echo -e "\033[0;32mAdded alias to ~/.zshrc successfully\033[0m"
fi

# Remind the user to restart the shell or source the file
echo ""
echo "To use the alias immediately, run:"
echo "  source ~/.zshrc"
echo ""
echo "You can now run the WebDev Backup Tool from any directory using:"
echo "  webback"
echo ""

# Make this script executable
chmod +x "$0"

exit 0
