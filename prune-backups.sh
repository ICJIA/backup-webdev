#!/bin/bash
# prune-backups.sh - Prune old backups from the backup destination
# Lists all backups and lets user keep the N latest (default 5) or prune one by one

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/ui.sh"
source "$SCRIPT_DIR/fs.sh"

BACKUP_DIR="${1:-$DEFAULT_BACKUP_DIR}"
KEEP_COUNT="${2:-5}"
SKIP_CONFIRMATION="${SKIP_CONFIRMATION:-false}"

# Validate BACKUP_DIR when explicitly passed (reject path traversal)
if [ -n "${1:-}" ]; then
    if [[ "$BACKUP_DIR" == *".."* ]]; then
        echo -e "${RED}Error: Path traversal (..) not allowed in backup directory${NC}"
        exit 1
    fi
    # Resolve to canonical path (portable: cd + pwd works on macOS and Linux)
    if BACKUP_DIR_CANONICAL=$(cd "$BACKUP_DIR" 2>/dev/null && pwd); then
        BACKUP_DIR="$BACKUP_DIR_CANONICAL"
    fi
fi

# Get list of backups sorted newest first (cross-platform)
get_backup_list() {
    local backup_dir="$1"
    if [ ! -d "$backup_dir" ]; then
        return 1
    fi
    if [ "$(uname -s)" = "Darwin" ]; then
        find "$backup_dir" -maxdepth 1 -type d \( -name "webdev_backup_*" -o -name "wsl2_backup_*" \) -exec stat -f "%m %N" {} \; | sort -rn | cut -d' ' -f2-
    else
        find "$backup_dir" -maxdepth 1 -type d \( -name "webdev_backup_*" -o -name "wsl2_backup_*" \) -printf "%T@ %p\n" | sort -rn | cut -d' ' -f2-
    fi
}

# Count backups
count_backups() {
    local backup_dir="$1"
    if [ ! -d "$backup_dir" ]; then
        echo "0"
        return
    fi
    find "$backup_dir" -maxdepth 1 -type d \( -name "webdev_backup_*" -o -name "wsl2_backup_*" \) | wc -l | tr -d ' '
}

