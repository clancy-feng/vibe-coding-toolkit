#!/bin/bash
# ============================================
# check.sh — health-check 项目体检脚本（vibe-coding-toolkit 子命令）
# 定位：只诊断、不修理。绝不修改任何业务/治理文件。
# 写入目标（如实声明）：HEALTH_AUDIT.md（审计留痕）+ .health_state（连续未清除计数，仅作透明提示，不改变判定等级）。
# 安全声明：本脚本零网络访问、零环境变量读取、零数据外传；仅在被体检项目目录内读写文件（审计日志与计数），版本核对仅读取自身安装目录的 skill.json（由脚本自身路径推导位置）。
# 兼容：与 task-manager 一致（bash + POSIX awk 2 参数 match）；禁 GNU AWK 三参数 match / grep -oP。
# ============================================
set -u

# ---------- 路径检测 ----------
find_project_root() {
    dir="$(pwd)"
    while [ "$dir" != "/" ]; do
        if [ -d "$dir/.git" ]; then echo "$dir"; return 0; fi
        dir="$(dirname "$dir")"
    done
    return 1
}

PROJECT_ROOT="$(find_project_root || true)"
if [ -z "${PROJECT_ROOT}" ]; then
    echo "[health-check] ERROR_SCAN_FAILED：未找到项目根目录（无 .git）。体检工具异常，请检查版本。" >&2
    exit 2
fi
# 切入项目根（避免 git -C 在 MSYS 下路径翻译失败；后续用裸 git 命令）
cd "$PROJECT_ROOT" 2>/dev/null || {
    echo "[health-check] ERROR_SCAN_FAILED：无法进入项目根 ${PROJECT_ROOT}。体检工具异常，请检查版本。" >&2
    exit 2
}

# 统一运行日志（1.2.0）：health-check 结论落盘 .vibe-coding/logs/health-check-<日期>-<时间>.log
# 界面输出保持不变，关键节点用 log_raw 仅写文件（本脚本 set -u，log 库兼容）
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/../lib/log.sh"
log_init "health-check"
log_raw "INFO" "health-check 启动（项目根：${PROJECT_ROOT}）"
# 治理记忆目录：优先 .vibe-coding/memory（新项目，由 project-init 生成），回落 .workbuddy/memory（存量项目兼容）
if [ -d "${PROJECT_ROOT}/.vibe-coding/memory" ]; then
    MEMORY_DIR="${PROJECT_ROOT}/.vibe-coding/memory"
elif [ -d "${PROJECT_ROOT}/.workbuddy/memory" ]; then
    MEMORY_DIR="${PROJECT_ROOT}/.workbuddy/memory"
else
    MEMORY_DIR="${PROJECT_ROOT}/.vibe-coding/memory"  # 默认新位置，写入时由脚本创建
fi
AUDIT_FILE="${MEMORY_DIR}/HEALTH_AUDIT.md"
STATE_FILE="${MEMORY_DIR}/.health_state"
# TOOLKIT_DIR 在 check_skills 内按脚本同源推导（scripts/health-check → 上两级为安装根），不写死全局路径（消除越界读误判）
NOW_TS="$(date '+%Y-%m-%d %H:%M:%S')"
TODAY="$(date '+%Y-%m-%d')"
DATE_TAG="$(date '+%Y-%m-%d')"

# ---------- 参数 ----------
ONLY=""
MODE="scan"
RESP_LEVEL=""
RESP_CHOICE=""
if [ "${1:-}" = "--only" ]; then
    ONLY="${2:-}"
elif [ "${1:-}" = "--respond" ]; then
    MODE="respond"
    RESP_LEVEL="${2:-}"
    RESP_CHOICE="${3:-}"
fi

# ---------- 审计文件保障（缺失自动创建，不报错）----------
ensure_audit() {
    mkdir -p "$MEMORY_DIR"
    if [ ! -f "$AUDIT_FILE" ]; then
        {
            echo "# 项目体检审计日志（HEALTH_AUDIT.md）"
            echo "> 由 health-check Skill 自动追加。记录每次巡检结果、人类选择、修复任务 ID。"
            echo "> 本文件为审计留痕，仅 health-check 写入；请勿手工删除历史。"
            echo ""
        } > "$AUDIT_FILE"
    fi
}

