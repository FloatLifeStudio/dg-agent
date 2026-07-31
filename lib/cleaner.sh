#!/usr/bin/env bash

trim() {
    local str="${1-}"

    str="${str#"${str%%[![:space:]]*}"}"
    str="${str%"${str##*[![:space:]]}"}"

    printf '%s' "$str"
}

# 过滤无效占位符 返回空字符串表示无效值
normalize() {
    local val
    val="$(trim "${1-}")"

    case "$val" in
        '' | 'Unknown' | 'unknown' | 'None' | 'N/A' | 'NA' | \
            'Not Specified' | 'System Product Name' | 'To be filled by O.E.M.' | \
            '[N/A]' | 'NO' | 'No' | 'none')
            printf ''
            ;;
        *)
            printf '%s' "$val"
            ;;
    esac
}

# JSON字符串安全转义
json_escape() {
    local str="${1-}"

    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\n'/\\n}"
    str="${str//$'\r'/\\r}"
    str="${str//$'\t'/\\t}"

    printf '%s' "$str"
}
