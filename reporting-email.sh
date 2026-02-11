#!/bin/bash
# reporting-email.sh - Email report generation functions
# SCRIPT TYPE: Module (sourced by reporting.sh)
# This module provides email report generation functionality

# Note: SCRIPT_DIR and utils.sh should be sourced by the parent script (reporting.sh)
# This module assumes SCRIPT_DIR and format_size() are available

create_email_report() {
    local backup_dir=$1
    local successful=$2
    local failed=$3
    local src_size=$4
    local backup_size=$5
    local start_time=$6
    local end_time=$7
    local backup_type=${8:-"full"}
    
    # Calculate duration (cross-platform: date_to_seconds from utils.sh)
    local end_sec start_sec duration
    end_sec=$(date_to_seconds "$end_time")
    start_sec=$(date_to_seconds "$start_time")
    duration=$(( end_sec - start_sec ))
    [ "$duration" -lt 0 ] && duration=0
    local duration_str=$(printf "%02d:%02d:%02d" $(($duration/3600)) $(($duration%3600/60)) $(($duration%60)))
    
    # Create email content
    local email_content="WebDev Backup Report - $(date '+%Y-%m-%d')\n"
    email_content+="\n===== Backup Summary =====\n"
    email_content+="Date: $end_time\n"
    email_content+="Backup Type: $(capitalize "$backup_type")\n"
    email_content+="Duration: $duration_str\n"
    email_content+="Projects Processed: $(($successful + $failed))\n"
    email_content+="Successfully Backed Up: $successful\n"
    email_content+="Failed Backups: $failed\n"
    email_content+="Total Source Size: $(format_size "$src_size")\n"
    email_content+="Total Backup Size: $(format_size "$backup_size")\n"
    
    # Add compression ratio if we have valid sizes
    if [ "$backup_size" -gt 0 ] && [ "$src_size" -gt 0 ]; then
        local ratio=$(awk "BEGIN {printf \"%.1f\", ($src_size/$backup_size)}")
        email_content+="Overall Compression Ratio: ${ratio}x\n"
    fi
    
    # Add backup location
    email_content+="Backup Location: $backup_dir\n"
    
    # Add status indication
    if [ "$failed" -eq 0 ]; then
        email_content+="\nStatus: SUCCESS - All projects backed up successfully.\n"
    else
        email_content+="\nStatus: WARNING - $failed projects failed to back up properly.\n"
        email_content+="Please check the detailed report for more information.\n"
    fi
    
    echo -e "$email_content"
}