# Main prune logic
main() {
    echo -e "\n${CYAN}===== Prune Backups =====${NC}"
    echo -e "Backup directory: ${GREEN}$BACKUP_DIR${NC}\n"

    if [ ! -d "$BACKUP_DIR" ]; then
        echo -e "${RED}Error: Backup directory does not exist: $BACKUP_DIR${NC}"
        exit 1
    fi

    local total
    total=$(count_backups "$BACKUP_DIR")
    if [ "$total" -eq 0 ]; then
        echo -e "${GREEN}No backups found in $BACKUP_DIR${NC}"
        exit 0
    fi

    # Build indexed array of backups (newest first)
    local backups=()
    while IFS= read -r line; do
        [ -n "$line" ] && backups=("${backups[@]}" "$line")
    done < <(get_backup_list "$BACKUP_DIR")

    echo -e "${YELLOW}Found $total backup(s):${NC}"
    echo ""
    local i
    for ((i=0; i<${#backups[@]}; i++)); do
        local name mtime
        name=$(basename "${backups[$i]}")
        if [ "$(uname -s)" = "Darwin" ]; then
            mtime=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "${backups[$i]}" 2>/dev/null)
        else
            mtime=$(stat -c "%y" "${backups[$i]}" 2>/dev/null | cut -d'.' -f1 | tr -d ' ')
        fi
        printf "  [%2d] %-45s  %s\n" "$((i+1))" "$name" "$mtime"
    done
    echo ""

    # Menu: Keep N latest (default) or Prune one by one
    echo -e "${CYAN}Options:${NC}"
    echo "  1) Keep $KEEP_COUNT latest (delete older backups) [default]"
    echo "  2) Prune one by one (choose which to delete)"
    echo "  q) Quit (no changes)"
    echo ""
    read -p "Enter your choice [1]: " choice
    choice="${choice:-1}"

    case "$choice" in
        1)
            # Keep N latest - delete the rest
            if [ "${#backups[@]}" -le "$KEEP_COUNT" ]; then
                echo -e "${GREEN}You have $total backup(s). None to remove (keeping $KEEP_COUNT latest).${NC}"
                exit 0
            fi
            local to_delete=$(( total - KEEP_COUNT ))
            echo -e "\n${YELLOW}Will delete $to_delete backup(s), keeping the $KEEP_COUNT most recent.${NC}"
            local dir
            local idx=0
            for ((i=KEEP_COUNT; i<${#backups[@]}; i++)); do
                dir="${backups[$i]}"
                local dir_name
                dir_name=$(basename "$dir")
                if [ "$SKIP_CONFIRMATION" = true ]; then
                    rm -rf "$dir"
                    echo -e "${GREEN}  ✓ Deleted: $dir_name${NC}"
                else
                    if safe_confirm "Delete $dir_name?" "y"; then
                        rm -rf "$dir"
                        echo -e "${GREEN}  ✓ Deleted: $dir_name${NC}"
                    else
                        echo -e "${YELLOW}  ✗ Kept: $dir_name${NC}"
                    fi
                fi
            done
            echo -e "\n${GREEN}Prune complete.${NC}"
            ;;
        2)
            # Prune one by one
            echo -e "\n${YELLOW}Enter the number(s) of backups to delete (e.g. 3 or 3,5,7 or 3-6). Press Enter when done.${NC}"
            echo -e "${YELLOW}Or type 'all' to delete all, 'keep N' to keep N latest and delete the rest.${NC}"
            echo ""
            local to_remove=()
            while true; do
                read -p "Delete backup # (or Enter to finish): " sel
                if [ -z "$sel" ]; then
                    break
                fi
                if [ "$sel" = "all" ]; then
                    to_remove=("${backups[@]}")
                    break
                fi
                if [[ "$sel" =~ ^keep[[:space:]]*[0-9]+$ ]]; then
                    local keep_n
                    keep_n=$(echo "$sel" | grep -oE '[0-9]+' | head -1)
                    for ((i=keep_n; i<${#backups[@]}; i++)); do
                        to_remove=("${to_remove[@]}" "${backups[$i]}")
                    done
                    break
                fi
                # Parse single number or range (e.g. 3-6) or comma list
                if [[ "$sel" =~ ^([0-9]+)-([0-9]+)$ ]]; then
                    local start="${BASH_REMATCH[1]}"
                    local end="${BASH_REMATCH[2]}"
                    for ((i=start; i<=end && i<=${#backups[@]}; i++)); do
                        to_remove=("${to_remove[@]}" "${backups[$((i-1))]}")
                    done
                elif [[ "$sel" =~ ^[0-9]+(,[0-9]+)*$ ]]; then
                    IFS=',' read -ra nums <<< "$sel"
                    for n in "${nums[@]}"; do
                        n=$(echo "$n" | tr -d ' ')
                        if [ "$n" -ge 1 ] && [ "$n" -le "${#backups[@]}" ]; then
                            to_remove=("${to_remove[@]}" "${backups[$((n-1))]}")
                        fi
                    done
                elif [[ "$sel" =~ ^[0-9]+$ ]]; then
                    if [ "$sel" -ge 1 ] && [ "$sel" -le "${#backups[@]}" ]; then
                        to_remove=("${to_remove[@]}" "${backups[$((sel-1))]}")
                    else
                        echo -e "${RED}Invalid number. Enter 1-${#backups[@]}.${NC}"
                    fi
                else
                    echo -e "${RED}Invalid input. Use a number, range (e.g. 3-6), or 'all'.${NC}"
                fi
            done

            if [ ${#to_remove[@]} -eq 0 ]; then
                echo -e "${YELLOW}No backups selected for deletion.${NC}"
                exit 0
            fi

            # Remove duplicates and delete
            for dir in "${to_remove[@]}"; do
                [ -d "$dir" ] || continue
                local dir_name
                dir_name=$(basename "$dir")
                if [ "$SKIP_CONFIRMATION" = true ]; then
                    rm -rf "$dir"
                    echo -e "${GREEN}  ✓ Deleted: $dir_name${NC}"
                else
                    if safe_confirm "Delete $dir_name?" "n"; then
                        rm -rf "$dir"
                        echo -e "${GREEN}  ✓ Deleted: $dir_name${NC}"
                    else
                        echo -e "${YELLOW}  ✗ Skipped: $dir_name${NC}"
                    fi
                fi
            done
            echo -e "\n${GREEN}Prune complete.${NC}"
            ;;
        q|Q)
            echo -e "${YELLOW}No changes made.${NC}"
            ;;
        *)
            echo -e "${RED}Invalid choice.${NC}"
            exit 1
            ;;
    esac
}

main
