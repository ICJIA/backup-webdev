#!/bin/bash
# utils-path.sh - Path utilities for backup-webdev
# Sourced by utils.sh after utils-os.sh (get_file_size_bytes requires IS_MACOS)
# Do not execute directly

# Portable absolute path resolution (realpath is not available on macOS < 13)
abs_path() {
    local path="$1"
    if command -v realpath &>/dev/null; then
        realpath "$path" 2>/dev/null || echo "$path"
    else
        (cd "$path" 2>/dev/null && pwd) || echo "$path"
    fi
}

# SECURITY: Comprehensive safe path handling function
validate_path() {
    local path="$1"
    local type="$2"

    if [ -z "$path" ]; then
        echo "Error: Empty path provided"
        return 1
    fi

    local sanitized_path
    sanitized_path=$(echo "$path" | tr -d ';&|$()`<>{}[]!?*#~')
    sanitized_path=$(echo "$sanitized_path" | sed 's|\.\./||g' | sed 's|\.\.\\||g')

    if [ "$type" = "dir" ]; then
        if [[ ! "$sanitized_path" =~ ^/ && ! "$sanitized_path" =~ ^~ ]]; then
            echo "Error: Directory path must be absolute or relative to home"
            return 1
        fi
        if [ ! -d "$sanitized_path" ]; then
            local parent_dir
            parent_dir=$(dirname "$sanitized_path")
            if [ ! -d "$parent_dir" ]; then
                echo "Error: Parent directory does not exist: $parent_dir"
                return 1
            fi
        fi
    fi

    echo "$sanitized_path"
}

# Get file size in bytes (cross-platform: macOS stat vs Linux du -b)
get_file_size_bytes() {
    local path="$1"
    if [ ! -e "$path" ]; then
        echo "0"
        return
    fi
    if [ "$IS_MACOS" = true ]; then
        if [ -f "$path" ]; then
            stat -f %z "$path" 2>/dev/null || echo "0"
        else
            find "$path" -type f -exec du -k {} + 2>/dev/null | awk '{sum += $1} END {print sum * 1024}'
        fi
    else
        du -sb "$path" 2>/dev/null | cut -f1
    fi
}

# Compare two files to see if they're different (cross-platform)
files_differ() {
    local file1=$1
    local file2=$2
    
    # If either file doesn't exist, they differ
    if [[ ! -f "$file1" || ! -f "$file2" ]]; then
        return 0  # true, they differ
    fi
    
    # Check size first (quick comparison) - cross-platform
    local size1
    local size2
    if [ "$IS_MACOS" = true ]; then
        size1=$(stat -f %z "$file1" 2>/dev/null)
        size2=$(stat -f %z "$file2" 2>/dev/null)
    else
        size1=$(stat -c %s "$file1" 2>/dev/null)
        size2=$(stat -c %s "$file2" 2>/dev/null)
    fi
    
    if [[ "$size1" != "$size2" ]]; then
        return 0  # true, they differ
    fi
    
    # Compare content: cmp -s returns 0 if same, 1 if different
    if cmp -s "$file1" "$file2"; then
        return 1  # files are the same (not different)
    fi
    return 0  # files differ
}

# Get file permissions in octal format (cross-platform)
get_file_permissions() {
    local file_path=$1
    if [ "$IS_MACOS" = true ]; then
        stat -f %OLp "$file_path" 2>/dev/null
    else
        stat -c %a "$file_path" 2>/dev/null
    fi
}
