#!/bin/bash
# check-config.sh - Configuration verification script
# Verifies system configuration and dependencies for WebDev Backup Tool

# Get the script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../core/config.sh"
source "$SCRIPT_DIR/../utils/utils.sh"

# Check for required utilities
echo -e "${CYAN}===== WebDev Backup Tool Configuration Check =====${NC}"
echo "Started at: $(date)"
echo

# Check system information
echo -e "${YELLOW}System Information:${NC}"
echo "- OS: $(uname -s)"
echo "- Version: $(uname -r)"
echo "- Hostname: $(hostname)"
echo "- User: $(whoami)"

echo -e "\n${YELLOW}Required Dependencies:${NC}"

# Define required and optional tools
REQUIRED_TOOLS=("bash" "tar" "gzip" "find" "awk" "sed" "grep")
OPTIONAL_TOOLS=("pigz" "gnuplot" "awscli" "bc")

# Check required tools
ALL_REQUIRED_PRESENT=true
for tool in "${REQUIRED_TOOLS[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ $tool${NC} $(command -v "$tool")"
    else
        echo -e "${RED}✗ $tool - MISSING (Required)${NC}"
        ALL_REQUIRED_PRESENT=false
    fi
done

echo -e "\n${YELLOW}Optional Dependencies:${NC}"
# Check optional tools
for tool in "${OPTIONAL_TOOLS[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ $tool${NC} $(command -v "$tool")"
        case "$tool" in
            pigz)
                echo "  - Parallel compression available"
                ;;
            gnuplot)
                echo "  - Chart generation available"
                ;;
            awscli)
                aws_version=$(aws --version 2>&1 | head -n 1)
                echo "  - Cloud storage to AWS/S3/DO Spaces available ($aws_version)"
                ;;
            bc)
                echo "  - Advanced calculations available"
                ;;
        esac
    else
        echo -e "${YELLOW}✗ $tool - not found${NC}"
        case "$tool" in
            pigz)
                echo "  - Parallel compression will not be available"
                echo "  - Install with: sudo apt install pigz"
                ;;
            gnuplot)
                echo "  - Chart generation will not be available"
                echo "  - Install with: sudo apt install gnuplot"
                ;;
            awscli)
                echo "  - Cloud storage to AWS/S3/DO Spaces will not be available"
                echo "  - Install with: sudo apt install awscli"
                ;;
            bc)
                echo "  - Some advanced calculations may not work properly"
                echo "  - Install with: sudo apt install bc"
                ;;
        esac
    fi
done

echo -e "\n${YELLOW}Configuration:${NC}"

