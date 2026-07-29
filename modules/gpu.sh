#!/usr/bin/env bash

set -euo pipefail

readonly PROGRAM_NAME="${0##*/}"
readonly VERSION="1.0.0"

DEFAULT_LOG_FILE="./test.log"
DEFAULT_OUTPUT_FILE="./output.json"

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

Check required system dependencies, collect GPU assets, and save JSON output.

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


collect_gpu_info() {
    local method_used=""
    local driver_ver=""
    local -a raw_json_items=()

    # Method 1: nvidia smi method (priority, most complete information)
    if command -v nvidia-smi > /dev/null 2>&1; then
        log "INFO" "Attempting GPU collection via nvidia-smi..."
        driver_ver="$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2> /dev/null | head -n1 | xargs || true)"

        local line index name uuid bus vbios serial memory
        while IFS=',' read -r index name uuid bus vbios serial memory; do
            [[ -z "$index" ]] && continue

            index="$(echo "$index" | xargs)"
            name="$(echo "$name" | xargs)"
            uuid="$(echo "$uuid" | xargs)"
            bus="$(echo "$bus" | xargs)"
            vbios="$(echo "$vbios" | xargs)"
            serial="$(echo "$serial" | xargs)"
            memory="$(echo "$memory" | xargs)"

            [[ "$serial" == "[N/A]" || "$serial" == "N/A" ]] && serial=""

            raw_json_items+=("$(jq -nc \
                --arg index "$index" \
                --arg name "$name" \
                --arg uuid "$uuid" \
                --arg bus "$bus" \
                --arg vbios "$vbios" \
                --arg serial "$serial" \
                --arg memory "${memory} MiB" \
                --arg driver "$driver_ver" \
                '{index: $index, name: $name, uuid: $uuid, pci_bus_id: $bus, vbios_version: $vbios, serial: $serial, memory: $memory, driver_version: $driver}')")
        done < <(nvidia-smi --query-gpu=index,gpu_name,uuid,pci.bus_id,vbios_version,serial,memory.total --format=csv,noheader,nounits 2> /dev/null || true)

        if [[ ${#raw_json_items[@]} -gt 0 ]]; then
            method_used="nvidia-smi"
        fi
    fi

    # Method 2:/sys/class/drm sysfs method (when Nvidia smi is unavailable or no device is found)
    if [[ ${#raw_json_items[@]} -eq 0 ]]; then
        log "INFO" "Attempting GPU collection via /sys/class/drm sysfs..."
        local card vendor_id device_id
        for card in /sys/class/drm/card*; do
            [[ -d "$card" ]] || continue
            [[ -r "$card/device/vendor" ]] || continue

            vendor_id="$(tr -d '\0' < "$card/device/vendor" 2> /dev/null | xargs || true)"
            device_id="$(tr -d '\0' < "$card/device/device" 2> /dev/null | xargs || true)"

            if [[ -n "$vendor_id" && -n "$device_id" ]]; then
                raw_json_items+=("$(jq -nc \
                    --arg vendor "$vendor_id" \
                    --arg device "$device_id" \
                    '{vendor_id: $vendor, device_id: $device, brand: ("vendor:" + $vendor), model: ("device:" + $device)}')")
            fi
        done

        if [[ ${#raw_json_items[@]} -gt 0 ]]; then
            method_used="sysfs"
        fi
    fi

    # Method 3: lspci method
    if [[ ${#raw_json_items[@]} -eq 0 ]] && command -v lspci > /dev/null 2>&1; then
        log "INFO" "Attempting GPU collection via lspci..."
        local line
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            raw_json_items+=("$(jq -nc --arg detail "$line" '{brand: "PCI Device", model: $detail}')")
        done < <(lspci 2> /dev/null | grep -iE 'vga|3d|nvidia' || true)

        if [[ ${#raw_json_items[@]} -gt 0 ]]; then
            method_used="lspci"
        fi
    fi

    # Assemble all collected nodes into a standard JSON array and output it to UWP
    if [[ ${#raw_json_items[@]} -gt 0 ]]; then
        log "INFO" "Successfully collected GPU info using [${method_used}]."
        printf '%s\n' "${raw_json_items[@]}" | jq -s '.'
    else
        log "WARN" "No GPU devices found on this system."
        echo "[]"
    fi
}

main() {
    parse_options "$@"

    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$(dirname "$OUTPUT_FILE")"

    eval "exec ${LOG_FD}>>\"\$LOG_FILE\""

    log "INFO" "Starting dependency checks..."

    if ! check_dependencies; then
        log "ERROR" "Dependency check failed."
        exit 1
    fi

    log "INFO" "All required dependencies satisfied. Executing GPU collection..."

    # Write JSON results to the specified target file
    collect_gpu_info > "$OUTPUT_FILE"

    log "INFO" "GPU information successfully saved to: ${OUTPUT_FILE}"
}

main "$@"
