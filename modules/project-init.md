# project-init 项目治理骨架初始化

> 脚本：`scripts/project-init/vibe-project-init.sh`
> 是 PACE 循环的"地基"子命令，必须在 commit-check / task-manager 之前运行。
> 
> 是VPG框架的项目初始化组件，与 `commit-check` / `health-check` / `task-manager` 并列，同属 `vibe-coding-toolkit` 。

## project-init模块铁律

- 必须仅生成治理骨架文件，包括 `.vibe-coding/` 下的 memory、TASKS-*、adapter.cfg、commit-rules.yaml 及 `.git/hooks/commit-msg`，不修改任何业务代码。
- 写入必须限定在项目目录内，治理记忆目录按新项目 `.vibe-coding/memory`、旧项目回落 `.workbuddy/memory` 取其一，不写两处。
- 所有路径与行为开关须从 `adapter.cfg` 读取；版本与路径须从脚本自身安装目录同源推导。
- 版本管理统一本地 git：`.git/` 由脚本自动管理，任务完成自动 commit；回滚须用户明确指令，先列后选。
- 适配存量项目时须先只读扫描、澄清边界，未经用户选择不写入任何正式治理目录。
- commit-msg 钩子须从源头拦截非法前缀，提交与推送由人类执行，本子命令不代劳。

## 定位

用户刚有个想法或已有项目但很乱。本子命令由 AI 助手在聊天中交互收集信息（AskUserQuestion / 自然语言解析），再把信息写成 `collected.cfg` 后以非交互方式生成治理骨架——脚本本身不接收终端输入、不含 read 向导。

> ⚠️ 本子命令不直接改业务代码。它只生成治理文件（`.vibe-coding/` 下的 memory、TASKS-*、adapter.cfg、commit-rules.yaml 及 `.git/hooks/commit-msg` 钩子）。业务代码由后续 PACE 循环（task-manager + commit-check）管。

## 触发词

新建项目模式：

- "初始化项目" / "新建项目" / "新建vibe coding项目" / "新建AI开发项目" / "开个新项目" / "init vibe coding project" / "init project"

适配已有项目模式：

- "帮我用这套治理体系管现有项目"
- "给现有项目接入治理"

update-prefixes（修改提交前缀）：

- "更新提交前缀" / "修改 commit 前缀规则"

update-adapter（修改项目配置）：

- "更新项目信息" / "修改项目配置"
- "迁移治理目录到xxxx"（需用户提供目标路径；AI 整体搬运治理目录并同步配置引用）

git（本地版本管理）：

- "列出历史版本" → `git history`（本地提交历史，hash|日期|消息）
- 回滚类（"回滚到改 X 之前" / "恢复到某个版本"）→ 先列后选：AI 先列出最近提交让用户选择，用户指定后 AI 用 git 还原（`git checkout <hash> -- .`）；AI 不得自行猜测版本

> 交互发生在 AI 聊天中：AI 助手就项目结构逐步提问或针对用户自然语言描述解析，收集齐字段后写入 `collected.cfg`，再调用脚本非交互生成；脚本侧不弹终端、不读 stdin。

## 新建模式交互流程

执行标准：AI 先运行 `bash scripts/project-init/vibe-project-init.sh ask --list` 获取 Q1-Q5 模板，逐轮照模板执行，禁止自行组织问题顺序、话术与选项，禁止一次问完多轮。所有交互发生在 AI 聊天中，脚本侧不弹终端、不读 stdin；字段收集齐写入 `.cache/project-init/collected.cfg`，运行 `ask --validate` 校验通过后再调用 `batch` 生成。

模板内容以 ask --list 输出为准，本节只说明设计意图，不再重复模板话术与选项：

1. 第 1 轮项目描述：用户自由回答，项目名从描述提取，不单独问"项目叫什么名字"。
2. 第 2 轮推断+确认：在哪用、分几块、用什么做三件事一体回显，用户可否决；模块代号必须英文标识符，中文模块名会被 ask_validate 拦截。
3. 第 3 轮 git 方式：确认项目目录有没有 git 库，本地 git 不需要账号。
4. 第 4 轮分角色：按模块生成角色方案写入 ROLES.md，用户可合并或改名。
5. 第 5 轮提交标签：按模块代号生成前缀写入 commit-rules.yaml。

自定义类选项铁律：任何轮次出现"自定义""其他/说不清"等表示用户自述的选项时，用户选中后必须追问真实内容并写入配置；禁止把"自定义""其他"等字面值写入 collected.cfg，脚本 ask_validate 会拦截。用户输入与选项无关的自由文本时按实际输入处理，同样禁止把"自定义"字样当答案。

### 生成后

全部字段写入 `.cache/project-init/collected.cfg`，调用 `batch` 生成骨架。batch 尾部会自动输出填充好的首次引导文本，AI 原样复制到聊天即可，只需把其中的"首个具体任务"替换为按项目推断的具体任务。

### 对话中 AI 每轮主动对用户的提示指引

- 每轮开头 AI 先一句话说明这轮问什么、为什么问。
- 用户说"不知道/你定"，AI 给默认值并标注可改，不卡流程。
- 用户可随时说"第 X 轮说的改成 Y"，AI 修正后重新回显确认。

