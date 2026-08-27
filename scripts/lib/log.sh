#!/usr/bin/env bash
# ============================================================
# log.sh — 统一运行日志库（VPG 1.2.0 新增）
# ------------------------------------------------------------
# 供 project-init / task-manager / commit-check / health-check 等脚本 source 使用。
# 双写：界面输出（保持原有格式）+ 落盘 .vibe-coding/logs/<模块>-<日期>-<时间>.log
# 文件名颗粒度：每次运行一个文件，<模块名>-<YYYYMMDD>-<HHMMSS>.log
# 内容颗粒度：启动（log_init）/ 动作（log_info）/ 成功含成功信息（log_success）/
#            失败含错误信息（log_error 退出 / log_fail 记录不退出）
# ============================================================


LOG_MODULE=""
LOG_DIR=""
LOG_FILE=""

log_find_governance() {
    local d="$(pwd)" steps=0
    if [ -d "${d}/.vibe-coding" ]; then echo "${d}/.vibe-coding"; return 0; fi
    while [ "$d" != "/" ] && [ "$d" != "." ] && [ -n "$d" ] && [ "$steps" -lt 20 ]; do
        steps=$((steps + 1))
        if [ -d "${d}/.vibe-coding" ]; then echo "${d}/.vibe-coding"; return 0; fi
        d="$(dirname "$d")"
    done
    echo ""
}

log_init() {
    LOG_MODULE="${1:-unknown}"
    local gov; gov="$(log_find_governance)"
    if [ -z "$gov" ]; then
        LOG_FILE=""
        return 0
    fi
    LOG_DIR="${gov}/logs"
    mkdir -p "${LOG_DIR}" 2>/dev/null || true
    LOG_FILE="${LOG_DIR}/${LOG_MODULE}-$(date +%Y%m%d-%H%M%S).log"
    log_raw "INFO" "===== ${LOG_MODULE} 启动 ====="
}

log_raw() {
    local level="$1" msg="$2"
    [ -n "${LOG_FILE:-}" ] || return 0
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${level}] ${msg}" >> "${LOG_FILE}" 2>/dev/null || true
}

log_info() {
    echo -e "✅ $1"
    log_raw "INFO" "$1"
}

log_success() {
    echo -e "✅ $1"
    log_raw "SUCCESS" "$1"
}

# 双写：界面 ⚠️ + 文件 [WARN]
log_warn() {
    echo -e "⚠️ $1"
    log_raw "WARN" "$1"
}

log_error() {
    echo -e "❌ $1" >&2
    log_raw "ERROR" "$1"
    exit 1
}

log_fail() {
    echo -e "❌ $1" >&2
    log_raw "ERROR" "$1"
    return 1
}
