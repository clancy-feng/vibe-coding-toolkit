#!/bin/sh
# commit-msg 钩子 — 源头痛点拦截非法提交前缀
# 由 vibe-project-init 安装。所有路径从 .vibe-coding/adapter.cfg 读取，禁止硬编码。
# POSIX 兼容：仅用 sh / sed / awk / grep，禁用 sed -i '' 等平台特定语法。
# 安全：绝不 source adapter.cfg（防任意代码执行）；仅白名单提取 COMMIT_RULES 相对路径。

MSG_FILE="$1"
[ -z "$MSG_FILE" ] && exit 0

# 定位治理根目录与适配层配置
GOV=".vibe-coding"
CFG="$GOV/adapter.cfg"
COMMIT_RULES="$GOV/commit-rules.yaml"

# 安全读取：仅白名单提取 COMMIT_RULES 键，拒绝绝对路径/含元字符取值（回落默认 .vibe-coding/commit-rules.yaml）
if [ -f "$CFG" ]; then
    cfg_val="$(grep -E '^[[:space:]]*COMMIT_RULES[[:space:]]*=' "$CFG" 2>/dev/null | head -n1 | sed -E 's/^[^=]*=[[:space:]]*//' | tr -d '[:space:]')"
    cfg_val="${cfg_val%\"}"; cfg_val="${cfg_val#\"}"
    cfg_val="${cfg_val%\'}"; cfg_val="${cfg_val#\'}"
    case "$cfg_val" in
        /*) ;;                                  # 绝对路径，拒绝
        *[!.a-zA-Z0-9/_-]*) ;;                  # 含非法字符，拒绝
        "") ;;
        *) COMMIT_RULES="$cfg_val" ;;
    esac
fi

# 前缀规则三级回落（与 commit-check 同源）：
#   .vibe-coding/adapter.cfg 的 COMMIT_RULES → .vibe-coding/commit-rules.yaml → .workbuddy/commit-rules.yaml
# 三者皆无则放行（不阻塞提交）
if [ ! -f "$COMMIT_RULES" ] && [ -f ".workbuddy/commit-rules.yaml" ]; then
    COMMIT_RULES=".workbuddy/commit-rules.yaml"
fi
[ -f "$COMMIT_RULES" ] || exit 0

# 解析 prefix_check 开关
enabled=$(grep -E '^[[:space:]]*prefix_check[[:space:]]*:' "$COMMIT_RULES" 2>/dev/null | head -n1 | sed 's/.*:[[:space:]]*//' | tr '[:upper:]' '[:lower:]')
case "$enabled" in
    true|yes|1|on) ;;
    *) exit 0 ;;
esac

# 解析 prefixes 列表（剥行内注释与前后空白，遇下一个顶层键停止）
prefixes=$(awk '
    BEGIN { f = 0 }
    /^prefixes:/ { f = 1; next }
    f && /^[[:space:]]*- / {
        line = $0
        sub(/^[[:space:]]*- /, "", line)
        sub(/[[:space:]]*#.*/, "", line)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
        if (line != "") print line
        next
    }
    f && /^[[:space:]]*[A-Za-z_]/ && !/^[[:space:]]*- / { f = 0 }
' "$COMMIT_RULES")

# 提取提交信息首行的 [XXX] 前缀
first=$(head -n1 "$MSG_FILE" 2>/dev/null)
inner=$(printf '%s' "$first" | sed -n 's/^\[\([^]]*\)\].*/\1/p')

# 无前缀直接放行（不强制所有提交都带前缀，由 commit-check 另行约束真实性）
[ -z "$inner" ] && exit 0

# 命中允许列表则放行，否则拦截
if printf '%s\n' "$prefixes" | grep -qx "$inner"; then
    exit 0
fi

echo "❌ 提交前缀 [$inner] 不在允许列表，合法前缀见 $COMMIT_RULES" >&2
echo "   如需跳过，请获得人类明确授权后再 amend 或调整提交信息，禁止自动 amend。" >&2
exit 1
