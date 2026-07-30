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

# 保存 OS 原始采集数据
declare -A OS_INFO

# 采集 OS 信息
collect_os() {
    local file
    local key
    local value

    # 1. 优先读取标准 os-release 配置文件
    for file in /etc/os-release /usr/lib/os-release; do
        if [[ -r "$file" ]]; then
            while IFS='=' read -r key value || [[ -n "${key:-}" ]]; do
                # 过滤注释与空行
                [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue

                key="$(trim "$key")"
                value="$(trim "$value")"

                # 剥离首尾单/双引号
                value="${value%\"}"
                value="${value#\"}"
                value="${value%\'}"
                value="${value#\'}"

                OS_INFO["$key"]="$value"
            done < "$file"
            break
        fi
    done

    # 2. 兼容老旧发行版
    if [[ -z "${OS_INFO["NAME"]:-}" ]]; then
        for file in /etc/{redhat,centos,system,alpine,arch}-release /etc/debian_version; do
            if [[ -r "$file" ]]; then
                local legacy_name
                legacy_name="$(head -n 1 "$file" 2> /dev/null || true)"
                legacy_name="$(trim "$legacy_name")"

                if [[ -n "$legacy_name" ]]; then
                    OS_INFO["NAME"]="$legacy_name"
                    OS_INFO["PRETTY_NAME"]="$legacy_name"
                    break
                fi
            fi
        done
    fi

    # 3. 补全默认兜底字段
    OS_INFO["NAME"]="${OS_INFO["NAME"]:-Linux}"
    OS_INFO["ID"]="${OS_INFO["ID"]:-linux}"
    OS_INFO["VERSION_ID"]="${OS_INFO["VERSION_ID"]:-}"
    OS_INFO["PRETTY_NAME"]="${OS_INFO["PRETTY_NAME"]:-${OS_INFO["NAME"]} ${OS_INFO["VERSION_ID"]:-$(uname -r)}}"
    OS_INFO["KERNEL"]="$(uname -r)"
}

# 校验采集结果
validate_os() {
    [[ -n "${OS_INFO["NAME"]:-}" ]] || return 1
    [[ -n "${OS_INFO["ID"]:-}" ]] || return 1
    [[ -n "${OS_INFO["PRETTY_NAME"]:-}" ]] || return 1
}

# 输出 JSON
output_json() {
    local name
    local id
    local version
    local pretty_name
    local kernel

    name="${OS_INFO["NAME"]}"
    id="${OS_INFO["ID"]}"
    version="${OS_INFO["VERSION_ID"]}"
    pretty_name="${OS_INFO["PRETTY_NAME"]}"
    kernel="${OS_INFO["KERNEL"]}"

    jq -n \
        --arg name "$name" \
        --arg id "$id" \
        --arg version "$version" \
        --arg pretty_name "$pretty_name" \
        --arg kernel "$kernel" '
    {
        os_name: $name,
        os_id: $id,
        os_version: $version,
        os_pretty_name: $pretty_name,
        kernel_version: $kernel
    }'
}

main() {
    check_command jq || {
        echo "ERROR missing command jq" >&2
        exit 1
    }

    collect_os

    validate_os || {
        echo "ERROR os information unavailable" >&2
        exit 1
    }

    output_json
}

main "$@"
