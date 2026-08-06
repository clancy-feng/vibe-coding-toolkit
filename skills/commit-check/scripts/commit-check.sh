#!/usr/bin/env bash
# ============================================================
# commit-check.sh — AI Commit 真实性 & 合规性验证
#
# 用途: AI 声称"已提交"后，验证 commit 是否真实、合规、属于当前项目。
# 用法: commit-check.sh [-h|-s|-m|-o]（在任意 git 仓库根目录运行）
#   -h    显示帮助
#   -s    仅检查 git status（工作区是否干净 + commit 存在）
#   -m    仅检查 commit message 前缀
#   -o    仅检查 commit 归属（属于当前项目）
#   无选项 三项全检
#
# 依赖: git
# 对应铁律:
#   铁律 #12 — 完成追踪与验证分离
#   职责边界: 本脚本仅验证 commit 属性，不负责代码审查或越界检查。
# ============================================================

set -o pipefail

# ── 路径初始化 ──────────────────────────────────────────
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$REPO_ROOT" ]; then
  echo "❌ 错误：当前目录不在 Git 仓库中"
  exit 2
fi
cd "$REPO_ROOT" || { echo "❌ 错误：无法进入仓库目录 $REPO_ROOT"; exit 2; }

# ── 常量 ────────────────────────────────────────────────
# 合法 commit message 前缀
VALID_PREFIX_RE='^\[(PC|ANDROID|CLOUD|MEMORY|DOCS|FIX|TOOL|DATA)\]'

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
  无选项  三项全检

合法前缀: [PC] [ANDROID] [CLOUD] [MEMORY] [DOCS] [FIX] [TOOL] [DATA]

对应铁律:
  铁律 #12 — 完成追踪与验证分离
  职责边界: 本脚本仅验证 commit 属性，不负责代码审查或越界检查。

输出格式:
  ✅ / ❌ 检查项: 说明
HELPEOF
  exit 0
}

# ── 诊断信息存储（全局变量） ────────────────────────────
REAL_DIAG=""       # commit 真实性失败原因
PREFIX_ACTUAL=""   # 实际的前缀
PREFIX_EXPECTED="" # 建议的前缀（基于内容推测）

# ── 检查 1: commit 真实性（静默，结果存全局变量）───────────
check_commit_real() {
  REAL_DIAG=""
  local hash
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
  return 0
}

# ── 检查 2: commit 前缀（静默，结果存全局变量）─────────────
check_commit_prefix() {
  PREFIX_ACTUAL=""
  PREFIX_EXPECTED="[PC]" # 默认建议
  local msg
  msg=$(git log -1 --format="%s" 2>/dev/null)
  if [ -z "$msg" ]; then
    PREFIX_ACTUAL="(无法获取 commit message)"
    return 1
  fi
  PREFIX_ACTUAL="$msg"
  if echo "$msg" | grep -qE "$VALID_PREFIX_RE"; then
    return 0
  fi

  # 尝试根据内容推测合适的前缀
  if echo "$msg" | grep -qiE '(android|apk|kotlin|gradle|activity|webview)'; then
    PREFIX_EXPECTED="[ANDROID]"
  elif echo "$msg" | grep -qiE '(docker|deploy|cloud|ubuntu|ssh|tencent|nginx)'; then
    PREFIX_EXPECTED="[CLOUD]"
  elif echo "$msg" | grep -qiE '(memory|记忆|MEMORY)'; then
    PREFIX_EXPECTED="[MEMORY]"
  elif echo "$msg" | grep -qiE '(doc|文档|知识库|说明书|readme)'; then
    PREFIX_EXPECTED="[DOCS]"
  elif echo "$msg" | grep -qiE '(tool|脚本|script|commit-check|治理)'; then
    PREFIX_EXPECTED="[TOOL]"
  elif echo "$msg" | grep -qiE '(fix|修复|bug|紧急)'; then
    PREFIX_EXPECTED="[FIX]"
  fi
  return 1
}