# Check source directories
if [ ${#DEFAULT_SOURCE_DIRS[@]} -eq 0 ]; then
    echo -e "${RED}✗ No default source directories configured${NC}"
    echo "  Please update the config.sh file to include source directories"
else
    echo -e "${GREEN}✓ Found ${#DEFAULT_SOURCE_DIRS[@]} configured source directories${NC}"
    for dir in "${DEFAULT_SOURCE_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            if [ -r "$dir" ]; then
                projects=$(find "$dir" -maxdepth 1 -mindepth 1 -type d -not -path "*/\.*" | wc -l)
                echo -e "  - ${GREEN}$dir${NC} (exists, readable) - $projects projects found"
            else
                echo -e "  - ${YELLOW}$dir${NC} (exists, but not readable)"
            fi
        else
            echo -e "  - ${RED}$dir${NC} (does not exist)"
        fi
    done
fi

# Check backup directory
if [ -d "$DEFAULT_BACKUP_DIR" ]; then
    if [ -w "$DEFAULT_BACKUP_DIR" ]; then
        space_available=$(df -h "$DEFAULT_BACKUP_DIR" | awk 'NR==2 {print $4}')
        echo -e "${GREEN}✓ Default backup directory is valid and writable: $DEFAULT_BACKUP_DIR${NC}"
        echo "  - Available space: $space_available"
    else
        echo -e "${RED}✗ Default backup directory exists but is not writable: $DEFAULT_BACKUP_DIR${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Default backup directory does not exist: $DEFAULT_BACKUP_DIR${NC}"
    echo -e "  Would you like to create it? [y/N]"
    read -p "> " create_dir
    if [[ "$create_dir" =~ ^[Yy]$ ]]; then
        if mkdir -p "$DEFAULT_BACKUP_DIR"; then
            echo -e "${GREEN}✓ Created default backup directory: $DEFAULT_BACKUP_DIR${NC}"
        else
            echo -e "${RED}✗ Failed to create default backup directory${NC}"
        fi
    fi
fi

# Check logs directory
if [ -d "$LOGS_DIR" ]; then
    if [ -w "$LOGS_DIR" ]; then
        echo -e "${GREEN}✓ Logs directory is valid and writable: $LOGS_DIR${NC}"
    else
        echo -e "${RED}✗ Logs directory exists but is not writable: $LOGS_DIR${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Logs directory does not exist: $LOGS_DIR${NC}"
    echo -e "  Creating logs directory..."
    if mkdir -p "$LOGS_DIR"; then
        echo -e "${GREEN}✓ Created logs directory: $LOGS_DIR${NC}"
    else
        echo -e "${RED}✗ Failed to create logs directory${NC}"
    fi
fi

# Check script permissions
echo -e "\n${YELLOW}Script Permissions:${NC}"
PERMISSION_ISSUES=0
for script in "$SCRIPT_DIR"/*.sh; do
    if [ -f "$script" ]; then
        if [ ! -x "$script" ]; then
            echo -e "${RED}✗ $(basename "$script") is not executable${NC}"
            PERMISSION_ISSUES=$((PERMISSION_ISSUES + 1))
        fi
    fi
done

if [ $PERMISSION_ISSUES -gt 0 ]; then
    echo -e "${YELLOW}Found $PERMISSION_ISSUES permission issues. Run ./secure-permissions.sh to fix.${NC}"
else
    echo -e "${GREEN}✓ All scripts have correct executable permissions${NC}"
fi

# Check secrets file
echo -e "\n${YELLOW}Credentials:${NC}"
if [ -f "$SCRIPT_DIR/secrets.sh" ]; then
    PERMS=$(stat -c "%a" "$SCRIPT_DIR/secrets.sh")
    if [ "$PERMS" = "600" ]; then
        echo -e "${GREEN}✓ secrets.sh exists with correct permissions (600)${NC}"
    else
        echo -e "${RED}✗ secrets.sh has incorrect permissions: $PERMS (should be 600)${NC}"
        echo "  Run ./secure-secrets.sh to fix"
    fi
else
    echo -e "${YELLOW}⚠ secrets.sh not found. Cloud operations will not work.${NC}"
    echo "  Run ./secure-secrets.sh to create it"
fi

# Summary
echo -e "\n${CYAN}===== Configuration Check Summary =====${NC}"
if ! $ALL_REQUIRED_PRESENT; then
    echo -e "${RED}✗ Some required dependencies are missing${NC}"
    echo "  Please install the missing dependencies"
    exit_status=1
elif [ $PERMISSION_ISSUES -gt 0 ]; then
    echo -e "${YELLOW}⚠ Some permission issues were found${NC}"
    echo "  Run ./secure-permissions.sh to fix them"
    exit_status=2
else
    echo -e "${GREEN}✓ Basic configuration check passed${NC}"
    exit_status=0
fi

# Check for backup history
if [ -f "$BACKUP_HISTORY_LOG" ]; then
    backup_count=$(grep -c "BACKUP:" "$BACKUP_HISTORY_LOG")
    echo -e "${GREEN}✓ Backup history found with $backup_count previous backups${NC}"
else
    echo -e "${YELLOW}⚠ No backup history found. This appears to be a new installation.${NC}"
fi

# Check for test directory
if [ ! -d "$TEST_DIR" ]; then
    echo -e "${YELLOW}⚠ Test directory does not exist: $TEST_DIR${NC}"
    echo -e "  Creating test directory..."
    if mkdir -p "$TEST_DIR"; then
        echo -e "${GREEN}✓ Created test directory: $TEST_DIR${NC}"
    fi
fi

# Final recommendations
echo -e "\n${YELLOW}Recommendations:${NC}"
if [ $exit_status -ne 0 ]; then
    echo "1. Fix the issues mentioned above"
fi
if ! command -v "pigz" >/dev/null 2>&1; then
    echo "- Install pigz for faster backups with parallel compression"
fi
if ! command -v "gnuplot" >/dev/null 2>&1; then
    echo "- Install gnuplot for backup size visualization and forecasting"
fi
if [ ! -f "$SCRIPT_DIR/secrets.sh" ]; then
    echo "- Run ./secure-secrets.sh to set up cloud storage credentials"
fi

echo -e "\n${CYAN}Configuration check completed at $(date)${NC}"
exit $exit_status
