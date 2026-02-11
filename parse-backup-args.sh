#!/bin/bash
# parse-backup-args.sh - CLI argument parsing for backup.sh
# Sourced by backup.sh - sets backup options from command line
# Requires: utils.sh, ui.sh (for validate_path, RED/NC, show_backup_help)

# Parse command line arguments (consumes $@ via shift)
while [[ $# -gt 0 ]]; do
    case $1 in
        --silent)
            SILENT_MODE=true
            shift
            ;;
        --quick)
            SILENT_MODE=true
            QUICK_BACKUP=true
            shift
            ;;
        --incremental)
            INCREMENTAL_BACKUP=true
            DIFFERENTIAL_BACKUP=false
            shift
            ;;
        --differential)
            DIFFERENTIAL_BACKUP=true
            INCREMENTAL_BACKUP=false
            shift
            ;;
        --verify)
            VERIFY_BACKUP=true
            VERIFY_EXPLICITLY_SET=true
            shift
            ;;
        --no-verify)
            VERIFY_BACKUP=false
            VERIFY_EXPLICITLY_SET=true
            shift
            ;;
        --thorough-verify)
            VERIFY_BACKUP=true
            THOROUGH_VERIFY=true
            VERIFY_EXPLICITLY_SET=true
            shift
            ;;
        --compression)
            if [[ -n "$2" && "$2" =~ ^[1-9]$ ]]; then
                COMPRESSION_LEVEL="$2"
                shift 2
            else
                echo -e "${RED}Error: Compression argument requires a number between 1 and 9${NC}"
                exit 1
            fi
            ;;
        --email)
            if [[ -n "$2" && "$2" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
                EMAIL_NOTIFICATION="$2"
                shift 2
            else
                echo -e "${RED}Error: Email argument requires a valid email address${NC}"
                exit 1
            fi
            ;;
        --cloud)
            if [[ -n "$2" && "$2" =~ ^(aws|s3|do|spaces|digitalocean|dropbox|gdrive|google)$ ]]; then
                CLOUD_PROVIDER="$2"
                EXTERNAL_BACKUP=true
                shift 2
            else
                echo -e "${RED}Error: Cloud provider must be one of: aws, s3, do, spaces, digitalocean, dropbox, gdrive, google${NC}"
                exit 1
            fi
            ;;
        --external)
            EXTERNAL_BACKUP=true
            CLOUD_PROVIDER="${CLOUD_PROVIDER:-$DEFAULT_CLOUD_PROVIDER}"
            shift
            ;;
        --bandwidth)
            if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
                BANDWIDTH_LIMIT="$2"
                shift 2
            else
                echo -e "${RED}Error: Bandwidth argument requires a number in KB/s${NC}"
                exit 1
            fi
            ;;
        --parallel)
            if [[ -n "$2" && "$2" =~ ^[1-8]$ ]]; then
                PARALLEL_THREADS="$2"
                shift 2
            else
                echo -e "${RED}Error: Parallel threads argument requires a number between 1 and 8${NC}"
                exit 1
            fi
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --destination|--dest|-d)
            if [[ -n "$2" && "$2" != --* ]]; then
                _dir="${2/#\~/$HOME}"
                CUSTOM_BACKUP_DIR=$(validate_path "$_dir" "dir") || { echo -e "${RED}Error: Invalid destination path${NC}"; exit 1; }
                shift 2
            else
                echo -e "${RED}Error: Destination argument requires a directory path${NC}"
                exit 1
            fi
            ;;
        --sources)
            if [[ -n "$2" ]]; then
                IFS=',' read -ra custom_dirs <<< "$2"
                for _dir in "${custom_dirs[@]}"; do
                    _dir=$(echo "$_dir" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    _dir="${_dir/#\~/$HOME}"
                    _validated=$(validate_path "$_dir" "dir") || { echo -e "${RED}Error: Invalid source path: $_dir${NC}"; exit 1; }
                    CUSTOM_SOURCE_DIRS+=("$_validated")
                done
                shift 2
            else
                echo -e "${RED}Error: --sources requires a comma-separated list of directories${NC}"
                exit 1
            fi
            ;;
        --source|-s)
            if [[ -n "$2" && "$2" != --* ]]; then
                _dir="${2/#\~/$HOME}"
                _validated=$(validate_path "$_dir" "dir") || { echo -e "${RED}Error: Invalid source path${NC}"; exit 1; }
                CUSTOM_SOURCE_DIRS+=("$_validated")
                shift 2
            else
                echo -e "${RED}Error: Source argument requires a directory path${NC}"
                exit 1
            fi
            ;;
        -h|--help)
            show_backup_help
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help to see available options"
            exit 1
            ;;
    esac
done
