# Vibe Coding Toolkit 使用手册

> English version at the bottom / 英文版见文件底部。
> 本文是面向使用者的操作手册，讲"怎么用这个工具管理你的 AI 开发项目"。技能本身的介绍见 [README.md](../README.md)。
> 本文假定读者没有编程基础；出现的专业词第一次出现时都会解释。

---

## 一、第一步：创建工作区

工作区是 WorkBuddy 里一个独立的项目文件夹，你的项目代码、治理文件都会放在里面。后续所有 AI 角色窗口都要指向同一个工作区，才能在一个项目上协作。

**操作**：

1. Workbuddy中新建一个对话；
2. 在输入框左下角点击「选择工作空间」；
3. 创建或选择一个文件夹，建议直接用项目名命名，例如 `计算器`；
4. 在这个对话里开始创建项目。

**为什么必须先建工作区**：如果不选，WorkBuddy 会自动生成一个按时间命名的目录，例如 `2026-08-12-22-03-30`。这个目录也能用，但之后无法在界面里改名或归入正式工作区，多角色窗口也不方便统一管理。所以第一步就要把工作区建好。

## 二、创建项目（初始化治理骨架）

在工作区的对话里说"新建项目"，也可以说"初始化项目""新建AI开发项目"等，AI 会按固定模板一轮一轮问你——不会一次抛一堆问题，每轮你确认后它才继续：

| 轮次  | AI 问什么                          | 你怎么答                                                       | 答不上怎么办          |
| --- | ------------------------------- | ---------------------------------------------------------- | --------------- |
| 1   | 你想做个什么产品？                       | 一句话描述：做什么、给谁用、大概在哪用。项目名会自动从你的描述里取——你说"做个计算器"，项目就叫"计算器"。    | 说个大概想法，AI 帮你提炼  |
| 2   | 我理解你要做 X：在 Y 上用，分 Z 块，用 W 做，对吗？ | 确认，或说"改"并告诉 AI 哪里不对。模块用英文代号：PC 电脑端、APP 手机端、CLOUD 后台，中文只是说明 | 说"你定"，AI 给默认值继续 |
| 3   | 代码怎么保存？                         | 项目自带本地git版本管理，此处确认项目目录有没有 git 库即可，新项目选"还没有"                | 选推荐项            |
| 4   | 给 AI 分几个角色？                     | AI 按模块自动安排，你确认或合并                                          | 说"你定"           |
| 5   | 提交标签，即提交前缀                      | 建议启用，AI 按模块自动配                                             | 选推荐项            |

**版本管理怎么运作**：项目初始化自动建本地 git 库，每次任务完成，系统自动保存一个版本（提交信息格式 `[模块] 任务ID: 标题`）；想回到之前的版本，说"回滚到改 X 之前"，AI 列出历史版本供你选择后还原。你全程不需要接触任何 git 命令。

**生成结果**：项目目录里会出现一个 `.vibe-coding/` 文件夹，这就是治理骨架，包含：

- `memory/` 下的治理文件：`MEMORY.md` 是索引、`RULES.md` 是铁律、`ROLES.md` 是角色、`CONTRACT.md` 是契约、`ARCHIVE.md` 记录演进与避坑
- 项目根目录的 `TASKS-<模块>.md`：每个模块一个任务看板
- 本地 `.git/`：项目版本库，由系统自动管理，你不需要碰
- 项目根目录的 `VPG.md`：项目入口文件，非隐藏——项目概况、治理文件在哪、角色、常用指令都写在里面。以后任何 AI 窗口进项目，先看这个文件就知道治理文件在哪。治理文件放在隐藏目录 `.vibe-coding/` 里，AI 用普通列举可能看不到，VPG.md 就是给它的指路牌。你自己想了解项目概况也可以直接打开它。

生成完成后，AI 会在对话里给你一段固定的使用引导，包含产物清单、角色方案和日常指令，照做即可。

**遇到异常**：如果 AI 问的问题很奇怪，比如问"项目在哪建""项目叫什么名字"这类模板里没有的问题，说明它没按模板执行——直接告诉它"请先运行 `vibe-project-init ask --list` 再提问"。

## 三、多窗口角色分工

