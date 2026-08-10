# task-manager 任务流转执行引擎（子命令，内部）

> 脚本：`scripts/task-manager/task-manager.sh`
> **内部基础设施型子命令**：由 WorkBuddy 意图识别模块隐式调用，不对用户暴露任何触发词或操作入口。

## 核心定位

本子命令是治理体系的"心脏"，所有与任务流转相关的操作（无论来自用户、AI 窗口或其他子命令）必须经过本子命令执行，确保规则 100% 落地。

## 触发条件（仅 WorkBuddy 内部调用，无用户触发词）

当 WorkBuddy 识别到以下意图时，自动调用本子命令的对应 Handler：

| 意图类型 | Handler | 调用场景示例 |
| --- | --- | --- |
| 创建任务 | `handle_create` | 用户说"给 PC 端加个修复登录超时的任务"、`project-init` 初始化后自动创建示例任务 |
| 认领任务 | `handle_claim` | AI 说"认领修复登录超时的任务" |
| 标记任务完成 | `handle_complete` | AI 说"任务做完了，commit 是 a1b2c3d"、`commit-check` 验证通过后自动触发 |
| 审查任务 | `handle_review` | 用户说"审查修复登录超时的任务"、`health-check` 发现任务异常时触发 |
| 查询任务 | `handle_list` | 用户说"看看 PC 端还有啥待办"、AI 启动时自动查询待办任务 |
| 修正任务状态 | `handle_fix` | `health-check` 发现任务状态不一致时调用 |

## 规则读取逻辑（所有规则从项目 memory 文件动态加载，不硬编码）

1. **权限校验**：调用前读取 `ROLES.md`，确认操作主体是否有对应模块权限。
2. **流程校验**：调用前读取 `WORKFLOW_TASK_DRIVEN.md`，确认操作符合任务生命周期（待处理→处理中→已完成）。
3. **铁律校验**：调用前读取 `RULES.md`，确认操作不违反核心铁律。
4. **契约校验**：若为跨端任务，调用前读取 `CONTRACT.md`，确认已更新跨端影响日志。

## 输出规范（仅返回结构化数据，不直接输出给用户）

所有 Handler 执行完毕后返回 JSON 结果，由 WorkBuddy 转译为自然语言提示：
```json
{
  "success": true,
  "code": "TASK_CREATED|PERMISSION_DENIED|RULE_VIOLATED|FORMAT_INCOMPLETE",
  "message": "结构化消息，供 WorkBuddy 转译",
  "data": { "task_id": "2026-07-15-PC-001", "module": "PC", "status": "pending", "commit_id": "a1b2c3d" }
}
```

## 联动逻辑

1. **与 `commit-check` 联动**：`handle_complete` 调用前自动触发 `commit-check` 验证 commit 合法性，验证失败则直接返回 `RULE_VIOLATED`。
2. **与 `health-check` 联动**：`handle_fix` 接收 `health-check` 的状态修正指令，强制同步 TASKS 文件与实际状态。
3. **与 `project-init` 联动**：初始化完成后自动创建符合 `WORKFLOW_TASK_DRIVEN.md` 格式的空任务看板。

## AI 执行强制规则（文件为唯一真相）

本引擎驱动的所有窗口（Coordinator / PC / 安卓 / 云端）必须严格遵守：
1. **所有窗口回复必须自带核验指引**：必须明确"请核验 `路径/文件` 的 `具体内容`，校验方法是 XXX"。
2. **禁止要求人复制回复内容**：所有回复必须引导人去核验磁盘文件，而非转发 AI 的话。
3. **Coordinator 收到"完成"指令后必须二次校验磁盘**：不能信人的话，必须自己读 `TASKS-*.md` 确认状态、读 commit 确认真实存在。
4. **人传递的指令必须包含文件核验结论**：若人只说"AI 说修完了"而没提文件核验，Coordinator 必须直接驳回。

## 错误处理

- **权限不足**：返回 `PERMISSION_DENIED`。
- **规则违反**：返回 `RULE_VIOLATED`。
- **格式不完整**：返回 `FORMAT_INCOMPLETE`。
- **文件锁冲突**：自动加文件锁，等待释放后重试，最多 3 次，失败返回 `SYSTEM_BUSY`。

## 降级逻辑

- **Git 未开启**：`handle_complete` 仅校验任务状态，不校验 commit 真实性，返回 `WARNING_GIT_DISABLED`。
- **规则文件缺失**：自动加载内置默认规则，返回 `WARNING_RULES_MISSING`。

## 任务更新与衍生决策（Coordinator 工作法）

`update` 调用约定：`bash scripts/task-manager/task-manager.sh update <task_id> <field> <value> [<actor>]`
- `field` ∈ `title` / `problem` / `change` / `verify` / `desc`
- 仅对 `📋 待处理` 任务生效；对已认领/完成返回 `UPDATE_NOT_ALLOWED`
- `problem` 不允许空或 `[待补充]`

## 版本
- 当前版本：**v1.0.0**（随 vibe-coding-toolkit 单包统一版本）
- 此前独立发布的 v1.0.10 已并入本包；内部 Handler 与强制规则保持不变。
