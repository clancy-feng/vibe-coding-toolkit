#!/bin/bash
set -euo pipefail

# ============================================
# task-manager.sh — Vibe 项目内部执行引擎（Windows Git Bash兼容版）
# 修正说明：修复flock依赖、sed多行匹配、前缀校验、存量任务迁移等问题
# ============================================

# ---------- 核心路径配置 ----------
find_project_root() {
    local dir="$(pwd)"
    while [ "$dir" != "/" ]; do
        if [ -d "$dir/.git" ]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    echo "{\"success\":false,\"code\":\"PROJECT_ROOT_NOT_FOUND\",\"message\":\"未找到项目根目录（无.git文件夹），请在项目根目录下调用本脚本\"}" >&2
    exit 1
}
PROJECT_ROOT="$(find_project_root)"
MEMORY_DIR="${PROJECT_ROOT}/.workbuddy/memory"
CACHE_DIR="${PROJECT_ROOT}/.cache/task-manager"
TASKS_BASE="${PROJECT_ROOT}"
COMMIT_CHECK_SCRIPT="${HOME}/.workbuddy/skills/commit-check/scripts/commit-check.sh"
LOCK_TIMEOUT=2
MAX_LOCK_RETRY=5
LOCKFILE=""  # 全局锁文件，供trap使用

# ---------- 工具函数 ----------
log_debug() { echo "[DEBUG] $1" >&2; }
error_exit() {
    local code="$1"
    local msg="$2"
    echo "{\"success\":false,\"code\":\"$code\",\"message\":\"$msg\"}"
    exit 1
}
success_exit() {
    local data="$1"
    echo "{\"success\":true,\"code\":\"TASK_OPERATION_SUCCESS\",\"message\":\"操作成功\",\"data\":$data}"
    exit 0
}

# ---------- 跨平台文件锁（无flock依赖）----------
acquire_lock() {
    local file="$1"
    LOCKFILE="${file}.pid"
    local retry=0
    while true; do
        if (set -o noclobber; echo $$ > "$LOCKFILE") 2>/dev/null; then
            trap 'rm -f "$LOCKFILE"' EXIT
            return 0
        fi
        if [ -f "$LOCKFILE" ]; then
            local lock_pid=$(cat "$LOCKFILE" 2>/dev/null || echo "")
            if [ -n "$lock_pid" ] && ! kill -0 "$lock_pid" 2>/dev/null; then
                rm -f "$LOCKFILE"
                continue
            fi
        fi
        if [ $retry -ge $MAX_LOCK_RETRY ]; then
            error_exit "LOCK_FAILED" "文件${file}加锁失败，超过最大重试次数${MAX_LOCK_RETRY}"
        fi
        log_debug "文件${file}锁冲突，第$((retry+1))次重试..."
        sleep "$LOCK_TIMEOUT"
        retry=$((retry+1))
    done
}

# ---------- 加载规则（兼容无合法前缀行场景）----------
load_rules() {
    local rules_file="${MEMORY_DIR}/RULES.md"
    local project_config="${MEMORY_DIR}/project.config"
    if [ ! -f "$rules_file" ]; then
        error_exit "RULES_NOT_FOUND" "未找到项目专属规则文件：${rules_file}"
    fi
    export RULES_FILE="$rules_file"
    export PROJECT_CONFIG="$project_config"
    # 默认合法前缀，优先从project.config读
    VALID_PREFIXES="PC,ANDROID,CLOUD,MEMORY,DOCS,FIX,TOOL"
    if [ -f "$project_config" ]; then
        VALID_PREFIXES=$(sed -n 's/^VALID_PREFIXES=\([^[:space:]]*\).*/\1/p' "$project_config" 2>/dev/null)
        [ -z "$VALID_PREFIXES" ] && VALID_PREFIXES="PC,ANDROID,CLOUD,MEMORY,DOCS,FIX,TOOL"
    fi
    log_debug "加载合法前缀：${VALID_PREFIXES}"
}

