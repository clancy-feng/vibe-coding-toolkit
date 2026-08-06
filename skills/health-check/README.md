# health-check — 项目健康巡检 Skill

> 项目体检医生，**只诊断不修理**。触发词：给项目做个体检 / 项目体检 / 健康巡检 / 巡检一下 / 跑体检。
> 是 Vibe 治理工具集的第四核心组件，与 `vibe-project-init` / `commit-check` / `task-manager` 并列。
> 安装路径：`~/.workbuddy/skills/health-check/`，在项目根目录（含 `.git`）下运行。

# 

---

## 它做什么

health-check 扫描 AI 项目的治理隐患，用非技术语言报告，并给出处置选项，**等你授权后再经 `task-manager` 新开任务修复**。它**绝不自动修改任何业务或治理文件**——只诊断、只记录审计、只在自身响应层拦截。

唯一会写入的文件是它自己的审计日志 `.workbuddy/memory/HEALTH_AUDIT.md`。

## 触发方式

| 你说                                           | 系统执行                                                          |
| -------------------------------------------- | ------------------------------------------------------------- |
| "给项目做个体检" / "项目体检" / "健康巡检" / "巡检一下" / "跑体检" | 全量体检：`bash ~/.workbuddy/skills/health-check/scripts/check.sh` |
| "开启每日定时巡检"                                   | 由你授权后配置定时任务（默认关闭）触发 `check.sh`                                |

## 六项巡检

| 项   | 名称          | 检查内容                                                                              | 默认级别    |
| --- | ----------- | --------------------------------------------------------------------------------- | ------- |
| 1   | 任务状态一致性     | 扫 `TASKS-*.md` 中 `✅ 已完成` 任务，提取其 `**commit**` 跑 `git log`；commit 不存在 → 假成功         | P1      |
| 2   | 契约完整性       | 两步：① `CONTRACT.md` / `CROSS_IMPACT_LOG.md` 是否缺失（缺失→P0）；② 待裁决项超 24h 未更新 → P1       | P0 / P1 |
| 3   | Skill 版本一致性 | 比对 `SKILL_REGISTRY.md` 与各 `SKILL.md` 的 `version` 字段；不一致或无 `version` → P2          | P2      |
| 4   | 跨模块改文件      | 扫最近 50 条 commit，AI 角色归属模块与修改文件前缀不匹配且未在待裁决段登记 → 越权                                 | P1      |
| 5   | 审计日志大小      | `.workbuddy/memory/HEALTH_AUDIT.md` 超过 10MB → 建议归档                                | P2      |
| 6   | TASKS 格式合规  | 每条 `**状态**:` 必须以合法状态 token 开头（`📋 待处理`/`🔄 处理中`/`✅ 已完成`/`⏸ 暂挂`/`✅ coordinator确认`） | P2      |

### 分级含义

- **P0 致命级**：框架失效（如契约文件丢失、git 仓库损坏、连续 3 次 P1 未处理）。必须立即新开紧急修复任务，无"暂不处理"选项。
- **P1 一般级**：合规隐患（如假成功、待裁决超时）。可选：① 立即新开修复任务；② 稍后修复（24h 内必须处理）。
- **P2 轻微级**：规范偏差（如版本不一致）。可选：① 新开任务对齐；② 忽略（默认）。

> **P1 自动升 P0**：连续 3 次体检发现 P0/P1 未清除，且本次仍有 P1 → 本次所有 P1 直接升级为 P0 输出。仅重分类严重度，不阻断任务流转。

## 命令行

### 全量体检

```bash
bash ~/.workbuddy/skills/health-check/scripts/check.sh
```

运行六项巡检，输出分级结果并追加写入 `HEALTH_AUDIT.md`。

### 单项巡检

```bash
bash ~/.workbuddy/skills/health-check/scripts/check.sh --only tasks    # 项1 任务假成功
bash ~/.workbuddy/skills/health-check/scripts/check.sh --only contract # 项2 契约完整性
bash ~/.workbuddy/skills/health-check/scripts/check.sh --only skills   # 项3 版本一致性
bash ~/.workbuddy/skills/health-check/scripts/check.sh --only cross    # 项4 跨模块合规
bash ~/.workbuddy/skills/health-check/scripts/check.sh --only log      # 项5 日志大小
bash ~/.workbuddy/skills/health-check/scripts/check.sh --only fmt      # 项6 TASKS格式
```

### 错误判断识别（判定某级别的选择是否违规）

```bash
bash ~/.workbuddy/skills/health-check/scripts/check.sh --respond P0 "暂不处理"  # 输出第一次警告话术
bash ~/.workbuddy/skills/health-check/scripts/check.sh --respond P1 "稍后修复"  # 提示 24h 时限
bash ~/.workbuddy/skills/health-check/scripts/check.sh --respond P2 "忽略"      # 放行（默认）
```

对**单次**选择做无状态判定并输出话术，同时写审计。多轮升级（首次→二次→兜底）由 Coordinator AI 在对话层实现，脚本不追踪轮次。

## 输出示例

```text
[health-check] 体检报告 2026-07-20 18:30:00
────────────────────────────────
巡检项1 任务状态一致性: ✅ 通过（12 个已完成任务 commit 全部真实）
巡检项2 契约完整性:     ⚠ P1 — 待裁决项 [2026-07-18] 已超 24h 未更新
巡检项3 Skill版本一致性: ⚠ P2 — commit-check 无 version 字段
────────────────────────────────
发现合规问题（P1）：CROSS_IMPACT_LOG 待裁决项 [2026-07-18] 超 24h。
  请选择处置方式：1. 立即新开修复任务　2. 稍后修复（24小时内必须处理）
发现轻微偏差（P2）：commit-check 缺 version 字段。
  给你两个选项：1. 新开任务对齐　2. 忽略（默认）
已写入审计: .workbuddy/memory/HEALTH_AUDIT.md
```

全部通过时输出 `✅ 体检通过，未发现隐患`。

## 错误处理与降级

- **文件缺失**：`HEALTH_AUDIT.md` 不存在则自动创建，不报错。
- **Git 未初始化**：跳过项1（commit 检查），报 `WARNING_GIT_DISABLED`。
- **扫描失败**：返回 `ERROR_SCAN_FAILED`，提示"体检工具异常，请检查版本"。

## 目录结构

```text
health-check/
├── README.md          # 本文档
├── SKILL.md           # WorkBuddy Skill 定义（含六项巡检规则）
├── skill.json         # 平台元数据
└── scripts/
    └── check.sh       # 纯工具：无状态单次扫描 / --respond 单次判定
```

## 铁律

1. **只诊断不修理**：不改任何业务/治理文件，修复一律经 `task-manager` 新开任务。
2. **不猜测结果**：脚本判定什么等级就是什么，AI 无升降级裁量权。
3. **文件为唯一真相**：所有结论指向可核验的磁盘文件。
4. **POSIX 兼容**：`check.sh` 禁用 GNU AWK 三参数 `match` / PCRE lookbehind。
5. **架构边界**：`check.sh` 是纯工具；多轮对话拦截属 Coordinator AI 职责，**严禁在 Shell 脚本里实现对话管理**；冻结机制严禁调用 `task-manager` 任何冻结命令、严禁脑补 `handle_freeze`，真正的流转阻断留 TODO。

## 许可

MIT
