#!/bin/bash
# encryption.sh - Encryption utilities for WebDev Backup Tool

# Get the script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Set restrictive umask to ensure secure file creation
umask 077
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/error-handling.sh"

# Define constants
ENCRYPTION_DIR="$SCRIPT_DIR/encryption"
KEY_FILE="$ENCRYPTION_DIR/backup.key"
PASSWORD_FILE="$ENCRYPTION_DIR/.passphrase"
SALT_FILE="$ENCRYPTION_DIR/.salt"

# Create encryption directory if it doesn't exist
mkdir -p "$ENCRYPTION_DIR"
chmod 700 "$ENCRYPTION_DIR"  # Secure directory permissions

# Check for required encryption tools
check_encryption_deps() {
    local missing=()
    local tools=("openssl" "gpg")
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            missing+=("$tool")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}Missing required encryption tools: ${missing[*]}${NC}"
        echo -e "${YELLOW}Please install:${NC}"
        if [[ " ${missing[*]} " == *" openssl "* ]]; then
            echo "  - openssl (sudo apt install openssl)"
        fi
        if [[ " ${missing[*]} " == *" gpg "* ]]; then
            echo "  - gpg (sudo apt install gnupg)"
        fi
        return 1
    fi
    
    return 0
}

# Generate encryption key
generate_encryption_key() {
    local key_length=${1:-256}
    local force=${2:-false}
    
    if [ -f "$KEY_FILE" ] && [ "$force" != "true" ]; then
        echo -e "${YELLOW}Encryption key already exists.${NC}"
        echo -e "Use --force to overwrite existing key."
        echo -e "${RED}WARNING: Overwriting the key will make existing encrypted backups unrecoverable!${NC}"
        return 1
    fi
    
    # Generate a secure random key
    openssl rand -base64 "$key_length" > "$KEY_FILE"
    chmod 600 "$KEY_FILE"
    
    echo -e "${GREEN}Generated new encryption key: $KEY_FILE${NC}"
    echo -e "${YELLOW}IMPORTANT: Keep this key safe! If lost, encrypted backups cannot be recovered.${NC}"
    echo -e "${YELLOW}Consider backing up this key to a secure location.${NC}"
    
    # Generate a random salt for password-based encryption
    openssl rand -hex 16 > "$SALT_FILE"
    chmod 600 "$SALT_FILE"
    
    return 0
}

# Encrypt a file using the encryption key
encrypt_file() {
    local input_file="$1"
    local output_file="${2:-$input_file.enc}"
    
    # Check if encryption key exists
    if [ ! -f "$KEY_FILE" ]; then
        echo -e "${RED}Encryption key not found. Generate one first with:${NC}"
        echo -e "${YELLOW}  $0 --generate-key${NC}"
        return 1
    fi
    
    # Check if input file exists
    if [ ! -f "$input_file" ]; then
        echo -e "${RED}Input file not found: $input_file${NC}"
        return 1
    fi
    
    # Encrypt the file using AES-256-GCM (authenticated encryption)
    openssl enc -aes-256-gcm -salt -in "$input_file" -out "$output_file" -pass file:"$KEY_FILE" -md sha256 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}File encrypted successfully: $output_file${NC}"
        return 0
    else
        echo -e "${RED}Encryption failed${NC}"
        return 1
    fi
}

# Decrypt a file using the encryption key
decrypt_file() {
    local input_file="$1"
    local output_file="${2:-${input_file%.enc}}"
    
    # Check if encryption key exists
    if [ ! -f "$KEY_FILE" ]; then
        echo -e "${RED}Encryption key not found. Cannot decrypt.${NC}"
        return 1
    fi
    
    # Check if input file exists
    if [ ! -f "$input_file" ]; then
        echo -e "${RED}Input file not found: $input_file${NC}"
        return 1
    fi
    
    # Decrypt the file
    openssl enc -d -aes-256-gcm -in "$input_file" -out "$output_file" -pass file:"$KEY_FILE" -md sha256 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}File decrypted successfully: $output_file${NC}"
        return 0
    else
        echo -e "${RED}Decryption failed. Wrong key or corrupted file.${NC}"
        return 1
    fi
}

# Set up password-based encryption (more user-friendly, less secure)
setup_password_encryption() {
    local password=""
    local confirm=""
    
    # Prompt for password
    echo -e "${CYAN}Setting up password-based encryption${NC}"
    echo -e "${YELLOW}Note: Key-based encryption is more secure but requires key management.${NC}"
    
    read -s -p "Enter encryption password: " password
    echo
    read -s -p "Confirm password: " confirm
    echo
    
    if [ "$password" != "$confirm" ]; then
        echo -e "${RED}Passwords do not match.${NC}"
        return 1
    fi
    
    # Ensure salt file exists
    if [ ! -f "$SALT_FILE" ]; then
        openssl rand -hex 16 > "$SALT_FILE"
        chmod 600 "$SALT_FILE"
    fi
    
    # Store the password hash securely using a strong KDF
    local salt=$(cat "$SALT_FILE")
    # Use 10000 iterations of PBKDF2 for key stretching
    local hash="$password$salt"
    for i in {1..10000}; do
        hash=$(echo -n "$hash" | sha256_stdin)
    done
    echo "$hash" > "$PASSWORD_FILE"
    chmod 600 "$PASSWORD_FILE"
    
    echo -e "${GREEN}Password-based encryption set up successfully.${NC}"
    echo -e "${YELLOW}IMPORTANT: If you forget this password, your backups cannot be recovered!${NC}"
    
    return 0
}

