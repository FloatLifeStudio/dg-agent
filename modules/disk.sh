#!/usr/bin/env bash

set -euo pipefail

readonly PROGRAM_NAME="${0##*/}"
readonly VERSION="1.0.0"

DEFAULT_LOG_FILE="./test.log"
DEFAULT_OUTPUT_FILE="./output_disk.json"

LOG_FILE="$DEFAULT_LOG_FILE"
OUTPUT_FILE="$DEFAULT_OUTPUT_FILE"
VERBOSE=0

readonly REQUIRED_COMMANDS=(
    curl
    wget
    jq
    lsblk
)

readonly LOG_FD=3

usage() {
    cat << EOF
Usage: ${PROGRAM_NAME} [OPTION]...

Check required system dependencies, collect Disk assets (Root required), and save JSON output.

Options:
  -l, --log-file=FILE    Specify log file path (default: ${DEFAULT_LOG_FILE})
  -o, --output=FILE      Specify JSON output path (default: ${DEFAULT_OUTPUT_FILE})
  -v, --verbose          Enable verbose log output to stderr
  -h, --help             Display this help and exit
  -V, --version          Output version information and exit
EOF
}

version() {
    printf "%s %s\n" "$PROGRAM_NAME" "$VERSION"
}

log() {
    local -r level="$1"
    local -r message="$2"
    local sec ms timestamp

    if [[ -n "${EPOCHREALTIME:-}" ]]; then
        sec="${EPOCHREALTIME%.*}"
        ms="${EPOCHREALTIME#*.}"
        ms="${ms:0:3}"
        printf -v timestamp '%(%Y-%m-%d %H:%M:%S)T.%s' "$sec" "$ms"
    else
        printf -v timestamp '%(%Y-%m-%d %H:%M:%S)T' -1
    fi

    local -r log_entry="${timestamp} - [${level}] ${message}"

    printf '%s\n' "$log_entry" >&"$LOG_FD"

    if [[ "$level" == "ERROR" || "$level" == "WARN" || "$VERBOSE" -eq 1 ]]; then
        printf '%s\n' "$log_entry" >&2
    fi
}

cleanup() {
    local -r exit_code=$?
    trap - EXIT INT TERM HUP

    if [[ "$exit_code" -ne 0 ]]; then
        log "ERROR" "Script terminated abnormally with exit code: ${exit_code}"
    fi

    eval "exec ${LOG_FD}>&-" 2> /dev/null || true
    exit "$exit_code"
}

trap cleanup EXIT INT TERM HUP

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log "ERROR" "This script requires root privileges. Please run as root or with sudo."
        return 1
    fi
    log "INFO" "Root permission check passed."
    return 0
}

parse_options() {
    local args
    if ! args=$(getopt -o "l:o:vhV" --long "log-file:,output:,verbose,help,version" -n "$PROGRAM_NAME" -- "$@"); then
        usage >&2
        exit 1
    fi

    eval set -- "$args"

    while true; do
        case "$1" in
            -l | --log-file)
                LOG_FILE="$2"
                shift 2
                ;;
            -o | --output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            -v | --verbose)
                VERBOSE=1
                shift 2
                ;;
            -h | --help)
                usage
                exit 0
                ;;
            -V | --version)
                version
                exit 0
                ;;
            --)
                shift
                break
                ;;
            *)
                exit 1
                ;;
        esac
    done
}

