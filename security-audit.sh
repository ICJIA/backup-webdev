#!/bin/bash
# security-audit.sh - Security audit script for WebDev Backup Tool
# This script checks for common security issues and recommended practices

# Get the script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Allow running without user config (utils.sh sources config.sh which validates source/dest)
export RUNNING_TESTS=1
source "$SCRIPT_DIR/utils.sh"

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

# Check scripts for excessive permissions (portable: -perm -0002 = world-writable; works on macOS and Linux)
while IFS= read -r line; do
    report_issue "HIGH" "Script has world-writable permissions: $line" \
                 "Run secure-permissions.sh to fix permissions (chmod 755 for scripts)"
done < <(find "$SCRIPT_DIR" -name "*.sh" -perm -0002 -exec ls -l {} \; 2>/dev/null)

# Check secrets file
if [ -f "$SCRIPT_DIR/secrets.sh" ]; then
    # Cross-platform permission check
    if [ "$(uname -s)" = "Darwin" ]; then
        current_perms=$(stat -f %OLp "$SCRIPT_DIR/secrets.sh" 2>/dev/null)
    else
        current_perms=$(stat -c "%a" "$SCRIPT_DIR/secrets.sh" 2>/dev/null)
    fi
    if [ "$current_perms" != "600" ]; then
        report_issue "HIGH" "Secrets file has incorrect permissions: $current_perms" \
                     "Run secure-permissions.sh to fix permissions (chmod 600 for secrets.sh)"
    else
        echo -e "${GREEN}✓ Secrets file has correct permissions (600)${NC}"
    fi
else
    echo -e "${YELLOW}⚠ No secrets.sh file found - skipping check${NC}"
fi

# Check for sensitive files in git (allowlist: templates and examples are intentional)
echo -e "${GREEN}Checking for potential sensitive files in git...${NC}"
if command -v git &>/dev/null && [ -d "$SCRIPT_DIR/.git" ]; then
    sensitive_patterns=("*secret*" "*password*" "*credential*" "*.key" "*.pem" "*.p12" "*.pkcs12" "*.pfx")
    # Files that are safe to track (templates/examples with no real secrets)
    git_safe_files="secrets.sh.example|secure-secrets.sh"
    
    for pattern in "${sensitive_patterns[@]}"; do
        git_files=$(git -C "$SCRIPT_DIR" ls-files "$pattern" 2>/dev/null | grep -v '^archive/' | grep -v -E "^($git_safe_files)$" || true)
        if [ -n "$git_files" ]; then
            report_issue "HIGH" "Potential sensitive files found in git: $git_files" \
                         "Remove sensitive files from git using: git rm --cached <file> and add to .gitignore"
        fi
    done
    
    # Check if secrets.sh is in git (only report if not in .gitignore; user may need git rm --cached)
    if git -C "$SCRIPT_DIR" ls-files --error-unmatch secrets.sh &>/dev/null; then
        if grep -q "secrets\.sh" "$SCRIPT_DIR/.gitignore" 2>/dev/null; then
            echo -e "${YELLOW}ℹ secrets.sh is tracked but listed in .gitignore. To stop tracking: git rm --cached secrets.sh${NC}"
        else
            report_issue "HIGH" "secrets.sh file is tracked by git" \
                         "Remove secrets.sh from git using: git rm --cached secrets.sh"
        fi
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

# Check for cryptographic material (exclude archive)
echo -e "${GREEN}Checking for exposed cryptographic material...${NC}"
while IFS= read -r file; do
    report_issue "HIGH" "Cryptographic material found: $file" \
                 "Remove cryptographic files from the repository and store them securely"
done < <(find "$SCRIPT_DIR" -type f \( -name "*.pem" -o -name "*.key" -o -name "*.p12" \) ! -path "*/archive/*" 2>/dev/null)

# Check for hardcoded credentials: only flag literal quoted values (exclude $VAR and empty/local placeholders)
echo -e "${GREEN}Checking for hardcoded credentials in scripts...${NC}"
# Match keyword= then a quote then a LITERAL value (no $) - avoids false positives like $EMAIL_PASSWORD or local password=""
while IFS= read -r file; do
    report_issue "HIGH" "Potential hardcoded credentials in: $file" \
                 "Move credentials to secrets.sh and reference them as variables"
done < <(grep -r -l -E "(password|secret|credential|token|api.?key)\s*=\s*['\"][^\"'\$]+['\"]" --include="*.sh" "$SCRIPT_DIR" 2>/dev/null | grep -v -E '(archive/|secure-secrets\.sh|secrets\.sh\.example)')

# Check for secure coding practices (exclude archive and allowlisted scripts)
# Allowlist: test runners (eval of test command), security-audit (self)
eval_allowlist="test-backup\.sh|test-tar-compatibility\.sh|security-audit\.sh"
echo -e "${GREEN}Checking for insecure coding practices...${NC}"
while IFS= read -r file; do
    basename_file=$(basename "$file")
    echo "$basename_file" | grep -q -E "^($eval_allowlist)$" && continue
    if grep -q "eval.*\$" "$file"; then
        report_issue "HIGH" "Potentially unsafe eval with variables found in: $file" \
                     "Replace eval with safer alternatives to prevent command injection"
    fi
done < <(grep -r -l "eval" --include="*.sh" "$SCRIPT_DIR" 2>/dev/null | grep -v 'archive/')

# Check for unsafe temp file creation (exclude archive; flag /tmp or $TMPDIR usage without mktemp)
while IFS= read -r file; do
    if ! grep -q "mktemp" "$file"; then
        report_issue "MEDIUM" "Potentially unsafe temp file handling in: $file" \
                     "Use mktemp for secure temporary file creation"
    fi
done < <(grep -r -l -E '(\$TMPDIR|/tmp/)' --include="*.sh" "$SCRIPT_DIR" 2>/dev/null | grep -v 'archive/' | grep -v 'test-backup.sh')

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
