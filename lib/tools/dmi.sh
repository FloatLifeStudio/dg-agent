#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

# 自动提权
require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        exec sudo -E bash "$0" "$@"
    fi
}

# 检查命令是否存在
check_command() {
    command -v "$1" >/dev/null 2>&1
}

# 去除首尾空白
trim() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

# 将 dmidecode 输出转为 JSON 数组
collect_dmi() {
    local first_record=1

    printf '[\n'

    local handle=""
    local dmi_type=""
    local record_type=""
    local fields="{}"

    flush_record() {
        [[ -z "$handle" ]] && return

        if [[ $first_record -eq 0 ]]; then
            printf ',\n'
        fi
        first_record=0

        jq -n \
            --arg handle "$handle" \
            --argjson dmi_type "$dmi_type" \
            --arg type "$record_type" \
            --argjson data "$fields" \
            '{
                handle: $handle,
                dmi_type: $dmi_type,
                type: $type,
                data: $data
            }'
    }

    while IFS= read -r line || [[ -n "$line" ]]; do
        # 匹配记录头 Handle 0x..., DMI type N,
        if [[ "$line" =~ ^Handle[[:space:]]+(0x[0-9A-Fa-f]+),[[:space:]]+DMI[[:space:]]+type[[:space:]]+([0-9]+), ]]; then
            flush_record
            handle="${BASH_REMATCH[1]}"
            dmi_type="${BASH_REMATCH[2]}"
            record_type=""
            fields="{}"
            continue
        fi

        [[ -z "$handle" ]] && continue

        line="$(trim "$line")"
        [[ -z "$line" ]] && continue

        # 第一条非标题行是记录类型名
        if [[ -z "$record_type" ]]; then
            record_type="$line"
            continue
        fi

        # key:value 行
        if [[ "$line" == *:* ]]; then
            local key="${line%%:*}"
            local value="${line#*:}"
            key="$(trim "$key")"
            value="$(trim "$value")"

            fields="$(jq \
                --argjson obj "$fields" \
                --arg key "$key" \
                --arg value "$value" \
                -n '$obj + {($key): $value}')"
        fi
    done < <(dmidecode)

    flush_record

    printf '\n]\n'
}

main() {
    require_root

    check_command dmidecode || {
        printf 'ERROR missing command dmidecode\n' >&2
        exit 1
    }

    check_command jq || {
        printf 'ERROR missing command jq\n' >&2
        exit 1
    }

    collect_dmi
}

main "$@"
