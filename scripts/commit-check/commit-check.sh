#!/usr/bin/env bash
# ============================================================
# commit-check.sh — AI Commit 真实性 & 合规性验证
#
# 用途: AI 声称"已提交"后，验证 commit 是否真实、合规、属于当前项目。
# 用法: commit-check.sh [-h|-s|-m|-o]（在任意 git 仓库内运行）
#   -h    显示帮助
#   -s    仅检查 git status（工作区是否干净 + commit 存在）
#   -m    仅检查 commit message 前缀
#   -o    仅检查 commit 归属（属于当前项目）
#   无选项 三项全检
#
# 依赖: git, bash
# 职责边界: 本脚本仅验证 commit 属性，不负责代码内容审查或越界检查。
#
# 前缀规则来源: 优先读取 .vibe-coding/adapter.cfg 的 COMMIT_RULES，
#   回落 .vibe-coding/commit-rules.yaml，再回落 .workbuddy/commit-rules.yaml
#   （由 vibe-project-init 生成，或手动创建）。脚本不硬编码任何项目特定前缀。
#   无配置文件 / 关闭校验 / 格式错误 时，前缀校验自动跳过（仅提示，不阻塞）。
# ============================================================

set -o pipefail

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

# ── 脚本自身位置（用于修复指引，避免硬编码路径）────────────
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)

# ── 路径初始化 ──────────────────────────────────────────
# 1.2.0：版本管理统一本地 git，不再有"快照模式"；非 git 仓库直接报错退出
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$REPO_ROOT" ]; then
  echo "❌ 错误：当前目录不是 Git 仓库（commit-check 仅支持 git 管理项目，1.2.0 起版本管理统一本地 git）" >&2
  echo "   → 请先运行 vibe-project-init 初始化（自动 git init），或确认在项目根目录下执行" >&2
  exit 2
fi
cd "$REPO_ROOT" || { echo "❌ 错误：无法进入仓库目录 $REPO_ROOT"; exit 2; }

# ── 统一运行日志（1.2.0）：结论落盘 .vibe-coding/logs/commit-check-<日期>-<时间>.log ──
# 界面报告结构保持不变，结论用 log_raw 仅写文件
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/log.sh"
log_init "commit-check"

# ── 前缀规则（由配置加载，不硬编码）─────────────────────
PREFIX_CHECK_ENABLED=false
PREFIX_LIST=""          # 形如 |PC|ANDROID|...| 便于 grep -F 判断

# ── 函数: 显示帮助 ──────────────────────────────────────
usage() {
  cat <<'HELPEOF'
用法: ./scripts/commit-check.sh [选项]

AI Commit 真实性 & 合规性验证。验证三项：
  1. commit 是否存在 + 工作区是否干净
  2. commit message 前缀是否合规
  3. commit 是否属于当前项目

选项:
  -h    显示本帮助
  -s    仅检查 git status（工作区干净 + commit 存在）
  -m    仅检查 commit message 前缀
  -o    仅检查 commit 归属（属于当前项目）
  -r    指定要校验的 commit（commit-ish，默认 HEAD）
  无选项  三项全检

前缀校验规则来源:
  优先读取 .vibe-coding/adapter.cfg 的 COMMIT_RULES，回落 .vibe-coding/commit-rules.yaml，再回落 .workbuddy/commit-rules.yaml（由 vibe-project-init 生成，也可手动创建）。
  该文件定义 prefix_check（开关）与 prefixes（允许的前缀列表）。
  无配置文件 / 已关闭校验 / 配置文件格式错误 时，前缀校验自动跳过（仅提示，不阻塞）。

输出格式:
  ✅ / ❌ / ⏭️ 检查项: 说明
HELPEOF
}

