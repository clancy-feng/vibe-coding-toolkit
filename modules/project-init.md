# project-init 项目治理骨架初始化（子命令）

> 脚本：`scripts/project-init/vibe-project-init.sh`
> 是 PACE 循环的"地基"子命令，必须在 commit-check / task-manager 之前运行。

## 定位

用户（非开发背景、用 AI 做项目的人）刚有个想法或已有项目但很乱。本子命令通过**交互式问答 + 自然语言解析**两种方式，帮用户把模糊想法翻译成治理骨架。

> ⚠️ 本子命令不直接改业务代码。它只生成治理文件（`.vibe-coding/` 下的 memory、TASKS-*、project.config、adapter.cfg、commit-rules.yaml 及 `.git/hooks/commit-msg` 钩子）。业务代码由后续 PACE 循环（task-manager + commit-check）管。

## 触发词

- "初始化项目" / "给我的项目加治理框架" / "init project" / "新项目"
- "补充项目信息" / "完善项目信息" / "治理框架" / "vibe init"
- "帮我用这套治理体系管现有项目"（适配模式）
- "更新提交前缀" / "修改 commit 前缀规则"
- "更新适配层配置" / "迁移治理目录"
- "简易快照" / "打个版本快照" / "保存当前版本" / "记一下现在的状态" / "备份一下" / "看看之前的版本" / "列一下快照" / "回滚到上个版本" / "恢复到某个版本" / "删除旧快照"

> 交互式 Skill：工具会就项目结构逐步问答，也支持用户一段话描述后自动解析。

## 交互模式（默认，7 轮问答）

1. **项目是什么**：项目名与描述。
2. **使用场景**：电脑浏览器 / 手机 App / 手机浏览器 / 后台自动跑 / 其他。
3. **模块命名**：把场景翻译成模块名（如 PC端、云端）。
4. **提交前缀规则配置（⭐）**：为每个模块生成前缀候选 + 预置通用前缀（FEAT/FIX/DOCS/CHORE/REFACTOR/TEST）；询问是否启用 `prefix_check`。写入 `.vibe-coding/commit-rules.yaml`。
5. **生成跨平台适配层配置（⭐，1.1.0 新增）**：写 `.vibe-coding/adapter.cfg`（治理根目录与各路径、行为开关）；安装 `.git/hooks/commit-msg` 钩子（源头拦截非法前缀，禁止自动 amend/push）。
6. **角色分工**：谁负责各模块。
7. **技术栈 / 痛点 / Git 引导**：收集背景并按需 `git init` + 首次 commit。**Git 引导分支（快照与 Git 互斥）**：用户"已用 Git"或"帮我开一个"→ 启用 Git，简易快照默认关闭（Git 用户完全无感）；用户"不需要 Git"→ 启用简易快照（调用 `snapshot init`），追问要备份的目录（默认 `src/`、`config/`，可补充 `data/ docs/` 等），写入 `.vibe-coding/adapter.cfg` 的 `SNAPSHOT_*` 配置。

## 自然语言模式（备选）

用户直接说一段话，解析出 project_name / modules / tech_stack / team_mode / pain_points，回显确认后进入生成。

## 适配模式（存量项目接入治理）

触发词：「帮我用这套治理体系管现有项目」。与新建模式独立并列，仅用于已有代码但无治理文件的存量项目，绝不自动触发。

1. **前置只读校验**：非 git 仓库 → 报错不自动建；已接入治理 → 报错不重复适配。
2. **只读扫描**：识别模块 / 历史 TODO / 合规缺口（只扫不写）。
3. **生成草稿**：全部放在 `.vibe-coding/memory/drafts/`，绝不碰正式治理目录。
4. **等用户选择**：全量适配 / 仅适配指定模块 / 先看草稿内容——选了才动。
5. **边界澄清优先（不硬停）**：新项目边界不清基本不会出现；接入已有项目时通过只读扫描 + 交互对话澄清边界，澄清后继续；若经对话仍无法判定边界，明确告知「此情况超出本技能设计边界，无法实现，建议联系 skill 作者获取进一步帮助」，停止适配。

## 子命令：update-prefixes（修改已生成的前缀规则）

触发词：「更新提交前缀」「修改 commit 前缀规则」。读取 `.vibe-coding/commit-rules.yaml` → 交互询问增删 → 写回。仅更新前缀配置，不动其它文件。

## 子命令：update-adapter（更新适配层配置）

