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
        ''|Unknown|unknown|None|'N/A'|NA|No|none) printf '' ;;
        *) printf '%s' "$val" ;;
    esac
}

_json_escape() {
    local str="${1-}"
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    printf '%s' "$str"
}

# 提取 PCI 基地址 去掉 0000: 前缀和功能号
_pci_base() {
    local pci="${1#0000:}"
    printf '%s' "${pci%.*}"
}

_pci_slot() {
    local pci="${1#0000:}"
    printf '%s' "$pci"
}

# 通过 lspci 获取型号
_get_model() {
    local pci="$1"
    local info
    info="$(lspci -s "$pci" 2>/dev/null | head -1 || true)"
    if [[ -z "$info" ]]; then
        printf 'Unknown'
        return
    fi
    info="${info#*: }"
    printf '%s' "$info"
}

# 根据型号判断网卡类型
_get_type() {
    local model="$1"
    local lower
    lower="$(printf '%s' "$model" | tr '[:upper:]' '[:lower:]')"
    case "$lower" in
        *ocp*)  printf 'OCP' ;;
        *rndc*) printf 'rNDC' ;;
        *mezz*) printf 'Mezzanine' ;;
        *lom*)  printf 'LOM' ;;
        *)      printf 'PCIe' ;;
    esac
}

# 读取 PCI 设备的序列号
_get_serial() {
    local base="$1"
    local dev file
    for dev in "/sys/bus/pci/devices/0000:${base}".*; do
        file="$dev/serial_number"
        if [[ -f "$file" ]]; then
            cat "$file"
            return
        fi
    done
    printf 'Unknown'
}

# 通过 ethtool 获取当前协商速率
_get_current_speed() {
    local iface="$1"
    local carrier
    carrier="$(cat "/sys/class/net/${iface}/carrier" 2>/dev/null || echo 0)"
    if [[ "$carrier" != '1' ]]; then
        printf 'NotConnected'
        return
    fi
    local speed
    speed="$(ethtool "$iface" 2>/dev/null | awk '/Speed:/{print $2}' || true)"
    if [[ -z "$speed" || "$speed" == 'Unknown!' ]]; then
        printf 'Unknown'
    else
        printf '%s' "$speed"
    fi
}

# 通过 ethtool 获取支持的最高速率
_get_max_speed() {
    local iface="$1"
    local speed
    speed="$(ethtool "$iface" 2>/dev/null | awk '
        /Supported link modes:/ { flag=1; next }
        flag && /^[[:space:]]+[0-9]+base/ { print }
        flag && !/base/ { exit }
    ' | grep -oE '[0-9]+' | sort -nr | head -1 || true)"

    if [[ -z "$speed" ]]; then
        printf 'Unknown'
    else
        printf '%sMb/s' "$speed"
    fi
}

main() {
    command -v jq >/dev/null 2>&1 || {
        printf '{"error":"jq not found"}\n' >&2
        exit 1
    }

    # 按 PCI 基地址聚合端口信息
    declare -A nic_ports
    declare -A nic_model
    declare -A nic_sn
    declare -A nic_type

    local path iface pci base
    local mac current max port_json

    for path in /sys/class/net/*; do
        iface="$(basename "$path")"
        [[ -e "$path/device" ]] || continue

        pci="$(basename "$(readlink -f "$path/device")")"

        # 校验 PCI 地址格式
        if [[ ! "$pci" =~ ^([0-9a-fA-F]{4}:)?[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\.[0-9]$ ]]; then
            continue
        fi

        base="$(_pci_base "$pci")"
        mac="$(cat "/sys/class/net/${iface}/address" 2>/dev/null || echo 'Unknown')"
        current="$(_get_current_speed "$iface")"
        max="$(_get_max_speed "$iface")"

        port_json="{\"slot\":\"$(_pci_slot "$pci")\","
        port_json+="\"interface\":\"$iface\","
        port_json+="\"mac\":\"$mac\","
        port_json+="\"current_speed\":\"$current\","
        port_json+="\"max_speed\":\"$max\"}"

        nic_ports["$base"]+="${port_json}"$'\n'

        if [[ -z "${nic_model[$base]:-}" ]]; then
            nic_model["$base"]="$(_get_model "$base")"
            nic_sn["$base"]="$(_get_serial "$base")"
            nic_type["$base"]="$(_get_type "${nic_model[$base]}")"
        fi
    done

    # 构建网卡JSON
    local nics_json='' first=1 base

    for base in "${!nic_ports[@]}"; do
        # 将换行分隔的端口JSON转为数组
        local ports_arr
        ports_arr="$(printf '%s\n' "${nic_ports[$base]}" | sed '/^$/d' | jq -s '.')"

        [[ "$first" -eq 0 ]] && nics_json+=','
        first=0

        nics_json+="$(jq -c -n \
            --arg slot "$base" \
            --arg model "${nic_model[$base]}" \
            --arg sn "${nic_sn[$base]}" \
            --arg type "${nic_type[$base]}" \
            --argjson ports "$ports_arr" '{
                slot: $slot,
                model: $model,
                sn: $sn,
                type: $type,
                port_count: ($ports | length),
                ports: $ports
            }')"
    done

    jq -c -n --argjson nics "[$nics_json]" '{nics: $nics}'
}

main "$@"
