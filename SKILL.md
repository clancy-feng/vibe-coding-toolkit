---
name: "vibe-coding-toolkit"
title: "Vibe Coding Toolkit"
slug: "vibe-coding-toolkit"
displayName: "Vibe Coding Toolkit"
summary: "全网首发，VPG治理体系skill"
version: "1.2.0"
tags: ["AI项目治理", "开发效率", "项目管理", "版本控制"]
description: "Vibe Coding Toolkit — AI开发项目治理工具包（单包，含4个模块：health-check / commit-check / task-manager / project-init）。零网络访问、零数据外传；仅读取平台注入的工作区变量与家目录用于平台探测；所有写入仅限当前项目目录内。当用户需要给项目做体检/健康巡检、验证 AI 提交是否真实合规、用自然语言管理任务流转、初始化项目治理骨架（自动建本地 git 库并管理版本，不需要账号，用户零操作）时，加载本技能并按 SKILL.md「子命令路由表」执行对应脚本。"
license: MIT
priority: 90
metadata:
  author: clancy-feng
  version: 1.2.0
compatibility: "运行环境需 Bash（Windows 建议用 Git Bash）；health-check/commit-check 需在 git 仓库内运行；零网络依赖。"
---

# Vibe Coding Toolkit

> 下面「技能简介 / 四个模块 / 版本管理」是给使用者看的技能简介；AI 操作指令在文末「子命令路由表」及之后的约束里。完整文档与作者信息见仓库 README：https://github.com/clancy-feng/vibe-coding-toolkit

## 技能简介

全网首发——Vibe Coding Toolkit 是「Vibe Project Governance（VPG）」AI 开发项目治理体系的第一个落地产物。

当你用 AI 开发平台（WorkBuddy、Codex、Cursor、Claude Code 等）写代码、做项目时，常会遇到几类问题：

- AI 说"我做完了、已经提交了"，但你一查根本没提交（假交付）。
- 项目越来越大，谁改了哪块、为什么改，说不清楚（责任不清）。
- 想从零规范一个项目，却不知道治理骨架怎么搭（无从下手）。
- 项目跑了一阵，悄悄积累隐患，出事才发现，想修无从下手（项目烂尾）。

本工具就是针对这些问题的"项目工程治理体系"，围绕两个核心概念展开：它用四个模块为你搭起一套管理体系，而这套控制的运行方式正是治理框架主张的"人审 AI 制"——人掌控方向和规则，AI 负责执行；AI不能全部做主，重要的事必须由人确认。

## 四个模块

| 子命令            | 功能   | 一句话定位          | 主要干什么                             |
| -------------- | ---- | -------------- | --------------------------------- |
| `health-check` | 项目体检 | 查违规的"巡检员"      | 定期给项目做体检，只报告问题、不改东西，发现问题汇报        |
| `commit-check` | 交付质检 | 卡交付的"质检员"      | AI 每次提交代码后，自动核查：提交是真的吗？信息写对了吗？    |
| `task-manager` | 任务调度 | 管 AI 干活的"任务中心" | 所有 AI 的开发任务都经它派发和记录，干完符合标准再继续     |
| `project-init` | 框架生成 | 定规矩的"奠基者"      | 给项目搭好治理骨架（模块划分、角色护栏、提交规则），可接入已有项目 |

## 工作方式

1. `project-init` 搭骨架：新项目第一次用，或老项目用它建立治理框架基础。
2. 你让 AI 干活：在对话框描述需求，`task-manager` 自动记任务、给编号。
3. AI 干完要提交：`commit-check` 自动验证"提交是否真实、信息是否合规"。
4. 你定期说"给项目做个体检"：`health-check` 扫描隐患，分级报给你。

四个模块形成闭环：项目由 `project-init` 建立 → 任务经 `task-manager` 派发 → 提交经 `commit-check` 卡关 → 违规经 `health-check` 查出。所有操作都写成文件留痕，随时可查。

## 版本管理

项目自带本地Git代码管理，所有项目用本地 git 库，由 task-manager 在任务完成时自动保存版本，随时能回退。

- 用法：初始化时自动 git init；每个任务完成时自动提交一个版本（消息 `[模块] 任务ID: 标题`）；需要时直接说"回滚到改 X 之前"，AI 列出历史版本供选择，选中后用该版本的文件覆盖工作区完成还原。提交历史始终保留，还原后随时可再回到任何版本，不删除任何提交。
- 说明：git 完全本地运行；首次提交缺身份时自动用项目本地身份兜底；用户不接触任何 git 命令。

## 子命令路由表

| 触发词                                                                                                                                                                                                  | 子命令            | 执行脚本                                        |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------- | ------------------------------------------- |
| 给项目做个体检 / 项目体检 / 健康巡检                                                                                                                                                                                | `health-check` | `scripts/health-check/check.sh`             |
| 检查 commit / 验证提交 / 检查提交（全面检查：commit 真实性、工作区是否干净、前缀合规、是否归属当前项目）                                                                                                                                       | `commit-check` | `scripts/commit-check/commit-check.sh`      |
| （无）                                                                                                                                                                                                  | `task-manager` | `scripts/task-manager/task-manager.sh`      |
| 初始化项目 / 新建项目 / 新建vibe coding项目 / 新建AI开发项目 / 搭建一个项目 / 开个新项目 / init vibe coding project / 帮我用这套治理体系管现有项目 / 给现有项目接入治理 / 更新提交前缀 / 修改 commit 前缀规则 / 更新项目信息 / 修改项目配置 / 迁移治理目录 / 回滚到改X之前 / 恢复到某个版本 / 列出历史版本 | `project-init` | `scripts/project-init/vibe-project-init.sh` |

> 手动运行时请用脚本的相对路径，并确保终端当前目录在目标项目仓库内（脚本靠 `git rev-parse --show-toplevel` 定位仓库）。

## project-init 交互约定

新建项目的完整流程见 modules/project-init.md「新建模式交互流程」：

1. `bash scripts/project-init/vibe-project-init.sh ask --list` 拿 Q1-Q5 模板，逐轮照模板执行。
2. 字段收集齐写入 `collected.cfg` 后运行 `ask --validate` 确认通过，再调用 `batch` 生成。
3. 适配模式（"帮我用这套治理体系管现有项目"）按 modules/project-init.md「适配模式」执行：只读扫描 → 生成草稿 → AI 显式 `apply` 才写入正式治理目录。

脚本侧无任何交互向导（batch 模式），所有字段由 AI 按模板收集后写入 `collected.cfg`，再调用 `batch` 生成（batch 内置 `ask_validate` 强制校验）。

## 子命令文档

- [modules/health-check.md](modules/health-check.md) — 项目健康巡检
- [modules/commit-check.md](modules/commit-check.md) — AI Commit 验证
- [modules/task-manager.md](modules/task-manager.md) — 任务流转执行引擎
- [modules/project-init.md](modules/project-init.md) — 项目治理骨架初始化

## 共享模板

初始化与提交钩子用到的模板统一放在 `templates/` 顶层目录（`RULES.template.md` / `commit-msg.sh` / `commit-rules.yaml` / `commit-rules.example.yaml`），由各子命令脚本从自身安装目录同源定位读取。
