# Vibe Coding Toolkit - Readme

> English version at the bottom 

## 一、技能简介

全网首发：Vibe Coding Toolkit 是 VPG AI 开发项目治理体系的第一个落地产物，VPG 全称 Vibe Project Governance。

VPG 源自作者对 AI 开发一些关键问题的持续思考——当 AI 开始替我们写代码、做项目，如何保证 AI 不跑偏、不瞎编、不把项目搞乱？人怎么来管理自己的 AI 开发项目？围绕这个问题，作者沉淀出一套 AI 项目治理方法论。Vibe Coding Toolkit 就是把这套方法论变成能真正装进 AI 开发平台、每天用得上的工具。

当你用主流 AI 开发平台帮你写代码、做项目时，经常会遇到几类问题，这些平台包括 WorkBuddy、Codex、Cursor、Claude Code 等：

- **AI撒谎**：AI 说"我做完了、已经提交了"，但你一查，根本没提交。
- **责任不清**：单对话操作，项目越来越大，谁改了哪块、为什么改，说不清楚。
- **无从下手**：想从零开始规范一个项目，但不知道治理骨架该怎么搭。
- **隐患看不见**：项目跑了一阵子，悄悄积累了一些隐患，等到出事才发现。

Vibe Coding Toolkit 就是一套针对这些问题的"项目工程治理体系"，本技能的所有设计，都围绕上面两个概念展开：它用四个模块为你搭起一套工程管理体系，而这套控制的运行方式，正是治理框架所主张的"人审 AI 制"——人掌控方向和规则，AI 负责执行；AI 不能偷偷做主，重要的事必须由人确认。

## 二、四个模块

这个技能内含四个功能模块，四个模块共同构成前述的治理体系。

| 子命令            | 功能   | 一句话定位          | 主要干什么                                |
| -------------- | ---- | -------------- | ------------------------------------ |
| `health-check` | 项目体检 | 查违规的"巡检员"      | 定期给项目做体检，只报告问题、不改东西，发现隐患第一时间告诉你      |
| `commit-check` | 交付质检 | 卡交付的"质检员"      | AI 每次提交代码后，自动核查：提交是真的吗？信息写对了吗？       |
| `task-manager` | 任务调度 | 管 AI 干活的"任务中心" | 只供 AI 内部使用，所有 AI 任务都经它派发和记录，以磁盘文件为准。 |
| `project-init` | 框架生成 | 定规矩的"奠基者"      | 给项目搭好治理骨架，涵盖模块划分、角色护栏、提交规则，骨架丢了还能重建  |

## 三、工作方式

1. **`project-init` 搭骨架**：新项目第一次用，或老项目没治理，用它建立治理框架基础。
2. **你让 AI 干活**：在对话框描述需求，`task-manager` 自动记任务、给编号、完成后自动验证，人可监督全过程。
3. **AI 干完要提交**：`commit-check` 自动验证"提交是否真实、信息是否合规"。
4. **你定期说"给项目做个体检"**：`health-check` 扫描隐患，分级报给你。

四个模块形成闭环：项目由 `project-init` 建立 → 任务经 `task-manager` 派发 → 提交经 `commit-check` 把关 → 违规经 `health-check` 查出。所有操作都写成文件留痕，随时可查——这正是治理框架设计的完整运行闭环，也是基于文件内容的内部控制"每一步留痕"要求的落地。

## 四、文档索引

- **本文档 README.md** = 总览、安装、安全说明。
- **`docs/USER_GUIDE.md`** = 使用手册：从工作区创建到多角色协作的完整操作流程（新用户从这里开始）。
- **`docs/health-check.md`** = 健康巡检模块详解：它查什么、怎么触发、报告怎么看。
- **`docs/commit-check.md`** = 提交验证模块详解：它验证什么、怎么配置前缀规则。
- **`docs/task-manager.md`** = 任务流转模块详解：任务怎么被派发和记录，即内部引擎说明。
- **`docs/project-init.md`** = 项目初始化模块详解：怎么搭治理骨架、适配已有项目。

## 五、安装

本技能面向主流 AI 开发平台设计，特别专门适配 WorkBuddy，也支持 Codex、Cursor、Claude Code 等，通过各平台通用的 `skills/` 目录机制加载。