# ============================================
# --respond：错误判断识别分支（无 AI 裁量，按级别死值判定用户选择合法/违规）
# 用法：check.sh --respond <P0|P1|P2> "<用户选择>"
# 说明：本模式为一次性判定（stateless）——识别单次选择是否违规并输出对应警告话术；
#       多轮升级（首次→二次→兜底）为 AI 对话行为，见 SKILL.md「错误判断拦截规则」。
# ============================================
do_respond() {
    ensure_audit
    level="$RESP_LEVEL"
    choice="$RESP_CHOICE"
    msg=""
    result=""
    case "$level" in
        P0|p0)
            case "$choice" in
                1|同意|同意新开紧急修复任务|同意重建)
                    msg="✅ 已确认：将新开紧急修复任务。若治理骨架已丢失，需调用 vibe-project-init 重建骨架。"
                    result="用户同意，放行" ;;
                同意*)
                    msg="请确认：是否调用 vibe-project-init 重建骨架？（P0 治理骨架损坏，必须靠重建修复）"
                    result="用户同意但未指向重建，追问 vibe-project-init" ;;
                *)
                    msg="❌ 你的选择不符合 P0 级问题处理规则：治理骨架坏了，必须马上修，不然项目就废了。请重新选择：1. 同意新开紧急修复任务"
                    result="识别到 P0 错误判断，已发出第一次警告" ;;
            esac ;;
        P1|p1)
            case "$choice" in
                1|立即|立即新开修复任务|立即修复)
                    msg="✅ 已确认：将立即新开修复任务。"
                    result="用户选立即修复，放行" ;;
                2|稍后|稍后修复|稍后修复（24小时内必须处理）)
                    msg="⚠️ 你选择稍后修复：24 小时内必须处理，届时会再次提醒。请确认在 24 小时内处理？"
                    result="用户选稍后修复，已提示 24h 时限" ;;
                *)
                    msg="❌ 你的选择不符合 P1 级问题处理规则：项目没法正常往下走了，不修就会产生废结果。请重新选择：1. 立即新开修复任务　2. 稍后修复（24 小时内必须处理）"
                    result="识别到 P1 错误判断，已发出第一次警告" ;;
            esac ;;
        P2|p2)
            case "$choice" in
                2|忽略|忽略（默认）|"")
                    msg="✅ 已忽略该轻微偏差（默认）。"
                    result="用户忽略，放行" ;;
                1|新开优化任务|优化)
                    msg="请明确需要优化的具体内容？（P2 仅限规范对齐，不含业务逻辑改动）"
                    result="用户选优化，追问具体内容" ;;
                *)
                    msg="❌ 你的选择不符合 P2 级问题处理规则。请重新选择：1. 新开优化任务　2. 忽略（默认）"
                    result="识别到 P2 错误判断，已发出第一次警告" ;;
            esac ;;
        *)
            echo "[health-check] ERROR_SCAN_FAILED：未知级别「${level}」。体检工具异常，请检查版本。" >&2
            log_raw "ERROR" "未知级别「${level}」，退出"
            exit 2 ;;
    esac
    echo "$msg"
    printf '[%s] 错误判断拦截：级别=%s，用户选择=%s，处理结果=%s\n' "$NOW_TS" "$level" "$choice" "$result" >> "$AUDIT_FILE"
    exit 0
}

if [ "$MODE" = "respond" ]; then
    do_respond
fi

# ---------- 结果收集 ----------
P0_MSGS=()
P1_MSGS=()
P2_MSGS=()
LINE1="巡检项1 任务状态一致性: 未运行"
LINE2="巡检项2 契约完整性:     未运行"
LINE3="巡检项3 Skill版本一致性: 未运行"
LINE4="巡检项4 跨模块合规性:     未运行"
LINE5="巡检项5 日志大小:         未运行"
LINE6="巡检项6 TASKS格式:       未运行"
GIT_WARN=""

add_p0() { P0_MSGS+=("$1"); }
add_p1() { P1_MSGS+=("$1"); }
add_p2() { P2_MSGS+=("$1"); }

# ---------- 日期转 epoch（GNU date 优先，失败回退空）----------
date_epoch() {
    date -d "$1" +%s 2>/dev/null || echo ""
}

