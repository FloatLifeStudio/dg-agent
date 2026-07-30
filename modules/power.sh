#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

# 检查命令是否存在
check_command() {
    command -v "$1" > /dev/null 2>&1
}

# 去除字符串首尾空白
trim() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

# 全局变量保存采集与清洗后的数据
DMI_POWER_OUT=""
CLEANED_POWER_DATA=""

# 采集电源模块信息
collect_power() {
    DMI_POWER_OUT="$(dmidecode -t 39 2> /dev/null || true)"
}

# 校验采集数据是否有效
validate_power() {
    [[ -n "$DMI_POWER_OUT" ]] || return 1
}

# 清洗电源模块信息提取标准字段
clean_power_data() {
    if grep -q "System Power Supply" <<< "$DMI_POWER_OUT"; then
        CLEANED_POWER_DATA="$(
            awk '
                BEGIN { RS = "System Power Supply"; FS = "\n" }
                /Location:/ || /Manufacturer:/ || /Power Capacity:/ {
                    vendor = ""; model = ""; serial = ""; location = ""; max_power = ""; status = ""; type = ""

                    for (i = 1; i <= NF; i++) {
                        line = $i
                        sub(/^[ \t]+/, "", line)
                        sub(/[ \t]+$/, "", line)

                        if (line ~ /^Manufacturer:/) {
                            split(line, arr, ":")
                            vendor = arr[2]
                        } else if (line ~ /^Model Part Number:/ || line ~ /^Part Number:/) {
                            split(line, arr, ":")
                            model = arr[2]
                        } else if (line ~ /^Serial Number:/) {
                            split(line, arr, ":")
                            serial = arr[2]
                        } else if (line ~ /^Location:/) {
                            split(line, arr, ":")
                            location = arr[2]
                        } else if (line ~ /^Max Power Capacity:/) {
                            split(line, arr, ":")
                            max_power = arr[2]
                        } else if (line ~ /^Status:/) {
                            split(line, arr, ":")
                            status = arr[2]
                        } else if (line ~ /^Type:/) {
                            split(line, arr, ":")
                            type = arr[2]
                        }
                    }

                    gsub(/^[ \t]+|[ \t]+$/, "", vendor)
                    gsub(/^[ \t]+|[ \t]+$/, "", model)
                    gsub(/^[ \t]+|[ \t]+$/, "", serial)
                    gsub(/^[ \t]+|[ \t]+$/, "", location)
                    gsub(/^[ \t]+|[ \t]+$/, "", max_power)
                    gsub(/^[ \t]+|[ \t]+$/, "", status)
                    gsub(/^[ \t]+|[ \t]+$/, "", type)

                    if (vendor ~ /^(NO|Unknown|[Nn]\/[Aa])/) vendor = ""
                    if (model ~ /^(NO|Unknown|[Nn]\/[Aa])/) model = ""
                    if (serial ~ /^(NO|Unknown|[Nn]\/[Aa])/) serial = ""
                    if (location ~ /^(NO|Unknown|[Nn]\/[Aa])/) location = ""
                    if (max_power ~ /^(NO|Unknown|[Nn]\/[Aa])/) max_power = ""
                    if (status ~ /^(NO|Unknown|[Nn]\/[Aa])/) status = ""
                    if (type ~ /^(NO|Unknown|[Nn]\/[Aa])/) type = ""

                    print vendor "\t" model "\t" serial "\t" location "\t" max_power "\t" status "\t" type
                }
            ' <<< "$DMI_POWER_OUT"
        )"
    fi
}

# 格式化输出 JSON 数据
output_json() {
    jq -Rn '
    [
        inputs
        | select(length > 0)
        | split("\t") as $fields
        | {
            vendor: $fields[0],
            model: $fields[1],
            serial: $fields[2],
            location: $fields[3],
            max_power: $fields[4],
            status: $fields[5],
            type: $fields[6]
        }
    ] as $supplies
    | {
        power_supply_count: ($supplies | length),
        power_supplies: $supplies
    }' <<< "$CLEANED_POWER_DATA"
}

# 主程序逻辑入口
main() {
    check_command dmidecode || {
        echo "ERROR missing command dmidecode" >&2
        exit 1
    }

    check_command jq || {
        echo "ERROR missing command jq" >&2
        exit 1
    }

    collect_power

    validate_power || {
        echo "ERROR power supply information unavailable" >&2
        exit 1
    }

    clean_power_data

    output_json
}

main "$@"
