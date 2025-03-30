#!/bin/bash
# secure-permissions.sh - Sets proper secure permissions on all files

# Set restrictive umask to ensure secure file creation
umask 027

# Get the script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "\033[0;36m===== WebDev Backup Tool Security Permissions Setup =====\033[0m"
echo "This script will set appropriate secure permissions on project files"
echo ""

# Make sure the script itself is executable
chmod +x "$0"

# Find all files and store in temporary files to avoid race conditions
TEMP_DIR=$(mktemp -d)
TEMP_SHELL_SCRIPTS="$TEMP_DIR/shell_scripts.txt"
TEMP_CONFIG_FILES="$TEMP_DIR/config_files.txt"
TEMP_JSON_FILES="$TEMP_DIR/json_files.txt"

# Use find securely with proper error handling
find "$SCRIPT_DIR" -type f -name "*.sh" 2>/dev/null > "$TEMP_SHELL_SCRIPTS"
find "$SCRIPT_DIR" -type f \( -name "*.conf" -o -name "config.sh" -o -name "secrets.*" \) 2>/dev/null > "$TEMP_CONFIG_FILES"
find "$SCRIPT_DIR" -type f -name "*.json" 2>/dev/null > "$TEMP_JSON_FILES"

# Read from the temporary files
SHELL_SCRIPTS=$(cat "$TEMP_SHELL_SCRIPTS")
CONFIG_FILES=$(cat "$TEMP_CONFIG_FILES")
JSON_FILES=$(cat "$TEMP_JSON_FILES")

# Count the files
SCRIPT_COUNT=$(echo "$SHELL_SCRIPTS" | grep -c "^" || echo 0)
CONFIG_COUNT=$(echo "$CONFIG_FILES" | grep -c "^" || echo 0)
JSON_COUNT=$(echo "$JSON_FILES" | grep -c "^" || echo 0)

echo -e "\033[0;33mFound $SCRIPT_COUNT shell scripts to secure\033[0m"

# Set executable permissions for script files (755 - owner can write, everyone can execute)
for script in $SHELL_SCRIPTS; do
    chmod 755 "$script" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "\033[0;32m✓ Secured executable permissions for: $(basename "$script")\033[0m"
    else
        echo -e "\033[0;31m✗ Failed to secure permissions for: $(basename "$script")\033[0m"
    fi
done

echo -e "\033[0;33mFound $CONFIG_COUNT configuration files to secure\033[0m"

# Set more restrictive permissions for configuration files (640 - owner can write, group can read)
for config in $CONFIG_FILES; do
    # Skip secrets.sh - we'll handle it specially
    if [[ "$(basename "$config")" == "secrets.sh" ]]; then
        continue
    fi
    
    chmod 640 "$config" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "\033[0;32m✓ Secured config permissions for: $(basename "$config")\033[0m"
    else
        echo -e "\033[0;31m✗ Failed to secure permissions for: $(basename "$config")\033[0m"
    fi
done

# Special handling for secrets file - only owner can read/write (600)
if [ -f "$SCRIPT_DIR/secrets.sh" ]; then
    chmod 600 "$SCRIPT_DIR/secrets.sh" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "\033[0;32m✓ Set private permissions for secrets.sh\033[0m"
    else
        echo -e "\033[0;31m✗ Failed to set permissions for secrets.sh\033[0m"
    fi
fi

echo -e "\033[0;33mFound $JSON_COUNT JSON files to secure\033[0m"

# Set permissions for JSON files (640 - more restrictive)
for json in $JSON_FILES; do
    chmod 640 "$json" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "\033[0;32m✓ Secured JSON file permissions for: $(basename "$json")\033[0m"
    else
        echo -e "\033[0;31m✗ Failed to secure permissions for: $(basename "$json")\033[0m"
    fi
done

# Make sure directories are accessible but secure (750 - more restrictive)
find "$SCRIPT_DIR" -type d -exec chmod 750 {} \; 2>/dev/null
echo -e "\033[0;32m✓ Secured directory permissions\033[0m"

# Clean up temporary files securely
rm -f "$TEMP_SHELL_SCRIPTS" "$TEMP_CONFIG_FILES" "$TEMP_JSON_FILES"
rmdir "$TEMP_DIR"

# Set proper permissions for this script
chmod 755 "$0" 2>/dev/null

echo ""
echo -e "\033[0;32mAll file permissions have been updated successfully!\033[0m"
echo -e "\033[0;32mYour backup system is now more secure.\033[0m"
echo ""
echo "Permission levels applied:"
echo "  - Shell scripts: 755 (rwxr-xr-x) - Executable by all, writable only by owner"
echo "  - Config files: 640 (rw-r-----) - Readable by group, writable only by owner"
echo "  - Secrets file: 600 (rw-------) - Readable and writable only by owner"
echo "  - Directories: 750 (rwxr-x---) - Accessible by group, modifiable only by owner"
echo ""

exit 0
