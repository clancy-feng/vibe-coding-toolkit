---
name: task-manager
description: >
  内部基础设施型Skill，是AI项目治理体系的执行引擎。负责严格按照memory/目录下的RULES.md、ROLES.md、WORKFLOW_TASK_DRIVEN.md规则，自动完成任务的创建、认领、流转、验证、归档全流程。
  仅由WorkBuddy意图识别模块隐式调用，不对用户暴露任何触发词或操作入口。
internal: true                  # 核心标记：内部Skill，不对外暴露
no_user_prompt: true            # 不生成面向用户的提示
strict_mode: always             # 严格执行规则，无妥协
priority: 100                   # 高优先级，意图识别后优先调用
version: "1.0.10"
---

# Task Manager 内部执行引擎规则
## 核心定位
本Skill是治理体系的“心脏”，所有与任务流转相关的操作（无论来自用户、AI窗口或其他Skill）必须经过本Skill执行，确保规则100%落地。

## 触发条件（仅WorkBuddy内部调用，无用户触发词）
当WorkBuddy识别到以下意图时，自动调用本Skill的对应Handler：
| 意图类型 | Handler | 调用场景示例 |
|---|---|---|
| 创建任务 | `handle_create` | 用户说“给PC端加个修复登录超时的任务”、`vibe-project-init`初始化后自动创建示例任务 |
| 认领任务 | `handle_claim` | AI说“认领修复登录超时的任务” |
| 标记任务完成 | `handle_complete` | AI说“任务做完了，commit是a1b2c3d”、`commit-check`验证通过后自动触发 |
| 审查任务 | `handle_review` | 用户说“审查修复登录超时的任务”、`health-check`发现任务异常时触发 |
| 查询任务 | `handle_list` | 用户说“看看PC端还有啥待办”、AI启动时自动查询待办任务 |
| 修正任务状态 | `handle_fix` | `health-check`发现任务状态不一致时调用 |

## 规则读取逻辑（所有规则从memory文件动态加载，不硬编码）
1. **权限校验**：调用前必须读取`ROLES.md`，确认操作主体（用户/AI窗口）是否有对应模块的操作权限。
2. **流程校验**：调用前必须读取`WORKFLOW_TASK_DRIVEN.md`，确认操作符合任务生命周期（待处理→处理中→已完成）。
3. **铁律校验**：调用前必须读取`RULES.md`，确认操作不违反核心铁律（如commit前缀、禁止越界等）。
4. **契约校验**：若为跨端任务，调用前必须读取`CONTRACT.md`，确认已更新跨端影响日志。

## 输出规范（仅返回结构化数据，不直接输出给用户）
所有Handler执行完毕后，返回JSON格式结果，由WorkBuddy转译为用户友好的自然语言提示：
json

{

"success": true/false,

"code": "TASK_CREATED|PERMISSION_DENIED|RULE_VIOLATED|FORMAT_INCOMPLETE",

"message": "结构化消息，供WorkBuddy转译",

"data": {

"task_id": "2026-07-15-PC-001",

"module": "PC",

"status": "pending/in_progress/done",

"commit_id": "a1b2c3d"

}

}

纯文本
## 联动逻辑
1. **与`commit-check`联动**：`handle_complete`调用前，自动触发`commit-check`验证commit合法性，验证失败则直接返回`RULE_VIOLATED`。
2. **与`health-check`联动**：`handle_fix`接收`health-check`的状态修正指令，强制同步TASKS文件与实际状态。
3. **与`vibe-project-init`联动**：初始化完成后，自动创建符合`WORKFLOW_TASK_DRIVEN.md`格式的空任务看板。

## AI 执行强制规则（文件为唯一真相）
本引擎驱动的所有窗口（Coordinator / PC / 安卓 / 云端）必须严格遵守，违反的回复应被 Coordinator 直接驳回（依据：`任务流转逻辑对比.md` v1.0）：
1. **所有窗口回复必须自带核验指引**：不得只说"我改了 X / 修完了"，必须明确"请核验 `路径/文件` 的 `具体内容`，校验方法是 XXX（如 `git log <id>`）"。AI 回复只是通知，不是事实。
2. **禁止要求人复制回复内容**：所有回复必须引导人去核验磁盘文件，而非转发 AI 的话。人搬的是"核验结果"，不是"AI 的原话"。
3. **Coordinator 收到"完成"指令后必须二次校验磁盘**：不能信人的话，必须自己读 `TASKS-*.md` 确认状态、读 commit 确认真实存在，不符合即返回 `VERIFICATION_FAILED` / 驳回。
4. **人传递的指令必须包含文件核验结论**：若人只说"AI 说修完了"而没提文件核验，Coordinator 必须直接驳回，要求补充"已核验 XXX 状态为 ✅、commit `<id>` 真实存在"。

> 联动：状态变更一律写入 `TASKS-*.md`（本引擎负责）；commit 必须真实存在（`commit-check` 负责）；所有 AI 回复必须指向磁盘文件而非空口承诺。

