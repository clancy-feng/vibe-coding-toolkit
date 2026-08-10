---
name: "vibe-coding-toolkit"
title: "Vibe Coding Toolkit"
slug: "vibe-coding-toolkit"
version: "1.0.0"
description: "Vibe Coding Toolkit — 面向非技术用户的 AI 项目治理工具包（单包，含 4 个子命令：health-check / commit-check / task-manager / project-init）。零网络访问、零环境变量读取、零数据外传；所有写入仅限当前项目目录内，不读取或写入项目目录之外的任何文件。各子命令的触发词与用法见下方「子命令路由表」。"
priority: 90
---

# Vibe Coding Toolkit（单包治理工具集）

> 这是一个**单包 skill**（一个 slug `vibe-coding-toolkit`，一个版本号），内部含 4 个子命令（模块），由 WorkBuddy 根据用户意图路由到对应脚本。
> 各子命令的完整说明见 `modules/` 下的文档（这些文档仅供阅读，不会被加载器当作独立 skill）。

## 安全声明（如实披露）

- **零网络访问**：本工具包不发起任何网络请求。
- **零环境变量读取**：不读取任何环境变量作为行为输入。
- **零数据外传**：不向任何外部位置发送项目数据。
- **写入范围（仅项目内）**：
  - 健康巡检会写入当前项目的 `.vibe-coding/memory/HEALTH_AUDIT.md`（审计留痕）与 `.vibe-coding/memory/.health_state`（连续未清除计数，仅作透明提示，不改变判定等级）；若项目仅有旧版 `.workbuddy/memory/`，自动回落该路径。
  - 项目初始化会写入当前项目的治理骨架文件（`.vibe-coding/` 下）。
  - 项目初始化会在当前项目的 `.git/hooks/commit-msg` 安装一个**可选**的提交前缀校验钩子（由 `HOOK_ENABLED` 控制，默认开启，可在 `adapter.cfg` 设为 `false` 关闭）；该钩子仅在 `git commit` 时于本地拦截非法前缀，不联网、不读取项目外文件。
  - 项目初始化会向当前项目的 `.workbuddy/memory/MEMORY.md` **追加一行** VPG 治理指针（仅追加、不覆盖宿主自有记忆、幂等，不执行任何代码），用于多工具适配时引导 AI 找到治理根目录 `.vibe-coding/`。
  - 项目初始化（启用「简易快照」时）会在当前项目的 `.vibe-coding/snapshots/` 写入全量备份（仅用户指定的业务目录，如 `src/`、`config/`）、`snapshot.meta` 元数据、`latest.meta` 与回滚前的 `rollback_backups/`；**仅当用户明确选择不使用 Git 时启用**，绝不备份 `.git/`、`.workbuddy/`、`.vibe-coding/` 等治理目录；所有快照操作（打/列/回滚/删）均须用户明确授权，AI 不自动执行。
  - 以上写入均发生在**被体检/被初始化的项目目录内**，不读取也不写入项目目录之外的任何文件；版本核对仅基于自身安装目录的 `skill.json`。

## 子命令路由表

| 用户意图（触发词）                                                            | 子命令            | 执行脚本                                        |
| -------------------------------------------------------------------- | -------------- | ------------------------------------------- |
| 给项目做个体检 / 项目体检 / 健康巡检                                                | `health-check` | `scripts/health-check/check.sh`             |
| 检查 commit / 验证提交 / 检查提交前缀 / 检查归属 / 工作区是否干净                           | `commit-check` | `scripts/commit-check/commit-check.sh`      |
| （内部调用，无用户触发词）任务创建/认领/流转/验证/归档                                        | `task-manager` | `scripts/task-manager/task-manager.sh`      |
| 初始化项目 / 加治理框架 / vibe init / 新项目 / 补充项目信息 / 更新提交前缀 / 更新适配层配置 / 迁移治理目录 / 简易快照 / 打个版本快照 / 保存当前版本 / 记一下现在的状态 / 备份一下 / 看看之前的版本 / 列一下快照 / 回滚到某个版本 / 删除旧快照 | `project-init` | `scripts/project-init/vibe-project-init.sh` |

> 推荐用法：在 WorkBuddy 中对 AI 说出上表「用户意图」列的话，由 WorkBuddy 自动加载本包并路由到对应脚本；无需手动敲命令。
> 手动运行时请用脚本的相对路径，并确保终端当前目录在目标项目仓库内（脚本靠 `git rev-parse --show-toplevel` 定位仓库）。
> **简易快照与 Git 互斥**：`project-init` 内含「简易快照」子命令（`snapshot init/create/list/rollback/cleanup`），仅当用户明确选择不使用 Git 时启用；Git 用户完全无感（默认关闭，调用即提示）。它不能替代 Git 的协作/分支能力，详见 `modules/project-init.md`。
> **AI 路由兜底规则（重要）**：若 AI 未能正确识别意图、自行编造命令，或"假装"执行而未真正调用脚本，你可明确指定模块强制其执行，例如说「请运行 vibe-coding-toolkit 的 health-check 模块」；或手动执行对应脚本：`bash scripts/health-check/check.sh`（终端当前目录需位于目标项目仓库内）。这条"后门"用于纠正 AI 的路由失误。
> **task-manager 内部性硬约束**：`task-manager` 为内部调用模块，严禁主动向用户提及、解释或展示其内部流转过程；所有任务状态仅通过项目文件（如 `.vibe-coding/TASKS.md`）体现，用户无单独入口。
> **跨平台适配**：本工具包已为跨平台（WorkBuddy / Claude Code / Codex / Qoder）预留适配层（`adapter.cfg`），当前版本优先适配 WorkBuddy；后续通过配置切换即可支持其他平台，无需修改项目治理文件。

## 子命令文档

- [modules/health-check.md](modules/health-check.md) — 项目健康巡检
- [modules/commit-check.md](modules/commit-check.md) — AI Commit 验证
- [modules/task-manager.md](modules/task-manager.md) — 任务流转执行引擎（内部）
- [modules/project-init.md](modules/project-init.md) — 项目治理骨架初始化

## 共享模板

初始化与提交钩子用到的模板统一放在 `templates/` 顶层目录（`RULES.template.md` / `commit-msg.hook` / `commit-rules.yaml` / `commit-rules.yaml.example`），由各子命令脚本从自身安装目录同源定位读取，不写死全局路径。