# ---------- 权限校验（修正版：大小写统一）----------
check_permission() {
    local module="$1"
    local actor="$2"
    # coordinator有所有权限
    if [[ "$actor" == "coordinator" ]]; then
        return 0
    fi
    # AI角色格式为ai-<模块名>，提取模块名后转小写比对
    if [[ "$actor" =~ ai-(.*) ]]; then
        local ai_module="${BASH_REMATCH[1],,}"  # ${var,,} 转小写
        local target_module="${module,,}"        # 目标模块也转小写
        if [[ "$ai_module" == "$target_module" ]]; then
            return 0
        fi
    fi
    error_exit "PERMISSION_DENIED" "操作主体$actor无模块$module的操作权限（AI角色需匹配ai-<模块名小写>，如ai-pc对应PC模块）"
}

# ---------- 任务ID生成 ----------
generate_task_id() {
    local module="$1"
    local date_str=$(date "+%Y-%m-%d")
    local seq_file="${CACHE_DIR}/${module}_seq"
    mkdir -p "$(dirname "$seq_file")"
    local seq=1
    if [ -f "$seq_file" ]; then
        seq=$(( $(cat "$seq_file") + 1 ))
    fi
    echo "$seq" > "$seq_file"
    echo "${date_str}-${module}-$(printf "%03d" "$seq")"
}

# ---------- Handler：迁移存量任务 ----------
handle_migrate() {
    local module="$1"
    local tasks_file="${TASKS_BASE}/TASKS-${module}.md"
    [ -f "$tasks_file" ] || error_exit "TASKS_NOT_FOUND" "任务文件${tasks_file}不存在"
    log_debug "迁移${module}存量任务..."
    sed -i -E "s/### #([0-9]+) (.*)/echo \"### [$(date '+%Y-%m-%d')-${module}-\$(printf '%03d' \1)] \2\"/e" "$tasks_file"
    echo "1" > "${CACHE_DIR}/${module}_seq"
    success_exit "{\"module\":\"$module\",\"status\":\"migrated\"}"
}

# ---------- Handler：创建任务 ----------
handle_create() {
    local module="$1" title="$2" actor="$3" problem="$4" change="${5:-}" verify="${6:-}"
    # 强制校验：问题描述必须提供且不能为空壳（根治 create 产出 [待补充] 空壳）
    if [ -z "$problem" ] || [ "$problem" = "[待补充]" ]; then
        error_exit "CREATE_INCOMPLETE" "问题描述不能为空，请 Coordinator 先根据用户自然语言提炼问题后再创建"
    fi
    check_permission "$module" "$actor"
    local task_id=$(generate_task_id "$module")
    local tasks_file="${TASKS_BASE}/TASKS-${module}.md"
    acquire_lock "$tasks_file"
    # 创建时即写入结构化任务内容：问题描述必填（来自 Coordinator 对用户需求的提炼）；
    # 变更内容/验证结果在任务完成前通常未知，允许占位 [待补充]
    cat >> "$tasks_file" << EOF

---
### [${task_id}] ${title}
**状态**: 📋 待处理
**创建者**: ${actor}
**创建时间**: $(date "+%Y-%m-%d %H:%M:%S")
**描述**: ${problem}

### 问题描述
${problem}
### 变更内容
${change:-[待补充]}
### 验证结果
${verify:-[待补充]}
---
EOF
    success_exit "{\"task_id\":\"$task_id\",\"module\":\"$module\",\"status\":\"pending\"}"
}