## 错误处理
1. **权限不足**：返回`PERMISSION_DENIED`，由WorkBuddy提示用户“你没有操作该模块的权限”。
2. **规则违反**：返回`RULE_VIOLATED`，由WorkBuddy提示用户“操作违反铁律第X条：XXX”。
3. **格式不完整**：返回`FORMAT_INCOMPLETE`，由WorkBuddy提示用户“请补充XXX字段（参考WORKFLOW模板）”。
4. **文件锁冲突**：若多个操作同时修改同一TASKS文件，自动加文件锁，等待释放后重试，最多重试3次，失败则返回`SYSTEM_BUSY`。

## 降级逻辑
1. **Git未开启**：`handle_complete`仅校验任务状态，不校验commit真实性，返回`WARNING_GIT_DISABLED`由WorkBuddy提示用户“未开存档，无法验证commit真实性”。
2. **规则文件缺失**：自动加载内置默认规则，返回`WARNING_RULES_MISSING`由WorkBuddy提示用户“未找到规则文件，使用默认规则，请运行vibe-project-init修复”。

## 任务更新与衍生决策（Coordinator 工作法）
当 Coordinator 分析后建了任务 A，用户补充细节导致需要"更全面的方案 B"时，按以下决策树操作（`update` 为此而生，详见下节）：

1. **A 已认领(🔄)/完成(✅)** → 绝不 `update` / 删 A（会破坏执行团队承诺）。B 必须是独立任务：`create B` 并在其 `problem` 写明"基于 [A 的 task_id] 结果"；状态检查会拒绝对已认领任务的 `update`。
2. **A 仍 📋 待处理，且 B 是对 A 的纠正/补全** → 用 `update` 原地升到 B 水平（保留 task_id 与追溯，不产生重叠待办）。**这是首选。**
3. **A 仍 📋，但 B 是真正的新后续工作** → `create B` 并关联 A（同第 1 种写法）。

### update 调用约定
`bash task-manager.sh update <task_id> <field> <value> [<actor>]`
- `field` ∈ `title` / `problem` / `change` / `verify` / `desc`
- 仅对 `📋 待处理` 任务生效；对已认领/完成返回 `UPDATE_NOT_ALLOWED`
- `problem` 不允许空或 `[待补充]`（复用 `CREATE_INCOMPLETE` 逻辑，错误码 `UPDATE_INCOMPLETE`）
- 每次 `update` 在任务块内追加 `**更新**: <时间> <actor> 修改了字段 <field>`，保留追溯，且多条更新有序集中在任务块末尾（`---` 之前）
- 不改变任务状态（状态流转归 `claim`/`complete`）

## 变更记录（CHANGELOG）
- **2026-07-15 v1.0.10**（coordinator 受控改动，user 级 skill 需留痕）
  - 文档结构重写 `USER_GUIDE.md`：统一编号（一节一级、接点内用有序步骤）、删除"你不用…因为…"冗余解释，全改为动作指令；保留派单只需"处理 `<task_id>`"、验收只需"核验磁盘+一句结论"的核心。
- **2026-07-15 v1.0.9**（coordinator 受控改动，user 级 skill 需留痕）
  - 文档级精简 `USER_GUIDE.md`：去除冗余的"派单/验收"口头指令。人类只需说"处理 `<task_id>`"（PC 窗口读 `task-manager` skill + `WORKFLOW_TASK_DRIVEN.md` + `TASKS-*.md` 自执行全套流程），验收只需"核验磁盘 + 一句核验结论"；明确 Coordinator 不参与派单、GO 信号无需口头告知协调员（磁盘状态可见）。
- **2026-07-15 v1.0.8**（coordinator 受控改动，user 级 skill 需留痕）
  - 新增「AI 执行强制规则（文件为唯一真相）」章节，将"文件为唯一真相、AI 回复只是通知、人传核验结果而非 AI 原话、Coordinator 二次校验磁盘"固化为所有窗口通用纪律（依据 `任务流转逻辑对比.md` v1.0）：① 所有窗口回复自带核验指引；② 禁止要求人复制回复；③ Coordinator 收到完成指令必须二次校验磁盘；④ 人指令缺文件核验结论则驳回。
  - 配合 `USER_GUIDE.md` 同步重构"两个人肉接点"：接点①要求 PC 窗口回复带核验指引；接点②改为"你核验文件→传核验结果→协调员二次校验→你实测→反馈闭环"。
- **2026-07-15 v1.0.7**（coordinator 受控改动，user 级 skill 需留痕）
  - 新增 `update` 操作（`handle_update`）：支持对待认领(📋)任务的 `title`/`problem`/`change`/`verify`/`desc` 字段原地更新，填补"建任务后分析演进、需修订提案"的工具缺口（此前只能 `create` 新任务，导致重叠待办或手动改文件绕过 skill）。
  - 护栏：仅对 `📋` 任务生效，对已认领/完成返回 `UPDATE_NOT_ALLOWED`（保护执行团队承诺）；`problem` 空/`[待补充]` 返回 `UPDATE_INCOMPLETE`；非法字段返回 `UPDATE_INVALID_FIELD`。
  - 追溯：每次更新在任务块内追加 `**更新**: <时间> <actor> 修改了字段 <field>`，并通过 awk 缓冲机制保证多条更新有序集中在块尾（`---` 之前），不被段落替换逻辑吞掉或错序。
  - 配套：新增 `USER_GUIDE.md`（人类用户使用手册），说明"提请求/看返回/拍板"的 4 步循环；本文件新增"任务更新与衍生决策"工作法章节。
