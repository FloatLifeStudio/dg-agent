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

    local dmi_raw
    dmi_raw="$(dmidecode -t 39 2>/dev/null || true)"

    if [[ -z "$dmi_raw" ]] || ! grep -q 'System Power Supply' <<< "$dmi_raw"; then
        printf '{"supplies":[]}\n'
        return 0
    fi

    local items='' first=1
    local vendor model serial location max_power status ptype
    local in_record=false

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="$(_trim "$line")"

        if [[ "$line" == 'System Power Supply' ]]; then
            # 输出上一个记录
            if [[ "$in_record" == true ]]; then
                [[ "$first" -eq 0 ]] && items+=','
                first=0
                items+="{\"vendor\":\"$(_json_escape "${vendor:-}")\","
                items+="\"model\":\"$(_json_escape "${model:-}")\","
                items+="\"serial\":\"$(_json_escape "${serial:-}")\","
                items+="\"location\":\"$(_json_escape "${location:-}")\","
                items+="\"max_power\":\"$(_json_escape "${max_power:-}")\","
                items+="\"status\":\"$(_json_escape "${status:-}")\","
                items+="\"type\":\"$(_json_escape "${ptype:-}")\"}"
            fi
            in_record=true
            vendor=''; model=''; serial=''; location=''; max_power=''; status=''; ptype=''
            continue
        fi

        [[ "$in_record" != true ]] && continue
        [[ -z "$line" ]] && continue

        case "$line" in
            Manufacturer:*)    vendor="$(_normalize "${line#Manufacturer:}")" ;;
            'Model Part Number:'*|'Part Number:'*)
                               model="$(_normalize "${line#*:}")" ;;
            'Serial Number:'*) serial="$(_normalize "${line#Serial Number:}")" ;;
            Location:*)        location="$(_normalize "${line#Location:}")" ;;
            'Max Power Capacity:'*)
                               max_power="$(_normalize "${line#Max Power Capacity:}")" ;;
            Status:*)          status="$(_normalize "${line#Status:}")" ;;
            Type:*)            ptype="$(_normalize "${line#Type:}")" ;;
        esac
    done <<< "$dmi_raw"

    # 最后一个记录
    if [[ "$in_record" == true ]]; then
        [[ "$first" -eq 0 ]] && items+=','
        items+="{\"vendor\":\"$(_json_escape "${vendor:-}")\","
        items+="\"model\":\"$(_json_escape "${model:-}")\","
        items+="\"serial\":\"$(_json_escape "${serial:-}")\","
        items+="\"location\":\"$(_json_escape "${location:-}")\","
        items+="\"max_power\":\"$(_json_escape "${max_power:-}")\","
        items+="\"status\":\"$(_json_escape "${status:-}")\","
        items+="\"type\":\"$(_json_escape "${ptype:-}")\"}"
    fi

    printf '{"supplies":[%s]}\n' "$items"
}

collect