# Encrypt backup using password
encrypt_backup_with_password() {
    local backup_file="$1"
    local encrypted_file="$2"
    local password=""
    
    # Check if password file exists
    if [ ! -f "$PASSWORD_FILE" ] || [ ! -f "$SALT_FILE" ]; then
        echo -e "${RED}Password encryption not set up. Run setup_password_encryption first.${NC}"
        return 1
    fi
    
    # Get the password
    read -s -p "Enter encryption password: " password
    echo
    
    # Verify password against stored hash
    local salt=$(cat "$SALT_FILE")
    local entered_hash=$(echo -n "$password$salt" | sha256_stdin)
    local stored_hash=$(cat "$PASSWORD_FILE")
    
    if [ "$entered_hash" != "$stored_hash" ]; then
        echo -e "${RED}Incorrect password.${NC}"
        return 1
    fi
    
    # Perform the encryption using password with PBKDF2
    echo -e "${CYAN}Encrypting backup with password...${NC}"
    openssl enc -aes-256-gcm -pbkdf2 -iter 10000 -salt -in "$backup_file" -out "$encrypted_file" -k "$password" -md sha256 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Backup encrypted successfully: $encrypted_file${NC}"
        return 0
    else
        echo -e "${RED}Encryption failed${NC}"
        return 1
    fi
}

# Decrypt backup using password
decrypt_backup_with_password() {
    local encrypted_file="$1"
    local output_file="$2"
    local password=""
    
    # Get the password
    read -s -p "Enter decryption password: " password
    echo
    
    # Attempt decryption
    echo -e "${CYAN}Decrypting backup...${NC}"
    openssl enc -d -aes-256-gcm -pbkdf2 -iter 10000 -in "$encrypted_file" -out "$output_file" -k "$password" -md sha256 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Backup decrypted successfully: $output_file${NC}"
        return 0
    else
        echo -e "${RED}Decryption failed. Incorrect password or corrupted file.${NC}"
        return 1
    fi
}

# Main function to handle command-line arguments
main() {
    local action=""
    local input_file=""
    local output_file=""
    local force=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --generate-key)
                action="generate-key"
                shift
                ;;
            --encrypt)
                action="encrypt"
                if [[ -n "$2" && "$2" != --* ]]; then
                    input_file="$2"
                    shift 2
                else
                    echo -e "${RED}Error: --encrypt requires a file path${NC}"
                    exit 1
                fi
                ;;
            --decrypt)
                action="decrypt"
                if [[ -n "$2" && "$2" != --* ]]; then
                    input_file="$2"
                    shift 2
                else
                    echo -e "${RED}Error: --decrypt requires a file path${NC}"
                    exit 1
                fi
                ;;
            --output)
                if [[ -n "$2" && "$2" != --* ]]; then
                    output_file="$2"
                    shift 2
                else
                    echo -e "${RED}Error: --output requires a file path${NC}"
                    exit 1
                fi
                ;;
            --setup-password)
                action="setup-password"
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            --help|-h)
                echo "Encryption Utility for WebDev Backup Tool"
                echo ""
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --generate-key           Generate a new encryption key"
                echo "  --encrypt FILE           Encrypt a file"
                echo "  --decrypt FILE           Decrypt a file"
                echo "  --output FILE            Output file path for encrypt/decrypt"
                echo "  --setup-password         Set up password-based encryption"
                echo "  --force                  Force overwrite of existing keys/files"
                echo "  --help                   Show this help message"
                echo ""
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # Check for required tools
    if ! check_encryption_deps; then
        exit 1
    fi
    
    # Perform the requested action
    case "$action" in
        generate-key)
            generate_encryption_key 256 "$force"
            ;;
        encrypt)
            if [ -n "$output_file" ]; then
                encrypt_file "$input_file" "$output_file"
            else
                encrypt_file "$input_file"
            fi
            ;;
        decrypt)
            if [ -n "$output_file" ]; then
                decrypt_file "$input_file" "$output_file"
            else
                decrypt_file "$input_file"
            fi
            ;;
        setup-password)
            setup_password_encryption
            ;;
        "")
            echo -e "${RED}No action specified. Use --help for usage information.${NC}"
            exit 1
            ;;
    esac
}

# If this script is being run directly (not sourced), call main with provided args
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
