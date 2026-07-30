#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

# 校验外部依赖
check_deps() {
    command -v jq > /dev/null 2>&1 || {
        echo "ERROR: jq is required." >&2
        exit 1
    }
}

# 格式化显存大小 (24576 MiB -> 24GB, 8192 MiB -> 8GB)
format_vram() {
    local mb="${1:-0}"
    if ((mb >= 1024)); then
        echo "$(((mb + 512) / 1024))GB"
    elif ((mb > 0)); then
        echo "${mb}MB"
    else
        echo ""
    fi
}

# 采集 NVIDIA 显卡信息
collect_nvidia() {
    command -v nvidia-smi > /dev/null 2>&1 || return 1

    local query_fields="index,gpu_name,uuid,pci.bus_id,vbios_version,serial,memory.total,driver_version"
    local raw
    raw="$(nvidia-smi --query-gpu="$query_fields" --format=csv,noheader,nounits 2> /dev/null)" || return 1
    [[ -n "$raw" ]] || return 1

    local index name uuid bus vbios serial vram driver
    local json_items=()

    while IFS=',' read -r index name uuid bus vbios serial vram driver; do
        # 清理多余空格
        index="${index// /}"
        name="$(echo "$name" | xargs)"
        uuid="${uuid// /}"
        bus="${bus// /}"
        vbios="${vbios// /}"
        serial="$(echo "$serial" | xargs)"
        vram="${vram// /}"
        driver="${driver// /}"

        # 处理 N/A 占位符
        [[ "$serial" =~ ^(\[N/A\]|N/A)$ ]] && serial=""

        json_items+=("$(jq -nc \
            --arg vendor "NVIDIA" \
            --arg index "$index" \
            --arg name "$name" \
            --arg uuid "$uuid" \
            --arg bus "$bus" \
            --arg vbios "$vbios" \
            --arg serial "$serial" \
            --arg memory "$(format_vram "$vram")" \
            --arg driver "$driver" \
            '{vendor: $vendor, index: $index, name: $name, uuid: $uuid, pci_bus_id: $bus, vbios_version: $vbios, serial: $serial, memory: $memory, driver_version: $driver}')")
    done <<< "$raw"

    printf '%s\n' "${json_items[@]}" | jq -s '.'
}

# 采集 AMD 显卡信息 (rocm-smi)
collect_amd() {
    command -v rocm-smi > /dev/null 2>&1 || return 1

    local raw
    raw="$(rocm-smi --showid --showproductname --showbus --showdriverversion --json 2> /dev/null)" || return 1
    [[ -n "$raw" && "$raw" != "{}" ]] || return 1

    # 将 rocm-smi 的字典对象归一化为通用数组结构
    jq '[to_entries[] | {
        vendor: "AMD",
        index: .key,
        name: .value["Card series"] // .value["Product Name"] // "",
        uuid: .value["Unique ID"] // "",
        pci_bus_id: .value["PCI Bus"] // "",
        vbios_version: .value["VBIOS version"] // "",
        serial: .value["Serial Number"] // "",
        memory: "",
        driver_version: .value["Driver version"] // ""
    }]' <<< "$raw"
}

# Fallback Pipeline
main() {
    check_deps

    collect_nvidia && exit 0
    collect_amd && exit 0

    # 无设备时的默认保底输出
    echo "[]"
}

main "$@"
