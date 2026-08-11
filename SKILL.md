---
name: "vibe-coding-toolkit"
title: "Vibe Coding Toolkit"
slug: "vibe-coding-toolkit"
displayName: "Vibe Coding Toolkit"
summary: "全网首发，VPG治理体系skill"
version: "1.0.0"
tags: ["AI项目治理", "开发效率", "项目管理", "版本控制"]
description: "Vibe Coding Toolkit — 面向非技术用户的 AI 项目治理工具包（单包，含 4 个子命令：health-check / commit-check / task-manager / project-init）。零网络访问、零环境变量读取、零数据外传；所有写入仅限当前项目目录内。当用户需要给项目做体检/健康巡检、验证 AI 提交是否真实合规、用自然语言管理任务流转、初始化项目治理骨架，或为不使用 Git 的项目做简易版本快照时，加载本技能并按 SKILL.md「子命令路由表」执行对应脚本。"
license: MIT
priority: 90
metadata:
  author: clancy-feng
  version: 1.0.0
compatibility: "运行环境需 Bash（Windows 建议用 Git Bash）；health-check/commit-check 需在 git 仓库内运行；零网络依赖。"
---

# Vibe Coding Toolkit

> 下面「这是什么 / 四个模块 / 简易快照」是给**使用者**看的人话简介；AI 操作指令在文末「子命令路由表」及之后的约束里，普通用户无需细看，直接对 AI 说需求即可。完整文档与作者信息见仓库 README：https://github.com/clancy-feng/vibe-coding-toolkit

## 技能简介

全网首发——Vibe Coding Toolkit 是「Vibe Project Governance（VPG）」AI 开发项目治理体系的第一个落地产物。

当你用 AI 开发平台（WorkBuddy、Codex、Cursor、Claude Code 等）写代码、做项目时，常会遇到几类问题：

- AI 说"我做完了、已经提交了"，但你一查根本没提交（**假交付**）。
- 项目越来越大，谁改了哪块、为什么改，说不清楚（**责任不清**）。
- 想从零规范一个项目，却不知道治理骨架怎么搭（**无从下手**）。
- 项目跑了一阵，悄悄积累隐患，出事才发现，想修无从下手（**项目烂尾**）。

本工具就是针对这些问题的"项目工程治理体系"，围绕两个核心概念展开：它用四个模块为你搭起一套工程管理体系，而这套控制的运行方式正是治理框架主张的"人审 AI 制"——人掌控方向和规则，AI 负责执行；AI 不能偷偷做主，重要的事必须由人确认。

## 四个模块

| 子命令            | 功能   | 一句话定位          | 主要干什么                                      |
| -------------- | ---- | -------------- | ------------------------------------------ |
| `health-check` | 项目体检 | 查违规的"巡检员"      | 定期给项目做体检，只报告问题、不改东西，发现隐患第一时间告诉你            |
| `commit-check` | 交付质检 | 卡交付的"质检员"      | AI 每次提交代码后，自动核查：提交是真的吗？信息写对了吗？             |
| `task-manager` | 任务调度 | 管 AI 干活的"任务中心" | 所有 AI 的活都经它派发和记录，干完经你审查才算数（后台自动运行，你没有单独入口） |
| `project-init` | 框架生成 | 定规矩的"奠基者"      | 帮你的项目搭好治理骨架（模块划分、角色护栏、提交规则），骨架丢了还能重建       |

> `task-manager` 是内部引擎，由 AI 在你使用其他功能时自动调用，你不需要手动触发。

## 四个模块怎么配合

1. **`project-init` 搭骨架**：新项目第一次用，或老项目骨架丢了，用它建立治理框架基础（一次性）。
2. **你让 AI 干活**：在对话框描述需求，`task-manager` 自动记任务、给编号。
3. **AI 干完要提交**：`commit-check` 自动验证"提交是否真实、信息是否合规"。
4. **你定期说"给项目做个体检"**：`health-check` 扫描隐患，分级报给你。

四个模块形成闭环：项目由 `project-init` 建立 → 任务经 `task-manager` 派发 → 提交经 `commit-check` 卡关 → 违规经 `health-check` 查出。所有操作都写成文件留痕，随时可查。

## 简易快照（无 Git 用户的后悔药）

不懂 Git？照样能"存版本、改坏了一键回退"。这是给**不使用 Git 的用户**准备的土法版本管理平替——全量备份 + 一键回滚，越简单越好。

- **和 Git 互斥**：只有初始化项目时明确说"不用 Git"，才会启用；用 Git 的用户完全无感。
- **怎么用（直接对 AI 说）**："打个版本快照""看看之前的版本""回滚到上个版本""删除旧快照"。
- **几条实话**：只备份你指定的业务目录，**绝不**碰 `.git/`、`.workbuddy/`、`.vibe-coding/`；每次打/回滚/删快照都**必须你点头**；它**不能替代 Git**（没有协作、没有分支），适合单用户小项目"防手滑"。

## 安全声明

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

| 用户意图（触发词）                                                                                                                                           | 子命令            | 执行脚本                                        |
| --------------------------------------------------------------------------------------------------------------------------------------------------- | -------------- | ------------------------------------------- |
| 给项目做个体检 / 项目体检 / 健康巡检                                                                                                                               | `health-check` | `scripts/health-check/check.sh`             |
| 检查 commit / 验证提交 / 检查提交前缀 / 检查归属 / 工作区是否干净                                                                                                          | `commit-check` | `scripts/commit-check/commit-check.sh`      |
| （内部调用，无用户触发词）任务创建/认领/流转/验证/归档                                                                                                                       | `task-manager` | `scripts/task-manager/task-manager.sh`      |
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

初始化与提交钩子用到的模板统一放在 `templates/` 顶层目录（`RULES.template.md` / `commit-msg.sh` / `commit-rules.yaml` / `commit-rules.example.yaml`），由各子命令脚本从自身安装目录同源定位读取，不写死全局路径。
