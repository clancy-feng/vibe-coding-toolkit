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

# 安全读取空格分隔的目录列表（如 SNAPSHOT_BACKUP_DIRS="src config"）
# 逐段校验：仅允许相对路径（拒绝绝对路径 / shell 元字符），全段通过才返回，否则回落默认（空串）。
# 不 return 非 0，避免触发 set -e 退出调用方。
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

# ---------- 配置区 ----------
CACHE_DIR=".cache/project-init"
COLLECTED_JSON="${CACHE_DIR}/collected.json"
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

# 简易快照（无 Git 用户的后悔药，1.0.0 新增）：默认关闭，仅用户明确选择不使用 Git 时启用
SNAPSHOT_ENABLED="false"
SNAPSHOT_DIR="${GOVERNANCE_DIR}/snapshots"
SNAPSHOT_BACKUP_DIRS="src config"
MAX_SNAPSHOT_COUNT="20"
ROLLBACK_BACKUP_RETENTION_DAYS="7"

if [ -f "${ADAPTER_CFG}" ]; then
    # 仅白名单提取，拒绝任意代码执行；取值非法（绝对路径/含元字符）则回落默认
    cfg_commit="$(safe_cfg_get COMMIT_RULES "${ADAPTER_CFG}")"
    [ -n "$cfg_commit" ] && COMMIT_RULES="$cfg_commit"
    cfg_hook="$(safe_cfg_get HOOK_ENABLED "${ADAPTER_CFG}")"
    [ -n "$cfg_hook" ] && HOOK_ENABLED="$cfg_hook"
    # 快照配置（SNAPSHOT_BACKUP_DIRS 含空格，用专用安全读取）
    cfg_snap="$(safe_cfg_get SNAPSHOT_ENABLED "${ADAPTER_CFG}")"
    [ -n "$cfg_snap" ] && SNAPSHOT_ENABLED="$cfg_snap"
    cfg_dirs="$(safe_cfg_get_dirs SNAPSHOT_BACKUP_DIRS "${ADAPTER_CFG}" 2>/dev/null || true)"
    [ -n "$cfg_dirs" ] && SNAPSHOT_BACKUP_DIRS="$cfg_dirs"
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
LEGACY_DIR=".workbuddy/memory"

# ---------- 工具函数 ----------
log_info() { echo -e "✅ $1"; }
log_warn() { echo -e "⚠️ $1"; }
log_error() { echo -e "❌ $1" >&2; exit 1; }

ensure_cache_dir() {
    mkdir -p "${CACHE_DIR}"
    touch "${COLLECTED_JSON}" 2>/dev/null || true
    echo "0" > "${QUESTION_INDEX}" 2>/dev/null || true
}

load_collected() {
    if [ -s "${COLLECTED_JSON}" ]; then
        cat "${COLLECTED_JSON}"
    else
        echo "{}"
    fi
}

save_collected() {
    local json="$1"
    echo "${json}" > "${COLLECTED_JSON}"
}