触发词：「更新适配层配置」「迁移治理目录」。读取 `.vibe-coding/adapter.cfg` → 回显当前值 → 解析用户自然语言改值并写回；涉及目录迁移按旧项目兼容逻辑整体搬运。仅更新适配层配置与必要文件迁移，不改业务代码。

## 子命令：snapshot（简易快照，无 Git 用户的后悔药）

> 仅当用户明确选择不使用 Git 时启用；Git 用户默认关闭、调用即提示，完全无感。不能替代 Git 的协作/分支能力，定位"土法全量备份 + 一键回滚"。

触发词与对应子命令：

- "打个版本快照" / "保存当前版本" / "记一下现在的状态" / "备份一下" → `snapshot create`（问描述 → 全量备份指定目录 → 写 `snapshot.meta` → 更新 `latest.meta`）
- "看看之前的版本" / "有哪些快照" / "列一下快照" → `snapshot list`（倒序列出所有快照，提示可回滚）
- "回滚到上个版本" / "回到改 X 之前的版本" / "恢复到 ID xxx 的版本" / "撤销刚才的修改" → `snapshot rollback [ID|编号]`（无参=回滚到上一个版本；回滚前自动备份当前版到 `rollback_backups/`，保留 7 天防误操作）
- "删除 3 个月前的旧快照" → `snapshot cleanup old`（列出→用户授权→删除）
- "删除 7 天前的回滚备份" → `snapshot cleanup rollback`（列出→用户授权→删除）

配置入口：`snapshot init`（由第 7 轮"不需要 Git"引导调用，也可用户直接调用），写入 `.vibe-coding/adapter.cfg`：

```
SNAPSHOT_ENABLED="true"
SNAPSHOT_DIR=".vibe-coding/snapshots"
SNAPSHOT_BACKUP_DIRS="src config"   # 用户指定的备份目录（空格分隔）
MAX_SNAPSHOT_COUNT="20"
ROLLBACK_BACKUP_RETENTION_DAYS="7"
```

约束（铁律）：

- **目录隔离**：只备份用户指定的业务目录，**绝不**备份 `.git/`、`.workbuddy/`、`.vibe-coding/`。
- **AI 零裁量**：打快照 / 回滚 / 删快照均须用户明确授权，AI 不自动执行任何操作。
- **纯 POSIX、零外部依赖**：仅用 `cp`/`date`/`find` 等标配工具，兼容 Windows Git Bash / macOS / Linux。
- **非破坏性**：完全新增，不改原有 Git 初始化与提交钩子逻辑。

## 生成产物（统一收敛到 `.vibe-coding/`，与 `.workbuddy/` 平级）

1. **跨平台适配层** `.vibe-coding/adapter.cfg`：治理根目录、各路径变量与行为开关，所有脚本从配置读取，禁止硬编码。
2. **系统记忆中心** `.vibe-coding/memory/`：`MEMORY.md` / `PROJECT_PROFILE.md` / `RULES.md`（核心铁律预置）/ `ROLES.md` / `CONTRACT.md` / `ARCHIVE.md`。
3. **任务看板** `TASKS-*.md`：每模块独立任务文件。
4. **配置文件** `memory/project.config`。
5. **提交前缀规则** `.vibe-coding/commit-rules.yaml`（供 commit-check 与 commit-msg 钩子使用，脚本不内置任何前缀）。
6. **提交钩子** `.git/hooks/commit-msg`（需 git 仓库且 `HOOK_ENABLED=true`）：源头拦截非法前缀，遵守 Git 纪律。
7. **简易快照（可选，仅无 Git 用户）** `.vibe-coding/snapshots/`：全量备份目录、`snapshot.meta` 元数据、`latest.meta` 与回滚前 `rollback_backups/`；由 `snapshot init` 按需生成。

## 铁律对齐
- 自动注入预置基础铁律模板，确保项目合规。
- 生成的 `commit-rules.yaml` 的 `prefixes` 即为 commit-check 校验的合法前缀来源，二者天然一致。
- 生成的 CONTRACT.md 中"只有 coordinator 可改"的护栏须与 task-manager 写权限一致。
- 交互友好声明：如需用户名/邮箱以便存档，直接在当前聊天窗口提问，不弹终端、不后台静默失败。

## 版本
- 当前版本：**v1.0.0**（随 vibe-coding-toolkit 单包统一版本）
- 此前独立发布的 v1.1.0 已并入本包；`.vibe-coding/` 治理目录、adapter.cfg、commit-msg 钩子、存量项目适配模式均保留。
