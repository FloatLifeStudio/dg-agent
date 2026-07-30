#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

# 检查依赖命令是否存在
check_command() {
    command -v "$1" > /dev/null 2>&1
}

# 全局变量保存 lsblk 原始输出
LSBLK_JSON=""

# 采集磁盘信息
collect_disk() {
    LSBLK_JSON="$(
        lsblk \
            -d \
            -b \
            -J \
            -o NAME,VENDOR,MODEL,SIZE,ROTA,TRAN,SERIAL,TYPE \
            2> /dev/null || true
    )"
}

# 校验采集数据是否有效
validate_disk() {
    [[ -n "$LSBLK_JSON" ]] || return 1

    local count
    count="$(jq '[.blockdevices[]? | select(.type == "disk")] | length' <<< "$LSBLK_JSON")"
    [[ "$count" -gt 0 ]] || return 1
}

# 解析并输出格式化的 JSON 数据
output_json() {
    jq '
    def format_size(bytes):
        if bytes == null or bytes == 0 then
            ""
        elif bytes >= 1000000000000 then
            "\( (bytes / 1000000000000 | round) )TB"
        elif bytes >= 1000000 then
            "\( (bytes / 1000000000 | round) )GB"
        elif bytes >= 1000 then
            "\( (bytes / 1000000 | round) )MB"
        else
            "\(bytes)B"
        end;

    def disk_type(rota; tran):
        if tran == "nvme" then
            "NVMe SSD"
        elif rota == "0" or rota == 0 then
            "SSD"
        elif rota == "1" or rota == 1 then
            "HDD"
        else
            "DISK"
        end;

    [.blockdevices[]? | select(.type == "disk")] as $disks
    | {
        disk_count: ($disks | length),
        disks: [
            $disks[] | {
                vendor: ((.vendor // "") | gsub("^\\s+|\\s+$"; "")),
                model: ((.model // "") | gsub("^\\s+|\\s+$"; "")),
                size: format_size(.size // 0),
                type: disk_type(.rota; .tran),
                sn: ((.serial // "") | gsub("^\\s+|\\s+$"; ""))
            }
        ]
    }' <<< "$LSBLK_JSON"
}

# 主程序逻辑入口
main() {
    check_command lsblk || {
        echo "ERROR missing command lsblk" >&2
        exit 1
    }

    check_command jq || {
        echo "ERROR missing command jq" >&2
        exit 1
    }

    collect_disk

    validate_disk || {
        echo "ERROR disk information unavailable or no disks found" >&2
        exit 1
    }

    output_json
}

main "$@"
