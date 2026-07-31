#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly CACHE_DIR="${ROOT_DIR}/cache"
readonly CACHE_FILE="${CACHE_DIR}/lshw.json"

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

# 采集 lshw 并缓存
collect_lshw() {
    mkdir -p "${CACHE_DIR}"
    lshw -json > "${CACHE_FILE}"
    cat "${CACHE_FILE}"
}

main() {
    require_root "$@"

    check_command lshw || {
        printf 'ERROR missing command lshw\n' >&2
        exit 1
    }

    check_command jq || {
        printf 'ERROR missing command jq\n' >&2
        exit 1
    }

    collect_lshw
}

main "$@"