# ── 函数: 加载前缀规则（轻量解析，容错，不崩溃）──────────
load_prefix_rules() {
  PREFIX_CHECK_ENABLED=false
  PREFIX_LIST=""
  # 前缀规则三级回落（与 vibe-project-init 的 commit-msg.sh 同源逻辑）：
  #   1. .vibe-coding/adapter.cfg 存在 → 用白名单提取 COMMIT_RULES（绝不 source，防任意代码执行）
  #   2. 否则回落 .vibe-coding/commit-rules.yaml
  #   3. 否则回落 .workbuddy/commit-rules.yaml（兼容未迁移旧项目，如 rl-rush-buy）
  local cfg=""
  if [ -f ".vibe-coding/adapter.cfg" ]; then
    cfg="$(safe_cfg_get COMMIT_RULES ".vibe-coding/adapter.cfg")"
    [ -z "$cfg" ] && cfg=".vibe-coding/commit-rules.yaml"
  elif [ -f ".vibe-coding/commit-rules.yaml" ]; then
    cfg=".vibe-coding/commit-rules.yaml"
  elif [ -f ".workbuddy/commit-rules.yaml" ]; then
    cfg=".workbuddy/commit-rules.yaml"
  fi
  if [ -z "$cfg" ] || [ ! -f "$cfg" ]; then
    return 1   # 无配置文件
  fi
  local in_prefixes=false
  while IFS= read -r line; do
    local trimmed
    trimmed=$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    [ -z "$trimmed" ] && continue
    case "$trimmed" in
      \#*) continue ;;
    esac
    if printf '%s' "$trimmed" | grep -qE '^prefix_check[[:space:]]*:' ; then
      local val
      val=$(printf '%s' "$trimmed" | sed -E 's/^prefix_check[[:space:]]*:[[:space:]]*//')
      case "$val" in
        true|True|TRUE|yes|Yes|YES|1) PREFIX_CHECK_ENABLED=true ;;
        *) PREFIX_CHECK_ENABLED=false ;;
      esac
    elif printf '%s' "$trimmed" | grep -qE '^[A-Za-z_][A-Za-z0-9_]*[[:space:]]*:' ; then
      # 任意顶层键出现 → 离开 prefixes 块
      in_prefixes=false
      if printf '%s' "$trimmed" | grep -qE '^prefixes[[:space:]]*:' ; then
        in_prefixes=true
      fi
    elif [ "$in_prefixes" = true ]; then
      if printf '%s' "$trimmed" | grep -qE '^-' ; then
        local p
        p=$(printf '%s' "$trimmed" | sed -E 's/^[-[:space:]]+//; s/^"//; s/"$//')
        [ -n "$p" ] && PREFIX_LIST="${PREFIX_LIST}|${p}"
      fi
    fi
  done < "$cfg"
  return 0
}

# ── 诊断信息存储（全局变量）────────────────────────────
REAL_DIAG=""       # commit 真实性失败原因
PREFIX_ACTUAL=""   # 实际的前缀 / message
PREFIX_EXPECTED="" # 失败时的建议说明
PREFIX_SKIP=""     # 跳过原因（非空表示跳过，不计入失败）

# ── 检查 1: commit 真实性（静默）────────────────────────
check_commit_real() {
  REAL_DIAG=""
  local hash
  if [ "${COMMIT_REF:-HEAD}" = "HEAD" ]; then
    # 默认校验 HEAD：要求仓库有 commit 且工作区干净
    hash=$(git log -1 --format="%h" 2>/dev/null)
    if [ -z "$hash" ]; then
      REAL_DIAG="仓库无任何 commit"
      return 1
    fi
    local dirty
    dirty=$(git status --porcelain 2>/dev/null)
    if [ -n "$dirty" ]; then
      REAL_DIAG="工作区存在未提交的改动"
      return 1
    fi
  else
    # 指定 commit：只验证该 commit 是否真实存在（历史 commit 无“未提交改动”概念）
    if ! git rev-parse --quiet --verify "${COMMIT_REF}^{commit}" >/dev/null 2>&1; then
      REAL_DIAG="指定的 commit 不存在: ${COMMIT_REF}"
      return 1
    fi
  fi
  return 0
}