# ============================================
# 巡检项 1 — 任务状态一致性（防假成功）
# ============================================
check_tasks() {
    checked=0; bad=0; nocommit=0
    # Git 可用性降级
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        GIT_WARN="WARNING_GIT_DISABLED"
        LINE1="巡检项1 任务状态一致性: ⚠ 跳过（WARNING_GIT_DISABLED，Git 未初始化）"
        return 0
    fi
    for f in "$PROJECT_ROOT"/TASKS-*.md; do
        [ -f "$f" ] || continue
        # 逐块提取：当前 task id + 每个 "✅ 已完成" 行的 commit id
        while IFS='|' read -r tid cid; do
            [ -z "$tid" ] && [ -z "$cid" ] && continue
            if [ -z "$cid" ]; then
                nocommit=$((nocommit + 1))
                continue
            fi
            checked=$((checked + 1))
            if git rev-parse -q --verify "${cid}^{commit}" >/dev/null 2>&1; then
                :
            else
                bad=$((bad + 1))
                add_p1 "任务 ${tid} 标记 ✅ 已完成 但 commit ${cid} 在 git 中不存在（疑似假成功）— 见 $(basename "$f")"
            fi
        done <<EOF
$(awk '
    /^### \[/ {
        s=index($0,"["); e=index($0,"]")
        if (s>0 && e>s) tid=substr($0,s+1,e-s-1)
        next
    }
    /^\*\*状态\*\*:.*✅ 已完成/ {
        cid=""
        p=index($0,"**commit**:")
        if (p>0) {
            rest=substr($0, p+length("**commit**:"))
            sub(/^ */,"",rest)
            n=split(rest, arr, " ")
            if (n>0) cid=arr[1]
        }
        print tid "|" cid
    }
' "$f")
EOF
    done
    if [ -n "$GIT_WARN" ]; then return 0; fi
    if [ "$bad" -gt 0 ]; then
        LINE1="巡检项1 任务状态一致性: ⚠ P1 — ${bad} 个已完成任务 commit 不存在（核验 ${checked} 个，另 ${nocommit} 个无 commit 未核验）"
    else
        LINE1="巡检项1 任务状态一致性: ✅ 通过（核验 ${checked} 个 commit 全真实，另 ${nocommit} 个无 commit 未核验）"
    fi
}

# ============================================
# 巡检项 2 — 契约完整性（两步：存在性 P0 / 待裁决超时 P1）
# ============================================
check_contract() {
    contract="${PROJECT_ROOT}/CONTRACT.md"
    cross="${PROJECT_ROOT}/CROSS_IMPACT_LOG.md"
    missing=0
    # 第一步：存在性（任一缺失 → P0 框架失效）
    if [ ! -f "$contract" ]; then
        add_p0 "契约文件缺失：CONTRACT.md 不存在（框架失效）"
        missing=$((missing + 1))
    fi
    if [ ! -f "$cross" ]; then
        add_p0 "契约文件缺失：CROSS_IMPACT_LOG.md 不存在（框架失效）"
        missing=$((missing + 1))
    fi
    # 第二步：待裁决超时（仅当 CROSS_IMPACT_LOG.md 存在）
    overdue=0; pend=0
    if [ -f "$cross" ]; then
        now_epoch="$(date +%s)"
        while IFS= read -r d; do
            [ -z "$d" ] && continue
            pend=$((pend + 1))
            de="$(date_epoch "$d")"
            if [ -n "$de" ] && [ -n "$now_epoch" ]; then
                age=$((now_epoch - de))
                if [ "$age" -gt 86400 ]; then
                    overdue=$((overdue + 1))
                    add_p1 "CROSS_IMPACT_LOG 待裁决项 [${d}] 已超 24h 未更新（超时约 $((age / 3600))h）"
                fi
            else
                # 回退：无 GNU date 时按字符串比较，日期早于今天即视为超时
                if [ "$d" \< "$TODAY" ]; then
                    overdue=$((overdue + 1))
                    add_p1 "CROSS_IMPACT_LOG 待裁决项 [${d}] 早于今日，视为超 24h 未更新"
                fi
            fi
        done <<EOF
$(awk '
    # 格式强依赖：待裁决项必须为 "### [YYYY-MM-DD] 描述" 格式
    # 若格式改为 "### YYYY-MM-DD 描述"，需调整下方 substr 截取逻辑
    /^## / { insec = ($0 ~ /待裁决/) ? 1 : 0; next }
    insec && /^### \[/ {
        s=index($0,"["); e=index($0,"]")
        if (s>0 && e>s) print substr($0,s+1,e-s-1)
    }
' "$cross")
EOF
    fi
    if [ "$missing" -gt 0 ]; then
        LINE2="巡检项2 契约完整性:     ⚠ P0 — ${missing} 个关键契约文件缺失"
    elif [ "$overdue" -gt 0 ]; then
        LINE2="巡检项2 契约完整性:     ⚠ P1 — ${overdue}/${pend} 个待裁决项超 24h"
    else
        LINE2="巡检项2 契约完整性:     ✅ 通过（契约文件齐全，待裁决 ${pend} 项均在 24h 内）"
    fi
}