check_dependencies() {
    local missing_cmds=()
    local cmd

    for cmd in "${REQUIRED_COMMANDS[@]}"; do
        if command -v "$cmd" > /dev/null 2>&1; then
            log "INFO" "Command is available: ${cmd}"
        else
            missing_cmds+=("$cmd")
        fi
    done

    if [[ ${#missing_cmds[@]} -gt 0 ]]; then
        log "ERROR" "Missing required command(s): ${missing_cmds[*]}"
        return 1
    fi

    return 0
}

collect_disk_info() {
    local -a raw_modules_json=()
    local total_size_bytes=0

    log "INFO" "Collecting physical disk details via lsblk..."

    # Use lsblk to output block devices in JSON format (disk type only, excluding loop, ROM, etc.)
    local lsblk_raw
    lsblk_raw="$(lsblk -d -b -J -o NAME,VENDOR,MODEL,SIZE,ROTA,TRAN,SERIAL,TYPE 2> /dev/null || echo '{"blockdevices":[]}')"

    local len
    len="$(echo "$lsblk_raw" | jq '.blockdevices | length' 2> /dev/null || echo 0)"

    local i=0
    for ((i = 0; i < len; i++)); do
        local dev_type name vendor model size_bytes rota tran serial

        dev_type="$(echo "$lsblk_raw" | jq -r ".blockdevices[$i].type // \"\"")"
        [[ "$dev_type" != "disk" ]] && continue

        name="$(echo "$lsblk_raw" | jq -r ".blockdevices[$i].name // \"\"")"
        vendor="$(echo "$lsblk_raw" | jq -r ".blockdevices[$i].vendor // \"\"" | xargs)"
        model="$(echo "$lsblk_raw" | jq -r ".blockdevices[$i].model // \"\"" | xargs)"
        size_bytes="$(echo "$lsblk_raw" | jq -r ".blockdevices[$i].size // 0")"
        rota="$(echo "$lsblk_raw" | jq -r ".blockdevices[$i].rota // \"\"")"
        tran="$(echo "$lsblk_raw" | jq -r ".blockdevices[$i].tran // \"\"")"
        serial="$(echo "$lsblk_raw" | jq -r ".blockdevices[$i].serial // \"\"" | xargs)"

        # Accumulated installed physical disk size
        total_size_bytes=$((total_size_bytes + size_bytes))

        # Determine media type (SSD vs HDD)
        local disk_type="DISK"
        if [[ "$tran" == "nvme" ]]; then
            disk_type="NVMe SSD"
        elif [[ "$rota" == "0" || "$rota" == "false" ]]; then
            disk_type="SSD"
        elif [[ "$rota" == "1" || "$rota" == "true" ]]; then
            disk_type="HDD"
        fi

        # Capacity conversion (bytes ->GB)
        local capacity="0GB"
        if [[ "$size_bytes" -gt 0 ]]; then
            local capacity_gb
            capacity_gb="$(awk "BEGIN {printf \"%.0f\", $size_bytes / 1024 / 1024 / 1024}")"
            capacity="${capacity_gb}GB"
        fi

        # Assemble display to show fields
        local display="${vendor:+${vendor} }${model:+${model} }${disk_type} ${capacity} SN:${serial}"
        display="$(echo "$display" | xargs)"

        raw_modules_json+=("$(jq -nc \
            --arg v "$vendor" \
            --arg m "$model" \
            --arg t "$disk_type" \
            --arg c "$capacity" \
            --arg s "" \
            --arg sn "$serial" \
            --arg d "$display" \
            '{vendor: $v, model: $m, type: $t, capacity: $c, speed: $s, serial: $sn, display: $d}')")
    done

    # Calculate the global capacity of the system disk (installed/available)
    local installed_str="0GB"
    local available_str="0GB"

    if [[ "$total_size_bytes" -gt 0 ]]; then
        local installed_gb
        installed_gb="$(awk "BEGIN {printf \"%.0f\", $total_size_bytes / 1024 / 1024 / 1024}")"
        installed_str="${installed_gb}GB"
    fi

    # Calculate the remaining available capacity of the root mount point
    if command -v df > /dev/null 2>&1; then
        local avail_kb
        avail_kb="$(df -k / | awk 'NR==2 {print $4}' || echo "0")"
        local avail_gb
        avail_gb="$(awk "BEGIN {printf \"%.0f\", $avail_kb / 1024 / 1024}")"
        available_str="${avail_gb}GB"
    fi

    local total_count="${#raw_modules_json[@]}"

    log "INFO" "Disk info collection completed. Found ${total_count} physical disk(s)."

    # Output specified format JSON
    if [[ ${#raw_modules_json[@]} -gt 0 ]]; then
        printf '%s\n' "${raw_modules_json[@]}" | jq -s \
            --argjson count "$total_count" \
            --arg installed "$installed_str" \
            --arg available "$available_str" \
            '{
                modules: .,
                count: $count,
                installed: $installed,
                available: $available
            }'
    else
        jq -nc \
            --arg installed "$installed_str" \
            --arg available "$available_str" \
            '{
                modules: [],
                count: 0,
                installed: $installed,
                available: $available
            }'
    fi
}

main() {
    parse_options "$@"

    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$(dirname "$OUTPUT_FILE")"

    eval "exec ${LOG_FD}>>\"\$LOG_FILE\""

    log "INFO" "Checking root privileges..."
    if ! check_root; then
        exit 1
    fi

    log "INFO" "Starting dependency checks..."
    if ! check_dependencies; then
        log "ERROR" "Dependency check failed."
        exit 1
    fi

    log "INFO" "All checks passed. Executing Disk collection..."

    collect_disk_info > "$OUTPUT_FILE"

    log "INFO" "Disk information successfully saved to: ${OUTPUT_FILE}"
}

main "$@"