## 适配模式

触发词：「帮我用这套治理体系管现有项目」「给现有项目接入治理」。与新建模式独立并列，仅用于已有代码但无治理文件的存量项目，本模式绝不自动触发。

1. 前置只读校验：非 git 仓库 → 报错不自动建；已接入治理 → 报错不重复适配。
2. 只读扫描：识别模块、历史 TODO 与合规缺口，仅做读取不写入。
3. 生成草稿：全部放在 `.vibe-coding/memory/drafts/`，绝不写入正式治理目录。
4. 等 AI 助手决定：agent 驱动、无 read 向导——草稿生成后打印"下一步请 AI 助手决定"指引，不弹终端选择。把草稿写入正式治理目录须由 AI 显式调用 `adapt apply all`，全量；或 `adapt apply <模块名>`，指定模块；`adapt preview` 仅预览草稿。未经显式 `apply`，任何正式目录都不被写入。
5. 边界澄清优先：新项目边界不清基本不会出现；接入已有项目时通过只读扫描与交互对话澄清边界，澄清后继续，不硬性中断；若经对话仍无法判定边界，明确告知「此情况超出本技能设计边界，无法实现，建议联系 skill 作者获取进一步帮助」，停止适配。

## 子命令：update-prefixes

触发词：「更新提交前缀」「修改 commit 前缀规则」。读取 `.vibe-coding/commit-rules.yaml` → 交互询问增删 → 写回，仅更新前缀配置，不动其它文件。

## 子命令：update-adapter

触发词：「更新项目信息」「修改项目配置」（对用户对话时统一称"项目配置/项目信息"，不出现 adapter.cfg 文件名）；「迁移治理目录」（需用户提供目标路径）。读取 `.vibe-coding/adapter.cfg` → 回显当前值 → 解析用户自然语言改值并写回；涉及目录迁移按旧项目兼容逻辑整体搬运，仅更新 adapter.cfg 配置与必要文件迁移，不改业务代码。

## 子命令：git

- "回滚到改 X 之前" / "恢复到某个版本" → 先列后选：AI 调用 `git history` 输出本地提交历史（`hash|日期|消息`，最近 30 条）呈现给用户，用户指定后 AI 用 git 还原（`git checkout <hash> -- .` 恢复工作区到该版本）。
- "列出历史版本" → `git history`。
- 提交由 task-manager complete 自动完成，通常无需手动。

## 版本管理约束

- 本地 git 统一管理：版本记录在项目本地 `.git/`，由脚本自动提交（任务完成自动 commit），不以 AI 口头说法为准；用户不接触 git 命令。
- 身份兜底：首次提交缺 user.name/email 时自动配置项目本地身份（vibe-coding-bot），不碰全局配置。
- commit-check 校验：校验本地 commit 真实性与前缀合规（git 管理项目的唯一校验路径）。
- 授权模型：任务完成自动 commit 为确定性联动，对标 git commit，无需逐次授权；回滚须用户明确指令，先列后选。
- 纯 POSIX、零外部依赖：仅用 git 与标配工具，兼容 Windows Git Bash / macOS / Linux。

## 生成产物（统一收敛到 `.vibe-coding/`，与 `.workbuddy/` 平级）

0. 根目录入口文件 `VPG.md`：非隐藏，解决 AI 看不到隐藏目录 `.vibe-coding` 的问题——包含项目概况、治理文件对照表、角色与常用指令，AI 枚举根目录必然可见、被引导进隐藏目录。
1. 跨平台适配层 `.vibe-coding/adapter.cfg`：唯一配置文件。包含治理根目录、各路径变量、行为开关 HOOK_ENABLED、git 方式 GIT_STATUS 与合法前缀 VALID_PREFIXES。所有脚本从配置读取，禁止硬编码。
2. 系统记忆中心 `.vibe-coding/memory/`：`MEMORY.md`、`PROJECT_PROFILE.md`、`RULES.md` 预置核心铁律、`ROLES.md`、`CONTRACT.md`、`ARCHIVE.md`。
3. 任务看板 `TASKS-*.md`：每模块独立任务文件。
4. 本地版本库 项目根 `.git/`：git 管理，task-manager 任务完成自动 commit，用户零操作。
5. 运行日志 `.vibe-coding/logs/`：各脚本运行过程落盘为 `<模块>-<日期>-<时间>.log`，颗粒度含启动、动作、成功或失败含错误信息。
6. 提交前缀规则 `.vibe-coding/commit-rules.yaml`：供 commit-check 与 commit-msg 钩子使用，脚本不内置任何前缀。
7. 提交钩子 `.git/hooks/commit-msg`：需 git 仓库且 `HOOK_ENABLED=true`，从源头拦截非法前缀，遵守 Git 纪律。

## 生成物一致性

- 自动注入预置基础铁律模板，确保项目合规。
- 生成的 `commit-rules.yaml` 的 `prefixes` 即为 commit-check 校验的合法前缀来源，二者天然一致。
- 生成的 CONTRACT.md 中"只有 coordinator 可改"的护栏须与 task-manager 写权限一致。

## 版本

- 当前版本：v1.2.0 