**推荐方式 A：市场一键安装**
在 ClawHub / SkillHub 搜索 `vibe-coding-toolkit`，一键安装。

**方式 B：源码安装**

```bash
git clone https://gitee.com/beclancy/vibe-coding-toolkit.git
# 安装到所用 AI 开发平台的 skills 目录，下面以 WorkBuddy 为例：
cp -r vibe-coding-toolkit ~/.workbuddy/skills/
```

主流 AI 开发平台会在启动时自动加载各自 `skills/` 目录下的技能；以 WorkBuddy 为例，加载路径为 `~/.workbuddy/skills/vibe-coding-toolkit/`。

**WorkBuddy 用户使用前提示**：新建项目前，先在 WorkBuddy 里建好工作区——新建对话时点击输入框左下角「选择工作空间」，创建或选择一个项目文件夹，再在这个工作区下的对话中发起"新建项目"。这样治理骨架会直接落在工作区目录里，后续多角色窗口都能共用；如果不先建工作区，项目会落在 WorkBuddy 自动生成的时间戳目录中，例如 `2026-08-12-22-03-30`，之后只能新建对话手动找到这个目录建工作区，管理起来很麻烦。

## 六、安全说明

- 不联网、不外传你的任何数据，仅读取平台注入的工作区变量与家目录用于平台探测。所有脚本行为只由项目内 `adapter.cfg` 的白名单键和命令行参数决定。
- 文件只写在你的项目内部：治理骨架在 `.vibe-coding/`，体检记录在 `.vibe-coding/memory/HEALTH_AUDIT.md` 与 `.health_state`，版本记录在项目本地 `.git/`，由 task-manager 自动提交，可选钩子在 `.git/hooks/commit-msg`，治理指针追加到 `.workbuddy/memory/MEMORY.md`。
  - **运行日志**：各脚本运行过程，包括启动、动作、成功或失败含错误信息，都会双写界面并落盘 `.vibe-coding/logs/<模块>-<日期>-<时间>.log`，日志不读取项目外任何文件。
  - 健康巡检：写入审计文件前会打印"即将写入"提示。
  - 项目初始化：写治理骨架文件，并在 `.git/hooks/commit-msg` 安装可选前缀校验钩子，仅在 `git commit` 时拦截非法前缀，可在 `adapter.cfg` 关闭。向 `.workbuddy/memory/MEMORY.md` 追加治理指针，引导 AI 找到治理根目录。这些写入由 AI 在对话确认后执行，写完后以 ✅ 日志告知结果。
  - **自带本地 Git 版本管理**：所有项目使用本地 git 库，不需要 GitHub/Gitee 账号；task-manager 在任务完成时自动 `git add + commit`（消息 `[模块] 任务ID: 标题`），首次提交缺身份时自动配置项目本地身份；`commit-check` 校验本地 commit 真实性与前缀合规。
- 以上写入都发生在被体检或被初始化的项目目录内；版本核对仅基于本工具自身安装目录的 `skill.json`。
- 路径同源：所有脚本从自身安装位置推导兄弟文件路径。
- 多平台适配：本工具包已为跨平台 WorkBuddy / Claude Code / Codex / Qoder 等预留适配层 `adapter.cfg`，当前版本优先适配 WorkBuddy；后续通过配置切换即可支持其他平台，无需修改项目治理文件。治理根目录统一为项目内的 `.vibe-coding/`，与具体 AI 平台无关，可随项目在任意支持 `skills/` 机制的平台间迁移。

## 七、目录结构

```
vibe-coding-toolkit/
├── README.md          # Skill文档
├── SKILL.md           # Skill总控
├── skill.json         # Skill信息
├── docs/              # 用户向模块详解（含 USER_GUIDE 使用手册）
├── modules/           # 技术实现参考，给 AI 与开发者
├── scripts/           # 四个子命令脚本 + lib/ 统一运行日志库
└── templates/         # 共享模板（RULES 铁律模板等）
```

## 八、许可

MIT

## 九、了解更多 / 关注作者

本工具源自 VPG AI 治理体系，VPG 全称 Vibe Project Governance。相关文章会陆续发布在以下平台，欢迎关注交流：

