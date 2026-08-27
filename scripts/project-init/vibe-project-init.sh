#!/bin/bash
set -euo pipefail

# ── 安全读取项目本地 adapter.cfg 的白名单键值（绝不 source，防任意代码执行）──
# 用法：safe_cfg_get <key> <cfg_file>
# 仅允许治理键的「相对路径 / 简单布尔值」；拒绝绝对路径、含 shell 元字符的取值，
# 任一不满足则返回空串（上层回落默认），从而杜绝执行项目提供的任意代码。
safe_cfg_get() {
  local key="$1" cfg="$2" val=""
  [ -f "$cfg" ] || { echo ""; return; }
  val="$(grep -E "^[[:space:]]*${key}[[:space:]]*=" "$cfg" 2>/dev/null | head -n1 | sed -E "s/^[^=]*=[[:space:]]*//" | tr -d '[:space:]')"
  [ -z "$val" ] && { echo ""; return; }
  val="${val%\"}"; val="${val#\"}"
  val="${val%\'}"; val="${val#\'}"
  case "$val" in
    /*) echo ""; return ;;                                # 绝对路径，拒绝
    *[!.a-zA-Z0-9/_-]*) echo ""; return ;;                # 含非法字符，拒绝
  esac
    echo "$val"
}

# 安全读取空格分隔的列表（白名单键值提取，拒绝任意代码执行）。
# 逐段校验：仅允许相对路径字符（拒绝绝对路径 / shell 元字符），全段通过才返回，否则回落默认（空串）。
# 不 return 非 0，避免触发 set -e 退出调用方。通用安全读取工具。
safe_cfg_get_dirs() {
    local key="$1" cfg="$2" raw=""
    raw="$(grep -E "^[[:space:]]*${key}[[:space:]]*=" "$cfg" 2>/dev/null | head -n1 | sed -E "s/^[^=]*=[[:space:]]*//" | sed -E "s/^[[:space:]]*//; s/[[:space:]]*$//" | tr -d '"' | tr -d "'")"
    [ -z "$raw" ] && { echo ""; return 0; }
    local out="" seg ok=1
    for seg in $raw; do
        case "$seg" in
            /*|*[!.a-zA-Z0-9/_-]*) ok=0; break ;;   # 绝对路径或含非法字符，拒绝整段
        esac
        out="${out:+$out }$seg"
    done
    [ "$ok" -eq 1 ] && echo "$out" || echo ""
}

# ============================================
# vibe-project-init.sh — Vibe 项目初始化 Skill
# 对应 skill.md: skills/vibe-project-init/skill.md
# ============================================

# ---------- 项目根目录（向上查找 .git 或 .vibe-coding，治理根优先）----------
# 用于将 .workbuddy/memory 等路径明确限定在「项目工作区内」，从路径层面杜绝误写全局 ~/.workbuddy。
find_project_root() {
    local dir="$(pwd)"
    while [ "$dir" != "/" ]; do
        if [ -d "$dir/.git" ] || [ -d "$dir/.vibe-coding" ]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    echo ""
    # 未找到也返回 0：调用方以「结果是否为空」判断，避免 set -e 下命令替换失败直接退出。
    return 0
}
PROJECT_ROOT="$(find_project_root)"

# ---------- 配置区 ----------
CACHE_DIR=".cache/project-init"
COLLECTED_FILE="${CACHE_DIR}/collected.cfg"
QUESTION_INDEX="${CACHE_DIR}/question_index"
GITIGNORE=".gitignore"

# 【跨平台适配层 1.1.0】治理根目录统一为项目内 .vibe-coding/（与 .workbuddy/ 平级）
# 路径默认值写死在脚本内（不读项目 cfg 代码）；仅当 adapter.cfg 存在时用白名单提取
# COMMIT_RULES/HOOK_ENABLED 等少数可控键，绝不 source 整个 cfg（防任意代码执行）。
GOVERNANCE_DIR=".vibe-coding"
ADAPTER_CFG="${GOVERNANCE_DIR}/adapter.cfg"
# 默认值（与 adapter.cfg 模板一致）
COMMIT_RULES="${GOVERNANCE_DIR}/commit-rules.yaml"
SKILL_REGISTRY="${GOVERNANCE_DIR}/SKILL_REGISTRY.md"
CONTRACT_FILE="${GOVERNANCE_DIR}/CONTRACT.md"
IMPACT_LOG="${GOVERNANCE_DIR}/CROSS_IMPACT_LOG.md"
TASKS_FILE="${GOVERNANCE_DIR}/TASKS.md"
AUDIT_LOG="${GOVERNANCE_DIR}/memory/HEALTH_AUDIT.md"
HOOK_ENABLED="true"

# 版本管理统一使用本地 git（1.2.0 起废除简易快照体系）：
# git 完全本地可用（不需要 GitHub/Gitee 账号），由 task-manager 在任务完成时自动提交，
# 用户不接触 git 命令。废除项：snapshot 子命令、hooks 写入前备份、pending/snapshots 目录。

if [ -f "${ADAPTER_CFG}" ]; then
    # 仅白名单提取，拒绝任意代码执行；取值非法（绝对路径/含元字符）则回落默认
    cfg_commit="$(safe_cfg_get COMMIT_RULES "${ADAPTER_CFG}")"
    [ -n "$cfg_commit" ] && COMMIT_RULES="$cfg_commit"
    cfg_hook="$(safe_cfg_get HOOK_ENABLED "${ADAPTER_CFG}")"
    [ -n "$cfg_hook" ] && HOOK_ENABLED="$cfg_hook"
fi
# 治理文件统一落在 GOVERNANCE_DIR 下；旧项目在 .workbuddy/ 的回落由读取函数处理
MEMORY_DIR="${GOVERNANCE_DIR}/memory"

# 【关键】铁律模板路径：你维护的“宪法”放在这里
# 模板位于 vibe-coding-toolkit/templates/RULES.template.md（顶层共享模板目录）
# 脚本会自动读取它来生成项目的 RULES.md
RULES_TEMPLATE="$(dirname "${BASH_SOURCE[0]}")/../../templates/RULES.template.md"  # 脚本下沉至 scripts/project-init，模板在顶层 templates/

# 适配模式（存量项目接入）专用：草稿只放临时目录，绝不碰正式治理目录
DRAFTS_DIR="${GOVERNANCE_DIR}/memory/drafts"

# 旧项目兼容：治理文件优先读 .vibe-coding/，缺失则回落 .workbuddy/
# 路径由 PROJECT_ROOT 锁定为工作区本地，避免误读全局 ~/.workbuddy；PROJECT_ROOT 为空时置空，由调用方守卫跳过
if [ -n "${PROJECT_ROOT:-}" ]; then
    LEGACY_DIR="${PROJECT_ROOT}/.workbuddy/memory"
else
    LEGACY_DIR=""
fi

# ---------- 工具函数 ----------
# 统一运行日志（1.2.0）：双写界面 + 落盘 .vibe-coding/logs/<模块>-<日期>-<时间>.log
# log_info/log_warn/log_error 语义兼容：log_error 仍输出后 exit 1
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/../lib/log.sh"

ensure_cache_dir() {
    mkdir -p "${CACHE_DIR}"
    touch "${COLLECTED_FILE}" 2>/dev/null || true
    echo "0" > "${QUESTION_INDEX}" 2>/dev/null || true
}

# ---------- 收集数据读取（零依赖：纯 key=value 文本，不使用 jq）----------
# 读取单个键的值（取首个匹配行，`=` 之后全部作为值，保留空格；缺失返回空串）。
# 用 { ...; } || true 包裹，避免 grep 无匹配时触发 set -e 退出。
collected_get() {
    local key="$1" file="${2:-${COLLECTED_FILE}}"
    [ -f "$file" ] || { echo ""; return 0; }
    {
        grep -E "^[[:space:]]*${key}[[:space:]]*=" "$file" 2>/dev/null | head -n1 \
            | sed -E "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*//"
    } || true
    return 0
}

