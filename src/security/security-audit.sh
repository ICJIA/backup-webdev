#!/bin/bash
# security-audit.sh - Security audit script for WebDev Backup Tool
# This script checks for common security issues and recommended practices

# Get the script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/utils.sh"

# Banner
echo -e "${CYAN}===== WebDev Backup Tool Security Audit =====${NC}"
echo "Checking for common security issues and best practices"
echo ""

# Results tracking
ISSUES_FOUND=0
WARNINGS_FOUND=0

# Display a security issue
report_issue() {
    local severity="$1"
    local message="$2"
    local recommendation="$3"
    
    if [ "$severity" = "HIGH" ]; then
        echo -e "${RED}[HIGH] $message${NC}"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    elif [ "$severity" = "MEDIUM" ]; then
        echo -e "${YELLOW}[MEDIUM] $message${NC}"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    else
        echo -e "${YELLOW}[LOW] $message${NC}"
        WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
    fi
    
    echo -e "  ${CYAN}Recommendation: $recommendation${NC}"
    echo ""
}

# Check file permissions
echo -e "${GREEN}Checking file permissions...${NC}"

# Check scripts for excessive permissions
find "$SCRIPT_DIR" -name "*.sh" -perm /o+w -exec ls -l {} \; | while read -r line; do
    report_issue "HIGH" "Script has world-writable permissions: $line" \
                 "Run secure-permissions.sh to fix permissions (chmod 755 for scripts)"
done

# Check secrets file
if [ -f "$SCRIPT_DIR/secrets.sh" ]; then
    current_perms=$(stat -c "%a" "$SCRIPT_DIR/secrets.sh")
    if [ "$current_perms" != "600" ]; then
        report_issue "HIGH" "Secrets file has incorrect permissions: $current_perms" \
                     "Run secure-permissions.sh to fix permissions (chmod 600 for secrets.sh)"
    else
        echo -e "${GREEN}✓ Secrets file has correct permissions (600)${NC}"
    fi
else
    echo -e "${YELLOW}⚠ No secrets.sh file found - skipping check${NC}"
fi

# Check for sensitive files in git
echo -e "${GREEN}Checking for potential sensitive files in git...${NC}"
if command -v git &>/dev/null && [ -d "$SCRIPT_DIR/.git" ]; then
    sensitive_patterns=("*secret*" "*password*" "*credential*" "*.key" "*.pem" "*.p12" "*.pkcs12" "*.pfx")
    
    for pattern in "${sensitive_patterns[@]}"; do
        git_files=$(git -C "$SCRIPT_DIR" ls-files "$pattern" 2>/dev/null)
        if [ -n "$git_files" ]; then
            report_issue "HIGH" "Potential sensitive files found in git: $git_files" \
                         "Remove sensitive files from git using: git rm --cached <file> and add to .gitignore"
        fi
    done
    
    # Check if secrets.sh is in git
    if git -C "$SCRIPT_DIR" ls-files secrets.sh &>/dev/null; then
        report_issue "HIGH" "secrets.sh file is tracked by git" \
                     "Remove secrets.sh from git using: git rm --cached secrets.sh"
    else
        echo -e "${GREEN}✓ secrets.sh is not tracked by git${NC}"
    fi
    
    # Check .gitignore
    if [ -f "$SCRIPT_DIR/.gitignore" ]; then
        if ! grep -q "secrets.sh" "$SCRIPT_DIR/.gitignore"; then
            report_issue "MEDIUM" "secrets.sh is not in .gitignore file" \
                         "Add 'secrets.sh' to .gitignore"
        else
            echo -e "${GREEN}✓ secrets.sh is properly ignored in .gitignore${NC}"
        fi
    else
        report_issue "MEDIUM" "No .gitignore file found" \
                     "Create a .gitignore file to prevent committing sensitive files"
    fi
else
    echo -e "${YELLOW}⚠ Git not found or not a git repository - skipping git checks${NC}"
fi

# Check for cryptographic material
echo -e "${GREEN}Checking for exposed cryptographic material...${NC}"
find "$SCRIPT_DIR" -type f -name "*.pem" -o -name "*.key" -o -name "*.p12" | while read -r file; do
    report_issue "HIGH" "Cryptographic material found: $file" \
                 "Remove cryptographic files from the repository and store them securely"
done

# Check for hardcoded credentials in scripts
echo -e "${GREEN}Checking for hardcoded credentials in scripts...${NC}"
grep -r -l -E "(password|secret|credential|token|api.?key).*=.*['\"]" --include="*.sh" "$SCRIPT_DIR" 2>/dev/null | grep -v -E '(secure-secrets.sh|secrets.sh.example)' | while read -r file; do
    report_issue "HIGH" "Potential hardcoded credentials in: $file" \
                 "Move credentials to secrets.sh and reference them as variables"
done

# Check for secure coding practices
echo -e "${GREEN}Checking for insecure coding practices...${NC}"
grep -r -l "eval" --include="*.sh" "$SCRIPT_DIR" | while read -r file; do
    if grep -q "eval.*\$" "$file"; then
        report_issue "HIGH" "Potentially unsafe eval with variables found in: $file" \
                     "Replace eval with safer alternatives to prevent command injection"
    fi
done

# Check for unsafe temp file creation
grep -r -l -E "mktemp|tempfile" --include="*.sh" "$SCRIPT_DIR" | while read -r file; do
    if ! grep -q -E "mktemp( -d)?( -q)? | tempfile" "$file"; then
        report_issue "MEDIUM" "Potentially unsafe temp file handling in: $file" \
                     "Use mktemp for secure temporary file creation"
    fi
done

# Final summary
echo -e "${GREEN}===== Security Audit Summary =====${NC}"
if [ $ISSUES_FOUND -eq 0 ] && [ $WARNINGS_FOUND -eq 0 ]; then
    echo -e "${GREEN}✓ No security issues found${NC}"
else
    echo -e "${RED}Issues found: $ISSUES_FOUND${NC}"
    echo -e "${YELLOW}Warnings found: $WARNINGS_FOUND${NC}"
    echo ""
    echo -e "Run ${CYAN}./secure-permissions.sh${NC} to fix permission issues"
    echo -e "Run ${CYAN}./secure-secrets.sh${NC} to secure credential management"
fi

exit $ISSUES_FOUND
