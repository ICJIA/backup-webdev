#!/bin/bash
# reporting.sh - Reporting functions for backup-webdev
# This file contains reporting-related functions used across scripts
#
# SCRIPT TYPE: Module (sourced by other scripts, not executed directly)
# This is the main reporting interface that sources specialized reporting modules

# Source the shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Source specialized reporting modules
# These modules contain the actual implementation of reporting functions
source "$SCRIPT_DIR/reporting-html.sh"    # HTML report generation
source "$SCRIPT_DIR/reporting-email.sh"   # Email report generation
source "$SCRIPT_DIR/reporting-charts.sh"   # Chart and visualization generation

# All reporting functions are now available:
# - create_backup_report()      (from reporting-html.sh)
# - create_email_report()       (from reporting-email.sh)
# - generate_history_chart()     (from reporting-charts.sh)
# - create_default_chart()       (from reporting-charts.sh)
# - generate_space_forecast_safe() (from reporting-charts.sh)
# - create_visual_dashboard()    (from reporting-charts.sh)

# End of reporting functions