# ── 检查 2: commit 前缀（静默）──────────────────────────
# 前置: load_prefix_rules 已调用；若 PREFIX_SKIP 非空则不应调用本函数
check_commit_prefix() {
  PREFIX_ACTUAL=""
  PREFIX_EXPECTED=""
  local msg
  msg=$(git log -1 --format="%s" "${COMMIT_REF:-HEAD}" 2>/dev/null)
  if [ -z "$msg" ]; then
    PREFIX_ACTUAL="(无法获取 commit message)"
    return 1
  fi
  PREFIX_ACTUAL="$msg"
  # 取开头方括号标签
  local tag
  tag=$(printf '%s' "$msg" | grep -oE '^\[[A-Za-z0-9_]+\]' | head -1)
  if [ -z "$tag" ]; then
    PREFIX_EXPECTED="(请以 [前缀] 开头，例如 [FEAT])"
    return 1
  fi
  # 未启用校验 / 无前缀清单 → 放行
  if [ "$PREFIX_CHECK_ENABLED" != true ] || [ -z "$PREFIX_LIST" ]; then
    return 0
  fi
  local inner
  inner=$(printf '%s' "$tag" | sed -E 's/^\[//; s/\]$//')
  if printf '%s|' "$PREFIX_LIST|" | grep -qF "|$inner|"; then
    return 0
  fi
  PREFIX_EXPECTED="(合法前缀见 commit-rules.yaml：.vibe-coding/ 或 .workbuddy/)"
  return 1
}

