#!/usr/bin/env bash

# 全局verbose开关 由logger_init设置
LOGGER_VERBOSE=false

# $1: verbose开关 true/false
logger_init() {
    LOGGER_VERBOSE="${1:-false}"
}

_timestamp() {
    date +"%Y-%m-%d %H:%M:%S"
}

# 仅verbose模式输出
log_info() {
    [[ "$LOGGER_VERBOSE" == true ]] || return 0
    printf "[%s]-[INFO] %s\n" "$(_timestamp)" "$1" >&2
}

# 始终输出到stderr
log_warn() {
    printf "[%s]-[WARN] %s\n" "$(_timestamp)" "$1" >&2
}

log_error() {
    printf "[%s]-[ERROR] %s\n" "$(_timestamp)" "$1" >&2
}

# 仅verbose模式输出
log_step() {
    [[ "$LOGGER_VERBOSE" == true ]] || return 0
    printf "[%s]-[STEP] %s\n" "$(_timestamp)" "$1" >&2
}

log_ok() {
    [[ "$LOGGER_VERBOSE" == true ]] || return 0
    printf "[%s]-[OK] %s\n" "$(_timestamp)" "$1" >&2
}