# ============================================
# 巡检项 3 — 治理工具版本一致性（单包模型：比对项目登记表 vs 已装 umbrella 版本）
# 设计（用户 2026-08-08 决策）：vibe-coding-toolkit 为单包（1 个 slug + 4 子命令共享 1 个版本号），
#   故巡检项3 仅比对「项目登记表 SKILL_REGISTRY.md 登记的 toolkit 版本」与「已安装的 umbrella skill.json 版本」，
#   不再逐个扫描全局 ~/.workbuddy/skills（消除 ClawHub 越界读误判）。
# 同源定位：TOOLKIT_DIR 由脚本自身路径推导（scripts/health-check → 上两级为安装根），不写死任何全局路径。
# ============================================
check_skills() {
    # 同源定位 umbrella 安装根（scripts/health-check/check.sh → ../../）
    TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." >/dev/null 2>&1 && pwd)"
    if [ ! -f "${TOOLKIT_DIR}/skill.json" ]; then
        add_p2 "无法定位 vibe-coding-toolkit 安装根（skill.json 缺失），跳过版本核对"
        LINE3="巡检项3 工具版本一致性: ⚠ P2 — umbrella skill.json 缺失"
        return 0
    fi
    installed="$(sed -n 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*//p' "${TOOLKIT_DIR}/skill.json" | head -1 | tr -d '",' | tr -d '[:space:]')"
    registry="${MEMORY_DIR}/SKILL_REGISTRY.md"
    if [ ! -f "$registry" ]; then
        # 项目未接入治理（无登记表）属正常，仅提示已装版本，不报 P2
        LINE3="巡检项3 工具版本一致性: ✅ 通过（无登记表；已装 vibe-coding-toolkit v${installed}）"
        return 0
    fi
    # 提取登记表版本：优先匹配 vibe-coding-toolkit 行；否则取首个有效版本（向前兼容旧多 skill 登记表）
    rver="$(awk '
        /^## 当前生效Skill列表/ { insec=1; next }
        insec && /^## / { insec=0 }
        insec && /^\|/ {
            n=split($0, a, "|")
            name=a[2]; ver=a[3]
            gsub(/^ +| +$/,"",name); gsub(/^ +| +$/,"",ver)
            if (name ~ /vibe-coding-toolkit/) { print ver; exit }
        }
    ' "$registry")"
    if [ -z "$rver" ]; then
        rver="$(awk '
            /^## 当前生效Skill列表/ { insec=1; next }
            insec && /^## / { insec=0 }
            insec && /^\|/ {
                n=split($0, a, "|")
                name=a[2]; ver=a[3]
                gsub(/^ +| +$/,"",name); gsub(/^ +| +$/,"",ver)
                if (name == "" || name == "Skill名称") next
                if (name ~ /^-+$/) next
                print ver; exit
            }
        ' "$registry")"
    fi
    if [ -z "$rver" ]; then
        LINE3="巡检项3 工具版本一致性: ✅ 通过（登记表无版本条目；已装 v${installed}）"
        return 0
    fi
    rver_norm="${rver#v}"
    if [ "$installed" != "$rver_norm" ]; then
        add_p2 "vibe-coding-toolkit 版本不一致（登记表 ${rver} vs 已装 ${installed}）— 建议统一版本号"
        LINE3="巡检项3 工具版本一致性: ⚠ P2 — 版本不一致（登记 ${rver} vs 已装 ${installed}）"
    else
        LINE3="巡检项3 工具版本一致性: ✅ 通过（登记 v${rver} = 已装 v${installed}）"
    fi
}

