# commit-check — AI Commit 验证 Skill

AI 声称"已提交"后，用确定性脚本验证 commit 是否真实、合规。是「Vibe coder toolkit」的第一个工具。

---

## 安装

将本目录放到 `~/.workbuddy/skills/commit-check/`，WorkBuddy 自动加载。

---

## 用法

### 触发词

| 你说                   | 系统执行                                             |
| -------------------- | ------------------------------------------------ |
| "检查 commit" / "验证提交" | 全量检查：真实性 + 前缀格式 + 越界，三项全查                        |
| "检查提交前缀"             | 只查 commit message 是否以 `[PC]`、`[ANDROID]` 等合法前缀开头 |
| "检查是否越界"             | 只查本次 commit 是否跨目录修改或触碰受保护文件                      |
| "工作区是否干净"            | 只查 git status 是否有未提交的改动                          |

也可通过 `/commit check` 斜杠命令触发。

### 命令行

bash

全量
bash scripts/commit-check.sh

单项
bash scripts/commit-check.sh -s   # 仅真实性

bash scripts/commit-check.sh -m   # 仅前缀

bash scripts/commit-check.sh -b   # 仅越界

bash scripts/commit-check.sh -h   # 帮助

纯文本
**无需传仓库路径**——脚本用 `git rev-parse --show-toplevel` 自动检测当前 git 仓库根目录。在仓库内任意子目录运行均可。

---

## 检查项

| 检查         | 内容              | 通过条件                                                                 |
| ---------- | --------------- | -------------------------------------------------------------------- |
| commit 真实性 | HEAD 存在 + 工作区干净 | `git log -1` 非空且 `git status --porcelain` 无输出                        |
| commit 前缀  | message 以合法前缀开头 | 匹配 `[PC]`/`[ANDROID]`/`[CLOUD]`/`[MEMORY]`/`[DOCS]`/`[FIX]`/`[TOOL]` |
| 越界检查       | 未跨域/触碰受保护文件     | 不同时改 pc/ 和 android/，不修改 coordinator 专用文件                             |

---

## 输出格式

**通过时：**
[✅ 通过] commit-check

结果：

✅ commit 真实性: 通过 (abc123)

✅ commit 前缀: 通过 ([PC])

✅ 越界检查: 通过

纯文本
**未通过时：**
[❌ 未通过] commit-check

HEAD: abc123

结果：

❌ commit 前缀: 未通过 — 当前: "feat: ..."

问题清单：

前缀不合规：[当前: "feat: ..."] → [请改为 [PC] 格式]

修复指引：

把这段结果复制给 AI，说：

"commit-check 没通过，请修一下：把 commit message 改成合规前缀，然后重新提交。修完再跑一次 commit-check 确认。"

纯文本
---

## 常见问题

### Q: 我完全不懂 Git，能用吗？

能。你只需要会说“检查 commit”，然后把结果复制给 AI，让 AI 修。所有 Git 操作都由 AI 完成。

### Q: 脚本报错“当前目录不在 Git 仓库中”怎么办？

确保你在项目的根目录或子目录下运行。如果不在 Git 仓库里，脚本无法工作。

### Q: 越界检查的规则能自定义吗？

可以。修改脚本中的 `check_boundary()` 函数，添加或移除受保护的文件/目录模式。

### Q: 结果出来了，然后呢？

如果全部通过（✅），继续下一步。如果有未通过的（❌），把结果复制给 AI，说“修一下”，AI 会自己处理。修完再跑一次确认。

### Q: 我可以在多个项目上用这个脚本吗？

可以。把 `commit-check.sh` 放到每个项目的 `scripts/` 目录下就行。它只检查当前所在仓库。

---

## 前置要求

- Git（`git` 命令可用）
- Bash（Git Bash / WSL / macOS Terminal）
- 当前工作目录在 git 仓库内（任意子目录均可）

---

## 依赖

- `git rev-parse --show-toplevel` — 自动检测仓库根目录
- `git log -1` — 获取 HEAD commit
- `git status --porcelain` — 检查工作区
- `git diff-tree` — 获取 commit 文件变更

---

## 目录结构

commit-check/

├── README.md

├── skill.md                  ← WorkBuddy Skill 定义

└── scripts/

└── commit-check.sh       ← 确定性验证脚本

纯文本
---

## 下一步

commit-check 是「AI 项目治理工具箱」的第一个工具。接下来你还可以：

- 用 `init-project` 一键生成项目治理骨架（角色分工 + 铁律 + 契约文件）
- 用 `health-check` 定期体检你的 AI 项目健康度
- 用模块化系统记忆模板，把你的项目记忆从一团乱麻变成结构化档案

👉 完整工具箱：[ai-project-governance](https://github.com/your-repo-link)

---

## 许可

MIT
