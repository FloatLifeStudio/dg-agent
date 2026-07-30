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
DMI_MEM_OUT=""
MEMINFO_OUT=""
CLEANED_MEM_DATA=""

# 采集内存信息
collect_memory() {
    DMI_MEM_OUT="$(dmidecode -t memory 2> /dev/null || true)"
    if [[ -r /proc/meminfo ]]; then
        MEMINFO_OUT="$(cat /proc/meminfo)"
    fi
}

# 校验采集数据是否有效
validate_memory() {
    [[ -n "$MEMINFO_OUT" ]] || return 1
}

# 清洗内存信息提取标准字段
clean_memory_data() {
    if grep -q "Memory Device" <<< "$DMI_MEM_OUT"; then
        CLEANED_MEM_DATA="$(
            awk '
                BEGIN { RS = "Memory Device"; FS = "\n" }
                /Size: [0-9]+/ {
                    size = ""; vendor = ""; model = ""; type = ""; speed = ""; configured_speed = ""; serial = ""
                    
                    for (i = 1; i <= NF; i++) {
                        line = $i
                        sub(/^[ \t]+/, "", line)
                        sub(/[ \t]+$/, "", line)
                        
                        if (line ~ /^Size:/) {
                            split(line, arr, ":")
                            size = arr[2]
                        } else if (line ~ /^Manufacturer:/) {
                            split(line, arr, ":")
                            vendor = arr[2]
                        } else if (line ~ /^Part Number:/) {
                            split(line, arr, ":")
                            model = arr[2]
                        } else if (line ~ /^Type:/) {
                            split(line, arr, ":")
                            type = arr[2]
                        } else if (line ~ /^Speed:/) {
                            split(line, arr, ":")
                            speed = arr[2]
                        } else if (line ~ /^Configured (Memory Speed|Clock Speed):/) {
                            split(line, arr, ":")
                            configured_speed = arr[2]
                        } else if (line ~ /^Serial Number:/) {
                            split(line, arr, ":")
                            serial = arr[2]
                        }
                    }

                    gsub(/^[ \t]+|[ \t]+$/, "", size)
                    gsub(/^[ \t]+|[ \t]+$/, "", vendor)
                    gsub(/^[ \t]+|[ \t]+$/, "", model)
                    gsub(/^[ \t]+|[ \t]+$/, "", type)
                    gsub(/^[ \t]+|[ \t]+$/, "", speed)
                    gsub(/^[ \t]+|[ \t]+$/, "", configured_speed)
                    gsub(/^[ \t]+|[ \t]+$/, "", serial)

                    if (vendor ~ /^(NO|Unknown|[Nn]\/[Aa])/) vendor = ""
                    if (model ~ /^(NO|Unknown|[Nn]\/[Aa])/) model = ""
                    if (serial ~ /^(NO|Unknown|[Nn]\/[Aa])/) serial = ""
                    if (type == "" || type == "Unknown") type = "DRAM"

                    gsub(/[ \t]+/, "", size)

                    print vendor "\t" model "\t" type "\t" size "\t" speed "\t" configured_speed "\t" serial
                }
            ' <<< "$DMI_MEM_OUT"
        )"
    fi
}

# 格式化输出 JSON 数据
output_json() {
    local total_kb avail_kb total_bytes avail_bytes
    total_kb="$(grep -iE '^MemTotal:' <<< "$MEMINFO_OUT" | awk '{print $2}' || echo "0")"
    avail_kb="$(grep -iE '^MemAvailable:' <<< "$MEMINFO_OUT" | awk '{print $2}' || echo "0")"

    total_bytes=$((total_kb * 1024))
    avail_bytes=$((avail_kb * 1024))

    jq -Rn \
        --argjson total_bytes "$total_bytes" \
        --argjson avail_bytes "$avail_bytes" '
    def format_declared_size(bytes):
        if bytes == null or bytes == 0 then
            ""
        elif bytes >= 1000000000000 then
            "\( (bytes / 1000000000000 | round) )TB"
        elif bytes >= 100000000 then
            "\( (bytes / 1000000000 | round) )GB"
        elif bytes >= 100000 then
            "\( (bytes / 1000000 | round) )MB"
        else
            "\(bytes)B"
        end;

    [
        inputs
        | select(length > 0)
        | split("\t") as $fields
        | {
            vendor: $fields[0],
            model: $fields[1],
            type: $fields[2],
            capacity: $fields[3],
            speed: $fields[4],
            configured_speed: $fields[5],
            serial: $fields[6]
        }
    ] as $modules
    | {
        memory_count: ($modules | length),
        installed: format_declared_size($total_bytes),
        available: format_declared_size($avail_bytes),
        modules: $modules
    }' <<< "$CLEANED_MEM_DATA"
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

    collect_memory

    validate_memory || {
        echo "ERROR memory information unavailable" >&2
        exit 1
    }

    clean_memory_data

    output_json
}

main "$@"
