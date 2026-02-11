#!/bin/bash
# utils-format.sh - Formatting utilities for backup-webdev
# Sourced by utils.sh - do not execute directly

# Format size function (converts bytes to human readable format)
format_size() {
    local size=$1
    awk '
        BEGIN {
            suffix[1] = "B"
            suffix[2] = "KB"
            suffix[3] = "MB"
            suffix[4] = "GB"
            suffix[5] = "TB"
        }
        {
            for (i = 5; i > 0; i--) {
                if ($1 >= 1024 ^ (i - 1)) {
                    printf("%.2f %s", $1 / (1024 ^ (i - 1)), suffix[i])
                    break
                }
            }
        }
    ' <<< "$size"
}

# Portable: capitalize first letter (replaces ${var^} for Bash 3.2)
capitalize() {
    echo "$1" | awk '{print toupper(substr($0,1,1)) substr($0,2)}'
}
