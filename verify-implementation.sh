#!/bin/bash
# verify-implementation.sh - Verify all implementation requirements are met

echo "==============================================="
echo "  Verification of macOS/Linux Compatibility"
echo "==============================================="
echo

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${CYAN}1. Checking config.sh as single source of truth...${NC}"
if grep -q "SINGLE SOURCE OF TRUTH" "$SCRIPT_DIR/config.sh"; then
    echo -e "${GREEN}   ✓ config.sh marked as single source of truth${NC}"
else
    echo -e "${RED}   ✗ config.sh not properly documented${NC}"
fi

if grep -q "DEFAULT_SOURCE_DIRS=()" "$SCRIPT_DIR/config.sh"; then
    echo -e "${GREEN}   ✓ DEFAULT_SOURCE_DIRS configurable${NC}"
else
    echo -e "${RED}   ✗ DEFAULT_SOURCE_DIRS not found${NC}"
fi

if grep -q "DEFAULT_BACKUP_DIR=" "$SCRIPT_DIR/config.sh"; then
    echo -e "${GREEN}   ✓ DEFAULT_BACKUP_DIR configurable${NC}"
else
    echo -e "${RED}   ✗ DEFAULT_BACKUP_DIR not found${NC}"
fi

echo

echo -e "${CYAN}2. Checking first-run detection...${NC}"
if grep -q "check_first_run" "$SCRIPT_DIR/utils.sh"; then
    echo -e "${GREEN}   ✓ check_first_run() function exists${NC}"
else
    echo -e "${RED}   ✗ check_first_run() not found${NC}"
fi

if grep -q "FIRST_RUN_MARKER=" "$SCRIPT_DIR/config.sh"; then
    echo -e "${GREEN}   ✓ First-run marker defined${NC}"
else
    echo -e "${RED}   ✗ First-run marker not defined${NC}"
fi

if grep -q "check_first_run" "$SCRIPT_DIR/webdev-backup.sh"; then
    echo -e "${GREEN}   ✓ First-run check called in launcher${NC}"
else
    echo -e "${RED}   ✗ First-run check not called${NC}"
fi

echo

echo -e "${CYAN}3. Checking configuration display...${NC}"
if grep -q "display_current_config" "$SCRIPT_DIR/utils.sh"; then
    echo -e "${GREEN}   ✓ display_current_config() function exists${NC}"
else
    echo -e "${RED}   ✗ display_current_config() not found${NC}"
fi

if grep -q "display_current_config" "$SCRIPT_DIR/webdev-backup.sh"; then
    echo -e "${GREEN}   ✓ Config displayed in launcher${NC}"
else
    echo -e "${RED}   ✗ Config not displayed in launcher${NC}"
fi

echo

echo -e "${CYAN}4. Checking macOS compatibility fixes...${NC}"

# Check for get_file_size_bytes
if grep -q "get_file_size_bytes()" "$SCRIPT_DIR/utils.sh"; then
    echo -e "${GREEN}   ✓ get_file_size_bytes() function exists (du -b fix)${NC}"
else
    echo -e "${RED}   ✗ get_file_size_bytes() not found${NC}"
fi

# Check for run_with_timeout
if grep -q "run_with_timeout()" "$SCRIPT_DIR/utils.sh"; then
    echo -e "${GREEN}   ✓ run_with_timeout() function exists (timeout fix)${NC}"
else
    echo -e "${RED}   ✗ run_with_timeout() not found${NC}"
fi

# Check for sha256_stdin
if grep -q "sha256_stdin()" "$SCRIPT_DIR/utils.sh"; then
    echo -e "${GREEN}   ✓ sha256_stdin() function exists (sha256sum fix)${NC}"
else
    echo -e "${RED}   ✗ sha256_stdin() not found${NC}"
fi

# Check for capitalize
if grep -q "capitalize()" "$SCRIPT_DIR/utils.sh"; then
    echo -e "${GREEN}   ✓ capitalize() function exists (Bash 3.2 fix)${NC}"
else
    echo -e "${RED}   ✗ capitalize() not found${NC}"
fi

# Check that numfmt is not used
if grep -q "numfmt" "$SCRIPT_DIR/quick-backup.sh" 2>/dev/null; then
    echo -e "${RED}   ✗ numfmt still used in quick-backup.sh${NC}"
else
    echo -e "${GREEN}   ✓ numfmt removed from quick-backup.sh${NC}"
fi

# Check for OS-specific install hints
if grep -q "brew install" "$SCRIPT_DIR/check-config.sh"; then
    echo -e "${GREEN}   ✓ macOS install hints (brew) added${NC}"
else
    echo -e "${RED}   ✗ brew install hints not found${NC}"
fi

echo

echo -e "${CYAN}5. Checking no mapfile usage...${NC}"
mapfile_count=$(grep -c "mapfile" "$SCRIPT_DIR/backup.sh" 2>/dev/null | head -1 | tr -d '\n')
[ -z "$mapfile_count" ] || ! [[ "$mapfile_count" =~ ^[0-9]+$ ]] && mapfile_count=0
if [ "$mapfile_count" -eq 0 ]; then
    echo -e "${GREEN}   ✓ mapfile removed from backup.sh${NC}"
else
    echo -e "${YELLOW}   ⚠ mapfile still used $mapfile_count times in backup.sh${NC}"
fi

echo

echo -e "${CYAN}6. OS Detection Test...${NC}"
os_type=$(uname -s)
echo -e "   Detected OS: ${CYAN}$os_type${NC}"

case "$os_type" in
    Darwin)
        echo -e "${GREEN}   ✓ macOS detected - will use macOS-specific commands${NC}"
        ;;
    Linux)
        echo -e "${GREEN}   ✓ Linux detected - will use Linux-specific commands${NC}"
        ;;
    *)
        echo -e "${YELLOW}   ⚠ Unknown OS: $os_type${NC}"
        ;;
esac

echo

echo "==============================================="
echo "  Verification Complete"
echo "==============================================="
echo
echo "Next steps:"
echo "1. Test on macOS: ./webdev-backup.sh"
echo "2. Test on Linux (Ubuntu 22.x): ./webdev-backup.sh"
echo "3. Verify config file path is displayed"
echo "4. Verify first-run prompt appears (rm .configured first)"
echo