# ── 检查 3: commit 归属（静默，结果存全局变量）─────────────
# 简化版：检查 commit 是否在当前仓库的 reflog 中，防止使用其他仓库的 hash
check_commit_ownership() {
  local hash
  hash=$(git log -1 --format="%h" 2>/dev/null)
  if [ -z "$hash" ]; then
    return 1 # 无commit，算归属失败
  fi
  # git rev-parse 会验证 hash 是否属于当前仓库
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

  while getopts "hsmo" opt 2>/dev/null; do
    case $opt in
      h) usage ;;
      s) check_all=false; do_real=true ;;
      m) check_all=false; do_prefix=true ;;
      o) check_all=false; do_ownership=true ;;
      *) usage ;;
    esac
  done

  if [ "$check_all" = true ]; then
    do_real=true; do_prefix=true; do_ownership=true
  fi

  local hash
  hash=$(git log -1 --format="%h" 2>/dev/null || echo "???")

  # ── 静默执行检查 ──
  local fail_real=0 fail_prefix=0 fail_ownership=0
  [ "$do_real" = true ]       && { check_commit_real;      fail_real=$?; }
  [ "$do_prefix" = true ]     && { check_commit_prefix;    fail_prefix=$?; }
  [ "$do_ownership" = true ]  && { check_commit_ownership; fail_ownership=$?; }

  # 计算 fail 数
  local total_fail=0
  [ "$do_real" = true ]       && [ $fail_real -ne 0 ]       && total_fail=$((total_fail + 1))
  [ "$do_prefix" = true ]     && [ $fail_prefix -ne 0 ]     && total_fail=$((total_fail + 1))
  [ "$do_ownership" = true ]  && [ $fail_ownership -ne 0 ]  && total_fail=$((total_fail + 1))

  local matched_prefix
  matched_prefix=$(echo "$PREFIX_ACTUAL" | grep -oE '^\[[A-Z]+\]' 2>/dev/null || echo "")

  # ══════════════════ 统一输出 ══════════════════
  if [ $total_fail -eq 0 ]; then
    echo "[✅ 通过] commit-check"
    echo ""
    echo "结果："
    [ "$do_real" = true ]       && echo "✅ commit 真实性: 通过 ($hash)"
    [ "$do_prefix" = true ]     && echo "✅ commit 前缀: 通过 ($matched_prefix)"
    [ "$do_ownership" = true ]  && echo "✅ commit 归属: 通过 (属于当前项目)"
    echo ""
    exit 0
  fi

  # ══════════════════ 未通过 ══════════════════
  echo "[❌ 未通过] commit-check"
  echo "HEAD: $hash"
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
    if [ $fail_prefix -eq 0 ]; then
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

  if [ "$do_prefix" = true ] && [ $fail_prefix -ne 0 ]; then
    echo "$issue_num. 前缀不合规：[当前: \"$PREFIX_ACTUAL\"] → [请改为 $PREFIX_EXPECTED 格式]"
    echo "   合规前缀: [PC] [ANDROID] [CLOUD] [MEMORY] [DOCS] [FIX] [TOOL] [DATA]"
    issue_num=$((issue_num + 1))
  fi

  if [ "$do_ownership" = true ] && [ $fail_ownership -ne 0 ]; then
    echo "$issue_num. 归属异常：Commit ID 不属于当前项目 → [请确认 commit 是否在当前仓库生成]"
    issue_num=$((issue_num + 1))
  fi

  # ── 修复指引 ──
  echo ""
  echo "修复指引："
  echo "请将以上结果复制给对应的 AI 窗口，并说："
  echo "\"commit-check 没通过，请按以下要求修复："

  local guide_num=1
  if [ "$do_real" = true ] && [ $fail_real -ne 0 ]; then
    echo "$guide_num. 清理工作区：commit 或 stash 所有未提交的文件"
    guide_num=$((guide_num + 1))
  fi
  if [ "$do_prefix" = true ] && [ $fail_prefix -ne 0 ]; then
    echo "$guide_num. 修改 commit message 前缀为合规格式: $PREFIX_EXPECTED"
    guide_num=$((guide_num + 1))
  fi
  if [ "$do_ownership" = true ] && [ $fail_ownership -ne 0 ]; then
    echo "$guide_num. 确保在当前项目仓库中生成 commit"
    guide_num=$((guide_num + 1))
  fi

  echo "修复后再次运行 bash ~/.workbuddy/skills/commit-check/scripts/commit-check.sh 确认。\""
  echo ""
  exit 1
}

main "$@"