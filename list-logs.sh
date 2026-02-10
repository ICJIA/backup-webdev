#!/bin/bash
# list-logs.sh - List all log files used by WebDev Backup Tool

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGS_DIR="${LOGS_DIR:-$SCRIPT_DIR/logs}"
TEST_DIR="${TEST_DIR:-$SCRIPT_DIR/test}"

# Optional: load config for consistent paths (may fail if not configured)
if [ -f "$SCRIPT_DIR/config.sh" ]; then
    export RUNNING_TESTS=1 2>/dev/null
    source "$SCRIPT_DIR/config.sh" 2>/dev/null || true
    LOGS_DIR="${LOGS_DIR:-$SCRIPT_DIR/logs}"
    TEST_DIR="${TEST_DIR:-$SCRIPT_DIR/test}"
fi

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Pattern to match error-like lines (case-insensitive)
ERROR_PATTERN='(error|failed|fail|fatal|warn|warning|exception|denied|refused|not found|cannot|unable|invalid)'

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "  List all log files (app logs and test logs), or list only error lines."
    echo ""
    echo "Options:"
    echo "  -h, --help           Show this help"
    echo "  -s, --short          Paths only, one per line (ignored with --errors)"
    echo "  -v, --verbose        Show size and modification time (default)"
    echo "  -e, --errors         List only lines that look like errors/warnings from logs"
}

SHORT=false
VERBOSE=true
ERRORS_MODE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help) usage; exit 0 ;;
        -s|--short) SHORT=true; VERBOSE=false; shift ;;
        -v|--verbose) VERBOSE=true; shift ;;
        -e|--errors|--list-log-errors) ERRORS_MODE=true; shift ;;
        *) echo "Unknown option: $1"; usage; exit 1 ;;
    esac
done

list_dir() {
    local dir="$1"
    local label="$2"
    local log_only="${3:-false}"   # if true, only list *.log files
    if [ ! -d "$dir" ]; then
        echo -e "${YELLOW}$label: directory not found ($dir)${NC}"
        return
    fi
    local count=0
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        count=$((count + 1))
        if [ "$SHORT" = true ]; then
            echo "$f"
        else
            if [ "$VERBOSE" = true ]; then
                ls -l "$f" 2>/dev/null | sed 's/^/  /'
            else
                echo "  $f"
            fi
        fi
    done < <(if [ "$log_only" = true ]; then
                 find "$dir" -type f -name "*.log" 2>/dev/null
             else
                 find "$dir" -type f \( -name "*.log" -o ! -name '.gitkeep' \) 2>/dev/null
             fi | sort -u)
    if [ "$SHORT" = false ] && [ $count -eq 0 ]; then
        echo -e "  ${YELLOW}(none)${NC}"
    fi
    echo ""
}

# Mode: list only error/warning lines from all logs
if [ "$ERRORS_MODE" = true ]; then
    echo -e "${CYAN}===== WebDev Backup Tool – Log Errors =====${NC}"
    echo ""
    found_any=0
    for dir in "$LOGS_DIR" "$TEST_DIR"; do
        [ ! -d "$dir" ] && continue
        while IFS= read -r f; do
            [ -z "$f" ] || [ ! -f "$f" ] && continue
            matches=$(grep -iE "$ERROR_PATTERN" "$f" 2>/dev/null)
            if [ -n "$matches" ]; then
                found_any=1
                echo -e "${GREEN}$f${NC}"
                echo "$matches" | sed 's/^/  /'
                echo ""
            fi
        done < <(find "$dir" -type f -name "*.log" 2>/dev/null | sort -u)
    done
    if [ "$found_any" -eq 0 ]; then
        echo -e "${GREEN}No error or warning lines found in log files.${NC}"
    fi
    exit 0
fi

echo -e "${CYAN}===== WebDev Backup Tool – Log Files =====${NC}"
echo ""

echo -e "${GREEN}App logs: $LOGS_DIR${NC}"
list_dir "$LOGS_DIR" "App logs"

echo -e "${GREEN}Test logs: $TEST_DIR${NC}"
list_dir "$TEST_DIR" "Test logs" true

if [ "$SHORT" = false ]; then
    echo -e "${CYAN}Note:${NC} Per-run backup logs (backup_log.log, backup_stats.txt) live inside each dated backup folder under your backup destination."
fi