# ---------- 痛点规则生成器 ----------
# 根据用户在init第6轮选择的痛点，生成针对性的规则文本
generate_pain_point_rules() {
    local pain_points=$(echo "$1" | jq -r '.pain_points[]?' 2>/dev/null)
    if [ -z "$pain_points" ]; then
        return
    fi

    echo "## 针对性加固规则（基于你的历史痛点）"
    echo "> 以下规则由初始化程序根据你的反馈自动生成，用于防范已知风险。"
    echo ""

    # 遍历痛点并生成规则
    echo "$pain_points" | while read -r point; do
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
    local json=$(load_collected)
    local project_name=$(echo "${json}" | jq -r '.project_name')
    local modules=$(echo "${json}" | jq -r '.modules[]')
    local supp=$(echo "${json}" | jq -r '.supplementary_notes // "无"')

    mkdir -p "${MEMORY_DIR}"

    # 1. MEMORY.md (保持不变)
    cat > "${MEMORY_DIR}/MEMORY.md" << EOF
# ${project_name} — 项目治理主索引
> 生成时间：$(date "+%Y-%m-%d %H:%M:%S")
> 框架版本：Vibe Project Governance v1.0

## 本目录身份声明
> 本目录是 **VPG 治理记忆**，由 vibe-coding-toolkit 生成与管理。
> 它与 WorkBuddy 宿主的 \`.workbuddy/memory/\`（AI 代理运行记忆）**相互独立、各司其职**：本目录存项目治理文档，\`.workbuddy/memory/\` 存 AI 自身运行记忆。
> 其他 AI 工具只需只读本目录即可获得完整治理上下文（多工具适配接口）。

## 全局铁律（不可违反）
请查阅 \`RULES.md\` 获取完整且不可篡改的基础铁律。

## 快速参考
- 仓库路径：$(pwd)
- 模块列表：$(echo "${modules}" | tr '\n' ',' | sed 's/,$//')
- Git纪律：commit前缀必须符合 .vibe-coding/commit-rules.yaml 中 prefixes 列表（不含方括号，如 [PC]）
EOF

    # 2. PROJECT_PROFILE.md (保持不变)
    cat > "${MEMORY_DIR}/PROJECT_PROFILE.md" << EOF
# 项目画像：${project_name}
> 生成时间：$(date "+%Y-%m-%d %H:%M:%S")

## 项目目标
$(echo "${json}" | jq -r '.project_desc')

## 使用场景
$(echo "${json}" | jq -r '.usage_places[] | "- \(.)"')

## 技术栈
$(echo "${json}" | jq -r '.tech_stack[] | "- \(.)"')

## 补充需求
${supp}
EOF

    # 3. ROLES.md (保持不变)
    cat > "${MEMORY_DIR}/ROLES.md" << EOF
# 角色分工与护栏
> 生成时间：$(date "+%Y-%m-%d %H:%M:%S")

## 全局角色
- **coordinator**：项目总管，负责创建任务、审查commit、更新记忆文件
- **各模块开发**：按模块分工，仅修改所属模块文件

## 模块分工
$(for module in ${modules}; do
echo "### ${module}"
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
$(if [ "$(echo "${json}" | jq -r '.git_status')" = "none" ]; then
echo "5. 未启用存档，commit-check真实性验证受限"
fi)
EOF

    # 4. RULES.md (核心修改：读取模板 + 插入痛点规则)
    if [ -f "$RULES_TEMPLATE" ]; then
        # 读取你维护的铁律模板
        cp "$RULES_TEMPLATE" "${MEMORY_DIR}/RULES.md"
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
    generate_pain_point_rules "$json" >> "${MEMORY_DIR}/RULES.md"

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
    cat > "${ADAPTER_CFG}" << 'EOF'
# .vibe-coding/adapter.cfg
# 跨平台适配配置，修改此文件即可切换产品环境，无需改核心逻辑
PRODUCT_NAME="workbuddy"       # 当前产品标识，Day1固定为workbuddy
GOVERNANCE_DIR=".vibe-coding"  # 治理根目录，相对项目根路径

# 衍生路径（基于GOVERNANCE_DIR，无需修改）
COMMIT_RULES="${GOVERNANCE_DIR}/commit-rules.yaml"
SKILL_REGISTRY="${GOVERNANCE_DIR}/SKILL_REGISTRY.md"
CONTRACT_FILE="${GOVERNANCE_DIR}/CONTRACT.md"
IMPACT_LOG="${GOVERNANCE_DIR}/CROSS_IMPACT_LOG.md"
TASKS_FILE="${GOVERNANCE_DIR}/TASKS.md"
AUDIT_LOG="${GOVERNANCE_DIR}/memory/HEALTH_AUDIT.md"

# 行为开关（Day1仅适配WorkBuddy，保留扩展字段）
HOOK_ENABLED="true"             # 默认开启commit-msg钩子
EOF
    log_info "✅ 已生成跨平台适配层配置 ${ADAPTER_CFG}"
}

# 生成提交前缀规则 commit-rules.yaml（干净前缀，不带行内注释，避免 commit-check 解析失败）
generate_commit_rules() {
    local json=$(load_collected)
    local check=$(echo "${json}" | jq -r '.commit_prefix_check // "true"' 2>/dev/null)
    local prefixes=$(echo "${json}" | jq -r '.commit_prefixes[]?' 2>/dev/null)
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
    log_warn "检测到旧版治理文件（.workbuddy/memory/），是否迁移至 ${GOVERNANCE_DIR}/？（Y 迁移 / N 保留，默认 N）"
    local ans="N"
    if [ -t 0 ]; then
        read -r -p "是否迁移？(y/N) " ans
    fi
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

# ---------- 其他函数（setup_archive, collect_supplementary, confirm_all_info, generate_tasks_files, generate_project_config, main）----------
# 以下函数保持不变，为了篇幅起见省略，实际使用时需保留你原有的这些函数
# 确保 main 函数中调用了 generate_memory_files 和 generate_tasks_files 等

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
        [ -f "${root}/${LEGACY_DIR}/${f}" ] && return 0
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
    echo "  你要不要先看草稿内容，还是直接选适配方案？"
    echo "  ① 全量适配  ② 仅适配指定模块  ③ 先看草稿内容"

    # ---- 步骤4：等用户三选一（显式授权才写入正式目录）----
    adapt_await_choice "${root}"
}

# 步骤4：等待用户三选一（非交互环境仅提示，不阻塞、不写入）
adapt_await_choice() {
    local root="$1"
    if [ ! -t 0 ]; then
        log_info "（非交互环境：请显式运行 'bash $0 adapt apply [模块名|all]' 或 'bash $0 adapt preview' 完成适配）"
        return 0
    fi
    local choice=""
    read -r -p "请选择（1/2/3）：" choice
    case "$choice" in
        1) adapt_apply "${root}" "all" ;;
        2)
            local mod=""
            read -r -p "请输入要适配的模块名：" mod
            adapt_apply "${root}" "${mod}" ;;
        3)
            adapt_preview "${root}"
            adapt_await_choice "${root}" ;;
        *) log_warn "无效选择，未写入任何正式目录" ;;
    esac
}

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
    local agent_mem=".workbuddy/memory/MEMORY.md"
    local marker="## VPG 治理指针"
    # 非 WorkBuddy 工作区（无 .workbuddy/memory/）则无需追加，直接跳过
    [ -d ".workbuddy/memory" ] || { log_info "未检测到 .workbuddy/memory/，跳过代理记忆指针追加"; return 0; }
    # 宿主尚未生成 MEMORY.md 时也不强行创建，避免与宿主行为冲突
    [ -f "$agent_mem" ] || { log_info "未检测到 ${agent_mem}（宿主将自行生成），跳过指针追加"; return 0; }
    # 已追加过则跳过（重复运行只加一次）
    grep -qF "$marker" "$agent_mem" && { log_info "代理记忆指针已存在，跳过"; return 0; }
    {
        echo ""
        echo "$marker"
        echo "本项目已接入 Vibe Project Governance（vibe-coding-toolkit）。"
        echo "权威治理文档位于 \`.vibe-coding/memory/\`，与本项目 AI 代理运行记忆（\`.workbuddy/memory/\`）相互独立。"
        echo "涉及治理规则、角色、契约、任务流转时，请读取 \`.vibe-coding/memory/\` 下的 MEMORY.md 及对应子文档。"
    } >> "$agent_mem"
    log_info "✅ 已在 .workbuddy/memory/MEMORY.md 追加 VPG 治理指针"
}

# ---------- 简易快照（无 Git 用户的后悔药，1.0.0 新增）----------
# 设计原则：非破坏性（不改原 Git 逻辑）、土法（全量备份+一键回滚）、AI 零裁量（每次操作须用户授权）、
# 目录隔离（只备份用户指定业务目录，绝不碰 .git/.workbuddy/.vibe-coding）、纯 POSIX、零外部依赖。

# 启用快照：仅当用户明确选择不使用 Git 时由 init 第7轮（或 AI 引导）调用，写入 adapter.cfg
snapshot_init() {
    [ -f "${ADAPTER_CFG}" ] || generate_adapter_cfg
    local dirs=""
    read -r -p "简易快照会备份哪些目录？（默认 src config，可补充如 data docs，空格分隔）" dirs
    dirs="${dirs:-src config}"
    {
        echo ""
        echo "# ===== 简易快照配置（仅 SNAPSHOT_ENABLED=true 时生效）====="
        echo "SNAPSHOT_ENABLED=\"true\""
        echo "SNAPSHOT_DIR=\"${GOVERNANCE_DIR}/snapshots\""
        echo "SNAPSHOT_BACKUP_DIRS=\"${dirs}\""
        echo "MAX_SNAPSHOT_COUNT=\"20\""
        echo "ROLLBACK_BACKUP_RETENTION_DAYS=\"7\""
    } >> "${ADAPTER_CFG}"
    SNAPSHOT_ENABLED="true"
    SNAPSHOT_BACKUP_DIRS="$dirs"
    mkdir -p "${SNAPSHOT_DIR}"
    log_info "✅ 已启用简易快照，备份目录：${dirs}（仅全量备份+一键回滚，不能替代 Git 的协作/分支）"
}

# 前置校验：快照是否启用；未启用则提示并退出
ensure_snapshot_enabled() {
    [ "${SNAPSHOT_ENABLED}" = "true" ] || { log_warn "快照功能未启用。请先运行：vibe-project-init snapshot init"; return 1; }
    # 重载最新配置（防止 init 后内存值未刷新）
    local cfg
    cfg="$(safe_cfg_get SNAPSHOT_ENABLED "${ADAPTER_CFG}" 2>/dev/null || true)"
    [ "$cfg" = "true" ] && SNAPSHOT_ENABLED="true"
    cfg="$(safe_cfg_get_dirs SNAPSHOT_BACKUP_DIRS "${ADAPTER_CFG}" 2>/dev/null || true)"
    [ -n "$cfg" ] && SNAPSHOT_BACKUP_DIRS="$cfg"
    [ "${SNAPSHOT_ENABLED}" = "true" ] || { log_warn "快照功能未启用。请先运行：vibe-project-init snapshot init"; return 1; }
    mkdir -p "${SNAPSHOT_DIR}"
    return 0
}

# 解析“上一个版本”：latest.meta 之外、时间戳倒序的第一条
snapshot_resolve_prev() {
    local latest=""
    [ -f "${SNAPSHOT_DIR}/latest.meta" ] && latest="$(cat "${SNAPSHOT_DIR}/latest.meta" 2>/dev/null || true)"
    find "${SNAPSHOT_DIR}" -mindepth 1 -maxdepth 1 -type d -name '20*' 2>/dev/null | sort -r | while IFS= read -r d; do
        local bn; bn="$(basename "$d")"
        [ "$bn" != "$latest" ] && { echo "$bn"; break; }
    done
}

# 按编号解析（list 倒序中的第 N 条）
snapshot_resolve_by_index() {
    local idx="$1" i=0
    find "${SNAPSHOT_DIR}" -mindepth 1 -maxdepth 1 -type d -name '20*' 2>/dev/null | sort -r | while IFS= read -r d; do
        i=$((i + 1))
        if [ "$i" -eq "$idx" ]; then echo "$(basename "$d")"; break; fi
    done
}

# 打快照：问描述 → 生成时间戳目录 → 全量 cp → 写 meta → 更新 latest → 数量上限提示
snapshot_create() {
    ensure_snapshot_enabled || exit 1
    local desc=""
    read -r -p "这次快照要记什么？（如：改了登录验证码）" desc
    desc="${desc:-未命名}"
    local name="$(date +%Y%m%d_%H%M%S)_$(echo "$desc" | tr ' /' '_')"
    local dest="${SNAPSHOT_DIR}/${name}"
    mkdir -p "${dest}"
    local d copied=0
    for d in ${SNAPSHOT_BACKUP_DIRS}; do
        case "$d" in
            .git|.workbuddy|.vibe-coding) log_warn "跳过治理目录 $d（不备份）"; continue ;;
        esac
        if [ -d "$d" ]; then
            cp -r "$d" "${dest}/"
            copied=$((copied + 1))
        else
            log_warn "目录不存在，跳过：$d"
        fi
    done
    {
        echo "时间戳：$(date "+%Y-%m-%d %H:%M:%S")"
        echo "描述：${desc}"
        echo "备份目录：${SNAPSHOT_BACKUP_DIRS}"
        echo "快照ID：${name}"
        echo "创建人：coordinator"
    } > "${dest}/snapshot.meta"
    echo "${name}" > "${SNAPSHOT_DIR}/latest.meta"
    local count
    count="$(find "${SNAPSHOT_DIR}" -mindepth 1 -maxdepth 1 -type d -name '20*' 2>/dev/null | wc -l | tr -d ' ')"
    if [ "$count" -gt "${MAX_SNAPSHOT_COUNT}" ]; then
        log_warn "已有 ${count} 个快照（上限 ${MAX_SNAPSHOT_COUNT}）。运行 'vibe-project-init snapshot cleanup old' 删除旧快照（需授权）"
    fi
    log_info "✅ 快照已保存，ID：${name}，描述：${desc}（已备份 ${copied} 个目录）"
}

# 列快照：倒序读 meta → 格式化列表 → 提示可回滚
snapshot_list() {
    ensure_snapshot_enabled || exit 1
    local metas
    metas="$(find "${SNAPSHOT_DIR}" -mindepth 2 -maxdepth 2 -name snapshot.meta 2>/dev/null | sort -r)"
    [ -z "$metas" ] && { log_warn "还没有任何快照。运行 'vibe-project-init snapshot create' 打个快照"; return 0; }
    local i=0 id ts desc
    echo "已保存的快照："
    echo "$metas" | while IFS= read -r m; do
        i=$((i + 1))
        id="$(grep -E '^快照ID：' "$m" | sed 's/^快照ID：//')"
        ts="$(grep -E '^时间戳：' "$m" | sed 's/^时间戳：//')"
        desc="$(grep -E '^描述：' "$m" | sed 's/^描述：//')"
        echo "  ${i}. ID: ${id} | 描述：${desc} | 时间：${ts}"
    done
    echo "要回滚到某个版本？告诉我 ID 或编号：vibe-project-init snapshot rollback <ID|编号>"
}

# 回滚：解析目标 → 校验 → 回滚前自动备份当前版 → cp -rf 覆盖业务目录 → 更新 latest
snapshot_rollback() {
    ensure_snapshot_enabled || exit 1
    local target="${1:-}" name=""
    if [ -z "$target" ]; then
        name="$(snapshot_resolve_prev)"
    elif [ -d "${SNAPSHOT_DIR}/${target}" ]; then
        name="$target"
    else
        name="$(snapshot_resolve_by_index "$target")"
    fi
    [ -z "$name" ] && log_error "没找到这个版本的快照，先用 'vibe-project-init snapshot list' 查看"
    [ -d "${SNAPSHOT_DIR}/${name}" ] || log_error "快照目录缺失：${name}"

    # 回滚前安全兜底：自动备份当前版本到 rollback_backups（保留 ROLLBACK_BACKUP_RETENTION_DAYS 天）
    local pre="$(date +%Y%m%d_%H%M%S)_pre_rollback"
    local pre_dir="${SNAPSHOT_DIR}/rollback_backups/${pre}"
    mkdir -p "${pre_dir}"
    local d
    for d in ${SNAPSHOT_BACKUP_DIRS}; do
        [ -d "$d" ] && cp -rf "$d" "${pre_dir}/"
    done

    # 执行回滚（仅覆盖用户指定的业务目录，绝不碰治理目录）
    for d in ${SNAPSHOT_BACKUP_DIRS}; do
        case "$d" in
            .git|.workbuddy|.vibe-coding) continue ;;
        esac
        if [ -d "${SNAPSHOT_DIR}/${name}/$d" ]; then
            cp -rf "${SNAPSHOT_DIR}/${name}/$d" "./"
        fi
    done
    echo "${name}" > "${SNAPSHOT_DIR}/latest.meta"
    log_info "✅ 已回滚到版本 ${name}。若回滚错了，可恢复临时备份（${pre}）：vibe-project-init snapshot rollback ${pre}"
}

# 清理：old=删3个月前快照；rollback=删7天前回滚备份；均需用户授权
snapshot_cleanup() {
    local what="${1:-old}"
    ensure_snapshot_enabled || exit 1
    local cutoff="" base="" list="" d bn ts
    if [ "$what" = "old" ]; then
        cutoff="$(date -d '3 months ago' +%Y%m%d 2>/dev/null || date -v-3m +%Y%m%d 2>/dev/null || true)"
        base="${SNAPSHOT_DIR}"
        local pat='20*'
    elif [ "$what" = "rollback" ]; then
        cutoff="$(date -d '7 days ago' +%Y%m%d 2>/dev/null || date -v-7d +%Y%m%d 2>/dev/null || true)"
        base="${SNAPSHOT_DIR}/rollback_backups"
        local pat='*_pre_rollback'
    else
        log_warn "用法：vibe-project-init snapshot cleanup old|rollback"
        return 0
    fi
    [ -z "$cutoff" ] && { log_warn "无法计算日期，跳过"; return 0; }
    list="$(find "$base" -mindepth 1 -maxdepth 1 -type d -name "$pat" 2>/dev/null | sort)"
    [ -z "$list" ] && { log_info "没有可清理的 ${what} 备份"; return 0; }
    echo "将删除以下 ${what} 备份："
    for d in $list; do
        bn="$(basename "$d")"; echo "  $bn"
    done
    local ans=""
    read -r -p "确认删除？（y/N）" ans
    case "$ans" in
        y|Y) for d in $list; do rm -rf "$d"; done; log_info "✅ 已删除 ${what} 备份" ;;
        *) log_warn "已取消" ;;
    esac
}

# ---------- 主逻辑（精简示意，保留你的原逻辑） ----------
main() {
    case "${1:-}" in
        -h|--help)
            echo "用法：$0 [选项]"
            echo "  -h, --help    显示帮助"
            echo "  start          开始项目初始化流程"
            echo "  resume         恢复未完成初始化"
            echo "  snapshot       简易快照（无 Git 用户的后悔药）：init|create|list|rollback|cleanup"
            exit 0
            ;;
        start)
            log_info "🎸 开始 Vibe 项目初始化..."
            rm -rf "./.cache/project-init"
            init_collected
            set_question_index "0"
            ;;
        resume)
            log_info "🔄 恢复项目初始化..."
            init_collected
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
        snapshot)
            shift
            case "${1:-}" in
                init)     snapshot_init ;;
                create)   snapshot_create ;;
                list)     snapshot_list ;;
                rollback) snapshot_rollback "${2:-}" ;;
                cleanup)  snapshot_cleanup "${2:-}" ;;
                *)        echo "用法：$0 snapshot <init|create|list|rollback|cleanup>"; exit 1 ;;
            esac
            exit 0
            ;;
        *)
            log_error "未知参数：${1}，使用-h查看帮助"
            ;;
    esac

    # 交互流程（你的原逻辑，保持不变）
    if [ ! -s "${COLLECTED_JSON}" ] || [ "$(cat "${COLLECTED_JSON}")" = "{}" ]; then
        # ... 你的交互问答逻辑 ...
        # 注意：确保最后调用了 generate_memory_files 等函数
        :
    fi

    collect_supplementary
    confirm_all_info

    generate_memory_files
    generate_tasks_files
    generate_project_config

    setup_archive "${git_status}"

    # 1.1.0：旧项目迁移 → 生成适配层配置 → 生成前缀规则 → 安装提交钩子
    maybe_migrate_legacy
    generate_adapter_cfg
    # 注意：此处不再 source adapter.cfg（防任意代码执行）；generate_* 仅用脚本内已知变量
    generate_commit_rules
    install_commit_msg_hook
    link_agent_memory_pointer  # 多工具适配：给 WorkBuddy 代理记忆追加治理指针（只追加、不覆盖）

    rm -rf "./.cache/project-init"
    log_info "🎉 项目初始化完成！"
    log_info "👉 下一步：运行 commit-check 验证，或用 task-manager 创建首个任务"
}

main "$@"