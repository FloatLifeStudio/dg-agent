#!/usr/bin/env bash

clear >/dev/null 2>&1 || true

# 权限检测 --help和空参数不需要root
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    for _a in "$@"; do
        if [[ "$_a" == "--help" || "$_a" == "-h" ]]; then
            cat << 'EOF'
dg-agent — 轻量级硬件资产采集框架

用法:
  dg-agent.sh [选项] [模块...]

选项:
  --all               运行所有模块
  --output <file>     结果写入文件 默认 stdout
  --verbose, -v       详细输出 日志写入 stderr
  --help, -h          显示帮助

模块:
  --os                操作系统
  --cpu               CPU 信息
  --memory            内存信息
  --disk              磁盘信息
  --gpu               GPU 信息
  --nic               网卡信息
  --power             电源信息

示例:
  sudo ./dg-agent.sh --cpu --os
  sudo ./dg-agent.sh --all --output /tmp/asset.json --verbose
  sudo bash modules/os.sh               # 单模块独立运行
EOF
            exit 0
        fi
    done
    if [[ "$#" -eq 0 ]]; then
        printf '{"error":"root required","hint":"use sudo or specify --help"}\n' >&2
        exit 5
    fi
    exec sudo bash "$0" "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly MODULE_DIR="${SCRIPT_DIR}/modules"
readonly LIB_DIR="${SCRIPT_DIR}/lib"
readonly VERSION='1.0.0'

# shellcheck source=./lib/cleaner.sh
source "${LIB_DIR}/cleaner.sh"
# shellcheck source=./lib/logger.sh
source "${LIB_DIR}/logger.sh"

declare -a SELECTED_MODULES=()
OUTPUT_FILE=''
VERBOSE=false
EXIT_CODE=0

# 可用模块列表
readonly ALL_MODULES=(os cpu memory disk gpu nic power)

_usage() {
    cat << 'EOF'
dg-agent — 轻量级硬件资产采集框架

用法:
  dg-agent.sh [选项] [模块...]

选项:
  --all               运行所有模块
  --output <file>     结果写入文件 默认 stdout
  --verbose, -v       详细输出 日志写入 stderr
  --help, -h          显示帮助

模块:
  --os                操作系统
  --cpu               CPU 信息
  --memory            内存信息
  --disk              磁盘信息
  --gpu               GPU 信息
  --nic               网卡信息
  --power             电源信息

示例:
  ./dg-agent.sh --cpu --os
  ./dg-agent.sh --all --output /tmp/asset.json --verbose
  modules/os.sh                          # 单模块独立运行
EOF
}

_parse_args() {
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --output)
                shift
                if [[ "$#" -eq 0 ]]; then
                    log_error '--output 需要文件路径参数'
                    exit 2
                fi
                OUTPUT_FILE="$1"
                ;;
            --verbose|-v)
                VERBOSE=true
                ;;
            --all)
                for m in "${ALL_MODULES[@]}"; do
                    _add_module "$m"
                done
                ;;
            --help|-h)
                _usage
                exit 0
                ;;
            --os|--cpu|--memory|--disk|--gpu|--nic|--power)
                _add_module "${1#--}"
                ;;
            *)
                log_error "无效参数: $1"
                _usage
                exit 2
                ;;
        esac
        shift
    done

    if [[ "${#SELECTED_MODULES[@]}" -eq 0 ]]; then
        log_error '未指定任何模块 (使用 --all 运行所有, --help 查看帮助)'
        _usage
        exit 2
    fi
}

_add_module() {
    local module="$1"
    local script="${MODULE_DIR}/${module}.sh"

    if [[ ! -f "$script" ]]; then
        log_error "模块不存在: ${module} (${script})"
        EXIT_CODE=3
        return 1
    fi

    # 去重
    local m
    for m in "${SELECTED_MODULES[@]}"; do
        [[ "$m" == "$module" ]] && return 0
    done

    SELECTED_MODULES+=("$module")
    return 0
}

_run_module() {
    local module="$1"
    local script="${MODULE_DIR}/${module}.sh"
    local output rc

    log_step "采集: ${module}"

    # 确保脚本可执行
    if [[ ! -x "$script" ]]; then
        chmod +x "$script" 2>/dev/null || true
    fi

    output="$(bash "$script" 2>&1)" || rc=$?
    rc=${rc:-0}

    if [[ "$rc" -ne 0 ]]; then
        log_warn "模块 ${module} 异常退出 (exit: $rc)"
        EXIT_CODE=6
        # 返回错误占位JSON
        printf '{"error":"collect failed (exit: %d)"}' "$rc"
        return 1
    fi

    # 验证输出是否为合法JSON
    if ! printf '%s' "$output" | jq empty 2>/dev/null; then
        log_warn "模块 ${module} 输出非合法 JSON"
        EXIT_CODE=7
        printf '{"error":"invalid json output"}'
        return 1
    fi

    log_ok "模块 ${module} 完成"
    printf '%s' "$output"
    return 0
}

# 构建模块名到输出的顶层映射 {os:{...},cpu:{...}}
_build_aggregate() {
    local result='{' first=1 module raw

    for module in "${SELECTED_MODULES[@]}"; do
        raw="$(_run_module "$module")" || true

        [[ "$first" -eq 0 ]] && result+=','
        first=0

        result+="\"${module}\":${raw}"
    done

    result+='}'

    # 格式化输出
    printf '%s' "$result" | jq '.'
}

_write_output() {
    local content="$1"

    if [[ -n "$OUTPUT_FILE" ]]; then
        if printf '%s\n' "$content" > "$OUTPUT_FILE"; then
            log_info "结果已写入: ${OUTPUT_FILE}"
        else
            log_error "写入文件失败: ${OUTPUT_FILE}"
            EXIT_CODE=8
        fi
    else
        printf '%s\n' "$content"
    fi
}

main() {
    _parse_args "$@"

    # 初始化日志 _parseArgs已设置VERBOSE
    logger_init "$VERBOSE"

    [[ "$VERBOSE" == true ]] && {
        log_info "dg-agent v${VERSION}"
        log_info "脚本路径: ${SCRIPT_DIR}"
        log_info "选中模块: ${SELECTED_MODULES[*]}"
        [[ -n "$OUTPUT_FILE" ]] && log_info "输出文件: ${OUTPUT_FILE}"
    }

    local output
    output="$(_build_aggregate)"

    _write_output "$output"

    return "$EXIT_CODE"
}

main "$@"
exit $?