# ---------- Handler：更新待认领任务内容 ----------
handle_update() {
    local task_id="$1" field="$2" value="$3" actor="${4:-coordinator}"
    # 校验字段合法
    case "$field" in
        title|problem|change|verify|desc) ;;
        *) error_exit "UPDATE_INVALID_FIELD" "不支持的字段：${field}（仅支持 title/problem/change/verify/desc）" ;;
    esac
    local module=$(echo "$task_id" | cut -d'-' -f4)
    check_permission "$module" "$actor"
    local tasks_file="${TASKS_BASE}/TASKS-${module}.md"
    [ -f "$tasks_file" ] || error_exit "TASKS_NOT_FOUND" "任务文件${tasks_file}不存在"

    # 仅允许更新 📋 待处理 的任务（保护已认领/已完成任务的执行承诺，避免覆盖团队工作）
    local current_status=$(awk -v tid="$task_id" '
        found && /^---$/ {exit}
        found && /\*\*状态\*\*: / {print $2; exit}
        $0 ~ "### \\[" tid "\\]" {found=1}
    ' "$tasks_file")
    if [ -z "$current_status" ]; then
        error_exit "TASK_NOT_FOUND" "任务${task_id}不存在（未找到匹配的任务块）"
    fi
    if [ "$current_status" != "📋" ]; then
        error_exit "UPDATE_NOT_ALLOWED" "任务${task_id}当前状态为${current_status}，已认领或已完成，不可直接修改内容；如需变更请新建衍生任务并在其描述中关联原任务${task_id}"
    fi

    # 问题描述不允许空壳
    if [ "$field" = "problem" ] && { [ -z "$value" ] || [ "$value" = "[待补充]" ]; }; then
        error_exit "UPDATE_INCOMPLETE" "问题描述不能为空，请 Coordinator 先根据用户自然语言提炼问题后再更新"
    fi

    acquire_lock "$tasks_file"
    local ts=$(date "+%Y-%m-%d %H:%M:%S")
    # 通过环境变量传值，避免 -v 对反斜杠/特殊字符的转义处理导致内容损坏
    TM_TID="$task_id" TM_FIELD="$field" TM_VAL="$value" TM_TS="$ts" TM_ACTOR="$actor" awk '
        function emit_audit() {
            if (recording) { print ENVIRON["TM_VAL"]; recording=0 }
            for (i = 1; i <= na; i++) print audits[i]
            print "**更新**: " ENVIRON["TM_TS"] " " ENVIRON["TM_ACTOR"] " 修改了字段 " ENVIRON["TM_FIELD"]
            na = 0
        }
        $0 ~ "^### \\[" ENVIRON["TM_TID"] "\\]" {
            if (ENVIRON["TM_FIELD"] == "title") {
                sub(/^### \[[^\]]*\] .*/, "### [" ENVIRON["TM_TID"] "] " ENVIRON["TM_VAL"])
            }
            print
            in_task=1
            next
        }
        in_task && /^### 问题描述$/ { if (recording) { print ENVIRON["TM_VAL"]; recording=0 }; print; if (ENVIRON["TM_FIELD"] == "problem") recording=1; next }
        in_task && /^### 变更内容$/  { if (recording) { print ENVIRON["TM_VAL"]; recording=0 }; print; if (ENVIRON["TM_FIELD"] == "change")  recording=1; next }
        in_task && /^### 验证结果$/ { if (recording) { print ENVIRON["TM_VAL"]; recording=0 }; print; if (ENVIRON["TM_FIELD"] == "verify")  recording=1; next }
        in_task && /^\*\*描述\*\*:/ {
            if (recording) { print ENVIRON["TM_VAL"]; recording=0 }
            if (ENVIRON["TM_FIELD"] == "desc") { print "**描述**: " ENVIRON["TM_VAL"]; next } else { print; next }
        }
        # 更新追溯行(**更新**:)是任务级 trailing 元数据：缓冲后在任务块末尾统一重放，避免被段落替换逻辑吞掉或错序
        in_task && /^\*\*更新\*\*:/ { audits[++na] = $0; next }
        in_task && /^---$/ { emit_audit(); in_task=0; print; next }
        END { if (in_task) emit_audit() }
        { if (recording) next; if (in_task) { print; next }; print }
    ' "$tasks_file" > "${tasks_file}.tmp" && mv "${tasks_file}.tmp" "$tasks_file"

    success_exit "{\"task_id\":\"$task_id\",\"module\":\"$module\",\"field\":\"$field\",\"status\":\"updated\"}"
}

# ---------- Handler：认领任务 ----------
handle_claim() {
    local task_id="$1" actor="$2"
    local module=$(echo "$task_id" | cut -d'-' -f4)
    check_permission "$module" "$actor"

    local tasks_file="${TASKS_BASE}/TASKS-${module}.md"
    acquire_lock "$tasks_file"

    # 用awk多行匹配检查是否已认领（和list逻辑完全一致）
    local current_status=$(awk -v tid="$task_id" '
        found && /^---$/ {exit}
        found && /\*\*状态\*\*: / {print $2; exit}
        $0 ~ "### \\[" tid "\\]" {found=1}
    ' "$tasks_file")

    if [ "$current_status" = "🔄" ]; then
        error_exit "TASK_ALREADY_CLAIMED" "任务${task_id}已被认领"
    fi
    if [ "$current_status" != "📋" ]; then
        error_exit "TASK_NOT_FOUND" "任务${task_id}不存在或状态异常"
    fi

    sed -i "/### \[${task_id}\]/,/^---/{s/\*\*状态\*\*: .*/**状态**: 🔄 处理中 **认领者**: ${actor} **认领时间**: $(date "+%Y-%m-%d %H:%M:%S")/}" "$tasks_file"
    # 校验 sed 是否真正改动了文件（防止 emoji/格式字节不匹配导致静默失败）
    local new_status
    new_status=$(awk -v tid="$task_id" 'found&&/^---$/{exit} found&&/\*\*状态\*\*: /{print $2;exit} $0~"### \\[" tid "\\]" {found=1}' "$tasks_file")
    if [ "$new_status" != "🔄" ]; then
        error_exit "CLAIM_FAILED" "认领失败：${task_id} 状态未从待处理变更（文件可能未修改或状态行格式异常）"
    fi
    success_exit "{\"task_id\":\"$task_id\",\"module\":\"$module\",\"status\":\"in_progress\",\"claimer\":\"$actor\"}"
}

# ---------- Handler：标记完成 ----------
handle_complete() {
    local task_id="$1" commit_id="$2" report="$3" actor="$4"
    local module=$(echo "$task_id" | cut -d'-' -f4)
    check_permission "$module" "$actor"

    # 校验commit前缀
    local commit_msg=$(git log --pretty=format:%s -1 "$commit_id" 2>/dev/null || echo "")
    local prefix=$(echo "$commit_msg" | sed -n 's/^\[\([^]]*\)\].*/\1/p')
    echo "$VALID_PREFIXES" | grep -qw "$prefix" || error_exit "RULE_VIOLATED" "前缀[$prefix]不符合要求，合法前缀：${VALID_PREFIXES}"

    # 校验Git状态
    local git_status="init"
    if [ -f "$PROJECT_CONFIG" ]; then
        git_status=$(sed -n 's/^GIT_STATUS=\([^[:space:]]*\).*/\1/p' "$PROJECT_CONFIG" 2>/dev/null)
        [ -z "$git_status" ] && git_status="init"
    fi
    if [ "$git_status" != "none" ] && ! git rev-parse --verify "$commit_id" >/dev/null 2>&1; then
        error_exit "COMMIT_INVALID" "commit $commit_id不存在"
    fi

    local tasks_file="${TASKS_BASE}/TASKS-${module}.md"
    acquire_lock "$tasks_file"

    # 用awk多行匹配检查是否已认领（和list逻辑完全一致）
    local current_status=$(awk -v tid="$task_id" '
        found && /^---$/ {exit}
        found && /\*\*状态\*\*: / {print $2; exit}
        $0 ~ "### \\[" tid "\\]" {found=1}
    ' "$tasks_file")

    if [ "$current_status" != "🔄" ]; then
        error_exit "TASK_NOT_CLAIMED" "任务${task_id}未被认领，当前状态：${current_status:-未知}"
    fi

    # 校验汇报模板
    echo "$report" | grep -q "### 问题描述" && echo "$report" | grep -q "### 变更内容" && echo "$report" | grep -q "### 验证结果" || error_exit "FORMAT_INCOMPLETE" "汇报模板不完整"

    # 更新状态
    sed -i "/### \[${task_id}\]/,/^---/{s/\*\*状态\*\*: .*/**状态**: ✅ 已完成 **commit**: ${commit_id} **完成时间**: $(date "+%Y-%m-%d %H:%M:%S")/}" "$tasks_file"
    # 校验 sed 是否真正改动了文件（防止 emoji/格式字节不匹配导致静默失败）
    local new_status
    new_status=$(awk -v tid="$task_id" 'found&&/^---$/{exit} found&&/\*\*状态\*\*: /{print $2;exit} $0~"### \\[" tid "\\]" {found=1}' "$tasks_file")
    if [ "$new_status" != "✅" ]; then
        error_exit "COMPLETE_FAILED" "完成失败：${task_id} 状态未变更为已完成（文件可能未修改或状态行格式异常）"
    fi

    # 将汇报中的三段内容写回任务文件对应段落（替换 [待补充] 占位），不再追加到文件末尾造成重复
    local r_problem r_change r_verify
    r_problem=$(printf '%s\n' "$report" | sed -n '/^### 问题描述$/,/^### 变更内容$/p' | sed '1d;$d')
    r_change=$(printf '%s\n' "$report" | sed -n '/^### 变更内容$/,/^### 验证结果$/p' | sed '1d;$d')
    r_verify=$(printf '%s\n' "$report" | sed -n '/^### 验证结果$/,$p' | sed '1d')
    awk -v tid="$task_id" -v prob="$r_problem" -v chg="$r_change" -v ver="$r_verify" '
        BEGIN { in_task=0; skipbody=0 }
        $0 ~ "### \\[" tid "\\]" { in_task=1; skipbody=0; print; next }
        in_task && /^---$/ { in_task=0; skipbody=0; print; next }
        in_task && /^### 问题描述$/ { print; if (prob!="") {print prob; skipbody=1} else {skipbody=0}; next }
        in_task && /^### 变更内容$/ { print; if (chg!="") {print chg; skipbody=1} else {skipbody=0}; next }
        in_task && /^### 验证结果$/ { print; if (ver!="") {print ver; skipbody=1} else {skipbody=0}; next }
        in_task && /^### / { skipbody=0; print; next }
        in_task && skipbody==1 { next }
        { print }
    ' "$tasks_file" > "${tasks_file}.tmp" && mv "${tasks_file}.tmp" "$tasks_file"

    # 跨端日志
    if echo "$report" | grep -q "跨端"; then
        local title=$(sed -n "s/^### \\[${task_id}\\] //p" "$tasks_file")
        local new_log="| $(date "+%Y-%m-%d") | ${module} | ${title} | 跨端影响 | ✅ 已更新 |"
        # 仅在 CONTRACT.md 存在时才尝试写入
        if [ -f "${MEMORY_DIR}/CONTRACT.md" ]; then
            grep -q "$new_log" "${MEMORY_DIR}/CONTRACT.md" || sed -i "/## 跨端影响日志/a $new_log" "${MEMORY_DIR}/CONTRACT.md"
        else
            # 记录 debug 日志，但不中断流程，因为跨端日志是辅助性的
            log_debug "警告：CONTRACT.md 不存在，跳过跨端日志更新。请检查项目初始化是否完整。"
        fi
    fi

    success_exit "{\"task_id\":\"$task_id\",\"module\":\"$module\",\"status\":\"done\",\"commit_id\":\"$commit_id\"}"
}

# ---------- Handler：审查任务 ----------
handle_review() {
    local task_id="$1" reviewer="$2"
    local module=$(echo "$task_id" | cut -d'-' -f4)
    check_permission "$module" "coordinator"
    local tasks_file="${TASKS_BASE}/TASKS-${module}.md"
    acquire_lock "$tasks_file"
    grep -qF "**状态**: ✅ 已完成" "$tasks_file" || error_exit "TASK_NOT_COMPLETED" "任务${task_id}未完成"
    local commit_id=$(sed -n 's/.*\*\*commit\*\*:[[:space:]]*\([a-f0-9][a-f0-9]*\).*/\1/p' "$tasks_file" | tail -1)
    [ -n "$commit_id" ] || error_exit "COMMIT_NOT_FOUND" "任务${task_id}未关联commit"
    if [ -f "$COMMIT_CHECK_SCRIPT" ]; then
        bash "$COMMIT_CHECK_SCRIPT" -m "$commit_id" -b >/dev/null 2>&1 || error_exit "COMMIT_CHECK_FAILED" "commit $commit_id 未通过验证"
    fi
    echo -e "\n**审查结果**: ✅ 通过（审查者：${reviewer} 时间：$(date "+%Y-%m-%d %H:%M:%S")）" >> "$tasks_file"
    success_exit "{\"task_id\":\"$task_id\",\"module\":\"$module\",\"review_status\":\"passed\",\"reviewer\":\"$reviewer\"}"
}

# ---------- Handler：查询任务 ----------
handle_list() {
    local module="$1" status="$2"
    local tasks_file="${TASKS_BASE}/TASKS-${module}.md"
    [ -f "$tasks_file" ] || success_exit "{\"tasks\":[]}"

    # 用awk一次性处理整个文件，避免变量作用域和子shell问题
    local json=$(awk -v filter="$status" '
        BEGIN { print "["; first=1; in_task=0; tid=""; task_status=""; }
        
        # 匹配任务开始行：### [2026-07-15-PC-003] 标题
        /^### \[/ {
            # 如果已经在任务块中，先输出上一个任务（如果有）
            if (in_task && tid != "" && (filter == "all" || task_status == filter)) {
                if (!first) printf ",";
                printf "{\"task_id\":\"%s\",\"status\":\"%s\"}", tid, task_status;
                first=0;
            }
            # 提取新任务的ID
            if (match($0, /^### \[[0-9]{4}-[0-9]{2}-[0-9]{2}-[A-Z]+-[0-9]+\]/)) {
                tid = substr($0, RSTART+5, RLENGTH-6);
                in_task=1;
                task_status="";
            }
        }
        
        # 在任务块内匹配状态行
        in_task && /\*\*状态\*\*: / {
            if (match($0, /\*\*状态\*\*: [^ ]+/)) {
                task_status = substr($0, RSTART + length("**状态**: "), RLENGTH - length("**状态**: "));
            }
        }
        
        # 遇到任务分隔符---，结束当前任务块
        /^---$/ {
            if (in_task && tid != "" && (filter == "all" || task_status == filter)) {
                if (!first) printf ",";
                printf "{\"task_id\":\"%s\",\"status\":\"%s\"}", tid, task_status;
                first=0;
            }
            in_task=0;
            tid="";
            task_status="";
        }
        
        END {
            # 处理文件末尾最后一个任务（可能没有---结尾的旧任务）
            if (in_task && tid != "" && (filter == "all" || task_status == filter)) {
                if (!first) printf ",";
                printf "{\"task_id\":\"%s\",\"status\":\"%s\"}", tid, task_status;
            }
            print "]";
        }
    ' "$tasks_file")

    success_exit "{\"tasks\":$json}"
}

# ---------- 主逻辑 ----------
main() {
    mkdir -p "$CACHE_DIR"
    load_rules
    local action="$1"
    shift
    case "$action" in
        migrate) handle_migrate "$@" ;;
        create) handle_create "$@" ;;
        claim) handle_claim "$@" ;;
        complete) handle_complete "$@" ;;
        review) handle_review "$@" ;;
        update) handle_update "$@" ;;
        list) handle_list "$@" ;;
        *) error_exit "INVALID_ACTION" "不支持的操作:$action" ;;
    esac
}

main "$@"