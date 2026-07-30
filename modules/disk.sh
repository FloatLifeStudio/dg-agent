#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

#
# Disk information collector
#
# Output:
#
# disk[0].vendor=
# disk[0].model=
# disk[0].size=
# disk[0].type=
# disk[0].sn=
#

check_dependencies() {

    command -v lsblk > /dev/null 2>&1 || {
        echo "ERROR lsblk not found" >&2
        exit 1
    }

    command -v jq > /dev/null 2>&1 || {
        echo "ERROR jq not found" >&2
        exit 1
    }
}

get_disk_type() {

    local rota="$1"
    local tran="$2"

    if [ "$tran" = "nvme" ]; then

        echo "NVMe SSD"

    elif [ "$rota" = "0" ]; then

        echo "SSD"

    elif [ "$rota" = "1" ]; then

        echo "HDD"

    else

        echo "DISK"

    fi
}

collect_disk() {

    local lsblk_json

    lsblk_json="$(
        lsblk \
            -d \
            -b \
            -J \
            -o NAME,VENDOR,MODEL,SIZE,ROTA,TRAN,SERIAL,TYPE \
            2> /dev/null
    )"

    local count

    count="$(
        jq '.blockdevices | length' <<< "$lsblk_json"
    )"

    local index=0

    for ((i = 0; i < count; i++)); do

        local dev_type

        dev_type="$(
            jq -r \
                ".blockdevices[$i].type // \"\"" \
                <<< "$lsblk_json"
        )"

        [ "$dev_type" != "disk" ] && continue

        local vendor
        local model
        local size_bytes
        local rota
        local tran
        local serial

        vendor="$(
            jq -r \
                ".blockdevices[$i].vendor // \"\"" \
                <<< "$lsblk_json" \
                | xargs
        )"

        model="$(
            jq -r \
                ".blockdevices[$i].model // \"\"" \
                <<< "$lsblk_json" \
                | xargs
        )"

        size_bytes="$(
            jq -r \
                ".blockdevices[$i].size // 0" \
                <<< "$lsblk_json"
        )"

        rota="$(
            jq -r \
                ".blockdevices[$i].rota // \"\"" \
                <<< "$lsblk_json"
        )"

        tran="$(
            jq -r \
                ".blockdevices[$i].tran // \"\"" \
                <<< "$lsblk_json"
        )"

        serial="$(
            jq -r \
                ".blockdevices[$i].serial // \"\"" \
                <<< "$lsblk_json" \
                | xargs
        )"

        local size

        if [ "$size_bytes" -gt 0 ]; then

            size="$(
                awk \
                    "BEGIN {printf \"%.0fGB\", $size_bytes / 1024 / 1024 / 1024}"
            )"

        else

            size=""

        fi

        local type

        type="$(
            get_disk_type "$rota" "$tran"
        )"

        echo "disk[${index}].vendor=${vendor}"
        echo "disk[${index}].model=${model}"
        echo "disk[${index}].size=${size}"
        echo "disk[${index}].type=${type}"
        echo "disk[${index}].sn=${serial}"

        index=$((index + 1))

    done

    if [ "$index" -eq 0 ]; then
        echo "ERROR no disk found" >&2
        return 1
    fi
}

main() {

    check_dependencies

    collect_disk

}

main "$@"
