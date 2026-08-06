# commit-check — Commit 验证 Skill

带 Git 库的 AI 开发项目，AI 声称"已提交"后，用确定性脚本验证 commit 是否真实、合规、属于当前项目。

## 安装

将本技能目录放到 WorkBuddy 的技能目录下（用户级：`~/.workbuddy/skills/` 内的任意位置，例如放进 `vibe-coding-toolkit/skills/` 或单独放 `commit-check/`），WorkBuddy 自动加载。装一次，所有工作区都能用。

---

## 用法（用户只看这一段就够了）

你**不需要记任何命令，也不需要敲任何开关**。在 WorkBuddy 里用大白话下指令，技能自动干活、出结果。

### 最常用（覆盖绝大多数情况）

> 在任意一个项目的 WorkBuddy 工作区里，对 AI 说：
> **「进行 commit 检查」** / 「检查 commit」 / 「验证提交」

技能会对**你当前所在的那个仓库**自动跑完整的三项检查（真实性 + 前缀 + 归属），然后把结果直接告诉你。就这一句话，完事。

也可以通过 `/commit check` 斜杠命令触发，效果完全一样。

### 想更具体一点

你只管用自然语言描述想要什么，技能内部会把你的话转成对应的检查：

| 你直接说                         | 技能自动做什么               |
| ---------------------------- | --------------------- |
| "只查一下提交前缀"                   | 自动只检查 commit 前缀是否合规   |
| "这个 commit 属于当前项目吗" / "检查归属" | 自动只检查 commit 是否属于当前仓库 |
| "工作区干净吗"                     | 自动只检查有没有未提交的改动        |

### 进阶：手动运行

如需手动跑，请**站在你的项目仓库目录内**（根目录或任意子目录均可），用脚本的绝对安装路径执行：

```bash
# 全量（三项，等价于对 AI 说"检查 commit"）
bash <commit-check 技能目录>/scripts/commit-check.sh
# 例如（实际路径随安装位置而变）：
bash ~/.workbuddy/skills/vibe-coding-toolkit/skills/commit-check/scripts/commit-check.sh

# 单项（技能内部按需使用，普通用户不必关心）
bash <同上路径> -s   # 仅真实性（工作区干净 + commit 存在）
bash <同上路径> -m   # 仅前缀
bash <同上路径> -o   # 仅归属（属于当前项目）
bash <同上路径> -h   # 帮助
```

**无需传仓库路径**——脚本会用 `git rev-parse --show-toplevel` 找到你当前命令行所在仓库的根目录并自动 `cd` 进去检查（见 `scripts/commit-check.sh` 第 22–27 行）。所以只要你的终端当前目录在那个 git 仓库内，它查的就是那个仓库。手动跑时务必从你的项目仓库里执行命令，否则会误查到脚本自身所在的仓库。

---

## 检查项

| 检查         | 内容               | 通过条件                                                                          |
| ---------- | ---------------- | ----------------------------------------------------------------------------- |
| commit 真实性 | HEAD 存在 + 工作区干净  | `git log -1` 非空且 `git status --porcelain` 无输出                                 |
| commit 前缀  | message 以合法前缀开头  | 匹配 `[PC]`/`[ANDROID]`/`[CLOUD]`/`[MEMORY]`/`[DOCS]`/`[FIX]`/`[TOOL]`/`[DATA]` |
| commit 归属  | commit ID 属于当前仓库 | `git rev-parse --verify <hash>^{commit}` 在当前仓库内能解析（防止套用别的仓库的 hash）            |

> 本脚本**只验证 commit 的属性**，不负责代码内容审查、越界 / 跨目录检查。后者由 `task-manager` 与 Code Review 流程负责（见脚本头部注释）。

---

## 输出格式

**通过时：**

```text
[✅ 通过] commit-check

结果：
✅ commit 真实性: 通过 (abc123)
✅ commit 前缀: 通过 ([PC])
✅ commit 归属: 通过 (属于当前项目)
```

**未通过时：**

```text
[❌ 未通过] commit-check

HEAD: abc123

结果：
❌ commit 前缀: 未通过 — 当前: "feat: ..."

问题清单：
前缀不合规：[当前: "feat: ..."] → [请改为 [PC] 格式]
合规前缀: [PC] [ANDROID] [CLOUD] [MEMORY] [DOCS] [FIX] [TOOL] [DATA]

修复指引：
把这段结果复制给 AI，说：
"commit-check 没通过，请修一下：把 commit message 改成合规前缀，然后重新提交。修完再跑一次 commit-check 确认。"
```

---

## 常见问题

### Q: 我完全不懂 Git，能用吗？

能。你只需要会说"检查 commit"，然后把结果复制给 AI，让 AI 修。所有 Git 操作都由 AI 完成。

### Q: 脚本报错"当前目录不在 Git 仓库中"怎么办？

确保你运行命令时，终端的当前目录在某个 Git 仓库内（你的项目目录）。如果不在 Git 仓库里，脚本无法工作。

### Q: 前缀不合规时，脚本能建议该用哪个前缀吗？

能。脚本会根据 commit message 里的关键词（如 android/apk、docker/deploy、memory/记忆、doc/文档、tool/脚本、fix/修复）推测一个建议前缀，在"问题清单"里给出。最终以你项目的实际分工为准。

### Q: 这个脚本会帮我审查代码内容或检查有没有改错文件吗？

不会。commit-check 只验证 commit 的"属性"三件事：真实性、前缀、归属。代码内容审查、越界 / 跨目录检查由 `task-manager` 和 Code Review 流程负责，本脚本明确不做（见脚本头部注释）。

### Q: 结果出来了，然后呢？

如果全部通过（✅），继续下一步。如果有未通过的（❌），把结果复制给 AI，说"修一下"，AI 会自己处理。修完再跑一次确认。

### Q: 我可以在多个项目上用这个 skill 吗？需要把脚本复制到每个项目吗？

不需要复制任何文件。commit-check 是 WorkBuddy 的**用户级（全局）技能**——你只要把它装到 `~/.workbuddy/skills/` 下**一次**，它在你所有工作区都生效。

用法：在任意一个项目的 WorkBuddy 工作区里，对 AI 说"检查 commit" / "验证提交"（或用 `/commit check` 斜杠命令），WorkBuddy 会自动加载这个技能，并对**你当前所在的那个仓库**运行校验。

---

## 前置要求

- Git（`git` 命令可用）
- Bash（Git Bash / WSL / macOS Terminal）
- 当前工作目录在 git 仓库内（任意子目录均可）

---

## 依赖

- `git rev-parse --show-toplevel` — 自动检测并进入仓库根目录
- `git log -1` — 获取 HEAD commit
- `git status --porcelain` — 检查工作区
- `git rev-parse --verify <hash>^{commit}` — 校验 commit 归属当前仓库

---

## 目录结构

```text
commit-check/
├── README.md           # 本文档
├── SKILL.md            # WorkBuddy Skill 定义
├── skill.json          # 平台元数据
└── scripts/
    └── commit-check.sh # 确定性验证脚本
```

---

## 下一步

commit-check 是「AI 项目治理工具箱」中的一个工具，接下来你还可以：

- 用 `vibe-project-init` 一键生成项目治理骨架（角色分工 + 铁律 + 契约文件）
- 用 `task-manager` 自动追踪任务进度，告别人工传话
- 用 `health-check` 定期体检你的 AI 项目健康度，提前发现烂尾风险

---

## 许可

MIT
