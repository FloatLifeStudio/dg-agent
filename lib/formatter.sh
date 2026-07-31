#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

# 将 key=value 格式输入转为 JSON
format_json() {
    local json="{}"

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" ]] && continue

        key="${line%%=*}"
        value="${line#*=}"

        # 数组嵌套 key[0].field
        if [[ "$key" =~ ^([a-zA-Z0-9_]+)\[([0-9]+)\]\.([a-zA-Z0-9_]+)$ ]]; then
            local name="${BASH_REMATCH[1]}"
            local index="${BASH_REMATCH[2]}"
            local field="${BASH_REMATCH[3]}"

            json="$(jq \
                --arg name "$name" \
                --argjson index "$index" \
                --arg field "$field" \
                --arg value "$value" \
                '
                if .[$name] == null then .[$name] = [] else . end
                | if .[$name][$index] == null then .[$name][$index] = {} else . end
                | .[$name][$index][$field] = $value
                ' <<< "$json")"
        else
            json="$(jq \
                --arg key "$key" \
                --arg value "$value" \
                '. + {($key): $value}' <<< "$json")"
        fi
    done

    printf '%s' "$json" | jq '.'
}

main() {
    case "${1:-json}" in
        json) format_json ;;
        *)
            printf 'ERROR unsupported format: %s\n' "$1" >&2
            exit 1
            ;;
    esac
}

main "$@"