角色是分给 AI 窗口的，和你用了几个人无关——一个人也可以同时有"总管 + 开发 + 数据分析"多个角色，每个角色开一个独立对话窗口。

以计算器项目为例，AI 会建议：

| 角色              | 干什么                       | 窗口数         |
| --------------- | ------------------------- | ----------- |
| coordinator（总管） | 收需求、派任务、验收成果、维护契约         | 1 个         |
| ai-pc 开发角色      | 负责 PC 电脑端和 APP 手机端两个模块的代码 | 1 个，一个窗口管两端 |

开角色窗口时，第一句话对 AI 说"你是 ai-pc 角色"，角色名就是 ai-<模块代号小写>，见 ROLES.md。

**开角色窗口的方法**：

1. 新建对话；
2. 在「选择工作空间」里选**同一个项目目录**，必须和 coordinator 一样；
3. 第一句话对 AI 说："你是 XX 角色"，例如"你是开发角色"。

**记住**：coordinator 窗口是总入口。你所有的需求、问题、指令，先告诉 coordinator，由它分发。

## 四、coordinator 的工作：分配与任务流转

coordinator 的日常是四件事：

1. **收需求**：你告诉它要做什么；
2. **写任务**：它把需求写成任务，记进对应模块的 `TASKS-<模块>.md`（任务板）；
3. **派活**：把任务交给对应开发角色窗口；
4. **验收**：开发完成后，coordinator 检查提交是否真实（commit-check）、改动是否合规，通过后标记完成。

**任务流转以任务板文件为准**：任务状态从待处理到处理中再到已完成，都写在 `TASKS-*.md` 里，任何窗口都能看到最新状态。你不需要传话，coordinator 会在每个环节完成后告诉你进度。

## 五、开发角色的工作：执行与任务流转

开发角色窗口拿到任务后按流程走：

1. 从 `TASKS-<模块>.md` 认领任务，标注"处理中"；
2. 按项目铁律（RULES.md）执行：一次只改一个功能，改前自查代码差异；
3. 改完代码，提交时遵守提交前缀规则，例如电脑端用 `[PC]`；
4. 改代码必须同时更新自己的开发文档，代码和文档**同一次提交**；
5. 在任务板里填写汇报，包括问题描述、变更内容、验证结果，标记"已完成"。

## 六、Bug 和需求处理

**报 bug**：直接对 coordinator 说"有个 bug：<现象>"。coordinator 会按固定格式写成任务，列出 bug 现象、可能原因、建议修复方案，派给对应开发窗口；开发修复后汇报，coordinator 验收通过才算完。

**提需求**：说"我想要 <功能>"。coordinator 按"需求描述 / 当前行为 / 期望行为"写成任务，同样派发 → 执行 → 验收。

**版本管理**：不用你操心，项目自带本地 git 版本库。每次任务完成，系统自动保存一个版本（提交信息 `[模块] 任务ID: 标题`）；想回到之前的版本，说"回滚到改 X 之前"，AI 列出历史版本供你选择后还原。全程不需要你接触 git 命令、不需要任何账号。

## 七、完整示例：从零到第一个任务

以计算器项目为例，走一遍全流程：

1. 在磁盘上手动新建工作区目录。
2. **建工作区**：新建对话 →「选择工作空间」→ 选刚刚新建的目录。
3. **创建项目**：对对话里的 AI 说"新建项目"。第一轮直接描述："我想做个计算器，带练习功能，在电脑上用"，项目名自动取"计算器"；第二轮确认 AI 推断的"PC"单模块；第三轮确认本地 git 库，新项目选"还没有"；角色按 AI 建议。生成 `.vibe-coding/` 骨架 + 本地 `.git/` 版本库。
4. **开角色窗口**：新建两个对话，都选同一个工作区目录——一个说"你是 coordinator，请读取系统记忆记住你的角色、职责、任务和纪律"，一个说"你是PC开发负责人，请读取系统记忆记住你的角色、职责、任务和纪律"，通过窗口中的第一句话进行角色声明。
5. **派任务**：对 coordinator 说"给计算器加个乘方功能"。coordinator 把任务写进 `TASKS-PC.md`，提供任务编号，如TASKS-PC-001，去开发窗口说"处理TASKS-PC-001"。
6. **执行**：开发窗口认领任务，改代码，提交（前缀 `[PC]`），在任务板填汇报，执行完毕后输出执行结果，或是提问要求澄清，这部分用户在窗口中对话即可。
7. **验收**：确认任务执行完毕，用户回到coordinator窗口说"TASKS-PC-001已完成，请验收"，coordinator会检查提交真实、改动合规，标记 `✅ coordinator 确认`，输出"完成"，至此一次任务执行闭环结束。
8. **日常**：报 bug、提需求都先跟 coordinator 说；想回退版本就说"回滚到改 X 之前"。

