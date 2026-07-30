#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly MODULE_DIR="${SCRIPT_DIR}/modules"
readonly FORMATTER="${SCRIPT_DIR}/lib/formatter.sh"

json_output=false
declare -a modules=()

exit_code=0

error() {
    echo "ERROR $*" >&2
}

usage() {
    cat << EOF
Usage:
  $0 [options]

Options:
  --all             Run all modules
  --json            Output json format
  --help            Show help

Modules:
  --<module>        Run specified module

Examples:
  $0 --cpu
  $0 --cpu --memory --disk
  $0 --all --json
EOF
}

module_exists() {

    local module="$1"

    [ -f "${MODULE_DIR}/${module}.sh" ]
}

add_module() {

    local module="$1"

    if ! module_exists "$module"; then
        error "module not found: ${module}"
        exit_code=1
        return
    fi

    modules+=("$module")
}

discover_modules() {

    local module_file
    local module_name

    for module_file in "${MODULE_DIR}"/*.sh; do
        [ -f "$module_file" ] || continue

        module_name="$(basename "$module_file" .sh)"

        modules+=("$module_name")
    done
}

parse_args() {

    if [ "$#" -eq 0 ]; then
        usage
        exit 1
    fi

    while [ "$#" -gt 0 ]; do
        case "$1" in

            --json)

                json_output=true
                ;;

            --all)

                discover_modules
                ;;

            --help | -h)

                usage
                exit 0
                ;;

            --*)

                add_module "${1#--}"
                ;;

            *)

                error "invalid argument: $1"
                usage
                exit 1
                ;;

        esac

        shift
    done

    if [ "${#modules[@]}" -eq 0 ]; then
        error "no module specified"
        exit 1
    fi
}

run_modules() {

    local module
    local module_script
    local output

    for module in "${modules[@]}"; do
        module_script="${MODULE_DIR}/${module}.sh"

        if output=$(bash "$module_script"); then
            printf '%s\n' "$output"
        else
            error "module failed: ${module}"
            exit_code=1
        fi

    done
}

run_json_formatter() {

    local input_file

    input_file="$(mktemp)"

    if run_modules > "$input_file"; then
        :
    else
        exit_code=1
    fi

    if [ ! -f "$FORMATTER" ]; then
        rm -f "$input_file"
        error "formatter not found"
        return 1
    fi

    if ! bash "$FORMATTER" json < "$input_file"; then
        exit_code=1
    fi

    rm -f "$input_file"
}

main() {

    parse_args "$@"

    if [ "$json_output" = true ]; then

        run_json_formatter

    else

        run_modules

    fi

    return "$exit_code"
}

main "$@"
exit $?
