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

_normalize() {
    local val
    val="$(_trim "${1-}")"
    case "$val" in
        '' | Unknown | unknown | None | 'N/A' | NA | No | none) printf '' ;;
        *) printf '%s' "$val" ;;
    esac
}

_json_escape() {
    local str="${1-}"
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    printf '%s' "$str"
}

# 根据rota和tran判断磁盘类型
_disk_type() {
    local rota="${1:-}" tran="${2:-}"
    if [[ "$tran" == 'nvme' ]]; then
        printf 'NVMe SSD'
    elif [[ "$rota" == '0' ]]; then
        printf 'SSD'
    elif [[ "$rota" == '1' ]]; then
        printf 'HDD'
    else
        printf 'DISK'
    fi
}

collect() {
    command -v lsblk > /dev/null 2>&1 || {
        printf '{"error":"lsblk not found"}\n' >&2
        exit 1
    }

    command -v jq > /dev/null 2>&1 || {
        printf '{"error":"jq not found"}\n' >&2
        exit 1
    }

    local lsblk_json disks_json
    lsblk_json="$(lsblk -d -b -J -o NAME,VENDOR,MODEL,SIZE,ROTA,TRAN,SERIAL,TYPE 2> /dev/null || true)"

    [[ -n "$lsblk_json" ]] || {
        printf '{"error":"lsblk failed"}\n' >&2
        exit 1
    }

    disks_json="$(jq -c '
        [.blockdevices[]? | select(.type == "disk")] as $disks
        | [
            $disks[] | {
                vendor: ((.vendor // "") | gsub("^\\s+|\\s+$"; "")),
                model: ((.model // "") | gsub("^\\s+|\\s+$"; "")),
                size_bytes: (.size // 0),
                type: (if .tran == "nvme" then "NVMe SSD"
                       elif .rota == "0" then "SSD"
                       elif .rota == "1" then "HDD"
                       else "DISK" end),
                serial: ((.serial // "") | gsub("^\\s+|\\s+$"; ""))
            }
        ]' <<< "$lsblk_json")"

    jq -c --argjson disks "$disks_json" '{disks: $disks}' <<< '{}'
}

collect