## 八、项目体检

项目体检是给项目做的定期检查，相当于项目的"体检医生"。AI 做项目，时间久了可能悄悄积累问题，比如某个任务 AI 说做完了但其实没真提交代码、某个跨模块约定没人跟进、提交前缀写错了。体检把这些按严重程度列出来告诉你。

**什么时候用**：

- 定期想看看项目健不健康；
- 项目要交付前，做一次合规检查；
- 怀疑某个 AI 提交可能有假、或某个约定没落实。

**怎么触发**：对 coordinator 说"给项目做个体检"或"项目体检"即可，会立即跑一次完整体检。

**它查什么**：任务状态一致性（防假成功）、契约完整性、工具版本一致性、跨模块改文件、审计日志大小、任务格式合规。

**问题分三个等级**：

| 等级    | 含义                   | 处理要求     |
| ----- | -------------------- | -------- |
| P0 致命 | 框架本身出问题，比如契约文件丢失     | 必须立即处理   |
| P1 一般 | 合规隐患，比如 AI 声称完成但没真提交 | 需要你选处置方式 |
| P2 轻微 | 规范小偏差，比如版本号不统一       | 可忽略      |

**关键特性**：体检只诊断、不改动——它发现问题不会自己动手改项目文件，只会报告并给你选项，等你授权后才通过任务系统去修。这样避免 AI 自作主张改东西。

---

# English Version

# Vibe Coding Toolkit User Guide

> This manual explains how to use this tool to manage your AI development projects. For an introduction to the skill itself, see [README.md](../README.md).
> This guide assumes no programming background; every technical term is explained when it first appears.

## 1. Step One: Create a Workspace

A workspace is an independent project folder in WorkBuddy. Your project code and governance files all live inside it. Every AI role window must point to the same workspace so that all of them collaborate on one project.

**Steps**:

1. Start a new conversation in WorkBuddy.
2. Click "选择工作空间" (Select Workspace) at the bottom-left of the input box.
3. Create or choose a folder; it is recommended to name it after the project, e.g., `Calculator`.
4. Start creating the project in this conversation.

**Why the workspace must come first**: if you skip it, WorkBuddy auto-generates a timestamp-named directory such as `2026-08-12-22-03-30`. It works, but you cannot rename it or promote it to a proper workspace in the UI later, and managing multiple role windows becomes awkward. So build the workspace in step one.

## 2. Create a Project (Initialize the Governance Skeleton)

In the workspace conversation, say "新建项目" (create a new project) — "初始化项目" (initialize project) or "新建AI开发项目" (new AI dev project) also work. AI asks you one question at a time following a fixed template — never a flood of questions at once; it continues only after you confirm each round:

| Round | What AI asks                                                                            | How you answer                                                                                                                                                                            | If you don't know                               |
| ----- | --------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------- |
| 1     | What product do you want to build?                                                      | Describe it in one sentence: what, who it is for, roughly where it runs. The project name is taken from your description — say "make a calculator" and the project is named "Calculator". | Give a rough idea and AI refines it             |
| 2     | I understand you want to build X: runs on Y, split into Z blocks, built with W — right? | Confirm, or say "change" and tell AI what is wrong. Modules use English codes: PC for desktop, APP for mobile, CLOUD for backend; Chinese is only for explanation                         | Say "you decide" and AI continues with defaults |
| 3     | How is the code saved?                                                                  | The project has built-in local git versioning; just confirm whether the project directory already has a git repo — choose "not yet" for a new project                                     | Pick the recommended option                     |
| 4     | How many roles for AI?                                                                  | AI arranges them by module; you confirm or merge                                                                                                                                          | Say "you decide"                                |
| 5     | Commit tags, i.e., commit prefixes                                                      | Recommended to enable; AI configures them per module                                                                                                                                      | Pick the recommended option                     |

