#!/bin/bash
# install.sh - Installation and setup script for WebDev Backup Tool
# Automates the setup process for new installations

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${CYAN}===============================================${NC}"
echo -e "${CYAN}|   WebDev Backup Tool - Installation        |${NC}"
echo -e "${CYAN}===============================================${NC}"
echo ""

# Check for required tools
echo -e "${YELLOW}Checking for required tools...${NC}"
MISSING_TOOLS=()

check_tool() {
    if command -v "$1" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} $1 is installed"
        return 0
    else
        echo -e "  ${RED}✗${NC} $1 is NOT installed"
        MISSING_TOOLS+=("$1")
        return 1
    fi
}

check_tool "bash"
check_tool "tar"
check_tool "gzip"

# Check for optional tools
echo -e "\n${YELLOW}Checking for optional tools...${NC}"
OPTIONAL_MISSING=()

check_optional_tool() {
    if command -v "$1" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} $1 is installed (optional)"
        return 0
    else
        echo -e "  ${YELLOW}○${NC} $1 is not installed (optional)"
        OPTIONAL_MISSING+=("$1")
        return 1
    fi
}

check_optional_tool "pigz"
check_optional_tool "gnuplot"
check_optional_tool "aws"

# Report missing required tools
if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    echo -e "\n${RED}ERROR: Required tools are missing:${NC}"
    for tool in "${MISSING_TOOLS[@]}"; do
        echo -e "  - $tool"
    done
    echo -e "\nPlease install the missing tools and run this script again."
    exit 1
fi

# Report missing optional tools
if [ ${#OPTIONAL_MISSING[@]} -gt 0 ]; then
    echo -e "\n${YELLOW}Note: Optional tools are missing:${NC}"
    for tool in "${OPTIONAL_MISSING[@]}"; do
        echo -e "  - $tool"
        case "$tool" in
            pigz)
                echo -e "    Install: sudo apt-get install pigz (for parallel compression)"
                ;;
            gnuplot)
                echo -e "    Install: sudo apt-get install gnuplot (for visualizations)"
                ;;
            aws)
                echo -e "    Install: See https://aws.amazon.com/cli/ (for cloud storage)"
                ;;
        esac
    done
    echo ""
fi

# Make all scripts executable
echo -e "${YELLOW}Setting script permissions...${NC}"
SCRIPT_COUNT=0
for script in "$SCRIPT_DIR"/*.sh; do
    if [ -f "$script" ]; then
        chmod +x "$script"
        SCRIPT_COUNT=$((SCRIPT_COUNT + 1))
    fi
done

# Also make archived test scripts executable
if [ -d "$SCRIPT_DIR/archive/src.legacy/test" ]; then
    for script in "$SCRIPT_DIR/archive/src.legacy/test"/*.sh; do
        if [ -f "$script" ]; then
            chmod +x "$script"
            SCRIPT_COUNT=$((SCRIPT_COUNT + 1))
        fi
    done
fi

echo -e "  ${GREEN}✓${NC} Made $SCRIPT_COUNT scripts executable"

# Create necessary directories
echo -e "\n${YELLOW}Creating necessary directories...${NC}"
mkdir -p "$SCRIPT_DIR/logs"
mkdir -p "$SCRIPT_DIR/test"
mkdir -p "$SCRIPT_DIR/backups"
echo -e "  ${GREEN}✓${NC} Created directories"

# Check configuration
echo -e "\n${YELLOW}Checking configuration...${NC}"
if [ -f "$SCRIPT_DIR/config.sh" ]; then
    source "$SCRIPT_DIR/config.sh"
    echo -e "  ${GREEN}✓${NC} Configuration file found"
    
    # Check if backup directory exists and is writable
    if [ -d "$DEFAULT_BACKUP_DIR" ]; then
        if [ -w "$DEFAULT_BACKUP_DIR" ]; then
            echo -e "  ${GREEN}✓${NC} Backup directory is writable: $DEFAULT_BACKUP_DIR"
        else
            echo -e "  ${YELLOW}⚠${NC} Backup directory exists but is not writable: $DEFAULT_BACKUP_DIR"
        fi
    else
        echo -e "  ${YELLOW}⚠${NC} Backup directory does not exist: $DEFAULT_BACKUP_DIR"
        echo -e "    It will be created on first backup run"
    fi
    
    # Check source directories
    if [ ${#DEFAULT_SOURCE_DIRS[@]} -gt 0 ]; then
        echo -e "  ${GREEN}✓${NC} Source directories configured:"
        for dir in "${DEFAULT_SOURCE_DIRS[@]}"; do
            if [ -d "$dir" ]; then
                echo -e "    ${GREEN}✓${NC} $dir"
            else
                echo -e "    ${YELLOW}⚠${NC} $dir (does not exist)"
            fi
        done
    else
        echo -e "  ${YELLOW}⚠${NC} No source directories configured (will use home directory)"
    fi
else
    echo -e "  ${RED}✗${NC} Configuration file not found!"
    exit 1
fi

# Run configuration check script if available
if [ -f "$SCRIPT_DIR/check-config.sh" ]; then
    echo -e "\n${YELLOW}Running configuration validation...${NC}"
    if "$SCRIPT_DIR/check-config.sh" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Configuration validation passed"
    else
        echo -e "  ${YELLOW}⚠${NC} Configuration validation found issues (run ./check-config.sh for details)"
    fi
fi

# Setup shell alias (optional)
echo -e "\n${YELLOW}Shell alias setup (optional)...${NC}"
read -p "Would you like to set up a shell alias for easy access? [y/N]: " setup_alias
if [[ "$setup_alias" =~ ^[Yy]$ ]]; then
    if [ -f "$SCRIPT_DIR/setup-alias.sh" ]; then
        "$SCRIPT_DIR/setup-alias.sh"
        echo -e "  ${GREEN}✓${NC} Shell alias configured"
    else
        echo -e "  ${YELLOW}⚠${NC} setup-alias.sh not found"
    fi
else
    echo -e "  ${YELLOW}○${NC} Skipped alias setup"
fi

# Security setup (optional)
echo -e "\n${YELLOW}Security setup (optional)...${NC}"
read -p "Would you like to run security setup? [y/N]: " setup_security
if [[ "$setup_security" =~ ^[Yy]$ ]]; then
    if [ -f "$SCRIPT_DIR/secure-permissions.sh" ]; then
        "$SCRIPT_DIR/secure-permissions.sh"
        echo -e "  ${GREEN}✓${NC} Security permissions configured"
    fi
    
    if [ -f "$SCRIPT_DIR/secure-secrets.sh" ]; then
        read -p "Set up secrets file? [y/N]: " setup_secrets
        if [[ "$setup_secrets" =~ ^[Yy]$ ]]; then
            "$SCRIPT_DIR/secure-secrets.sh"
            echo -e "  ${GREEN}✓${NC} Secrets file configured"
        fi
    fi
else
    echo -e "  ${YELLOW}○${NC} Skipped security setup"
fi

# Summary
echo -e "\n${CYAN}===============================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${CYAN}===============================================${NC}"
echo ""
echo -e "Next steps:"
echo -e "  1. Review configuration: ${CYAN}./check-config.sh${NC}"
echo -e "  2. Test the installation: ${CYAN}./backup.sh --dry-run${NC}"
echo -e "  3. Run your first backup: ${CYAN}./webdev-backup.sh${NC}"
echo -e "  4. Or use npm: ${CYAN}npm start${NC}"
echo ""
echo -e "For help, see: ${CYAN}./README.md${NC}"
echo ""

exit 0