- **2026-07-14 v1.0.6**（coordinator 受控改动，user 级 skill 需留痕）
  - 修复 `handle_review` 第 286 行 `grep -q "**状态**: ✅ 已完成"` 的正则 bug：BRE 下 `*` 为量词，`**` 不匹配字面 `**`，导致 review 永远误报 `TASK_NOT_COMPLETED`。改为 `grep -qF`（固定字符串匹配），状态检查恢复正常。
  - 澄清：任务描述称 claim/handle_complete 同有此 bug——**不实**。该两处自 v1.0.1 起已改用 awk（`/\*\*状态\*\*: /` 正确转义），不受影响。commit-check 的 grep 均为 `-qE` 正常正则，亦无此问题。
- **2026-07-10 v1.0.3**（coordinator 受控改动，沿用用户提供的修复片段，user 级 skill 需留痕）
- **2026-07-13 v1.0.4**（coordinator 受控改动，修复 `handle_create` 参数未提取导致 `module: unbound variable` 崩溃；按 TASKS-SKILL.md 末尾任务落盘，user 级 skill 需留痕）
  - 修复 `handle_complete` 跨端日志段的潜伏缺陷：原 `sed -i "${MEMORY_DIR}/CONTRACT.md"` 假设该文件必存在，仓库无 `CONTRACT.md` 时 `sed` 报错并在 `set -e` 下中断 `complete`（表现为无 JSON 输出、任务实际未标记完成）。
  - 改为：仅当 `CONTRACT.md` 存在才写入跨端日志；不存在时 `log_debug` 告警并跳过，不再中断主流程（跨端日志属辅助性）。
- **2026-07-13 v1.0.5**（coordinator 受控改动，根治"create 产出空壳"设计缺口，user 级 skill 需留痕）
  - `handle_create` 契约扩展为 `create <module> <title> <actor> <problem> [<change>] [<verify>]`：`问题描述` 必填（来自 Coordinator 对用户自然语言的提炼），`变更内容/验证结果` 在完成前允许占位 `[待补充]`。
  - 新增强制校验：problem 为空或等于 `[待补充]` 时 `error_exit CREATE_INCOMPLETE` 拒绝创建，从机制上杜绝空壳任务（对齐"流程由脚本强制，非靠 AI 自觉"原则）。
  - `handle_complete` 改为将汇报的三段内容**写回任务文件对应段落**（替换 `[待补充]` 占位），不再把整段 report 追加到文件末尾，消除"骨架永远空 + 末尾重复 blob"的脏结构。
  - 调用约定：Coordinator 在调用 `create` 前必须先①判断模块归属（PC/安卓/云端）②把用户自然语言提炼为结构化 `problem` 传入；未提炼直接传空会被脚本拒绝。
- **2026-07-10 v1.0.2**（coordinator 受控改动，user 级 skill 需留痕）
  - 移除全部 PCRE / GNU 专属语法，全面 POSIX 化，消除跨 awk/grep 实现的兼容隐患：
    - 删除 5 处 `grep -oP` 的 Perl lookbehind（`(?<=...)` / `\K`），改用 `sed` 提取：`VALID_PREFIXES`、`commit` 前缀、`GIT_STATUS`、`title`、`commit_id`。
    - `handle_list` 的 2 处 GNU awk 三参数 `match($0, re, arr)` 改为 POSIX 两参数 `match` + `substr($0, RSTART, RLENGTH)`，任务 ID 与状态提取不再依赖 gawk。
  - 验证：旧报的"jq 依赖隐患"经全目录 grep 复核 **已不存在**（脚本全程手写 JSON，未调用 jq），无需改动；本次仅消除 lookbehind / gawk 隐患。
- **2026-07-10 v1.0.1**（coordinator 排障任务授权修改，user 级 skill 需留痕）
  - 修复 `handle_claim` / `handle_complete` 静默失败：
    - 根因：sed 替换状态后不校验结果，当 emoji/格式字节不匹配时 sed 静默 no-op 却返回 `success=true`，导致后续 `complete` 误报 `TASK_NOT_CLAIMED`。
    - 修复①：sed 搜索模式由精确 `📋 待处理` / `🔄 处理中` 改为锚定 `**状态**: ` 前缀 + `.*`，不再依赖旧 emoji 的精确字节。
    - 修复②：每次 sed 后重新 awk 读状态，未达预期直接 `error_exit`（新错误码 `CLAIM_FAILED` / `COMPLETE_FAILED`），把"假成功"变"真报错"。