# task-manager — 任务流转引擎

> 定位：Vibe 治理工具箱的**核心执行引擎**。它后台自动运行，**没有给用户的操作入口**——你平时感知不到它，所有任务的创建、认领、流转、验证、归档都由 AI 按规则自动跑。
> 安装路径：`~/.workbuddy/skills/vibe-coding-toolkit/skills/task-manager/`

## 这是什么

task-manager 是 AI 项目治理体系的"心脏"。只要 WorkBuddy 识别到任务相关的意图（报个 bug、让团队动手、标记完成、审查、查待办……），就会自动调用它，按项目规则把任务全流转起来。你不需要手动建表、手动改状态——这些都由它落到磁盘文件 `TASKS-*.md` 里。

## 主要功能

- **任务全生命周期**：创建（create）、认领（claim）、完成（complete）、审查（review）、列表（list）、修正状态（fix），一条龙。
- **规则强制落地**：每次操作前自动读取 `RULES.md`（铁律）、`ROLES.md`（权限）、`WORKFLOW_TASK_DRIVEN.md`（流程）、`CONTRACT.md`（跨端契约）并校验，规则 100% 由脚本执行，不靠 AI 自觉。
- **文件唯一真相**：所有状态变更只写 `TASKS-*.md`；AI 的回复只是通知，磁盘文件才是事实。
- **自动联动**：
  - 与 `commit-check` 联动：标记完成前自动验证 commit 真实、合规、归属当前项目，不达标直接驳回。
  - 与 `health-check` 联动：体检发现任务状态不一致时，自动修正 TASKS 文件与实际状态对齐。
  - 与 `vibe-project-init` 联动：项目初始化后自动生成符合规范的空任务看板。
- **人只做两个接点**：派单（对执行窗口说"处理 `<task_id>`"）和验收（核验磁盘文件 + 一句结论）。其余全由 AI 跑。

## 在工具箱里的位置

| 你看到的      | 背后发生                                              |
| --------- | ------------------------------------------------- |
| 报需求 / bug | Coordinator 调 task-manager `create`               |
| 团队开始修     | 执行窗口 `claim` → 改代码 → `complete`（自动跑 commit-check） |
| 验收通过      | Coordinator `review` 二次校验磁盘                       |

## 想知道怎么用？（给用户的手册）

👉 见 **[USER_GUIDE.md](./USER_GUIDE.md)** —— 讲你平时要做的四件事：说清楚、看返回、拍板、两个接点操作。

## 许可

MIT
