#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

cpu_socket=""
cpu_core=""
cpu_thread=""

declare -a cpu_models=()

collect_from_lscpu() {

    command -v lscpu > /dev/null 2>&1 || return 1

    local data

    data="$(lscpu)"

    cpu_socket="$(awk -F: '/Socket\(s\)/ {gsub(/ /,"",$2);print $2}' <<< "$data")"

    cpu_core="$(awk -F: '/Core\(s\) per socket/ {
        gsub(/ /,"",$2)
        print $2
    }' <<< "$data")"

    cpu_thread="$(awk -F: '/CPU\(s\)/ {
        gsub(/ /,"",$2)
        print $2
        exit
    }' <<< "$data")"

    local model

    model="$(awk -F: '
        /Model name/ {
            gsub(/^ +/,"",$2)
            print $2
            exit
        }
    ' <<< "$data")"

    if [ -n "$model" ]; then

        local count

        count="${cpu_socket:-1}"

        for ((i = 0; i < count; i++)); do
            cpu_models+=("$model")
        done

    fi

    [ -n "$cpu_socket" ] \
        && [ -n "$cpu_core" ] \
        && [ -n "$cpu_thread" ] \
        && [ "${#cpu_models[@]}" -gt 0 ]

}

collect_from_dmidecode() {

    command -v dmidecode > /dev/null 2>&1 || return 1

    local models

    mapfile -t models < <(
        dmidecode -t processor 2> /dev/null \
            | awk -F: '
        /Version:/ {
            gsub(/^ +/,"",$2)

            if ($2 != "")
                print $2
        }
        '
    )

    [ "${#models[@]}" -eq 0 ] && return 1

    cpu_models=("${models[@]}")

    cpu_socket="${#cpu_models[@]}"

    cpu_core="$(
        dmidecode -t processor 2> /dev/null \
            | awk -F: '
        /Core Count:/ {
            gsub(/^ +/,"",$2)
            print $2
            exit
        }
        '
    )"

    cpu_thread="$(
        dmidecode -t processor 2> /dev/null \
            | awk -F: '
        /Thread Count:/ {
            gsub(/^ +/,"",$2)
            print $2
            exit
        }
        '
    )"

    [ -n "$cpu_socket" ]
}

collect_from_sysfs() {

    [ -r /proc/cpuinfo ] || return 1

    local model

    model="$(
        awk -F: '
        /model name/ {
            gsub(/^ +/,"",$2)
            print $2
            exit
        }
        ' /proc/cpuinfo
    )"

    [ -z "$model" ] && return 1

    cpu_socket=1

    cpu_core="$(nproc --all 2> /dev/null || true)"

    cpu_thread="$cpu_core"

    cpu_models+=("$model")

}

output() {

    local index=0

    for model in "${cpu_models[@]}"; do
        echo "cpu[${index}].model=${model}"
        index=$((index + 1))
    done

    echo "cpu_socket=${cpu_socket}"
    echo "cpu_core=${cpu_core}"
    echo "cpu_thread=${cpu_thread}"
}

main() {

    if ! collect_from_lscpu; then

        cpu_models=()

        if ! collect_from_dmidecode; then

            cpu_models=()

            if ! collect_from_sysfs; then
                echo "ERROR cpu information unavailable" >&2
                exit 1
            fi

        fi

    fi

    output

}

main "$@"
