#!/bin/bash
# utils-time.sh - Time and date utilities for backup-webdev
# Sourced by utils.sh after utils-os.sh (requires IS_MACOS)
# Do not execute directly

# Format Unix timestamp to readable datetime (cross-platform)
# Usage: format_timestamp SECONDS [FMT]
format_timestamp() {
    local sec="${1:-0}"
    local fmt="${2:-%Y-%m-%d %H:%M}"
    if [ "$IS_MACOS" = true ]; then
        date -r "$sec" "+$fmt" 2>/dev/null
    else
        date -d "@$sec" "+$fmt" 2>/dev/null
    fi
}

# Add hours/days to now and return formatted datetime (cross-platform for cron prediction)
date_add_hours() {
    local hours="${1:-0}"
    local now=$(date +%s)
    local then=$((now + hours * 3600))
    format_timestamp "$then" "%Y-%m-%d %H:%M"
}
date_add_days() {
    local days="${1:-0}"
    local now=$(date +%s)
    local then=$((now + days * 86400))
    format_timestamp "$then" "%Y-%m-%d %H:%M"
}

# Next Sunday 00:00 (cross-platform)
date_next_sunday() {
    local w add_days
    w=$(date +%u)
    if [ "$w" -eq 7 ]; then
        add_days=7
    else
        add_days=$((7 - w))
    fi
    local now=$(date +%s)
    local then=$((now + add_days * 86400))
    format_timestamp "$then" "%Y-%m-%d 00:00"
}
date_next_sunday_plus_week() {
    local w add_days
    w=$(date +%u)
    if [ "$w" -eq 7 ]; then
        add_days=7
    else
        add_days=$((7 - w))
    fi
    add_days=$((add_days + 7))
    local now=$(date +%s)
    local then=$((now + add_days * 86400))
    format_timestamp "$then" "%Y-%m-%d 00:00"
}

# Parse datetime string to Unix seconds (cross-platform: macOS BSD date vs GNU date)
date_to_seconds() {
    local datetime="${1:-}"
    if [ -z "$datetime" ]; then
        echo "0"
        return
    fi
    if [ "$IS_MACOS" = true ]; then
        date -j -f "%Y-%m-%d %H:%M:%S" "$datetime" +%s 2>/dev/null || echo "0"
    else
        date -d "$datetime" +%s 2>/dev/null || echo "0"
    fi
}

# Format time in seconds to readable format (e.g. 45s, 2m 5s, 1h 1m)
format_time() {
    local seconds=$1
    
    if [ "$seconds" -lt 60 ]; then
        echo "${seconds}s"
    elif [ "$seconds" -lt 3600 ]; then
        local m=$((seconds / 60))
        local s=$((seconds % 60))
        printf "%dm %ds" $m $s
    else
        local h=$((seconds / 3600))
        local m=$(((seconds % 3600) / 60))
        printf "%dh %dm" $h $m
    fi
}

# Get file modification time as Unix timestamp (cross-platform)
get_file_mtime() {
    local file_path=$1
    if [ "$IS_MACOS" = true ]; then
        stat -f %m "$file_path" 2>/dev/null
    else
        stat -c %Y "$file_path" 2>/dev/null
    fi
}

# Format file modification date (cross-platform: macOS date -r vs Linux date -d)
format_file_date() {
    local file_path="$1"
    local fmt="${2:-%Y-%m-%d}"
    local mtime
    mtime=$(get_file_mtime "$file_path")
    [ -z "$mtime" ] && return 1
    if [ "$IS_MACOS" = true ]; then
        date -r "$mtime" "+$fmt" 2>/dev/null
    else
        date -d "@$mtime" "+$fmt" 2>/dev/null
    fi
}
