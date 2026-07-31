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

_strip_quotes() {
    local str="${1-}"
    str="${str#\"}"; str="${str%\"}"
    str="${str#\'}"; str="${str%\'}"
    printf '%s' "$str"
}

collect() {
    local name=''
    local id=''
    local version=''
    local pretty_name=''
    local kernel=''

    # 读取 os-release
    local file
    for file in /etc/os-release /usr/lib/os-release; do
        if [[ -r "$file" ]]; then
            while IFS='=' read -r key value || [[ -n "${key:-}" ]]; do
                [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
                key="$(_trim "$key")"
                value="$(_strip_quotes "$(_trim "$value")")"

                case "$key" in
                    NAME)        name="$value" ;;
                    ID)          id="$value" ;;
                    VERSION_ID)  version="$value" ;;
                    PRETTY_NAME) pretty_name="$value" ;;
                esac
            done < "$file"
            break
        fi
    done

    # 兜底老旧发行版
    if [[ -z "$name" ]]; then
        for file in /etc/redhat-release /etc/centos-release /etc/system-release \
                    /etc/alpine-release /etc/arch-release /etc/debian_version; do
            if [[ -r "$file" ]]; then
                name="$(_trim "$(head -n1 "$file" 2>/dev/null || true)")"
                [[ -n "$name" ]] && break
            fi
        done
        [[ -z "$name" ]] && name='Linux'
        [[ -z "$id" ]] && id='linux'
        [[ -z "$pretty_name" ]] && pretty_name="$name"
    fi

    # 内核版本
    kernel="$(uname -r)"

    # 输出扁平JSON
    printf '{"name":"%s","id":"%s","version":"%s","pretty_name":"%s","kernel":"%s"}\n' \
        "$(_json_escape "$name")" \
        "$(_json_escape "$id")" \
        "$(_json_escape "$version")" \
        "$(_json_escape "$pretty_name")" \
        "$(_json_escape "$kernel")"
}

# JSON字符串转义
_json_escape() {
    local str="${1-}"
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    printf '%s' "$str"
}

collect