**How versioning works**: project init automatically creates a local git repo. Each time a task completes, the system auto-saves a version (commit message format `[module] taskID: title`). To go back to an earlier version, say "回滚到改 X 之前" (roll back to before X was changed); AI lists historical versions for you to pick, then restores. You never touch any git command.

**What you get**: a `.vibe-coding/` folder appears in the project directory. This is the governance skeleton:

- Governance files under `memory/`: `MEMORY.md` is the index, `RULES.md` is the rules, `ROLES.md` is the roles, `CONTRACT.md` is the contract, `ARCHIVE.md` records evolution and lessons learned
- `TASKS-<module>.md` at the project root: one task board per module
- A local `.git/`: the project version repository, managed automatically — you don't need to touch it
- `VPG.md` at the project root: a non-hidden project entry file — project overview, where the governance files are, roles, and everyday commands. Any AI window entering the project reads this file first to find the governance files. The governance files live in the hidden `.vibe-coding/` directory that AI may not see with a plain listing; VPG.md is the signpost. You can also open it yourself to learn about the project.

When generation finishes, AI gives you a fixed usage guide in the conversation, including the output list, role plan, and everyday commands. Just follow it.

**If something looks wrong**: if AI asks odd questions that are not in the template, such as "where is the project created" or "what is the project called", it is not following the template — tell it: "请先运行 `vibe-project-init ask --list` 再提问" (run `vibe-project-init ask --list` first, then ask).

## 3. Multi-Window Role Division

Roles are assigned to AI windows, unrelated to how many people you have — one person can hold several roles at once ("manager + developer + data analyst"), each role opening its own conversation window.

Using the calculator project as an example, AI suggests:

| Role                  | What it does                                                                          | Windows                        |
| --------------------- | ------------------------------------------------------------------------------------- | ------------------------------ |
| coordinator (manager) | Collects requirements, dispatches tasks, accepts deliverables, maintains the contract | 1                              |
| ai-pc developer role  | Handles code for both the PC desktop and APP mobile modules                           | 1, one window covers both ends |

When opening a role window, say to AI as your first sentence: "你是 ai-pc 角色" (you are the ai-pc role). Role names follow the pattern ai-<lowercase module code>; see ROLES.md.

**How to open a role window**:

1. Start a new conversation.
2. In "选择工作空间" (Select Workspace), pick the same project directory — it must be the same one as the coordinator.
3. Say to AI as your first sentence: "你是 XX 角色" (you are the XX role), e.g., "you are the developer role".

**Remember**: the coordinator window is the single entry point. All your requirements, questions, and instructions go to the coordinator first, and it dispatches them.

## 4. What the Coordinator Does: Assignment and Task Flow

The coordinator does four things day to day:

1. **Collect requirements**: you tell it what needs to be done.
2. **Write tasks**: it turns requirements into tasks and records them in the module's `TASKS-<module>.md` (task board).
3. **Dispatch**: it hands the task to the corresponding developer role window.
4. **Accept**: after development, the coordinator checks whether the commit is real (commit-check) and the changes are compliant, then marks the task complete.

**The task board file is the source of truth**: task status moves from pending to in-progress to completed, all recorded in `TASKS-*.md`; every window can see the latest state. You don't need to relay messages — the coordinator tells you progress at each step.

## 5. What Developer Roles Do: Execution and Task Flow

A developer role window follows this flow after receiving a task:

1. Claim the task from `TASKS-<module>.md` and mark it "in progress".
2. Follow the project rules (RULES.md): change one feature at a time, review your own diff before changing.
3. When committing, follow the commit prefix rules, e.g., use `[PC]` for the desktop end.
4. Changing code requires updating your own dev documentation in the same commit — code and docs are committed together.
5. Fill in the report on the task board, including problem description, changes made, and verification results, then mark it "completed".

## 6. Handling Bugs and Requirements