# ── 检查 3: commit 归属（静默）──────────────────────────
check_commit_ownership() {
  local hash
  hash=$(git log -1 --format="%h" "${COMMIT_REF:-HEAD}" 2>/dev/null)
  if [ -z "$hash" ]; then
    return 1
  fi
  if git rev-parse --quiet --verify "$hash^{commit}" >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

# ── 主入口 ───────────────────────────────────────────────
main() {
  local check_all=true
  local do_real=false
  local do_prefix=false
  local do_ownership=false

  local COMMIT_REF="HEAD"
  while getopts "hsm:or:" opt 2>/dev/null; do
    case $opt in
      h) usage; exit 0 ;;
      s) check_all=false; do_real=true ;;
      m) check_all=false; do_prefix=true; COMMIT_REF="$OPTARG" ;;
      o) check_all=false; do_ownership=true ;;
      r) COMMIT_REF="$OPTARG" ;;
      *) echo "未知选项: -$opt" >&2; usage >&2; exit 1 ;;
    esac
  done

  if [ "$check_all" = true ]; then
    do_real=true; do_prefix=true; do_ownership=true
  fi

  local hash
  hash=$(git log -1 --format="%h" "${COMMIT_REF:-HEAD}" 2>/dev/null || echo "???")

  # ── 前缀规则加载与跳过判定 ──
  PREFIX_SKIP=""
  if [ "$do_prefix" = true ]; then
    load_prefix_rules
    local rc=$?
    if [ $rc -ne 0 ]; then
      PREFIX_SKIP="未找到 commit-rules.yaml（已检查 .vibe-coding/ 与 .workbuddy/）"
    elif [ "$PREFIX_CHECK_ENABLED" != true ]; then
      PREFIX_SKIP="配置文件已关闭前缀校验 (prefix_check: false)"
    elif [ -z "$PREFIX_LIST" ]; then
      PREFIX_SKIP="配置中未定义任何前缀 (prefixes 为空)"
    fi
  fi

  # ── 静默执行检查 ──
  local fail_real=0 fail_prefix=0 fail_ownership=0
  [ "$do_real" = true ]       && { check_commit_real;      fail_real=$?; }
  [ "$do_prefix" = true ]     && [ -z "$PREFIX_SKIP" ] && { check_commit_prefix;    fail_prefix=$?; }
  [ "$do_ownership" = true ]  && { check_commit_ownership; fail_ownership=$?; }

  local total_fail=0
  [ "$do_real" = true ]       && [ $fail_real -ne 0 ]       && total_fail=$((total_fail + 1))
  [ "$do_prefix" = true ]     && [ -z "$PREFIX_SKIP" ] && [ $fail_prefix -ne 0 ] && total_fail=$((total_fail + 1))
  [ "$do_ownership" = true ]  && [ $fail_ownership -ne 0 ]  && total_fail=$((total_fail + 1))

  local matched_prefix=""
  [ "$do_prefix" = true ] && matched_prefix=$(printf '%s' "$PREFIX_ACTUAL" | grep -oE '^\[[A-Za-z0-9_]+\]' 2>/dev/null | head -1)

  # ══════════════════ 统一输出 ══════════════════
  if [ $total_fail -eq 0 ]; then
    echo "[✅ 通过] commit-check"
    echo ""
    echo "结果："
    [ "$do_real" = true ]      && echo "✅ commit 真实性: 通过 ($hash)"
    if [ "$do_prefix" = true ]; then
      if [ -n "$PREFIX_SKIP" ]; then
        echo "⏭️  commit 前缀: 跳过 — $PREFIX_SKIP"
      else
        echo "✅ commit 前缀: 通过 ($matched_prefix)"
      fi
    fi
    [ "$do_ownership" = true ] && echo "✅ commit 归属: 通过 (属于当前项目)"
    echo ""
    log_raw "SUCCESS" "commit-check 通过：commit ${hash}，真实性/前缀/归属校验通过"
    exit 0
  fi

  # ══════════════════ 未通过 ══════════════════
  echo "[❌ 未通过] commit-check"
  echo "目标 commit: $hash"
  echo ""
  echo "结果："

  if [ "$do_real" = true ]; then
    if [ $fail_real -eq 0 ]; then
      echo "✅ commit 真实性: 通过"
    else
      echo "❌ commit 真实性: 未通过 — $REAL_DIAG"
    fi
  fi

  if [ "$do_prefix" = true ]; then
    if [ -n "$PREFIX_SKIP" ]; then
      echo "⏭️  commit 前缀: 跳过 — $PREFIX_SKIP"
    elif [ $fail_prefix -eq 0 ]; then
      echo "✅ commit 前缀: 通过 ($matched_prefix)"
    else
      echo "❌ commit 前缀: 未通过 — 当前: \"$PREFIX_ACTUAL\""
    fi
  fi

  if [ "$do_ownership" = true ]; then
    if [ $fail_ownership -eq 0 ]; then
      echo "✅ commit 归属: 通过"
    else
      echo "❌ commit 归属: 未通过 — Commit ID 不属于当前项目"
    fi
  fi

  echo ""
  echo "问题清单："
  local issue_num=1

  if [ "$do_real" = true ] && [ $fail_real -ne 0 ]; then
    echo "$issue_num. 工作区不干净：[$REAL_DIAG] → [请先 commit 或 stash 所有改动]"
    issue_num=$((issue_num + 1))
  fi

  if [ "$do_prefix" = true ] && [ -z "$PREFIX_SKIP" ] && [ $fail_prefix -ne 0 ]; then
    echo "$issue_num. 前缀不合规：[当前: \"$PREFIX_ACTUAL\"] → $PREFIX_EXPECTED"
    issue_num=$((issue_num + 1))
  fi

  if [ "$do_ownership" = true ] && [ $fail_ownership -ne 0 ]; then
    echo "$issue_num. 归属异常：Commit ID 不属于当前项目 → [请确认 commit 是否在当前仓库生成]"
    issue_num=$((issue_num + 1))
  fi

  echo ""
  echo "修复指引："
  echo "请将以上结果复制给对应的 AI 窗口，并说："
  echo "\"commit-check 没通过，请按以下要求修复："

  local guide_num=1
  if [ "$do_real" = true ] && [ $fail_real -ne 0 ]; then
    echo "$guide_num. 清理工作区：commit 或 stash 所有未提交的文件"
    guide_num=$((guide_num + 1))
  fi
  if [ "$do_prefix" = true ] && [ -z "$PREFIX_SKIP" ] && [ $fail_prefix -ne 0 ]; then
    echo "$guide_num. 修改 commit message 前缀为合法值（见 commit-rules.yaml：.vibe-coding/ 或 .workbuddy/）"
    guide_num=$((guide_num + 1))
  fi
  if [ "$do_ownership" = true ] && [ $fail_ownership -ne 0 ]; then
    echo "$guide_num. 确保在当前项目仓库中生成 commit"
    guide_num=$((guide_num + 1))
  fi

  echo "修复后再次运行 bash $SCRIPT_DIR/commit-check.sh 确认。\""
  echo ""
  log_raw "ERROR" "commit-check 未通过：${total_fail} 项检查失败（真实性/前缀/归属）"
  exit 1
}

main "$@"