# 读取逗号分隔的列表，逐行输出（对标 jq '.x[]'），自动去空格并跳过空项。
# 末尾 || true 保证空列表时管道退出码为 0，不触发 set -e。
collected_list() {
    local raw
    raw="$(collected_get "$1")"
    [ -z "$raw" ] && return 0
    printf '%s\n' "$raw" | tr ',' '\n' \
        | sed -E 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$' || true
}

# 写入/覆盖单个键（幂等：重复调用只保留最新值，不重复追加）。
collected_set() {
    local key="$1" value="$2" file="${3:-${COLLECTED_FILE}}"
    [ -f "$file" ] || { echo "${key}=${value}" > "$file"; return 0; }
    local tmp; tmp="$(mktemp)"
    grep -vE "^[[:space:]]*${key}[[:space:]]*=" "$file" > "$tmp" 2>/dev/null || true
    echo "${key}=${value}" >> "$tmp"
    mv "$tmp" "$file"
    return 0
}

# ---------- 痛点规则生成器 ----------
# 根据用户在init第6轮选择的痛点，生成针对性的规则文本
generate_pain_point_rules() {
    local point
    local pain_points; pain_points="$(collected_list pain_points)"
    if [ -z "$pain_points" ]; then
        return
    fi

    echo "## 针对性加固规则（基于你的历史痛点）"
    echo "> 以下规则由初始化程序根据你的反馈自动生成，用于防范已知风险。"
    echo ""

    # 遍历痛点并生成规则
    echo "$pain_points" | while IFS= read -r point; do
        case "$point" in
            *"撒谎"*|*"没改"*)
                echo "### 防虚假提交规则"
                echo "- **铁律**：AI 声称“已提交”时，必须提供具体的 commit ID。"
                echo "- **验证**：每次提交后必须运行 \`commit-check\`，禁止无 ID 宣称完成。"
                echo ""
                ;;
            *"越界"*|*"不该改"*)
                echo "### 防越界修改规则"
                echo "- **铁律**：AI 仅允许修改所属模块目录下的文件。"
                echo "- **验证**：\`commit-check\` 将拦截跨模块修改，除非 Coordinator 批准。"
                echo ""
                ;;
            *"忘约定"*)
                echo "### 防遗忘约定规则"
                echo "- **铁律**：修改代码前必须读取 \`CHARTER.md\` 和 \`CONTRACT.md\`。"
                echo "- **验证**：若修改内容与契约冲突，task-manager 将拒绝合并。"
                echo ""
                ;;
            *"混乱"*|*"多窗口"*)
                echo "### 防多窗口混乱规则"
                echo "- **铁律**：严格执行文件驱动，禁止人工复制粘贴任务内容。"
                echo "- **验证**：所有任务流转必须通过 \`task-manager\` 更新 TASKS 文件。"
                echo ""
                ;;
        esac
    done
}

