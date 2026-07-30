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

# 保存 lscpu 输出
declare -A CPU_INFO

# 采集 CPU 信息
collect_cpu() {

    local key
    local value

    while IFS=: read -r key value; do
        key="$(trim "$key")"
        value="$(trim "$value")"
        [[ -z "$key" ]] && continue
        CPU_INFO["$key"]="$value"
    done < <(lscpu)

}

# 校验采集结果
validate_cpu() {

    [[ -n "${CPU_INFO["Architecture"]:-}" ]] || return 1
    [[ -n "${CPU_INFO["Vendor ID"]:-}" ]] || return 1
    [[ -n "${CPU_INFO["Model name"]:-}" ]] || return 1
    [[ -n "${CPU_INFO["Socket(s)"]:-}" ]] || return 1
    [[ -n "${CPU_INFO["Core(s) per socket"]:-}" ]] || return 1
    [[ -n "${CPU_INFO["CPU(s)"]:-}" ]] || return 1

}

# 输出 JSON
output_json() {

    local socket_count
    local cores_per_socket
    local total_threads
    local architecture
    local vendor
    local model

    socket_count="${CPU_INFO["Socket(s)"]}"
    cores_per_socket="${CPU_INFO["Core(s) per socket"]}"
    total_threads="${CPU_INFO["CPU(s)"]}"
    architecture="${CPU_INFO["Architecture"]}"
    vendor="${CPU_INFO["Vendor ID"]}"
    model="${CPU_INFO["Model name"]}"

    jq -n \
        --argjson socket_count "$socket_count" \
        --argjson cores_per_socket "$cores_per_socket" \
        --argjson total_threads "$total_threads" \
        --arg architecture "$architecture" \
        --arg vendor "$vendor" \
        --arg model "$model" '
    {
        cpu_count: $socket_count,
        cpu_cores: ($socket_count * $cores_per_socket),
        cpu_threads: $total_threads,
        cpu_processors: [
            range(0; $socket_count)
            |
            {
                cpu_socket: .,
                cpu_vendor: $vendor,
                cpu_model: $model,
                cpu_architecture: $architecture,
                cpu_cores: $cores_per_socket,
                cpu_threads: ($total_threads / $socket_count)
            }
        ]
    }'

}

main() {
    check_command lscpu || {
        echo "ERROR missing command lscpu" >&2
        exit 1
    }
    check_command jq || {
        echo "ERROR missing command jq" >&2
        exit 1
    }
    collect_cpu
    validate_cpu || {
        echo "ERROR cpu information unavailable" >&2
        exit 1
    }
    output_json

}

main "$@"