- 小红书：[AI监工老冯](https://www.xiaohongshu.com/user/profile/66db02af000000001d022ff9)
- 知乎：[clancy-feng](https://www.zhihu.com/people/clancy-feng)
- GitHub：[vibe-coding-toolkit](https://github.com/clancy-feng/vibe-coding-toolkit)

---

# English Version

## 1. About

Vibe Coding Toolkit is the first productized piece of the VPG AI project governance framework. VPG stands for Vibe Project Governance.

VPG grew out of the author's ongoing thinking about key problems in AI-assisted development: when AI starts writing code and running projects for us, how do we keep it from going off track, making things up, or turning the project into a mess? How does a person actually manage their AI development project? Around this question, the author developed a methodology for AI project governance. Vibe Coding Toolkit turns that methodology into a tool that can actually be installed into AI development platforms and used every day.

When you use mainstream AI development platforms — WorkBuddy, Codex, Cursor, Claude Code, and similar — to write code and run projects, you run into several recurring problems:

- **AI lying**: AI says "I'm done, I've committed," but when you check, nothing was committed at all.
- **Unclear accountability**: Working in a single conversation as the project grows, it becomes impossible to tell who changed what and why.
- **No way to start**: You want to bring structure to a project from scratch, but you don't know how to set up a governance skeleton.
- **Invisible problems**: The project runs for a while, quietly accumulating issues, and you only find out when something breaks.

Vibe Coding Toolkit is a project engineering governance system built to address these problems. Every design decision in this skill revolves around two concepts: four modules form an engineering management system, and that system runs on the governance framework's "human review, AI execute" model — humans own the direction and rules, AI does the execution; AI cannot quietly make its own decisions, and important matters must be confirmed by a human.

## 2. The Four Modules

The skill contains four functional modules that together form the governance system.

| Subcommand     | Function           | One-line Role          | What It Does                                                                                                          |
| -------------- | ------------------ | ---------------------- | --------------------------------------------------------------------------------------------------------------------- |
| `health-check` | Project checkup    | The "inspector"        | Periodically checks the project, only reports problems, never changes anything, and flags risks immediately           |
| `commit-check` | Delivery QA        | The "QA gate"          | After every AI commit, verifies: is the commit real? Is the message compliant?                                        |
| `task-manager` | Task orchestration | The "task hub" for AI  | For AI internal use only; every AI task is dispatched and recorded through it, with disk files as the source of truth |
| `project-init` | Framework setup    | The "foundation layer" | Sets up the governance skeleton: module breakdown, role guardrails, commit rules; the skeleton can be rebuilt if lost |

## 3. How It Works

1. **`project-init` builds the skeleton**: use it on a new project, or on an existing project without governance, to establish the governance foundation.
2. **You tell AI to work**: describe the requirement in the conversation. `task-manager` records the task, assigns an ID, and automatically verifies completion; you can oversee the whole process.
3. **AI commits when done**: `commit-check` automatically verifies whether the commit is real and whether the message is compliant.
4. **You say "run a checkup" periodically**: `health-check` scans for risks and reports them to you by severity.

The four modules form a closed loop: `project-init` sets up the project → `task-manager` dispatches tasks → `commit-check` gates commits → `health-check` finds violations. Every operation is written to files for the record, always auditable — this is the complete operating loop the governance framework is designed for, and the implementation of the framework's internal-control requirement that "every step leaves a trace."

## 4. Documentation Index

- **This file README.md** = overview, installation, and security.
- **`docs/USER_GUIDE.md`** = user manual: the full workflow from workspace creation to multi-role collaboration (start here if you are new).
- **`docs/health-check.md`** = health-check module details: what it checks, how to trigger it, how to read the report.
- **`docs/commit-check.md`** = commit-check module details: what it verifies, how to configure prefix rules.
- **`docs/task-manager.md`** = task-manager module details: how tasks are dispatched and recorded — the internal engine.
- **`docs/project-init.md`** = project-init module details: how to build the governance skeleton and onboard existing projects.

## 5. Installation

The skill is designed for mainstream AI development platforms. It is specifically adapted for WorkBuddy and also supports Codex, Cursor, Claude Code, and others, loaded through each platform's standard `skills/` directory mechanism.

**Recommended — Method A: one-click install from a marketplace**
Search `vibe-coding-toolkit` on ClawHub / SkillHub and install with one click.

**Method B: install from source**

```bash
git clone https://gitee.com/beclancy/vibe-coding-toolkit.git
# Copy into the skills directory of your AI development platform; WorkBuddy shown here:
cp -r vibe-coding-toolkit ~/.workbuddy/skills/
```

Mainstream AI development platforms auto-load skills from their `skills/` directory at startup. For WorkBuddy, the load path is `~/.workbuddy/skills/vibe-coding-toolkit/`.

**Before you start with WorkBuddy**: create a workspace before creating a project — when starting a new conversation, click "选择工作空间" (Select Workspace) at the bottom-left of the input box, create or pick a project folder, then start "新建项目" (Create Project) in a conversation inside that workspace. This way the governance skeleton lands directly in the workspace directory and all role windows can share it. If you skip the workspace, the project lands in an auto-generated timestamp directory such as `2026-08-12-22-03-30`, and you will have to manually find that directory in new conversations to set up the workspace, which is much harder to manage.

## 6. Security

- No network access, no data sent anywhere. It only reads platform-injected workspace variables and the home directory for platform detection. All script behavior is determined solely by the whitelisted keys in the project's `adapter.cfg` and command-line arguments.
- Files are only written inside your project: the governance skeleton in `.vibe-coding/`, checkup records in `.vibe-coding/memory/HEALTH_AUDIT.md` and `.health_state`, version history in the project-local `.git/` (auto-committed by task-manager), the optional hook in `.git/hooks/commit-msg`, and a governance pointer appended to `.workbuddy/memory/MEMORY.md`.
  - **Run logs**: every script run — startup, actions, success, or failure with error messages — is written both to the console and to `.vibe-coding/logs/<module>-<date>-<time>.log`; logs never read files outside the project.
  - Health checkup: prints a "about to write" notice before writing the audit file.
  - Project init: writes governance skeleton files and installs an optional prefix-checking hook in `.git/hooks/commit-msg`, which only blocks illegal prefixes at `git commit` time and can be disabled in `adapter.cfg`. It also appends a governance pointer to `.workbuddy/memory/MEMORY.md` to guide AI to the governance root. These writes are executed only after AI confirms in the conversation, and the result is reported with a ✅ log.
  - **Built-in local Git versioning**: every project uses a local git repository and needs no GitHub/Gitee account; task-manager automatically runs `git add + commit` when a task completes (message `[module] taskID: title`), auto-configuring a project-local identity on the first commit when none exists; `commit-check` verifies local commits are real and prefix-compliant.
- All writes happen inside the project directory being checked or initialized; version verification is based only on the `skill.json` in this tool's own installation directory.
- Path consistency: all scripts derive sibling file paths from their own installation location.
- Multi-platform adaptation: the package reserves an adapter layer `adapter.cfg` for cross-platform use (WorkBuddy / Claude Code / Codex / Qoder, etc.), currently optimized for WorkBuddy; other platforms can be supported later via configuration switches without modifying project governance files. The governance root is uniformly the project-local `.vibe-coding/`, independent of the specific AI platform, and can move with the project across any platform that supports the `skills/` mechanism.

## 7. Directory Structure

```
vibe-coding-toolkit/
├── README.md          # Skill documentation
├── SKILL.md           # Skill master control
├── skill.json         # Skill metadata
├── docs/              # User-facing module guides (including USER_GUIDE manual)
├── modules/           # Technical reference for AI and developers
├── scripts/           # Four subcommand scripts + lib/ unified logging library
└── templates/         # Shared templates (RULES template, etc.)
```

## 8. License

MIT

## 9. Learn More / Follow the Author

This tool originates from the VPG AI governance framework (VPG = Vibe Project Governance). Related articles will be published on the following platforms; welcome to follow:

- Xiaohongshu: [AI监工老冯](https://www.xiaohongshu.com/user/profile/66db02af000000001d022ff9)
- Zhihu: [clancy-feng](https://www.zhihu.com/people/clancy-feng)
- GitHub: [vibe-coding-toolkit](https://github.com/clancy-feng/vibe-coding-toolkit)