# ---------- 生成治理文件 ----------
generate_memory_files() {
    local project_name="$(collected_get project_name)"
    local supp="$(collected_get supplementary_notes)"
    [ -z "$supp" ] && supp="无"

    mkdir -p "${MEMORY_DIR}"

    # 1. MEMORY.md (保持不变)
    cat > "${MEMORY_DIR}/MEMORY.md" << EOF
# ${project_name} — 项目治理主索引
> 生成时间：$(date "+%Y-%m-%d %H:%M:%S")
> 框架版本：Vibe Project Governance v1.0
> 本文档为治理记忆的索引入口，具体规则请查阅对应子文件。

## 本目录身份声明
> 本目录是 **VPG 治理记忆**，由 vibe-coding-toolkit 生成与管理。
> 它与 WorkBuddy 宿主的 \`.workbuddy/memory/\`（AI 代理运行记忆）**相互独立、各司其职**：本目录存项目治理文档，\`.workbuddy/memory/\` 存 AI 自身运行记忆。
> 其他 AI 工具只需只读本目录即可获得完整治理上下文（多工具适配接口）。

## 快速导航

| 文件 | 内容 | 适用场景 |
| --- | --- | --- |
| \`PROJECT_PROFILE.md\` | 项目画像：目标、使用场景、技术栈 | 新会话了解项目 |
| \`RULES.md\` | 基础铁律（不可篡改）与 Git 纪律 | 行为纪律、代码审查 |
| \`ROLES.md\` | 角色分工与护栏规则 | 角色定位、权限边界 |
| \`CONTRACT.md\` | 契约与跨端影响日志 | 接口变更、跨端影响 |
| \`ARCHIVE.md\` | 项目演进与避坑记录 | 复盘、历史规则查询 |

## 按需调用表

| 你要找什么 | 去哪个文件 |
| --- | --- |
| 项目目标 / 使用场景 / 技术栈 | \`PROJECT_PROFILE.md\` |
| 行为铁律 / 提交纪律 | \`RULES.md\` |
| 角色职责 / 护栏 / 汇报文件 | \`ROLES.md\` |
| API 契约 / 跨端影响日志 | \`CONTRACT.md\` |
| 历史演进 / 避坑经验 | \`ARCHIVE.md\` |
| 任务流转 / 待办 | 项目根的 \`TASKS-<模块>.md\` |
| 配置开关（前缀校验 / 钩子 / git 状态） | \`.vibe-coding/adapter.cfg\` |

## 全局铁律（不可违反）
请查阅 \`RULES.md\` 获取完整且不可篡改的基础铁律。

## 快速参考
- 仓库路径：$(pwd)
- 模块列表：$(collected_list modules | paste -sd, -)
- Git纪律：commit前缀必须符合 .vibe-coding/commit-rules.yaml 中 prefixes 列表（不含方括号，如 [PC]）
EOF

    # 2. PROJECT_PROFILE.md (保持不变)
    cat > "${MEMORY_DIR}/PROJECT_PROFILE.md" << EOF
# 项目画像：${project_name}
> 生成时间：$(date "+%Y-%m-%d %H:%M:%S")

## 项目目标
$(collected_get project_desc)

## 使用场景
$(collected_list usage_places | sed 's/^/- /')

## 技术栈
$(collected_list tech_stack | sed 's/^/- /')

## 补充需求
${supp}
EOF

    # 3. ROLES.md (保持不变)
    cat > "${MEMORY_DIR}/ROLES.md" << EOF
# 角色分工与护栏
> 生成时间：$(date "+%Y-%m-%d %H:%M:%S")

## 全局角色
- **coordinator**：项目总管，负责创建任务、审查commit、更新记忆文件
- **各模块开发**：按模块分工，仅修改所属模块文件；角色名为 ai-<模块名>，见下方模块分工

## 模块分工
$(for module in $(collected_list modules); do
echo "### ${module}"
echo "- **开发角色名**：ai-${module}（多窗口协作时，开发窗口第一句声明"你是 ai-${module} 角色"；task-manager 按此校验操作权限）"
echo "- 职责：负责${module}相关代码/配置修改"
echo "- 护栏：禁止修改其他模块文件（DONT_TOUCH）"
echo "- 汇报：任务完成后更新TASKS-${module}.md"
echo ""
done)

## 护栏规则（DONT_TOUCH）
1. 各模块仅可修改自身目录文件
2. memory/目录下文件仅coordinator可修改
3. CONTRACT.md仅coordinator可修改
4. 跨端修改必须先获coordinator批准
EOF

    # 4. RULES.md (核心修改：读取模板 + 插入痛点规则)
    if [ -f "$RULES_TEMPLATE" ]; then
        # 读取你维护的铁律模板
        cp "$RULES_TEMPLATE" "${MEMORY_DIR}/RULES.md"
        # 替换模板中的生效日期占位符（如 2026-07-XX）为实际生成日期
        sed -i "s/生效日期：[0-9]\{4\}-[0-9]\{2\}-XX/生效日期：$(date "+%Y-%m-%d")/" "${MEMORY_DIR}/RULES.md"
        log_info "✅ 已注入基础铁律模板"
    else
        # 如果模板不存在，生成一个最小化的备用规则文件，防止后续脚本报错
        log_warn "未找到铁律模板，生成备用规则文件。"
        cat > "${MEMORY_DIR}/RULES.md" << EOF
# 项目行为规范（备用）
> 生成时间：$(date "+%Y-%m-%d %H:%M:%S")
> ⚠️ 未检测到预置的铁律模板，请检查 Skill 安装。

## 核心铁律（基础版）
1. **一次一任务**：同一时间仅处理一个任务。
2. **commit规范**：前缀必须符合 .vibe-coding/commit-rules.yaml 的 prefixes 列表。
3. **验证闭环**：每次commit后必须运行commit-check验证。
EOF
    fi

    # 在模板末尾追加“针对性加固规则”
    generate_pain_point_rules >> "${MEMORY_DIR}/RULES.md"

    # 追加“自定义补充区”
    cat >> "${MEMORY_DIR}/RULES.md" << EOF

---

## 自定义补充规则（可选）
> 如需添加个性化规则，请直接在此处下方编辑，或通过自然语言指令告知 Coordinator。
> 例如：禁止AI修改.env文件；所有修改必须留存日志。

<!-- 用户自定义规则将追加于此 -->
EOF
    log_info "✅ 行为规范(RULES.md)生成完毕（含痛点加固）"

    # 5. CONTRACT.md (保持不变)
    cat > "${MEMORY_DIR}/CONTRACT.md" << EOF
# 契约与日志
> 生成时间：$(date "+%Y-%m-%d %H:%M:%S")

## API契约（示例）
- 接口路径：
- 请求格式：
- 响应格式：
- 认证方式：

## 跨端影响日志（CROSS_IMPACT_LOG）
| 日期 | 提出端 | 变更内容 | 影响端 | 状态 |
|---|---|---|---|---|

## 环境变更日志（ENV_CHANGELOG）
| 日期 | 变更内容 | 变更人 | 影响范围 |
|---|---|---|---|

## 部署清单（DEPLOY_CHECKLIST）
### 部署前确认
- [ ] 代码已commit并通过commit-check
- [ ] 跨端影响已记录
- [ ] 环境变量已更新
### 部署后确认
- [ ] 服务可访问
- [ ] 日志无异常
- [ ] 核心功能验证通过
EOF

    # 6. ARCHIVE.md (保持不变)
    cat > "${MEMORY_DIR}/ARCHIVE.md" << EOF
# 历史档案
> 生成时间：$(date "+%Y-%m-%d %H:%M:%S")

## 项目演进
- $(date "+%Y-%m-%d")：项目治理骨架初始化完成

## 关键学习
（后续踩坑记录将追加于此）

## 决策记录
（后续重大技术决策将追加于此）
EOF

    log_info "✅ 治理骨架文件生成完毕"
}

# ---------- 1.1.0 新增：适配层配置 / 提交前缀 / 提交钩子 ----------

# 生成跨平台适配层配置 adapter.cfg（核心预留接口，所有路径从此读取）
generate_adapter_cfg() {
    mkdir -p "${GOVERNANCE_DIR}"
    local gs; gs="$(collected_get git_status)"
    [ -z "$gs" ] && gs="new"
    # 版本管理统一本地 git（1.2.0 废除简易快照）：所有项目都是 git 管理，钩子恒启用
    # 前缀（task-manager VALID_PREFIXES 来源）：collected commit_prefixes，缺省默认
    local prefixes; prefixes="$(collected_list commit_prefixes | paste -sd, -)"
    [ -z "$prefixes" ] && prefixes="FEAT,FIX,DOCS,CHORE,REFACTOR,TEST"
    cat > "${ADAPTER_CFG}" << EOF
# .vibe-coding/adapter.cfg
# 唯一配置文件（1.2.0 起合并 memory/project.config）：平台/路径/开关/git 状态/前缀全部在此
PRODUCT_NAME="workbuddy"       # 当前产品标识，Day1固定为workbuddy
GOVERNANCE_DIR=".vibe-coding"  # 治理根目录，相对项目根路径

# 衍生路径（基于GOVERNANCE_DIR，无需修改）
COMMIT_RULES="${GOVERNANCE_DIR}/commit-rules.yaml"
SKILL_REGISTRY="${GOVERNANCE_DIR}/SKILL_REGISTRY.md"
CONTRACT_FILE="${GOVERNANCE_DIR}/CONTRACT.md"
IMPACT_LOG="${GOVERNANCE_DIR}/CROSS_IMPACT_LOG.md"
TASKS_FILE="${GOVERNANCE_DIR}/TASKS.md"
AUDIT_LOG="${GOVERNANCE_DIR}/memory/HEALTH_AUDIT.md"

# 行为开关（版本管理统一本地 git：钩子恒启用，commit-msg 拦截非法前缀）
HOOK_ENABLED="true"            # commit-msg 钩子开关

# git 方式与合法前缀（task-manager 读取；枚举：new 本地新建 git 库 / existing 项目已有 git 库）
GIT_STATUS=${gs}
VALID_PREFIXES=${prefixes}
EOF
    log_info "✅ 已生成跨平台适配层配置 ${ADAPTER_CFG}"
}

# ---------- 配置一致性判定（git 唯一模式，1.2.0 废除快照后简化）----------
# 版本管理统一本地 git：校验 GIT_STATUS 枚举合法（new/existing）且仓库真实存在（.git）。
config_sanity() {
    local gs=""
    # GIT_STATUS 在 adapter.cfg（唯一配置文件）；存量项目回落 memory/project.config
    if [ -f "${ADAPTER_CFG}" ] && grep -q '^GIT_STATUS=' "${ADAPTER_CFG}" 2>/dev/null; then
        gs="$(sed -n 's/^GIT_STATUS=\([^[:space:]]*\).*/\1/p' "${ADAPTER_CFG}" 2>/dev/null | tail -1)"
    elif [ -f "${GOVERNANCE_DIR}/memory/project.config" ]; then
        gs="$(sed -n 's/^GIT_STATUS=\([^[:space:]]*\).*/\1/p' "${GOVERNANCE_DIR}/memory/project.config" 2>/dev/null)"
    fi
    [ -z "$gs" ] && gs="new"

    case "$gs" in
        new|existing)
            log_info "配置一致：git 管理（GIT_STATUS=${gs}）" ;;
        none)
            log_error "配置不一致：GIT_STATUS=none 已废弃（1.2.0 起版本管理统一本地 git），请重新初始化或修正为 new/existing" ;;
        *)
            log_error "配置不一致：GIT_STATUS=${gs} 非法（应为 new/existing）" ;;
    esac
    return 0
}

# ---------- 平台探测：判断当前运行环境（保留，供诊断与兼容）----------
# 依据（优先级从高到低）：平台注入的环境变量 → 用户级特征目录。
platform_detect() {
    local p="unknown"
    if [ -n "${CODEBUDDY_PROJECT_DIR:-}" ]; then
        p="workbuddy"
    elif [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
        p="claude-code"
    elif [ -n "${CURSOR_PROJECT_DIR:-}" ]; then
        p="cursor"
    elif [ -n "${CODEX_HOME:-}" ]; then
        p="codex"
    elif [ -d "${HOME}/.workbuddy" ]; then
        p="workbuddy"
    elif [ -d "${HOME}/.claude" ]; then
        p="claude-code"
    elif [ -d "${HOME}/.cursor" ]; then
        p="cursor"
    elif [ -d "${HOME}/.codex" ]; then
        p="codex"
    fi
    echo "$p"
}

# 把平台写入 adapter.cfg（幂等：先移除旧 PLATFORM 行再追加）
write_platform() {
    local p="${1:-unknown}"
    [ -f "${ADAPTER_CFG}" ] || return 0
    local tmp; tmp="$(mktemp)"
    grep -vE '^PLATFORM=' "${ADAPTER_CFG}" > "$tmp" 2>/dev/null || true
    echo "PLATFORM=\"${p}\"" >> "$tmp"
    mv "$tmp" "${ADAPTER_CFG}"
    log_info "已探测运行平台：${p}（写入 adapter.cfg）"
}


# 生成提交前缀规则 commit-rules.yaml（干净前缀，不带行内注释，避免 commit-check 解析失败）
generate_commit_rules() {
    local check="$(collected_get commit_prefix_check)"
    [ -z "$check" ] && check="true"
    local prefixes; prefixes="$(collected_list commit_prefixes)"
    if [ -z "${prefixes}" ]; then
        # 兜底默认通用前缀（用户未通过问答提供时）
        prefixes=$'FEAT\nFIX\nDOCS\nCHORE\nREFACTOR\nTEST'
    fi
    mkdir -p "${GOVERNANCE_DIR}"
    {
        echo "# commit-rules.yaml — 提交前缀规则"
        echo "#"
        echo "# 由 vibe-project-init 生成到项目根 .vibe-coding/ 目录。"
        echo "# commit-check / commit-msg 钩子读取本文件校验提交前缀。"
        echo "# 你随时可以手动编辑本文件的 prefixes 列表，无需改动 skill 代码。"
        echo ""
        echo "# 是否启用前缀校验。false 时跳过前缀检查（不阻塞）。"
        echo "prefix_check: ${check}"
        echo ""
        echo "# 允许的提交前缀（不含方括号）。请按需增删。"
        echo "prefixes:"
        echo "${prefixes}" | while IFS= read -r p; do
            [ -z "$p" ] && continue
            echo "  - ${p}"
        done
    } > "${COMMIT_RULES}"
    log_info "✅ 已生成提交前缀规则 ${COMMIT_RULES}"
}

# 安装 commit-msg 钩子（源头拦截非法前缀；POSIX 兼容，无脚本特定语法）
install_commit_msg_hook() {
    local hook_src="$(dirname "${BASH_SOURCE[0]}")/../../templates/commit-msg.sh"
    [ "${HOOK_ENABLED}" = "true" ] || { log_warn "钩子已配置为关闭（HOOK_ENABLED=false），跳过安装"; return 0; }
    [ -f "${hook_src}" ] || { log_warn "未找到钩子模板，跳过安装"; return 0; }
    [ -d ".git" ] || { log_warn "当前目录非 git 仓库，跳过钩子安装"; return 0; }
    mkdir -p ".git/hooks"
    cp "${hook_src}" ".git/hooks/commit-msg"
    chmod +x ".git/hooks/commit-msg"
    log_info "✅ 已安装 commit-msg 钩子（.git/hooks/commit-msg）"
}

# 旧项目兼容：检测到 .workbuddy/memory/ 旧治理文件时，提示迁移到 .vibe-coding/
maybe_migrate_legacy() {
    [ -d "${LEGACY_DIR}" ] || return 0
    [ -d "${GOVERNANCE_DIR}/memory" ] && return 0   # 已迁移过
    log_warn "检测到旧版治理文件（.workbuddy/memory/）。本脚本不接收终端交互，默认保留旧路径（不迁移）；如需迁移至 ${GOVERNANCE_DIR}/，请由 AI 助手显式处理。"
    local ans="N"
    case "$ans" in
        N|n) log_info "保留旧路径，按兜底逻辑读取 .workbuddy/"; return 0 ;;
        *)
            mkdir -p "${GOVERNANCE_DIR}/memory"
            for f in MEMORY.md RULES.md ROLES.md CONTRACT.md ARCHIVE.md PROJECT_PROFILE.md; do
                [ -f "${LEGACY_DIR}/${f}" ] && cp "${LEGACY_DIR}/${f}" "${GOVERNANCE_DIR}/memory/${f}"
            done
            [ -d "${LEGACY_DIR}/drafts" ] && cp -r "${LEGACY_DIR}/drafts" "${GOVERNANCE_DIR}/memory/drafts" 2>/dev/null || true
            [ -f "${LEGACY_DIR}/../commit-rules.yaml" ] && cp "${LEGACY_DIR}/../commit-rules.yaml" "${GOVERNANCE_DIR}/commit-rules.yaml" 2>/dev/null || true
            log_info "✅ 已迁移旧治理文件至 ${GOVERNANCE_DIR}/memory/" ;;
    esac
}

# ============================================
# 缺失函数补全（修复"示意化裁剪"导致的未定义调用，阻塞 v1.1.0 发布）
# 契约：所有 generate_* 从 ${COLLECTED_FILE}（key=value）读取；该文件由 AI 助手预置，
#       同时设置全局 git_status（供 setup_archive 与快照分支使用）。
# ============================================

# 收集文件守卫：本脚本不接收终端交互输入（无 read 向导）。
# collected.cfg 必须由 AI 助手（WorkBuddy / Claude Code / Codex 等）在聊天中
# 收集项目信息后写入；缺失或为空则明确报错，引导用户走 AI 助手。
ensure_collected_present() {
    if [ ! -s "${COLLECTED_FILE}" ]; then
        log_error "未找到项目信息文件 ${COLLECTED_FILE}（或为空）。
本脚本由 AI 助手调用，不接收终端交互输入，也不含 read 向导。
请 AI 助手按 SKILL.md「project-init 交互约定」的流程与用户对话，
把这些信息写入 ${COLLECTED_FILE} 后，再运行：
    bash scripts/project-init/vibe-project-init.sh batch
详见 SKILL.md「project-init 交互约定」。"
    fi
}

# ---------- ask：问题模板输出 + collected.cfg 校验（交互约定脚本化，AI 照模板执行，脚本兜底）----------
# ask --list     输出 Q1-Q5 问题模板（话术/兜底/字段/选项/默认值/必填），AI 逐轮照模板提问
# ask --validate 校验 collected.cfg 值合法（非空、非"自定义/其他"字面值、枚举合法、必填齐全），
#                失败逐字段列出并退出 1；batch 前强制调用，AI 不手动跑也会被拦
ask_list() {
    cat <<'EOF'
===== project-init 问题模板（AI 逐轮照此执行，不得自行组织问题与选项）=====

[Q1] 项目描述（必问）
  问题: 你想做个什么产品？一句话说清楚就行——做什么、给谁用、大概在哪用（电脑上、手机上，拿不准也没关系）。
  兜底: 若回答抽象（如"想用 AI 编程"）追问：具体想做个什么产品呢？比如记账本、小游戏、资料整理工具、自动跑数据的脚本……有个大概想法就行。
  字段: project_name（从描述提取，如"做一个桌面万花筒"→ project_name=桌面万花筒）、project_desc
  选项: 无（用户自由回答，不出现"项目叫什么名字"类独立问题）
  必填: 是

[Q2] 推断+确认（必问）
  问题: 我理解你要做一个 X：在 Y 上用，分 Z 块（模块名），用 W 做。对吗？（用户可改/否决；说"不知道/你定"→ AI 给默认继续）
  字段: usage_places（电脑/手机/平板/后台/其他，可多选）、modules（模块代号，默认按端分）、tech_stack（按场景推断）
  模块代号: 用英文标识符（字母/数字/下划线/连字符，如 PC 电脑端、APP 手机端、CLOUD 后台、WEB 网页端、SERVER 服务端）；禁止中文模块名（ask_validate 会拦截）
  选项: 推断候选回显确认，用户可否决
  必填: usage_places、modules 是；tech_stack 可空（推断）

[Q3] 代码怎么管（必问，1.2.0 起统一本地 git）
  问题: 项目自带本地版本管理（Git，完全本地运行、不需要 GitHub/Gitee 账号）。你不需要懂 git——任务完成时系统自动保存一个版本，随时能回退。只需确认：项目目录现在有没有 git 库？
  选项: ① 还没有，新建本地 Git 库（git_status=new，推荐）② 项目已经有 Git 库（git_status=existing）
  字段: git_status
  必填: 是
  后续: 进入 Q4

[Q4] 给 AI 分角色（必问）
  问题: 角色是分给 AI 窗口的，与使用者人数无关——一个人也能有多个角色。按模块+场景生成角色方案并回显确认。
  字段: 角色方案（写入 ROLES.md，不写 collected.cfg）
  选项: 用户确认/合并/改名
  必填: 是（用户确认后闭环）

[Q5] 提交标签（必问）
  问题: 每次提交要带个标签（前缀），方便分清是哪个模块的改动。要启用吗？
  选项: ① 启用，按模块自动配（推荐）→ commit_prefix_check=true，commit_prefixes 按模块代号生成（PC→[PC]、APP→[APP]、CLOUD→[CLOUD]）② 关闭 → commit_prefix_check=false
  字段: commit_prefix_check、commit_prefixes
  必填: 否（建议启用）
EOF
}

# 校验 collected.cfg 值合法；失败输出全部问题字段并返回 1
ask_validate() {
    [ -s "${COLLECTED_FILE}" ] || { log_error "未找到项目信息文件 ${COLLECTED_FILE}（或为空），无法校验"; }
    local errs=""
    local name; name="$(collected_get project_name)"
    local desc; desc="$(collected_get project_desc)"
    local modules; modules="$(collected_list modules)"
    local git_status; git_status="$(collected_get git_status)"
    local usage_places; usage_places="$(collected_list usage_places)"

    # project_name：非空、非"自定义/其他"字面值
    if [ -z "$name" ]; then
        errs="${errs}❌ project_name 为空：请 AI 回问用户真实项目名\n"
    else
        case "$name" in
            *自定义*|*其他*) errs="${errs}❌ project_name 疑似选项字面值（${name}）：请 AI 追问用户真实项目名，禁止把选项字面值写入\n" ;;
        esac
    fi
    # project_desc：非空
    [ -n "$desc" ] || errs="${errs}❌ project_desc 为空：请 AI 回问用户项目是做什么的\n"
    # modules：非空、每项为英文标识符（字母/数字/下划线/连字符）、非"自定义"字面值
    if [ -z "$modules" ]; then
        errs="${errs}❌ modules 为空：请 AI 按第 2 轮推断+确认补齐模块\n"
    else
        local m
        for m in $modules; do
            case "$m" in
                *自定义*|*其他*) errs="${errs}❌ modules 含选项字面值（${m}）：请 AI 追问真实模块代号，禁止把选项字面值写入\n" ;;
            esac
            # 中英文兼容：模块代号必须为英文标识符（如 PC/APP/CLOUD），禁止中文模块名
            case "$m" in
                *[一-龥]*|[!A-Za-z0-9_-]*)
                    errs="${errs}❌ modules 含非法模块代号（${m}）：模块名需为英文标识符（字母/数字/下划线/连字符，如 PC/APP/CLOUD），中文仅可作展示说明\n" ;;
            esac
        done
    fi
    # git_status：非空且枚举合法（1.2.0 起统一本地 git，none 已废弃）
    case "$git_status" in
        new|existing) ;;
        none) errs="${errs}❌ git_status=none 已废弃（1.2.0 起版本管理统一本地 git）：请 AI 改为 new（新建本地 git 库）或 existing（已有 git 库）\n" ;;
        "") errs="${errs}❌ git_status 为空：请 AI 在第 3 轮确认 git 方式\n" ;;
        *)  errs="${errs}❌ git_status 非法（${git_status}）：应为 new/existing\n" ;;
    esac
    # usage_places：空则警告（AI 按默认推断），不阻塞
    [ -n "$usage_places" ] || log_warn "usage_places 为空：AI 将按默认推断（工具类→电脑网页版 / App 类→手机端）"

    if [ -n "$errs" ]; then
        log_error "collected.cfg 校验未通过，请 AI 按以下问题回问用户修正后再跑 batch：
$(printf "$errs")"
    fi
    log_info "collected.cfg 校验通过：项目名=${name:-空}，模块=${modules:-空}，git=${git_status:-空}"
    return 0
}

# ask 子命令派发：ask --list | ask --validate
ask() {
    case "${1:-}" in
        --list)    ask_list ;;
        --validate) ask_validate ;;
        --guide)   ask_guide ;;
        *) echo "用法：$0 ask <--list|--validate|--guide>"; return 1 ;;
    esac
}

# ---------- ask --guide：输出填充好的首次引导文本（1.2.0，彻底摆脱 AI 阅读理解模板）----------
# 脚本读取 templates/FIRST_GUIDE.template.md + collected.cfg + ROLES.md，替换占位符后输出完整引导，
# AI 直接原样复制到聊天即可，不需要自己组织话术。仅"首个任务建议"由 AI 补充。
ask_guide() {
    local tpl="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../templates" >/dev/null 2>&1 && pwd)/FIRST_GUIDE.template.md"
    # Windows Git Bash 下 pwd 是 /c/... POSIX 格式，Windows 版 python 不认，转 C:/...
    if command -v cygpath >/dev/null 2>&1; then
        tpl="$(cygpath -m "$tpl" 2>/dev/null || echo "$tpl")"
    fi
    [ -f "$tpl" ] || { log_error "未找到首次引导模板 ${tpl}"; return 1; }
    local py=""
    for c in python python3; do command -v "$c" >/dev/null 2>&1 && { py="$c"; break; }; done
    [ -z "$py" ] && { log_error "未找到 python，无法生成首次引导"; return 1; }

    local name gs mods prefixes ws
    # 数据源用已生成的治理文件（不依赖 collected.cfg，batch 后与单独跑均可用）
    name="$(sed -n 's/^# 项目画像：//p' "${MEMORY_DIR}/PROJECT_PROFILE.md" 2>/dev/null | head -1)"
    [ -z "$name" ] && name="$(collected_get project_name)"
    gs="$(grep -E '^GIT_STATUS=' "${ADAPTER_CFG}" 2>/dev/null | tail -1 | sed 's/^GIT_STATUS=//; s/"//g')"
    [ -z "$gs" ] && gs="new"
    prefixes="$(grep -E '^VALID_PREFIXES=' "${ADAPTER_CFG}" 2>/dev/null | tail -1 | sed 's/^VALID_PREFIXES=//' | cut -d, -f1)"
    mods="$(ls TASKS-*.md 2>/dev/null | sed 's/^TASKS-//; s/\.md$//' | paste -sd, -)"
    ws="$(basename "$(pwd)")"

    # 角色行：从 ROLES.md 模块分工读开发角色名与职责（模块列表取自 TASKS 文件名）
    local roles="" m
    for m in $(ls TASKS-*.md 2>/dev/null | sed 's/^TASKS-//; s/\.md$//'); do
        local role_name duty
        role_name="$(grep -A3 "^### ${m}\$" "${MEMORY_DIR}/ROLES.md" 2>/dev/null | grep "开发角色名" | sed 's/.*：ai-/ai-/; s/（.*//' | head -1)"
        duty="$(grep -A3 "^### ${m}\$" "${MEMORY_DIR}/ROLES.md" 2>/dev/null | grep "职责：" | sed 's/- 职责：//' | head -1)"
        [ -z "$role_name" ] && role_name="ai-${m}"
        [ -z "$duty" ] && duty="负责${m}相关代码/配置修改"
        roles="${roles}
- ${role_name}：${duty}"
    done

    "$py" - "$tpl" "$name" "$ws" "$mods" "$prefixes" "$gs" "$roles" <<'PYEOF'
import sys
tpl, name, ws, mods, prefixes, gs, roles = sys.argv[1:8]
with open(tpl, encoding="utf-8") as f:
    text = f.read()
# 截断：去掉模板末尾的"--- 占位符取值说明"段
if "\n---\n" in text:
    text = text.split("\n---\n")[0]
# 角色行：替换模板中的占位角色行
import re
text = re.sub(r"- <角色名>：<职责简述>\n?", "", text)  # 删模板占位行
if roles.strip():
    # 在 coordinator 行后插入真实角色行
    text = text.replace("- coordinator：项目总管，收需求、派任务、审查提交、维护治理文件",
                        "- coordinator：项目总管，收需求、派任务、审查提交、维护治理文件" + roles)
# 其余占位符
git_state = "已 init" if gs == "new" else "已接入现有 git 库"
git_full = "已 init，治理文件尚未首次提交" if gs == "new" else "已接入现有 git 库"
text = text.replace("<项目名>", name)
text = text.replace("<工作区名>", ws)
text = text.replace("<模块列表>", mods)
text = text.replace("<前缀>", prefixes)
text = text.replace("<git 状态>", git_state)
text = text.replace("<已 init，治理文件尚未首次提交 / 已接入现有 git 库>", git_full)
text = text.replace("<首个任务建议>", "首个具体任务")
print(text)
PYEOF
}

# ---------- git history：本地提交历史（1.2.0 统一本地 git 后，供 AI 列出版本供回滚选择）----------
# 版本管理由 git 承担（用户不接触 git 命令）；回滚流程：AI 跑本命令列出历史 → 用户选定 → AI 执行 git 还原。
git_history() {
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_warn "当前目录不是 git 仓库（项目未初始化或 .git 缺失），无法列出历史版本"
        return 1
    fi
    git log --pretty=format:'%h|%ad|%s' --date=short -30 2>/dev/null
    echo ""
}

# ---------- VPG.md：根目录可见入口文件（1.2.0 新增）----------
# 解决"AI 看不到隐藏目录 .vibe-coding"问题：初始化时在项目根生成非隐藏入口文件，
# AI 枚举根目录必然可见，被引导进 .vibe-coding。内容动态生成（项目名/模块/角色/指令）。
generate_vpg_entry() {
    local name; name="$(collected_get project_name)"
    [ -z "$name" ] && name="未命名项目"
    local git_status; git_status="$(collected_get git_status)"
    [ -z "$git_status" ] && git_status="existing"

    # 模块 → 角色行（对齐 ROLES.md：ai-<模块>，task-manager 匹配时转小写）
    local roles="" tasks_list=""
    local m
    for m in $(collected_list modules); do
        roles="${roles}- **ai-${m}**：只改 ${m} 模块文件，完成后更新 TASKS-${m}.md
"
        tasks_list="${tasks_list}| \`TASKS-${m}.md\` | ${m} 模块任务看板 | 派任务 / 认领任务时 |
"
    done

    cat > "VPG.md" << EOF
# VPG.md — 项目入口

> 这个文件是项目治理的入口说明，放在根目录最显眼的位置。
> **给 AI**：进入本项目先读本文件，按指引找到治理文件，再应答任何关于"项目介绍 / 角色分工 / 职责 / 边界 / 纪律"的问题。
> **给用户**：本文件只说明"治理文件在哪"，本身不承载治理内容。

## 治理文件在哪

项目全部治理文件在隐藏目录 **\`.vibe-coding/\`** 下，AI 用普通目录列举可能看不到（点开头目录在 Unix 惯例里默认隐藏），**必须用 \`ls -a\` 或直接读取**：

| 文件 | 内容 | 什么时候读 |
| --- | --- | --- |
| \`.vibe-coding/memory/MEMORY.md\` | 治理记忆索引（**先读这个**） | 每次进入项目、被问项目情况时 |
| \`.vibe-coding/memory/PROJECT_PROFILE.md\` | 项目画像（目标/模块/技术栈） | 被问"项目介绍"时 |
| \`.vibe-coding/memory/ROLES.md\` | 角色分工与权限边界 | 被问"角色分工/职责/边界"时 |
| \`.vibe-coding/memory/RULES.md\` | 项目铁律（纪律） | 被问"纪律"时；执行任何任务前 |
| \`.vibe-coding/memory/CONTRACT.md\` | 接口契约与跨端影响日志 | 改跨端接口前 |
| \`.vibe-coding/memory/ARCHIVE.md\` | 演进与避坑记录 | 复盘、查历史 |
${tasks_list}
## 项目概况

- **项目名**：${name}
- **模块**：$(collected_list modules | tr '\n' ' ')
- **治理框架**：Vibe Project Governance，记忆目录 \`.vibe-coding/memory/\`

## 角色

- **coordinator**（总管）：收需求、派任务、审查 commit、更新记忆文件；CONTRACT.md / ROLES.md 仅真人下令可改
${roles}
## 常用指令（对 coordinator 说）

- "记个任务：要做 X" —— 记进任务板
- "任务 X 做完了" —— 记录改动并验证，任务归档（系统自动保存版本）
- "回滚到改 X 之前" —— 列出历史版本供选择后还原
EOF
    log_info "✅ 已生成根目录入口文件 VPG.md（解决隐藏目录不可见问题）"
}

# 交互问答已迁移到 AI 助手侧（见 SKILL.md「project-init 交互约定」）：
# 脚本不再含 read 向导 / 补充问答 / 确认步骤；项目信息由 AI 助手在聊天中收集，
# 写入 ${COLLECTED_FILE}（key=value）后，本脚本仅做读取与生成。
# 这样保证 WorkBuddy / Claude Code / Codex 等任何 agent 平台行为一致，且不依赖终端 TTY。

# 生成每模块任务看板 TASKS-<模块>.md（落项目根，匹配 task-manager 的 TASKS_BASE=PROJECT_ROOT）
generate_tasks_files() {
    local modules; modules="$(collected_list modules)"
    [ -z "$modules" ] && { log_warn "未识别到模块，跳过 TASKS 生成"; return 0; }
    echo "$modules" | while IFS= read -r m; do
        [ -z "$m" ] && continue
        local f="TASKS-${m}.md"
        cat > "$f" <<EOF
# ${m} 模块任务看板（TASKS-${m}.md）
> 由 vibe-project-init 生成于 $(date "+%Y-%m-%d %H:%M:%S")
> 任务格式见 task-manager 规范：### [日期-模块-序号] 标题

（暂无任务，使用 task-manager create 创建首个任务）
EOF
        log_info "✅ 已生成 ${f}"
    done
}

# 生成 memory/project.config（task-manager 读取 VALID_PREFIXES 与 GIT_STATUS）
# 1.2.0：project.config 已并入 adapter.cfg（唯一配置文件），本函数删除。
# 保留一个占位说明，防止存量文档/调用点误引；存量项目由 task-manager 兼容回落读取。
generate_project_config() {
    return 0
}

# 按 git_status 处理 Git 仓库就绪（不代劳 commit/push，由人类执行）
setup_archive() {
    local gs="${1:-existing}"
    case "$gs" in
        new)
            if [ ! -d ".git" ]; then
                git init -q 2>/dev/null && log_info "✅ 已 git init（请自行添加 remote 并首次 commit）" \
                    || log_warn "git init 失败，请手动执行 git init"
            else
                log_info "Git 仓库已存在，跳过 git init"
            fi
            ;;
        none)
            log_info "未启用 Git：已为你准备简易快照（任务完成自动存版），无需 git init"
            ;;
        *)
            if [ ! -d ".git" ]; then
                log_warn "你选择使用 Git，但当前目录无 .git，请运行 git init"
            else
                log_info "Git 仓库就绪"
            fi
            ;;
    esac
}

# ============================================
# 适配模式（存量项目接入治理）— 自包含实现
# 不依赖 main 的占位函数（generate_tasks_files / setup_archive / 等）
# 草稿统一放 ${DRAFTS_DIR}，绝不碰正式治理目录
# ============================================

# 判断项目是否已接入治理（存在任一正式治理文件即视为已接入）
is_already_adapted() {
    local root="$1"
    for f in MEMORY.md RULES.md ROLES.md CONTRACT.md ARCHIVE.md; do
        [ -f "${root}/${GOVERNANCE_DIR}/memory/${f}" ] && return 0
        [ -f "${LEGACY_DIR}/${f}" ] && return 0
    done
    return 1
}

adapt() {
    local root="$(pwd)"

    # ---- 步骤1：前置只读校验 ----
    log_info "🔍 适配模式：前置校验（只读，绝不碰文件）..."
    if [ ! -d "${root}/.git" ]; then
        log_error "该项目未初始化 git 仓库，请先运行 git init 后再适配"
    fi
    if is_already_adapted "${root}"; then
        log_error "该项目已接入治理体系（.vibe-coding/memory 或 .workbuddy/memory 已存在正式治理文件），无需重复适配"
    fi

    # 仅创建临时草稿目录（非正式治理目录）
    mkdir -p "${root}/${DRAFTS_DIR}"

    # ---- 步骤2：只读扫描 ----
    log_info "📡 只读扫描现有项目（不写任何文件）..."

    # 2.1 识别模块
    local modules=()
    [ -d "${root}/pc" ]       && modules+=("PC")
    [ -d "${root}/android" ]  && modules+=("安卓")
    [ -d "${root}/cloud" ]    && modules+=("云端")
    [ -f "${root}/package.json" ] && modules+=("Node.js")

    # 2.1b 额外未识别的顶层目录（视为潜在模块，用于边界判定）
    # 排除：版本控制/构建/文档/测试等明显非业务模块目录
    local extra_modules=()
    for d in "${root}"/*/; do
        [ -d "$d" ] || continue
        local base="$(basename "$d")"
        case "$base" in
            .git|.workbuddy|node_modules|scripts|script|docs|doc|test|tests|build|dist|.cache|.idea|.vscode|target|vendor|.github|assets|public) continue ;;
            pc|android|cloud) continue ;;  # 已识别模块不重复计数
        esac
        extra_modules+=("$base")
    done
    local total_modules=$(( ${#modules[@]} + ${#extra_modules[@]} ))

    # 2.2 找历史 TODO 文件
    local todo_files=()
    for f in TODO.md todo.txt TODO.txt issues.md ISSUES.md CHANGELOG.md; do
        [ -f "${root}/$f" ] && todo_files+=("$f")
    done

    # 2.3 识别技术栈
    local techs=()
    [ -f "${root}/package.json" ] && techs+=("Node.js")
    { [ -f "${root}/build.gradle" ] || [ -f "${root}/build.gradle.kts" ]; } && techs+=("Java/Gradle")
    [ -f "${root}/pom.xml" ] && techs+=("Java/Maven")
    { [ -f "${root}/requirements.txt" ] || [ -f "${root}/pyproject.toml" ]; } && techs+=("Python")
    [ -f "${root}/go.mod" ] && techs+=("Go")
    [ -d "${root}/android" ] && techs+=("Kotlin/Android")

    # 2.4 查 commit 前缀规律（合规缺口依据）
    # 注意：Git-Bash 下 `git -C <symlink-path>` 会因 /tmp 等符号链接路径解析失败，
    # 改用子shell cd 进入项目根再执行 git，规避该问题。
    local has_prefix="no"
    local recent_msgs=""
    if (cd "${root}" && git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
        recent_msgs="$(cd "${root}" && git log --oneline -50 2>/dev/null || true)"
        if echo "${recent_msgs}" | grep -qiE '\[(PC|ANDROID|CLOUD|MEMORY|DOCS|FIX|TOOL)\]'; then
            has_prefix="yes"
        fi
    fi

    # 2.5 合规缺口清单
    local gaps=()
    [ "${has_prefix}" = "no" ] && gaps+=("当前 commit 无统一前缀，建议统一使用 [PC]/[ANDROID]/[CLOUD]/[MEMORY]/[DOCS]/[FIX]/[TOOL] 前缀")
    [ "${#todo_files[@]}" -eq 0 ] && gaps+=("未发现历史 TODO 文件（TODO.md/todo.txt/issues），无迁移来源")
    # 跨端日志 / Skill 版本记录 检查
    [ ! -f "${root}/${GOVERNANCE_DIR}/memory/CROSS_IMPACT_LOG.md" ] && gaps+=("无跨端影响日志 CROSS_IMPACT_LOG.md")
    [ ! -f "${root}/${GOVERNANCE_DIR}/SKILL_REGISTRY.md" ] && gaps+=("无 Skill 版本记录 SKILL_REGISTRY.md")

    # ---- 步骤3：生成草稿（仅草稿目录）----
    log_info "📝 生成适配草稿（放入 ${DRAFTS_DIR}/）..."

    # 3.1 RULES.draft.md：通用铁律 + 模块专属规则
    {
        echo "# 适配规则草稿（RULES.draft.md）"
        echo "> 生成时间：$(date "+%Y-%m-%d %H:%M:%S")"
        echo "> 来源：vibe-project-init 适配模式（存量项目接入）"
        echo ""
        echo "## 通用铁律（预置）"
        echo "- 已归档内容不可修改（历史 TODO/CHANGELOG 原文件不动）"
        echo "- 显式授权：任何写入正式治理目录的动作必须等你确认"
        echo "- 复杂度过高走兜底，不强行适配"
        echo ""
        echo "## 模块专属规则"
        if [ "${#modules[@]}" -gt 0 ]; then
            for m in "${modules[@]}"; do
                case "$m" in
                    PC)      echo "- PC 模块：commit 前缀用 [PC]" ;;
                    安卓)    echo "- 安卓模块：commit 前缀用 [ANDROID]" ;;
                    云端)    echo "- 云端模块：commit 前缀用 [CLOUD]" ;;
                    Node.js) echo "- Node.js：沿用 [PC]/[CLOUD] 等适用前缀" ;;
                esac
            done
        else
            echo "- （未识别到标准模块目录）"
        fi
    } > "${root}/${DRAFTS_DIR}/RULES.draft.md"

    # 3.2 TASKS-<模块>.draft.md：历史 TODO 拆任务，每条标 [历史迁移]
    local todo_items=()
    if [ "${#todo_files[@]}" -gt 0 ]; then
        for tf in "${todo_files[@]}"; do
            while IFS= read -r line; do
                local stripped="$(echo "$line" | sed -E 's/^[-*]\s*//; s/^\[[ xX]\]\s*//' | sed -E 's/^[0-9]+\.\s*//')"
                [ -z "${stripped}" ] && continue
                todo_items+=("${stripped}")
            done < <(grep -iE '^\s*[-*]\s*\[?[ xX]?\]?' "${root}/$tf" 2>/dev/null || true)
        done
    fi
    if [ "${#modules[@]}" -gt 0 ]; then
        for m in "${modules[@]}"; do
            {
                echo "# ${m} 模块任务草稿（TASKS-${m}.draft.md）"
                echo "> 生成时间：$(date "+%Y-%m-%d %H:%M:%S")"
                echo "> 来源：历史 TODO 迁移，全部标 [历史迁移]"
                echo ""
                if [ "${#todo_items[@]}" -gt 0 ]; then
                    for item in "${todo_items[@]}"; do
                        echo "## [历史迁移] ${item}"
                        echo "- 状态：📋 待处理"
                        echo "- 来源：现有项目历史 TODO（原文件未改动）"
                        echo ""
                    done
                else
                    echo "（未扫描到历史 TODO 条目，无迁移任务）"
                fi
            } > "${root}/${DRAFTS_DIR}/TASKS-${m}.draft.md"
        done
    fi

    # 3.3 ADAPT_REPORT.draft.md：合规缺口清单 + 适配建议
    {
        echo "# 适配报告草稿（ADAPT_REPORT.draft.md）"
        echo "> 生成时间：$(date "+%Y-%m-%d %H:%M:%S")"
        echo ""
        echo "## 识别到的模块"
        [ "${#modules[@]}" -gt 0 ] && echo "${modules[*]}" || echo "无"
        echo ""
        echo "## 识别到的技术栈"
        [ "${#techs[@]}" -gt 0 ] && echo "${techs[*]}" || echo "无"
        echo ""
        echo "## 历史 TODO 文件"
        if [ "${#todo_files[@]}" -gt 0 ]; then
            for tf in "${todo_files[@]}"; do echo "- $tf"; done
        else
            echo "未找到 TODO.md / todo.txt / issues 等文件"
        fi
        echo ""
        echo "## 合规缺口清单"
        if [ "${#gaps[@]}" -gt 0 ]; then
            for g in "${gaps[@]}"; do echo "- $g"; done
        else
            echo "- 未发现明显合规缺口"
        fi
        echo ""
        echo "## 适配建议"
        echo "- 将上述草稿经你确认后写入正式 .workbuddy/memory/ 目录"
        echo "- 历史任务统一标记 [历史迁移]，原 TODO/CHANGELOG 文件保持不变"
    } > "${root}/${DRAFTS_DIR}/ADAPT_REPORT.draft.md"

    log_info "适配草稿已生成，放在 ${DRAFTS_DIR}/ 目录下"
    echo "────────────────────────────────────────"
    echo "适配草稿已就绪。本脚本不接收终端交互，请由 AI 助手决定下一步："
    echo "  ① 全量适配：  bash $0 adapt apply all"
    echo "  ② 指定模块：  bash $0 adapt apply <模块名>"
    echo "  ③ 预览草稿：  bash $0 adapt preview"
    echo "（仅 'apply' 会把草稿写入正式治理目录 ${GOVERNANCE_DIR}/memory/，需明确授权）"
    echo "────────────────────────────────────────"
}

# 步骤4：适配草稿已生成后由 AI 助手显式调用 'adapt apply' / 'adapt preview' 完成适配，
#        本脚本不再含 read 向导（agent 驱动，详见 SKILL.md「project-init 交互约定」）。

# 步骤4-①/②：把草稿写入正式治理目录（仅在你明确授权后调用）
adapt_apply() {
    local root="$1"
    local scope="${2:-all}"
    local target="${root}/${GOVERNANCE_DIR}/memory"
    mkdir -p "${target}"
    local moved=0
    for f in "${root}/${DRAFTS_DIR}"/*.draft.md; do
        [ -f "$f" ] || continue
        local base="$(basename "$f" .draft.md)"
        # 按 scope 过滤模块任务文件
        if [ "$scope" != "all" ]; then
            case "$base" in
                TASKS-*)
                    local mod="${base#TASKS-}"
                    [ "$mod" != "$scope" ] && continue ;;
            esac
        fi
        cp "$f" "${target}/${base}.md"
        moved=$((moved + 1))
    done
    log_info "已将 ${moved} 份草稿写入正式治理目录 ${target}/"
    # 偏差2：health-check 降级——目录不存在时仅提示，不卡死、不留空壳调用
    if [ -d "${root}/.workbuddy/skills/health-check" ] || command -v health-check >/dev/null 2>&1; then
        log_info "触发 health-check 首次体检..."
    else
        log_warn "health-check 待上线，跳过首次体检，待其就绪后手动运行"
    fi
}

# 步骤4-③：预览草稿核心规则
adapt_preview() {
    local root="$1"
    echo "📖 草稿核心规则预览："
    echo "----------------------------------------"
    cat "${root}/${DRAFTS_DIR}/RULES.draft.md" 2>/dev/null || true
    echo "----------------------------------------"
}

# ---------- 多工具适配：给 WorkBuddy 代理记忆追加治理指针（只追加、不覆盖、重复运行只加一次） ----------
link_agent_memory_pointer() {
    # 未定位到项目根目录（非治理工作区）则安全跳过，绝不退化为写全局 ~/.workbuddy
    [ -n "${PROJECT_ROOT:-}" ] || { log_info "未定位到项目根目录，跳过代理记忆指针追加"; return 0; }
    local agent_mem="${PROJECT_ROOT}/.workbuddy/memory/MEMORY.md"
    local marker="## VPG 治理指针"
    # 仅当项目工作区内的 .workbuddy/memory/ 存在时才写入，路径已由 PROJECT_ROOT 锁定为工作区本地
    [ -d "${PROJECT_ROOT}/.workbuddy/memory" ] || { log_info "未检测到 ${PROJECT_ROOT}/.workbuddy/memory/，跳过代理记忆指针追加"; return 0; }
    # 已追加过则跳过（重复运行只加一次）
    if [ -f "$agent_mem" ] && grep -qF "$marker" "$agent_mem"; then
        log_info "代理记忆指针已存在，跳过"; return 0
    fi
    # 宿主尚未生成 MEMORY.md 时，创建仅含指针的最小文件（幂等；宿主后续按追加方式写入，不覆盖不冲突）
    if [ ! -f "$agent_mem" ]; then
        echo "# AI 代理运行记忆" > "$agent_mem"
        log_info "已创建 ${agent_mem}（仅含治理指针，宿主可继续追加）"
    fi
    {
        echo ""
        echo "$marker"
        echo "本项目已接入 Vibe Project Governance（vibe-coding-toolkit）。"
        echo "权威治理文档位于 \`.vibe-coding/memory/\`，与本项目 AI 代理运行记忆（\`.workbuddy/memory/\`）相互独立。"
        echo "涉及治理规则、角色、契约、任务流转时，请读取 \`.vibe-coding/memory/\` 下的 MEMORY.md 及对应子文档。"
    } >> "$agent_mem"
    log_info "✅ 已在 .workbuddy/memory/MEMORY.md 追加 VPG 治理指针"
}


# ---------- 主逻辑（精简示意，保留你的原逻辑） ----------
main() {
    case "${1:-start}" in
        -h|--help)
            echo "用法：$0 <start|batch> [snapshot ...] [adapt ...]"
            echo "  -h, --help      显示帮助"
            echo "  start|batch     生成治理骨架（二选一，行为相同）。"
            echo "                   本脚本不接收终端交互输入，也不含 read 向导；"
            echo "                   须由 AI 助手在聊天中收集项目信息并写入"
            echo "                   .cache/project-init/collected.cfg 后调用。"
            echo "  ask              问题模板与校验（交互约定脚本化）：--list 输出 Q1-Q5 模板 | --validate 校验 collected.cfg"
            echo "  git              本地提交历史（版本管理统一 git，回滚选版本用）：history"
            echo "  adapt            适配存量项目：apply [all|模块名] | preview"
            exit 0
            ;;
        batch|start)
            # agent 专用入口：要求 collected.cfg 已由 AI 助手预置，跳过任何交互。
            ensure_collected_present
            # 强制校验：值非法（空/选项字面值/枚举错误）则拒绝生成，AI 不手动跑 ask --validate 也会被拦
            ask_validate
            ;;
        adapt)
            shift
            case "${1:-}" in
                apply)   adapt_apply "$(pwd)" "${2:-all}" ;;
                preview) adapt_preview "$(pwd)" ;;
                *)       adapt ;;
            esac
            exit 0
            ;;
        ask)
            shift
            ask "$@"
            exit 0
            ;;
        git)
            shift
            case "${1:-}" in
                history) git_history ;;
                *)       echo "用法：$0 git <history>"; exit 1 ;;
            esac
            exit 0
            ;;
        *)
            log_error "未知参数：${1}，使用-h查看帮助"
            ;;
    esac

    # 数据契约：所有 generate_* 从 ${COLLECTED_FILE}（key=value）读取。
    # 本脚本不接收终端交互输入；collected.cfg 必须由 AI 助手预置（详见 SKILL.md「project-init 交互约定」）。
    git_status="$(collected_get git_status)"
    [ -z "${git_status}" ] && git_status="existing"

    # 运行日志：骨架目录未建时先建 logs 容器，再初始化本次运行日志（模块-日期-时间.log）
    mkdir -p ".vibe-coding/logs" 2>/dev/null || true
    log_init "project-init"
    log_info "开始生成治理骨架（模块：$(collected_list modules | tr '\n' ',' | sed 's/,$//')，git：${git_status}）"

    generate_memory_files
    generate_tasks_files
    generate_project_config
    generate_vpg_entry   # 根目录可见入口文件（解决隐藏目录不可见问题）

    setup_archive "${git_status}"

    # 1.1.0：旧项目迁移 → 生成适配层配置 → 生成前缀规则 → 安装提交钩子
    maybe_migrate_legacy
    generate_adapter_cfg
    write_platform "$(platform_detect)"   # 平台探测：写入 adapter.cfg 的 PLATFORM（保留供诊断）
    # 注意：此处不再 source adapter.cfg（防任意代码执行）；generate_* 仅用脚本内已知变量
    generate_commit_rules
    install_commit_msg_hook
    link_agent_memory_pointer  # 多工具适配：给 WorkBuddy 代理记忆追加治理指针（只追加、不覆盖）

    # 配置一致性自检：GIT_STATUS 枚举合法（git 唯一模式）
    config_sanity

    rm -rf "./.cache/project-init"
    log_success "项目初始化完成（骨架生成成功，日志：${LOG_FILE}）"

    # 首次引导：脚本输出填充好的引导文本，AI 原样复制到聊天（摆脱 AI 阅读理解模板）
    echo ""
    log_info "========== 首次引导（请 AI 原样复制以下内容到聊天，并将'首个具体任务'替换为按项目推断的具体任务）=========="
    ask_guide
    echo "========================================================"
}

main "$@"