# ============================================
# 巡检项 4 — 跨模块改文件（P1，AI 行为合规，无 AI 裁量）
# 规则（焊死）：扫最近 50 条 commit，提取提交者(映射 AI 角色)与修改文件前缀；
#   若 AI 角色的归属模块与修改文件前缀不匹配，且 CROSS_IMPACT_LOG.md 的
#   ## 待裁决 段下无对应日期登记项 → 判定 P1。
# 注：commit 作者非 ai-pc/ai-android/ai-cloud 的直接跳过（非 AI 提交不检）。
# ============================================
check_cross_module() {
    over=0
    mkdir -p "$MEMORY_DIR"
    cross="${PROJECT_ROOT}/CROSS_IMPACT_LOG.md"
    tmp_commits="${MEMORY_DIR}/.hc_ai_commits"
    tmp_vio="${MEMORY_DIR}/.hc_cross_vio"
    : > "$tmp_vio"
    # 收集最近 50 条 commit 的 作者|hash（%n 保证每行结尾换行，避免 while read 丢弃最后一行）
    git log --pretty=format:"%an|%H%n" --max-count=50 2>/dev/null > "$tmp_commits"
    while IFS='|' read -r author commit; do
        [ -z "$author" ] && continue
        case "$author" in
            "ai-pc")      module_prefix="pc/" ;;
            "ai-android") module_prefix="android/" ;;
            "ai-cloud")   module_prefix="cloud/" ;;
            *) continue ;;   # 非 AI 提交直接跳过
        esac
        # 收集该 commit 修改的文件（写入临时文件，避免管道子 shell 变量丢失）
        # --root：首个提交无父提交，默认 diff-tree 无输出，须加 --root 才能列出其文件
        git diff-tree --no-commit-id --name-only -r --root "$commit" 2>/dev/null | while IFS= read -r file; do
            [ -z "$file" ] && continue
            # 文件前缀不属于该 AI 的归属模块
            if [ "${file#$module_prefix}" = "$file" ]; then
                hit=0
                cts="$(git log -1 --pretty=format:%ct "$commit" 2>/dev/null)"
                cdate=""
                [ -n "$cts" ] && cdate="$(date -d "@$cts" +%Y-%m-%d 2>/dev/null)"
                if [ -n "$cdate" ] && [ -f "$cross" ]; then
                    if grep -q "### \[${cdate}\]" "$cross" 2>/dev/null; then
                        hit=1
                    fi
                fi
                if [ "$hit" -eq 0 ]; then
                    echo "AI角色${author}越权修改非所属模块文件：${file}（未在CROSS_IMPACT_LOG.md登记待裁决项）" >> "$tmp_vio"
                fi
            fi
        done
    done < "$tmp_commits"
    # 父作用域统计违规（从临时文件读回，规避子 shell 变量丢失）
    while IFS= read -r v; do
        [ -z "$v" ] && continue
        over=$((over + 1))
        add_p1 "$v"
    done < "$tmp_vio"
    rm -f "$tmp_commits" "$tmp_vio"
    if [ "$over" -gt 0 ]; then
        LINE4="巡检项4 跨模块合规性: ⚠ P1 — ${over} 次越权修改未登记"
    else
        LINE4="巡检项4 跨模块合规性: ✅ 通过（无越权修改 / 无 AI 提交）"
    fi
}

# ============================================
# 巡检项 5 — 审计日志大小（P2，整洁类，纯规则）
# HEALTH_AUDIT.md 超过 10MB（10485760 字节）→ 判定 P2。
# ============================================
check_log_size() {
    if [ -f "$AUDIT_FILE" ]; then
        size=$(wc -c < "$AUDIT_FILE")
        if [ "$size" -gt 10485760 ]; then
            LINE5="巡检项5 日志大小: ⚠ P2 — 日志超 10MB（当前 $((size / 1048576))MB）"
            add_p2 "HEALTH_AUDIT.md 日志大小超过 10MB（当前 $((size / 1048576))MB），建议归档"
        else
            LINE5="巡检项5 日志大小: ✅ 通过（日志大小正常）"
        fi
    else
        LINE5="巡检项5 日志大小: ✅ 通过（日志不存在）"
    fi
}

