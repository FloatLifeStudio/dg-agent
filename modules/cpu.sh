#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

# 权限检测
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    printf '{"error":"root required (use sudo)"}\n' >&2
    exit 5
fi

_trim() {
    local str="${1-}"
    str="${str#"${str%%[![:space:]]*}"}"
    str="${str%"${str##*[![:space:]]}"}"
    printf '%s' "$str"
}

_json_escape() {
    local str="${1-}"
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    printf '%s' "$str"
}

collect() {
    command -v lscpu >/dev/null 2>&1 || {
        printf '{"error":"lscpu not found"}\n' >&2
        exit 1
    }

    local arch='' vendor='' model='' sockets=0 cores_per_socket=0 total_threads=0

    # 解析 lscpu 输出
    while IFS=: read -r key value; do
        [[ -z "$key" ]] && continue
        key="$(_trim "$key")"
        value="$(_trim "$value")"

        case "$key" in
            Architecture)     arch="$value" ;;
            'Vendor ID')      vendor="$value" ;;
            'Model name')     model="$value" ;;
            'Socket(s)')      sockets="$value" ;;
            'Core(s) per socket') cores_per_socket="$value" ;;
            'CPU(s)')         total_threads="$value" ;;
        esac
    done < <(lscpu)

    [[ -n "$model" ]] || { printf '{"error":"cpu info unavailable"}\n' >&2; exit 1; }

    local total_cores=$((sockets * cores_per_socket))

    printf \
        '{"vendor":"%s","model":"%s","arch":"%s","cores":%d,"threads":%d,"socket_count":%d}\n' \
        "$(_json_escape "$vendor")" \
        "$(_json_escape "$model")" \
        "$(_json_escape "$arch")" \
        "$total_cores" \
        "$total_threads" \
        "$sockets"
}

collect
