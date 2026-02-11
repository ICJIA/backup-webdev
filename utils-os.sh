#!/bin/bash
# utils-os.sh - OS detection and platform utilities for backup-webdev
# Sourced by utils.sh - do not execute directly

# OS Detection - Cross-platform compatibility
detect_os() {
    case "$(uname -s)" in
        Darwin*)
            echo "macOS"
            ;;
        Linux*)
            echo "Linux"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            echo "Windows"
            ;;
        *)
            echo "Unknown"
            ;;
    esac
}

# Get human-readable OS name and version (for display in app)
# Examples: "macOS 15.0 (Darwin 24.0.0)" or "Ubuntu 22.04 (Linux 5.15.0)"
get_os_version_display() {
    local kernel_name kernel_release
    kernel_name=$(uname -s)
    kernel_release=$(uname -r 2>/dev/null)

    case "$kernel_name" in
        Darwin*)
            if [ -x "/usr/bin/sw_vers" ]; then
                local product_name product_version
                product_name=$(sw_vers -productName 2>/dev/null)
                product_version=$(sw_vers -productVersion 2>/dev/null)
                if [ -n "$product_name" ] && [ -n "$product_version" ]; then
                    echo "${product_name} ${product_version} (Darwin ${kernel_release})"
                    return
                fi
            fi
            echo "macOS (Darwin ${kernel_release})"
            ;;
        Linux*)
            if [ -f /etc/os-release ]; then
                local pretty_name version_id
                pretty_name=$(grep -E '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d'"' -f2)
                version_id=$(grep -E '^VERSION_ID=' /etc/os-release 2>/dev/null | cut -d'"' -f2)
                if [ -n "$pretty_name" ]; then
                    echo "${pretty_name} (Linux ${kernel_release})"
                    return
                fi
                if [ -n "$version_id" ]; then
                    local name
                    name=$(grep -E '^NAME=' /etc/os-release 2>/dev/null | cut -d'"' -f2)
                    echo "${name} ${version_id} (Linux ${kernel_release})"
                    return
                fi
            fi
            if command -v lsb_release >/dev/null 2>&1; then
                local desc
                desc=$(lsb_release -ds 2>/dev/null | tr -d '"')
                if [ -n "$desc" ]; then
                    echo "${desc} (Linux ${kernel_release})"
                    return
                fi
            fi
            echo "Linux ${kernel_release}"
            ;;
        *)
            echo "${kernel_name} ${kernel_release}"
            ;;
    esac
}

# Set OS type flags (used by other modules)
OS_TYPE=$(detect_os)
IS_MACOS=false
IS_LINUX=false
IS_WINDOWS=false

case "$OS_TYPE" in
    macOS)
        IS_MACOS=true
        ;;
    Linux)
        IS_LINUX=true
        ;;
    Windows)
        IS_WINDOWS=true
        ;;
esac

# SECURITY IMPROVEMENT: Secure way to check required tools
check_required_tools() {
    local missing_tools=()
    
    for tool in "$@"; do
        if ! command -v "$tool" > /dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo "Error: Required tools not installed: ${missing_tools[*]}"
        return 1
    fi
    
    return 0
}

# Secure function to open a file in the default browser (in background)
open_in_browser() {
    local file_path="$1"
    
    # Sanitize the file path
    file_path=$(validate_path "$file_path" "file")
    
    # Make sure the file exists
    if [ ! -f "$file_path" ]; then
        echo "Error: File not found: $file_path"
        return 1
    fi
    
    # Only allow specific file types for browser opening
    local extension="${file_path##*.}"
    local allowed_extensions=("html" "htm" "pdf" "txt" "md" "csv" "json" "xml")
    local is_allowed=false
    
    for allowed in "${allowed_extensions[@]}"; do
        if [ "$extension" == "$allowed" ]; then
            is_allowed=true
            break
        fi
    done
    
    if [ "$is_allowed" == "false" ]; then
        echo "Error: Unsupported file type for browser opening: .$extension"
        return 1
    fi
    
    # Convert to file:// URL if it's a local path and doesn't already have a scheme
    if [[ ! "$file_path" =~ ^[a-zA-Z]+:// ]]; then
        # Make sure it's an absolute path
        if [[ ! "$file_path" =~ ^/ ]]; then
            file_path="$(pwd)/$file_path"
        fi
        file_path="file://$file_path"
    fi
    
    # Create a temporary script to properly detach the browser process
    local temp_script
    temp_script=$(mktemp)
    chmod 700 "$temp_script"
    
    # Write the appropriate browser command to the script based on OS
    echo "#!/bin/bash" > "$temp_script"
    
    if [ "$IS_MACOS" = true ]; then
        echo "open \"$file_path\" &>/dev/null &" >> "$temp_script"
    elif [ "$IS_LINUX" = true ]; then
        echo "if command -v xdg-open &>/dev/null; then" >> "$temp_script"
        echo "    nohup xdg-open \"$file_path\" &>/dev/null &" >> "$temp_script"
        echo "elif command -v gnome-open &>/dev/null; then" >> "$temp_script"
        echo "    nohup gnome-open \"$file_path\" &>/dev/null &" >> "$temp_script"
        echo "elif command -v kde-open &>/dev/null; then" >> "$temp_script"
        echo "    nohup kde-open \"$file_path\" &>/dev/null &" >> "$temp_script"
        echo "elif command -v firefox &>/dev/null; then" >> "$temp_script"
        echo "    nohup firefox \"$file_path\" &>/dev/null &" >> "$temp_script"
        echo "elif command -v google-chrome &>/dev/null; then" >> "$temp_script"
        echo "    nohup google-chrome \"$file_path\" &>/dev/null &" >> "$temp_script"
        echo "else" >> "$temp_script"
        echo "    echo \"No suitable browser found.\"" >> "$temp_script"
        echo "    exit 1" >> "$temp_script"
        echo "fi" >> "$temp_script"
    elif [ "$IS_WINDOWS" = true ]; then
        echo "start \"\" \"$file_path\" &>/dev/null &" >> "$temp_script"
    else
        echo "echo \"Unknown OS. Cannot open browser automatically.\"" >> "$temp_script"
        echo "exit 1" >> "$temp_script"
    fi
    
    # Add self-cleanup to the script
    echo "sleep 1" >> "$temp_script"
    echo "rm -f \"$temp_script\"" >> "$temp_script"
    
    # Launch the script with nohup to completely detach from the parent process
    nohup "$temp_script" >/dev/null 2>&1 &
    
    # Brief pause to allow the script to start executing
    sleep 1
    
    return 0
}
