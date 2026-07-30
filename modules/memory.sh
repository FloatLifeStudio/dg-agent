#!/usr/bin/env bash

set -euo pipefail

readonly PROGRAM_NAME="${0##*/}"
readonly VERSION="1.0.0"

DEFAULT_LOG_FILE="./test.log"
DEFAULT_OUTPUT_FILE="./output_memory.json"

LOG_FILE="$DEFAULT_LOG_FILE"
OUTPUT_FILE="$DEFAULT_OUTPUT_FILE"
VERBOSE=0

readonly REQUIRED_COMMANDS=(
    curl
    wget
    jq
    dmidecode
)

readonly LOG_FD=3

usage() {
    cat << EOF
Usage: ${PROGRAM_NAME} [OPTION]...

Check required system dependencies, collect Memory assets (Root required), and save JSON output.

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
                shift
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

collect_memory_info() {
    local -a raw_modules_json=()
    local installed_str="0GB"
    local available_str="0GB"

    log "INFO" "Collecting memory modules via dmidecode..."
    local dmi_out
    dmi_out="$(dmidecode -t memory 2> /dev/null || true)"

    local vendor="" model="" type="" capacity="" speed="" serial=""
    local block size

    while IFS= read -r block; do
        [[ -z "$block" ]] && continue

        size="$(echo "$block" | grep -iE '^[[:space:]]*Size:' | awk -F: '{print $2}' | xargs || true)"
        [[ -z "$size" || "$size" == "No Module Installed" ]] && continue

        vendor="$(echo "$block" | grep -iE '^[[:space:]]*Manufacturer:' | awk -F: '{print $2}' | xargs || true)"
        model="$(echo "$block" | grep -iE '^[[:space:]]*Part Number:' | awk -F: '{print $2}' | xargs || true)"
        type="$(echo "$block" | grep -iE '^[[:space:]]*Type:' | awk -F: '{print $2}' | xargs || true)"
        speed="$(echo "$block" | grep -iE '^[[:space:]]*Speed:' | awk -F: '{print $2}' | xargs || true)"
        serial="$(echo "$block" | grep -iE '^[[:space:]]*Serial Number:' | awk -F: '{print $2}' | xargs || true)"

        # Filter invalid placeholder characters
        [[ "$vendor" =~ ^(NO|Unknown|[Nn]/[Aa]) ]] && vendor=""
        [[ "$model" =~ ^(NO|Unknown|[Nn]/[Aa]) ]] && model=""
        [[ "$serial" =~ ^(NO|Unknown|[Nn]/[Aa]) ]] && serial=""
        [[ -z "$type" || "$type" == "Unknown" ]] && type="DRAM"

        capacity="$(echo "$size" | tr -d ' ')"

        # Format and splice display fields
        local display="${vendor:+${vendor} }${model:+${model} }${type:+${type} }${capacity} SN:${serial}"
        display="$(echo "$display" | xargs)"

        raw_modules_json+=("$(jq -nc \
            --arg v "$vendor" \
            --arg m "$model" \
            --arg t "$type" \
            --arg c "$capacity" \
            --arg s "$speed" \
            --arg sn "$serial" \
            --arg d "$display" \
            '{vendor: $v, model: $m, type: $t, capacity: $c, speed: $s, serial: $sn, display: $d}')")
    done < <(echo "$dmi_out" | awk -v RS="Memory Device" '{print $0}')

    # Calculate global installation capacity and available capacity
    if [[ -r /proc/meminfo ]]; then
        local mem_total_kb mem_avail_kb mem_total_gb mem_avail_gb
        mem_total_kb="$(grep -iE '^MemTotal:' /proc/meminfo | awk '{print $2}' || echo "0")"
        mem_avail_kb="$(grep -iE '^MemAvailable:' /proc/meminfo | awk '{print $2}' || echo "0")"

        mem_total_gb="$(awk "BEGIN {printf \"%.0f\", $mem_total_kb / 1024 / 1024}")"
        mem_avail_gb="$(awk "BEGIN {printf \"%.0f\", $mem_avail_kb / 1024 / 1024}")"

        installed_str="${mem_total_gb}GB"
        available_str="${mem_avail_gb}GB"
    fi

    local total_count="${#raw_modules_json[@]}"

    log "INFO" "Memory info collection completed. Found ${total_count} physical module(s)."

    # Format to the final JSON data format
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

    log "INFO" "All checks passed. Executing Memory collection..."

    collect_memory_info > "$OUTPUT_FILE"

    log "INFO" "Memory information successfully saved to: ${OUTPUT_FILE}"
}

main "$@"
