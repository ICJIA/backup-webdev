#!/bin/bash
# secure-secrets.sh - Securely sets up and manages credentials

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRETS_FILE="$SCRIPT_DIR/secrets.sh"
SECRETS_EXAMPLE="$SCRIPT_DIR/secrets.sh.example"
SECRETS_CHECKSUM="$SCRIPT_DIR/.secrets.checksum"

# Make sure this script is executable
chmod +x "$0" 2>/dev/null

# Set text colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}===== WebDev Backup Tool Secure Credentials Setup =====${NC}"

# Create example file if it doesn't exist
if [ ! -f "$SECRETS_EXAMPLE" ]; then
    cat > "$SECRETS_EXAMPLE" << 'EOL'
#!/bin/bash
# secrets.sh - Example credentials file
# Fill in your cloud provider credentials and rename to secrets.sh

# DigitalOcean Spaces credentials
export DO_SPACES_KEY="your-key"
export DO_SPACES_SECRET="your-secret"
export DO_SPACES_ENDPOINT="nyc3.digitaloceanspaces.com"
export DO_SPACES_BUCKET="your-bucket"
export DO_SPACES_REGION="nyc3"

# AWS S3 credentials
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
export AWS_DEFAULT_REGION="us-east-1"
export AWS_S3_BUCKET="your-bucket"

# Dropbox credentials
export DROPBOX_TOKEN="your-token"

# Email notification settings (for alerts)
export EMAIL_FROM="alerts@example.com"
export EMAIL_SMTP_SERVER="smtp.example.com"
export EMAIL_SMTP_PORT="587"
export EMAIL_SMTP_USER="username"
export EMAIL_SMTP_PASSWORD="password"
export EMAIL_SMTP_TLS="yes"
EOL
    echo -e "${GREEN}Created example credentials file: $SECRETS_EXAMPLE${NC}"
    echo -e "${YELLOW}Please edit this file with your credentials and rename it to secrets.sh${NC}"
    chmod 644 "$SECRETS_EXAMPLE" 2>/dev/null || echo -e "${RED}Warning: Could not set permissions on example file${NC}"
fi

# Make sure we can create the directories and files we need
mkdir -p "$(dirname "$SECRETS_CHECKSUM")" 2>/dev/null

# Check if secrets file exists
if [ ! -f "$SECRETS_FILE" ]; then
    echo -e "${YELLOW}No secrets.sh file found.${NC}"
    read -p "Would you like to create one now? [y/N] " create_secrets
    
    if [[ "$create_secrets" =~ ^[Yy]$ ]]; then
        cp "$SECRETS_EXAMPLE" "$SECRETS_FILE" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            chmod 600 "$SECRETS_FILE" 2>/dev/null
            echo -e "${GREEN}Created secrets.sh file with restricted permissions (600)${NC}"
            echo -e "${YELLOW}Please edit $SECRETS_FILE now to add your credentials${NC}"
            
            # Offer to open in editor
            read -p "Open in editor now? [y/N] " open_editor
            if [[ "$open_editor" =~ ^[Yy]$ ]]; then
                ${EDITOR:-nano} "$SECRETS_FILE"
            fi
        else
            echo -e "${RED}Error: Failed to create secrets.sh file.${NC}"
            echo -e "${RED}Check directory permissions and try again.${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}No secrets file created. Some backup features may not work.${NC}"
    fi
else
    # Calculate checksum of existing secrets file
    if command -v sha256sum >/dev/null 2>&1; then
        checksum=$(sha256sum "$SECRETS_FILE" 2>/dev/null | cut -d' ' -f1)
    elif command -v shasum >/dev/null 2>&1; then
        checksum=$(shasum -a 256 "$SECRETS_FILE" 2>/dev/null | cut -d' ' -f1)
    else
        echo -e "${YELLOW}Warning: No checksum tool available. Skipping checksum verification.${NC}"
        checksum=""
    fi
    
    # Set proper permissions
    # Cross-platform permission check
    if [ "$(uname -s)" = "Darwin" ]; then
        current_perms=$(stat -f %OLp "$SECRETS_FILE" 2>/dev/null || echo "unknown")
    else
        current_perms=$(stat -c "%a" "$SECRETS_FILE" 2>/dev/null || echo "unknown")
    fi
    if [ "$current_perms" != "600" ]; then
        echo -e "${YELLOW}WARNING: secrets.sh has incorrect permissions: $current_perms${NC}"
        echo -e "${YELLOW}Securing file with correct permissions (600)${NC}"
        chmod 600 "$SECRETS_FILE" 2>/dev/null
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to change permissions. Check ownership and file system permissions.${NC}"
        fi
    fi
    
    # Store checksum for integrity monitoring
    if [ -n "$checksum" ]; then
        echo "$checksum" > "$SECRETS_CHECKSUM" 2>/dev/null
        if [ $? -eq 0 ]; then
            chmod 600 "$SECRETS_CHECKSUM" 2>/dev/null
            echo -e "${GREEN}Existing secrets.sh file secured (permissions: 600)${NC}"
            echo -e "${GREEN}Credentials checksum stored for integrity verification${NC}"
        else
            echo -e "${RED}Warning: Could not save checksum for integrity verification.${NC}"
        fi
    fi
fi

echo -e "\n${CYAN}====== Security Recommendations ======${NC}"
echo -e "1. ${YELLOW}Never commit secrets.sh to version control${NC}"
echo -e "2. ${YELLOW}Restrict access to the secrets.sh file${NC}"
echo -e "3. ${YELLOW}Consider using environment variables instead for CI/CD pipelines${NC}"
echo -e "4. ${YELLOW}Regularly rotate your credentials for better security${NC}"

exit 0
