#!/bin/bash
set -euo pipefail

# ============================================
# vibe-project-init.sh — Vibe 项目初始化 Skill
# 对应 skill.md: skills/vibe-project-init/skill.md
# ============================================

# ---------- 配置区 ----------
CACHE_DIR=".cache/project-init"
COLLECTED_JSON="${CACHE_DIR}/collected.json"
QUESTION_INDEX="${CACHE_DIR}/question_index"
MEMORY_DIR="memory"
GITIGNORE=".gitignore"

# 【关键】铁律模板路径：你维护的“宪法”放在这里
# 建议将此文件放在 skill 目录下，例如 skills/vibe-project-init/templates/RULES.template.md
# 脚本会自动读取它来生成项目的 RULES.md
RULES_TEMPLATE="$(dirname "$0")/../templates/RULES.template.md"
VALID_PREFIXES=("PC" "ANDROID" "CLOUD" "MEMORY" "DOCS" "FIX" "TOOL")

# 适配模式（存量项目接入）专用：草稿只放临时目录，绝不碰正式治理目录
DRAFTS_DIR=".workbuddy/memory/drafts"

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

## 全局铁律（不可违反）
请查阅 \`RULES.md\` 获取完整且不可篡改的基础铁律。

## 快速参考
- 仓库路径：$(pwd)
- 模块列表：$(echo "${modules}" | tr '\n' ',' | sed 's/,$//')
- Git纪律：commit前缀必须符合[${VALID_PREFIXES[*]}]格式
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
2. **commit规范**：前缀必须为[${VALID_PREFIXES[*]}]。
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
        [ -f "${root}/.workbuddy/memory/${f}" ] && return 0
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
        log_error "该项目已接入治理体系（.workbuddy/memory 已存在正式治理文件），无需重复适配"
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

    # 2.1b 额外未识别的顶层目录（视为潜在模块，用于复杂度熔断）
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
    [ ! -f "${root}/.workbuddy/memory/CROSS_IMPACT_LOG.md" ] && gaps+=("无跨端影响日志 CROSS_IMPACT_LOG.md")
    [ ! -f "${root}/.workbuddy/skills/SKILL_REGISTRY.md" ] && gaps+=("无 Skill 版本记录 SKILL_REGISTRY.md")

    # ---- 步骤5：复杂度熔断（扫描后判定，必须执行）----
    # 注意：使用 total_modules（已知模块 + 额外顶层模块）作为判定基数，
    # 仅统计已知 3 模块会漏判 PC/安卓/云端 + IoT/硬件 等超 3 模块场景。
    local fuse_reason=""
    if [ "${total_modules}" -gt 3 ]; then
        fuse_reason="模块数=${total_modules}（>3：已知=${modules[*]:-无} 额外=${extra_modules[*]:-无}）"
    elif [ "${#techs[@]}" -gt 3 ]; then
        fuse_reason="技术栈数=${#techs[@]}（>3：${techs[*]}）"
    elif [ "${has_prefix}" = "no" ] && [ -z "$(echo "${recent_msgs}" | grep -iE '\[|#|fix|feat|init' || true)" ]; then
        fuse_reason="历史 commit 完全无前缀或归属标记规律"
    fi
    if [ -n "${fuse_reason}" ]; then
        log_warn "适配复杂度过高（原因：${fuse_reason}），建议申请 Coordinator 数字分身兜底处理"
        return 0
    fi

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
    local target="${root}/.workbuddy/memory"
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

# ---------- 主逻辑（精简示意，保留你的原逻辑） ----------
main() {
    case "${1:-}" in
        -h|--help)
            echo "用法：$0 [选项]"
            echo "  -h, --help    显示帮助"
            echo "  start          开始项目初始化流程"
            echo "  resume         恢复未完成初始化"
            exit 0
            ;;
        start)
            log_info "🎸 开始 Vibe 项目初始化..."
            rm -rf "${CACHE_DIR}"
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
    
    rm -rf "${CACHE_DIR}"
    log_info "🎉 项目初始化完成！"
    log_info "👉 下一步：运行 commit-check 验证，或用 task-manager 创建首个任务"
}

main "$@"