**Report a bug**: say directly to the coordinator "有个 bug：<symptom>" (there's a bug: <symptom>). The coordinator turns it into a task in a fixed format, listing the symptom, likely cause, and suggested fix, and dispatches it to the corresponding developer window. After the developer fixes it and reports back, the coordinator must accept it before the task is done.

**Request a feature**: say "我想要 <功能>" (I want <feature>). The coordinator writes it as a task in "requirement / current behavior / expected behavior" format, then the same flow: dispatch → execute → accept.

**Versioning**: don't worry about it. The project has a built-in local git repository. Each completed task auto-saves a version (commit message `[module] taskID: title`). To go back, say "回滚到改 X 之前" (roll back to before X was changed); AI lists historical versions for you to pick, then restores. You never touch git commands and need no account.

## 7. Full Example: From Zero to the First Task

Using the calculator project, here is the whole flow:

1. Manually create a workspace directory on disk.
2. **Create the workspace**: new conversation → "选择工作空间" (Select Workspace) → pick the directory you just created.
3. **Create the project**: say "新建项目" (create project) to AI in the conversation. Round 1: describe directly — "我想做个计算器，带练习功能，在电脑上用" (I want a calculator with practice features, running on a computer); the project name becomes "Calculator". Round 2: confirm AI's inferred single "PC" module. Round 3: confirm the local git repo — choose "not yet" for a new project. Roles follow AI's suggestion. This generates the `.vibe-coding/` skeleton and a local `.git/` repository.
4. **Open role windows**: start two conversations pointing at the same workspace directory — in one say "你是 coordinator，请读取系统记忆记住你的角色、职责、任务和纪律" (you are the coordinator; read the system memory and remember your role, duties, tasks, and rules); in the other say "你是PC开发负责人，请读取系统记忆记住你的角色、职责、任务和纪律" (you are the PC development lead; read the system memory and remember your role, duties, tasks, and rules). The first sentence is the role declaration.
5. **Dispatch a task**: tell the coordinator "给计算器加个乘方功能" (add a power function to the calculator). The coordinator writes the task into `TASKS-PC.md`, provides the task ID, e.g., TASKS-PC-001, and tells the developer window "处理TASKS-PC-001" (handle TASKS-PC-001).
6. **Execute**: the developer window claims the task, changes code, commits (prefix `[PC]`), fills in the report on the task board, then outputs the execution result or asks for clarification — this part is just conversation in the windows.
7. **Accept**: once execution is done, go back to the coordinator window and say "TASKS-PC-001已完成，请验收" (TASKS-PC-001 is done, please accept). The coordinator checks that the commit is real and the changes are compliant, marks `✅ coordinator 确认` (coordinator confirmed), and says "done". That closes the loop for one task.
8. **Everyday**: report bugs and request features through the coordinator first; to roll back a version, say "回滚到改 X 之前" (roll back to before X was changed).

## 8. Project Checkup

A project checkup is a periodic health inspection for the project — its "doctor". When AI runs your project, problems can quietly accumulate: a task AI says is done but was never actually committed, a cross-module convention nobody follows up on, a wrong commit prefix. The checkup lists these by severity.

**When to use it**:

- You want to periodically see whether the project is healthy.
- Before delivering the project, you want a compliance check.
- You suspect an AI commit may be fake, or a convention was not honored.

**How to trigger it**: say "给项目做个体检" (run a checkup on the project) or "项目体检" (project checkup) to the coordinator; a full checkup runs immediately.

**What it checks**: task status consistency (against fake completions), contract integrity, tool version consistency, cross-module file changes, audit log size, task format compliance.

**Three severity levels**:

| Level       | Meaning                                                          | Handling                    |
| ----------- | ---------------------------------------------------------------- | --------------------------- |
| P0 Critical | The framework itself is broken, e.g., a contract file is missing | Must be handled immediately |
| P1 Moderate | Compliance risk, e.g., AI claims done but never committed        | You choose how to handle it |
| P2 Minor    | Minor deviation, e.g., inconsistent version numbers              | Can be ignored              |

**Key property**: the checkup only diagnoses, never changes anything — when it finds a problem it does not modify project files on its own; it only reports and gives you options, and fixes go through the task system only after you authorize them. This keeps AI from acting on its own.