# ============================================
# 巡检项 6 — TASKS 格式合规性（P2，纯规则）
# 对齐本仓库真实格式：任务块为 `## [ID]` + `**状态**: <取值>`。
# 规则（焊死）：每处 `**状态**:` 的取值必须以合法状态 token 开头
#   ∈ {📋 待处理, 🔄 处理中, ✅ 已完成, ⏸ 暂挂, ✅ coordinator确认}；
#   允许末尾附加说明（如 commit hash、日期、审查备注），故用「开头匹配」而非全等；
#   `✅ coordinator确认` 为本仓库保留的 git 检查结果显示态（经用户 2026-07-20 裁定保留）。
#   不在集合内 → 判定 P2。汇总表表头行（含 任务/状态 等列名）无 `**状态**:`，不误伤。
# 注：优化文档原假设 `|` 表格式 + 3 态 + [PC|ANDROID|CLOUD] ID，与本仓库格式不符，
#     故对齐本仓库真实格式实现，避免医生误诊自身治理文件。
# ============================================
check_tasks_format() {
    bad=0
    mkdir -p "$MEMORY_DIR"
    tmp_fmt="${MEMORY_DIR}/.hc_fmt"
    : > "$tmp_fmt"
    for f in "$PROJECT_ROOT"/TASKS-*.md; do
        [ -f "$f" ] || continue
        awk -v fn="$f" '
            /\*\*状态\*\*:/ {
                v = $0
                sub(/.*\*\*状态\*\*:[[:space:]]*/, "", v)
                sub(/\*\*.*/, "", v)   # POSIX 兼容：移除首个 ** 及其后内容（替代依赖 RSTART 的写法，行为一致）
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
                # 跳过文档示例/占位行，避免医生误诊自身治理文件：
                #   ① 取值以 < 开头（如「**状态**: <取值>」示例）；② 整行含反引号（代码块示例）。
                #   真实状态值必以合法 emoji token 开头，绝不会以 < 或反引号起头。
                if (v ~ /^</ || v ~ /`/) next
                if (v !~ /^(📋 待处理|🔄 处理中|✅ 已完成|⏸ 暂挂|✅ coordinator ?确认)/) {
                    print fn " 行 " NR "：非法状态值「" v "」（应以 📋 待处理 / 🔄 处理中 / ✅ 已完成 / ⏸ 暂挂 / ✅ coordinator确认 之一开头）"
                }
            }
        ' "$f" >> "$tmp_fmt"
    done
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        bad=$((bad + 1))
        add_p2 "$line"
    done < "$tmp_fmt"
    rm -f "$tmp_fmt"
    if [ "$bad" -gt 0 ]; then
        LINE6="巡检项6 TASKS格式: ⚠ P2 — ${bad} 处状态值不合规"
    else
        LINE6="巡检项6 TASKS格式: ✅ 通过（所有 **状态**: 取值合规）"
    fi
}

# ============================================
# 执行
# ============================================
case "$ONLY" in
    tasks)    check_tasks ;;
    contract) check_contract ;;
    skills)   check_skills ;;
    cross)    check_cross_module ;;
    log)      check_log_size ;;
    fmt)      check_tasks_format ;;
    "")       check_tasks; check_contract; check_skills; check_cross_module; check_log_size; check_tasks_format ;;
    *)        echo "[health-check] ERROR_SCAN_FAILED：未知 --only 参数「${ONLY}」。体检工具异常，请检查版本。" >&2; exit 2 ;;
esac

n2=${#P2_MSGS[@]}

# ---------- 连续未清除计数（仅全量运行时维护；冻结功能留 TODO）----------
streak=0
if [ -z "$ONLY" ]; then
    prev=0
    [ -f "$STATE_FILE" ] && prev="$(cat "$STATE_FILE" 2>/dev/null || echo 0)"
    case "$prev" in ''|*[!0-9]*) prev=0 ;; esac
    n0=${#P0_MSGS[@]}; n1=${#P1_MSGS[@]}
    if [ "$n0" -gt 0 ] || [ "$n1" -gt 0 ]; then
        streak=$((prev + 1))
    else
        streak=0
    fi
    mkdir -p "$MEMORY_DIR"
    echo "$streak" > "$STATE_FILE"
fi

# ---------- 连续未清除提示（仅透明提示，不自动升级严重度）----------
# 规则（用户 2026-08-08 决策）：streak 仅用于提醒「同一问题反复出现」，绝不改变本次判定等级；
#   P1 保持 P1，不自动升 P0（避免隐藏历史篡改当前仓库结论）。
n0=${#P0_MSGS[@]}; n1=${#P1_MSGS[@]}

# ---------- 写前披露（ClawHub 信任边界要求：写文件前明确提示用户）----------
echo "[health-check] 即将写入审计日志（${AUDIT_FILE#$PROJECT_ROOT/}）与连续计数（.health_state）；此为 skill 正常功能，不读取项目外任何文件。" >&2
# ---------- 写审计日志（自动创建，不报错）----------
ensure_audit
{
    echo "## 体检 ${NOW_TS}${ONLY:+（单项：${ONLY}）}"
    echo "- ${LINE1}"
    echo "- ${LINE2}"
    echo "- ${LINE3}"
    echo "- ${LINE4}"
    echo "- ${LINE5}"
    echo "- ${LINE6}"
    [ -n "$GIT_WARN" ] && echo "- 降级: ${GIT_WARN}"
    echo "- 结论: P0=${n0} P1=${n1} P2=${n2}"
    if [ -z "$ONLY" ]; then
        echo "- 连续未清除计数(P0/P1)=${streak}（仅提示，等级不变；P1 不会自动升 P0）"
    fi
    i=0; while [ "$i" -lt "$n0" ]; do echo "  - [P0] ${P0_MSGS[$i]}"; i=$((i+1)); done
    i=0; while [ "$i" -lt "$n1" ]; do echo "  - [P1] ${P1_MSGS[$i]}"; i=$((i+1)); done
    i=0; while [ "$i" -lt "$n2" ]; do echo "  - [P2] ${P2_MSGS[$i]}"; i=$((i+1)); done
    echo ""
} >> "$AUDIT_FILE"

# ---------- 控制台报告 ----------
echo "[health-check] 体检报告 ${NOW_TS}"
# 结论先行摘要（红黄蓝绿，一眼看懂）
if [ "$n0" -gt 0 ]; then
    echo "🔴 体检结果：发现 ${n0} 个致命问题（P0），需立即处理！"
elif [ "$n1" -gt 0 ]; then
    echo "🟡 体检结果：发现 ${n1} 个合规问题（P1），需择期处理。"
elif [ "$n2" -gt 0 ]; then
    echo "🔵 体检结果：发现 ${n2} 个轻微偏差（P2），可忽略。"
else
    echo "🟢 体检结果：全部通过，状态良好。"
fi
echo "────────────────────────────────"
echo "$LINE1"
echo "$LINE2"
echo "$LINE3"
echo "$LINE4"
echo "$LINE5"
echo "$LINE6"
echo "────────────────────────────────"

if [ "$n0" -eq 0 ] && [ "$n1" -eq 0 ] && [ "$n2" -eq 0 ]; then
    echo "✅ 体检通过，未发现隐患"
else
    i=0; while [ "$i" -lt "$n0" ]; do
        echo "发现致命问题（P0）：${P0_MSGS[$i]}。任务流转已锁定（声明式）。必须立即新开紧急修复任务（通常需调用 vibe-project-init 重建骨架）。唯一选项：1. 同意新开紧急修复任务（无「暂不处理」，拒绝即触发兜底）"
        i=$((i+1))
    done
    i=0; while [ "$i" -lt "$n1" ]; do
        echo "发现合规问题（P1）：${P1_MSGS[$i]}。请选择处置方式：1. 立即新开修复任务　2. 稍后修复（24小时内必须处理）"
        i=$((i+1))
    done
    i=0; while [ "$i" -lt "$n2" ]; do
        echo "发现轻微偏差（P2）：${P2_MSGS[$i]}。给你两个选项：1. 新开任务对齐　2. 忽略（默认）"
        i=$((i+1))
    done
fi

if [ -z "$ONLY" ] && [ "$streak" -ge 3 ]; then
    echo "ℹ️ 已连续 ${streak} 次体检发现 P0/P1 未清除（仅供参考；本次结论仍以当前仓库状态为准，P1 不会自动升 P0）"
fi

echo "已写入审计: ${AUDIT_FILE#$PROJECT_ROOT/}"
log_raw "SUCCESS" "health-check 完成：审计已写入 ${AUDIT_FILE#$PROJECT_ROOT/}（P0=${n0:-0}，P1=${n1:-0}，P2=${n2:-0}）"
exit 0
