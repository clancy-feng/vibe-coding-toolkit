---
title: "commit-check"
name: "commit-check"
description: "AI Commit 真实性 & 合规性验证。AI 声称已提交后，用确定性脚本验证 commit 是否真实、前缀是否合规、是否属于当前项目。"
agent_created: true
version: "1.0.0"
---

# AI Commit 验证 Skill

> 脚本: `scripts/commit-check.sh`（与本 SKILL.md 同目录）
> 在任意 git 仓库内运行，脚本自动检测并 `cd` 到仓库根目录（见 `scripts/commit-check.sh` 第 22–27 行）。

## 用途

AI 开发窗口声称"已提交"后，用确定性脚本验证三件事：
1. **真实性**：commit 是否真实存在于本地仓库（且工作区干净）。
2. **合规性**：commit message 前缀是否符合全局铁律。
3. **归属**：commit 是否属于当前项目（防止套用别的仓库的 hash）。

**注意**：本 Skill 仅验证 commit 本身的属性，不涉及代码内容审查、越界检查或业务逻辑校验。代码审查与越界防护由 `task-manager` Skill 负责。

## 命令

> 推荐用法：在 WorkBuddy 中对 AI 说"检查 commit" / "验证提交"（或 `/commit check`），由 WorkBuddy 自动加载并执行，无需手动敲命令。
> 手动运行请用脚本的绝对路径，并**确保你的终端当前目录在目标项目仓库内**——脚本靠 `git rev-parse --show-toplevel` 定位仓库，若站在别的目录会查错仓库。

### 全量检查

```bash
bash ~/.workbuddy/skills/vibe-coding-toolkit/skills/commit-check/scripts/commit-check.sh
```

检查全部三项（真实性 + 前缀 + 归属），输出总结。

### 单项检查

```bash
# 仅检查工作区干净 + commit 存在（真实性）
bash ~/.workbuddy/skills/vibe-coding-toolkit/skills/commit-check/scripts/commit-check.sh -s

# 仅检查 commit message 前缀（合规性）
bash ~/.workbuddy/skills/vibe-coding-toolkit/skills/commit-check/scripts/commit-check.sh -m

# 仅检查 commit 是否属于当前项目（归属）
bash ~/.workbuddy/skills/vibe-coding-toolkit/skills/commit-check/scripts/commit-check.sh -o
```

（以上路径随本技能的实际安装位置而变；也可直接用 `scripts/commit-check.sh` 的相对路径，前提是 WorkBuddy 从本技能目录启动它。）

---

## 触发场景

| 用户说 | 系统执行 |
|--------|---------|
| "检查 commit" / "验证提交" | 全量检查 `bash <技能目录>/scripts/commit-check.sh` |
| "检查提交前缀" | `.../commit-check.sh -m` |
| "是否属于当前项目" / "检查归属" | `.../commit-check.sh -o` |
| "工作区是否干净" | `.../commit-check.sh -s` |

---

## 输出格式

全部通过时：

```text
[✅ 通过] commit-check

结果：
✅ commit 真实性: 通过 (xxxxxxx)
✅ commit 前缀:   通过 ([PC])
✅ commit 归属:   通过 (属于当前项目)
```

不通过时：

```text
[❌ 未通过] commit-check

HEAD: xxxxxxx

结果：
✅ commit 真实性: 通过
❌ commit 前缀:   未通过 — 当前: "chore: ..."
✅ commit 归属:   通过

问题清单：
前缀不合规：[当前: "chore: ..."] → [请改为 [PC] 格式]

修复指引：
请将以上结果复制给对应的 AI 窗口，并说：
"commit-check 没通过，请按以下要求修复：
修改 commit message 前缀为合规格式
修复后再次运行 commit-check 确认。"
```

---

## 合法前缀

| 前缀 | 适用角色 | 示例 |
|------|---------|------|
| `[PC]` | Node.js 开发 | `[PC] 修复 login 超时` |
| `[ANDROID]` | 安卓开发 | `[ANDROID] 多站点支持` |
| `[CLOUD]` | 云端运维 | `[CLOUD] 更新依赖` |
| `[MEMORY]` | coordinator | `[MEMORY] 更新项目记忆` |
| `[DOCS]` | coordinator | `[DOCS] 更新知识库` |
| `[FIX]` | 任一端 | `[FIX] 紧急修复 xxx` |
| `[TOOL]` | 工程治理 | `[TOOL] 新增工具脚本` |
| `[DATA]` | 数据相关 | `[DATA] 更新数据集` |

---

## 铁律对齐

1. **每次 commit 后必须自查**：各窗口提交前运行此脚本（由 `task-manager` 在标记任务完成时自动触发）。
2. **不猜测结果**：脚本输出什么就是什么，真实状态优先于 AI 声称。
3. **脏工作区不等于 commit 不存在**：可能只是有未提交的文档改动，需区分对待。
4. **历史 commit 前缀不合规不阻塞**：新标准建立前的 commit 用旧格式是正常的。
5. **职责分离**：本 Skill 不负责代码审查、越界检查或业务逻辑验证，此类检查由 `task-manager` 及 Code Review 流程负责。

---
