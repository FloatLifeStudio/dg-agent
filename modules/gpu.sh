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
        ''|Unknown|unknown|None|'N/A'|NA|'[N/A]'|No|none) printf '' ;;
        *) printf '%s' "$val" ;;
    esac
}

_json_escape() {
    local str="${1-}"
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    printf '%s' "$str"
}

# MiB 转 GB 格式化
_format_vram() {
    local mb="${1:-0}"
    if (( mb >= 1024 )); then
        printf '%dGB' "$(((mb + 512) / 1024))"
    elif (( mb > 0 )); then
        printf '%dMB' "$mb"
    else
        printf ''
    fi
}

# 采集 NVIDIA 显卡
_collect_nvidia() {
    command -v nvidia-smi >/dev/null 2>&1 || return 1

    local raw
    raw="$(nvidia-smi --query-gpu=index,gpu_name,uuid,pci.bus_id,vbios_version,serial,memory.total,driver_version \
        --format=csv,noheader,nounits 2>/dev/null)" || return 1

    [[ -n "$raw" ]] || return 1

    local index name uuid bus vbios serial vram driver
    local items='' first=1

    while IFS=',' read -r index name uuid bus vbios serial vram driver; do
        index="$(_trim "$index")"
        name="$(_trim "$name")"
        uuid="$(_trim "$uuid")"
        bus="$(_trim "$bus")"
        vbios="$(_trim "$vbios")"
        serial="$(_normalize "$serial")"
        vram="$(_trim "$vram")"
        driver="$(_trim "$driver")"

        [[ "$first" -eq 0 ]] && items+=','
        first=0

        items+="{\"vendor\":\"NVIDIA\",\"index\":\"$index\","
        items+="\"name\":\"$(_json_escape "$name")\","
        items+="\"uuid\":\"$uuid\","
        items+="\"pci_bus_id\":\"$bus\","
        items+="\"vbios\":\"$vbios\","
        items+="\"serial\":\"$(_json_escape "$serial")\","
        items+="\"memory\":\"$(_format_vram "$vram")\","
        items+="\"driver\":\"$driver\"}"

    done <<< "$raw"

    printf '[%s]\n' "$items"
    return 0
}

# 采集 AMD 显卡
_collect_amd() {
    command -v rocm-smi >/dev/null 2>&1 || return 1

    command -v jq >/dev/null 2>&1 || return 1

    local raw
    raw="$(rocm-smi --showid --showproductname --showbus --showdriverversion --json 2>/dev/null)" || return 1

    [[ -n "$raw" && "$raw" != '{}' ]] || return 1

    jq -c '[to_entries[] | {
        vendor: "AMD",
        index: .key,
        name: (.value["Card series"] // .value["Product Name"] // ""),
        uuid: (.value["Unique ID"] // ""),
        pci_bus_id: (.value["PCI Bus"] // ""),
        vbios: (.value["VBIOS version"] // ""),
        serial: (.value["Serial Number"] // ""),
        memory: "",
        driver: (.value["Driver version"] // "")
    }]' <<< "$raw"
}

main() {
    _collect_nvidia && exit 0
    _collect_amd   && exit 0

    printf '[]\n'
}

main "$@"
