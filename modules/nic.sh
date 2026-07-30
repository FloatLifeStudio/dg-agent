#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

declare -A NIC_PORTS
declare -A NIC_MODEL
declare -A NIC_SN
declare -A NIC_TYPE

get_pci_base() {
    local pci="$1"

    pci="${pci#0000:}"

    echo "${pci%.*}"
}

get_pci_slot() {
    local pci="$1"

    echo "${pci#0000:}"
}

get_model() {
    local pci="$1"

    local info

    info=$(lspci -s "$pci" 2> /dev/null | head -1 || true)

    if [[ -z "$info" ]]; then
        echo "Unknown"
        return
    fi

    echo "$info" | sed -E 's/^.*: //'
}

get_type() {
    local model="$1"

    local lower

    lower=$(echo "$model" | tr '[:upper:]' '[:lower:]')

    if [[ "$lower" =~ ocp ]]; then
        echo "OCP"
    elif [[ "$lower" =~ rndc ]]; then
        echo "rNDC"
    elif [[ "$lower" =~ mezz ]]; then
        echo "Mezzanine"
    elif [[ "$lower" =~ lom ]]; then
        echo "LOM"
    else
        echo "PCIe"
    fi
}

get_serial() {
    local base="$1"

    local dev
    local file

    for dev in /sys/bus/pci/devices/0000:${base}.*; do

        file="$dev/serial_number"

        if [[ -f "$file" ]]; then
            cat "$file"
            return
        fi

    done

    echo "Unknown"
}

get_current_speed() {
    local iface="$1"

    local carrier

    carrier=$(cat "/sys/class/net/${iface}/carrier" 2> /dev/null || echo 0)

    if [[ "$carrier" != "1" ]]; then
        echo "NotConnected"
        return
    fi

    local speed

    speed=$(ethtool "$iface" 2> /dev/null \
        | awk '/Speed:/{
            print $2
        }' || true)

    if [[ -z "$speed" || "$speed" == "Unknown!" ]]; then
        echo "Unknown"
    else
        echo "$speed"
    fi
}

get_max_speed() {
    local iface="$1"

    local speed

    speed=$(ethtool "$iface" 2> /dev/null \
        | awk '
        /Supported link modes:/ {
            flag=1
            next
        }

        flag && /^[[:space:]]+[0-9]+base/ {
            print
        }

        flag && !/base/ {
            exit
        }
        ' \
        | grep -oE '[0-9]+' \
        | sort -nr \
        | head -1 || true)

    if [[ -z "$speed" ]]; then
        echo "Unknown"
    else
        echo "${speed}Mb/s"
    fi
}

get_port_json() {
    local iface="$1"
    local pci="$2"

    local mac
    local current
    local max

    mac=$(cat "/sys/class/net/${iface}/address" 2> /dev/null || echo "Unknown")

    current=$(get_current_speed "$iface")

    max=$(get_max_speed "$iface")

    jq -n \
        --arg slot "$(get_pci_slot "$pci")" \
        --arg interface "$iface" \
        --arg mac "$mac" \
        --arg current "$current" \
        --arg max "$max" \
        '
        {
            slot:$slot,
            interface:$interface,
            mac:$mac,
            current_speed:$current,
            max_speed:$max
        }
        '
}

collect() {
    local path
    local iface
    local pci
    local base

    for path in /sys/class/net/*; do

        iface=$(basename "$path")

        [[ -e "$path/device" ]] || continue

        pci=$(basename "$(readlink -f "$path/device")")

        if [[ ! "$pci" =~ ^([0-9a-fA-F]{4}:)?[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\.[0-9]$ ]]; then
            continue
        fi

        base=$(get_pci_base "$pci")

        NIC_PORTS["$base"]+=$(get_port_json "$iface" "$pci")$'\n'

        if [[ -z "${NIC_MODEL[$base]:-}" ]]; then

            NIC_MODEL["$base"]=$(get_model "$base")

            NIC_SN["$base"]=$(get_serial "$base")

            NIC_TYPE["$base"]=$(get_type "${NIC_MODEL[$base]}")

        fi

    done
}

build_json() {
    local tmp

    tmp=$(mktemp)

    local base

    for base in "${!NIC_PORTS[@]}"; do

        echo "${NIC_PORTS[$base]}" \
            | jq -s \
                --arg slot "$base" \
                --arg model "${NIC_MODEL[$base]}" \
                --arg sn "${NIC_SN[$base]}" \
                --arg type "${NIC_TYPE[$base]}" \
                '
            {
                slot:$slot,
                name:$model,
                model:$model,
                sn:$sn,
                type:$type,
                port_count:length,
                ports:.
            }
            ' >> "$tmp"

    done

    jq -s '
    {
        nic_count:length,
        nics:.
    }
    ' "$tmp"

    rm -f "$tmp"
}

main() {

    command -v jq > /dev/null || {
        echo '{"error":"jq not installed"}'
        exit 1
    }

    collect

    build_json
}

main "$@"
