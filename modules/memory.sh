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
        ''|Unknown|unknown|None|'N/A'|NA|'[N/A]'|No|none|'Not Specified') printf '' ;;
        *) printf '%s' "$val" ;;
    esac
}

_json_escape() {
    local str="${1-}"
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    printf '%s' "$str"
}

collect() {
    command -v dmidecode >/dev/null 2>&1 || {
        printf '{"error":"dmidecode not found"}\n' >&2
        exit 1
    }

    local dmi_raw meminfo_raw
    dmi_raw="$(dmidecode -t memory 2>/dev/null || true)"
    meminfo_raw="$(cat /proc/meminfo 2>/dev/null || true)"

    [[ -n "$meminfo_raw" ]] || {
        printf '{"error":"meminfo unavailable"}\n' >&2
        exit 1
    }

    # 总大小和可用大小
    local total_kb avail_kb
    total_kb="$(grep -iE '^MemTotal:' <<< "$meminfo_raw" | awk '{print $2}' || echo 0)"
    avail_kb="$(grep -iE '^MemAvailable:' <<< "$meminfo_raw" | awk '{print $2}' || echo 0)"

    # 解析 DIMM 模块
    local modules_json=''
    local first=1

    if grep -q 'Memory Device' <<< "$dmi_raw"; then
        local vendor model type size speed configured_speed serial
        local IFS_BAK="$IFS"
        IFS=''
        local record in_record=false

        while IFS= read -r line || [[ -n "$line" ]]; do
            line="$(_trim "$line")"

            if [[ "$line" == 'Memory Device' ]]; then
                # 输出上一个记录
                if [[ "$in_record" == true && -n "${size:-}" && "$size" =~ [0-9] ]]; then
                    [[ "$first" -eq 0 ]] && modules_json+=','
                    first=0

                    modules_json+="{\"vendor\":\"$(_json_escape "${vendor:-}")\","
                    modules_json+="\"model\":\"$(_json_escape "${model:-}")\","
                    modules_json+="\"type\":\"$(_json_escape "${type:-DRAM}")\","
                    modules_json+="\"capacity\":\"$(_json_escape "${size:-}")\","
                    modules_json+="\"speed\":\"$(_json_escape "${speed:-}")\","
                    modules_json+="\"serial\":\"$(_json_escape "${serial:-}")\"}"

                fi
                in_record=true
                vendor=''; model=''; type=''; size=''; speed=''; configured_speed=''; serial=''
                continue
            fi

            [[ "$in_record" != true ]] && continue
            [[ -z "$line" ]] && continue

            case "$line" in
                Size:*)
                    size="$(_trim "${line#Size:}")"
                    size="${size// /}"
                    ;;
                Manufacturer:*)
                    vendor="$(_normalize "${line#Manufacturer:}")"
                    ;;
                'Part Number:'*)
                    model="$(_normalize "${line#Part Number:}")"
                    ;;
                Type:*)
                    type="$(_normalize "${line#Type:}")"
                    [[ -z "$type" || "$type" == 'Unknown' ]] && type='DRAM'
                    ;;
                Speed:*)
                    speed="$(_trim "${line#Speed:}")"
                    ;;
                'Configured Memory Speed:'*|'Configured Clock Speed:'*)
                    configured_speed="$(_trim "${line#*:}")"
                    ;;
                'Serial Number:'*)
                    serial="$(_normalize "${line#Serial Number:}")"
                    ;;
            esac
        done <<< "$dmi_raw"

        # 最后一个记录
        if [[ "$in_record" == true && -n "${size:-}" && "$size" =~ [0-9] ]]; then
            [[ "$first" -eq 0 ]] && modules_json+=','
            modules_json+="{\"vendor\":\"$(_json_escape "${vendor:-}")\","
            modules_json+="\"model\":\"$(_json_escape "${model:-}")\","
            modules_json+="\"type\":\"$(_json_escape "${type:-DRAM}")\","
            modules_json+="\"capacity\":\"$(_json_escape "${size:-}")\","
            modules_json+="\"speed\":\"$(_json_escape "${speed:-}")\","
            modules_json+="\"serial\":\"$(_json_escape "${serial:-}")\"}"
        fi

        IFS="$IFS_BAK"
    fi

    printf \
        '{"total_bytes":%d,"available_bytes":%d,"modules":[%s]}\n' \
        "$((total_kb * 1024))" \
        "$((avail_kb * 1024))" \
        "$modules_json"
}

collect
