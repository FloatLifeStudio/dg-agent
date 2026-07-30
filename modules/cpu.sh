#!/usr/bin/env bash

set -euo pipefail

readonly PROGRAM_NAME="${0##*/}"
readonly VERSION="1.0.0"

DEFAULT_LOG_FILE="./test.log"
DEFAULT_OUTPUT_FILE="./output_cpu.json"

LOG_FILE="$DEFAULT_LOG_FILE"
OUTPUT_FILE="$DEFAULT_OUTPUT_FILE"
VERBOSE=0

readonly REQUIRED_COMMANDS=(
    curl
    wget
    jq
)

readonly LOG_FD=3

usage() {
    cat << EOF
Usage: ${PROGRAM_NAME} [OPTION]...

Check required system dependencies, collect CPU assets, and save JSON output.

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

collect_cpu_info() {
    local method_used=""
    local model_name=""
    local vendor_id=""
    local architecture=""
    local sockets="1"
    local cores_per_socket=""
    local threads_per_core=""
    local total_cores=""
    local total_threads=""
    local max_mhz=""
    local cache_l3=""
    local -a flags=()

    # Method 1: lscpu method (priority, most complete and standardized information)
    if command -v lscpu >/dev/null 2>&1; then
        log "INFO" "Attempting CPU collection via lscpu..."
        local lscpu_out
        lscpu_out="$(lscpu 2>/dev/null || true)"

        if [[ -n "$lscpu_out" ]]; then
            model_name="$(echo "$lscpu_out" | grep -iE '^Model name:' | sed 's/Model name:[[:space:]]*//' | xargs || true)"
            vendor_id="$(echo "$lscpu_out" | grep -iE '^Vendor ID:' | sed 's/Vendor ID:[[:space:]]*//' | xargs || true)"
            architecture="$(echo "$lscpu_out" | grep -iE '^Architecture:' | sed 's/Architecture:[[:space:]]*//' | xargs || true)"
            sockets="$(echo "$lscpu_out" | grep -iE '^Socket\(s\):' | sed 's/Socket(s):[[:space:]]*//' | xargs || true)"
            cores_per_socket="$(echo "$lscpu_out" | grep -iE '^Core\(s\) per socket:' | sed 's/Core(s) per socket:[[:space:]]*//' | xargs || true)"
            threads_per_core="$(echo "$lscpu_out" | grep -iE '^Thread\(s\) per core:' | sed 's/Thread(s) per core:[[:space:]]*//' | xargs || true)"
            total_threads="$(echo "$lscpu_out" | grep -iE '^CPU\(s\):' | sed 's/CPU(s):[[:space:]]*//' | xargs || true)"
            max_mhz="$(echo "$lscpu_out" | grep -iE '^CPU max MHz:' | sed 's/CPU max MHz:[[:space:]]*//' | xargs || true)"
            cache_l3="$(echo "$lscpu_out" | grep -iE '^L3 cache:' | sed 's/L3 cache:[[:space:]]*//' | xargs || true)"

            method_used="lscpu"
        fi
    fi

    # Method 2:/doc/cpuinfo method (downgrade scheme, suitable for general Linux)
    if [[ -z "$model_name" ]] && [[ -r /proc/cpuinfo ]]; then
        log "INFO" "Attempting CPU collection via /proc/cpuinfo..."
        architecture="$(uname -m 2>/dev/null || true)"
        model_name="$(grep -m1 -iE '^model name' /proc/cpuinfo | awk -F: '{print $2}' | xargs || true)"
        vendor_id="$(grep -m1 -iE '^vendor_id' /proc/cpuinfo | awk -F: '{print $2}' | xargs || true)"
        total_threads="$(grep -c -iE '^processor' /proc/cpuinfo || true)"
        
        local physical_ids
        physical_ids="$(grep -iE '^physical id' /proc/cpuinfo | sort -u | wc -l || true)"
        [[ "$physical_ids" -gt 0 ]] && sockets="$physical_ids"

        local cpu_cores
        cpu_cores="$(grep -m1 -iE '^cpu cores' /proc/cpuinfo | awk -F: '{print $2}' | xargs || true)"
        [[ -n "$cpu_cores" ]] && cores_per_socket="$cpu_cores"

        method_used="/proc/cpuinfo"
    fi

    # Method 3: sysfs/uname/dmidecode method
    if [[ -z "$model_name" ]]; then
        log "INFO" "Attempting CPU collection via sysfs and fallback tools..."
        architecture="$(uname -m 2>/dev/null || true)"
        total_threads="$(nproc 2>/dev/null || echo "1")"
        
        if command -v dmidecode >/dev/null 2>&1; then
            model_name="$(dmidecode -t processor 2>/dev/null | grep -m1 'Version:' | awk -F: '{print $2}' | xargs || true)"
            vendor_id="$(dmidecode -t processor 2>/dev/null | grep -m1 'Manufacturer:' | awk -F: '{print $2}' | xargs || true)"
        fi

        [[ -z "$model_name" ]] && model_name="Unknown CPU (${architecture})"
        method_used="fallback"
    fi

    # Complete the calculation of the total number of logical cores/physical cores
    if [[ -n "$sockets" && -n "$cores_per_socket" ]]; then
        total_cores=$(( sockets * cores_per_socket ))
    else
        total_cores="${total_threads:-1}"
    fi

    log "INFO" "Successfully collected CPU info using [${method_used}]."

    # Constructing standard JSON objects using jq
    jq -nc         --arg model "$model_name"         --arg vendor "$vendor_id"         --arg arch "$architecture"         --arg sockets "${sockets:-1}"         --arg cores_per_socket "${cores_per_socket:-1}"         --arg threads_per_core "${threads_per_core:-1}"         --arg total_cores "$total_cores"         --arg total_threads "${total_threads:-1}"         --arg max_mhz "$max_mhz"         --arg l3_cache "$cache_l3"         '{
            model_name: $model,
            vendor_id: $vendor,
            architecture: $arch,
            sockets: ($sockets | tonumber),
            cores_per_socket: ($cores_per_socket | tonumber),
            threads_per_core: ($threads_per_core | tonumber),
            total_cores: ($total_cores | tonumber),
            total_threads: ($total_threads | tonumber),
            max_mhz: (if $max_mhz != "" then ($max_mhz | tonumber) else null end),
            l3_cache: $l3_cache
        }'
}

main() {
    parse_options "$@"

    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$(dirname "$OUTPUT_FILE")"

    eval "exec ${LOG_FD}>>"\$LOG_FILE""

    log "INFO" "Starting dependency checks..."

    if ! check_dependencies; then
        log "ERROR" "Dependency check failed."
        exit 1
    fi

    log "INFO" "All required dependencies satisfied. Executing CPU collection..."

    collect_cpu_info > "$OUTPUT_FILE"

    log "INFO" "CPU information successfully saved to: ${OUTPUT_FILE}"
}

main "$@"
