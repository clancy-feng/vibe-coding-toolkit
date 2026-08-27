# 首次引导模板

AI 在治理骨架生成后按本模板输出，结构、句式、顺序完全照抄，仅替换尖括号占位符。占位符取值说明见文件末尾。

「<项目名>」的 VPG 治理骨架已建好。

产物均在「<工作区名>」工作区：

- VPG.md — 项目入口说明，AI 进来先读这个
- .vibe-coding/memory/ — 治理记忆：MEMORY.md / PROJECT_PROFILE.md / ROLES.md / RULES.md / CONTRACT.md / ARCHIVE.md
- .vibe-coding/adapter.cfg — 唯一配置：模块 <模块列表>、提交前缀 [<前缀>]、git=<git 状态>
- .vibe-coding/commit-rules.yaml + .git/hooks/commit-msg — 提交前缀拦截钩子
- 任务看板 TASKS-*.md，每模块一个，日常任务记在这里
- .git/ — 本地版本库已就绪

角色方案已写入 ROLES.md：

- coordinator：项目总管，收需求、派任务、审查提交、维护治理文件
- <角色名>：<职责简述>
- <角色名>：<职责简述>

Git 当前状态：<已 init，治理文件尚未首次提交 / 已接入现有 git 库>。

日常你只需对我说这几句话：

1. "记个任务：要做 X" —— 我记进任务看板。
2. "任务 X 做完了" —— 我记录改动并验证，任务归档，系统自动存一版。
3. "存个版本" —— 把当前改动存成一版，随时找回。
4. "回滚到改 X 之前" —— 我列出版本让你选，选好还原。

建议先说一句"存个版本"，把初始治理骨架先存进本地版本库。下一步可以说"记个任务：<首个任务建议>"，开始第一个开发任务。

---

占位符取值说明：

- 项目名：collected.cfg 的 project_name
- 工作区名：当前目录名
- 模块列表：collected.cfg 的 modules，逗号分隔
- 前缀：commit_prefixes 的第一个前缀
- git 状态：git_status=new 写"已 init"，existing 写"已接入现有 git 库"
- 角色名与职责：从生成的 ROLES.md 读取，每个角色一行
- 首个任务建议：AI 按项目类型推断，给一个具体可执行的开发任务
