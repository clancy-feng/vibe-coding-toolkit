# Vibe Coding Toolkit — AI 项目治理工具集

四个 WorkBuddy Skill，把「AI 帮你写代码」的过程管起来：**项目初始化、角色功能纪律定义、GIT仓库推送验证、任务流转规范化、项目体检**。你定规则，AI 按规则执行，关键节点由你拍板。

---

## 包含的四个 Skill

| Skill               | 角色   | 一句话定位           | 核心职责                                                         |
| ------------------- | ---- | --------------- | ------------------------------------------------------------ |
| `vibe-project-init` | 初始化  | 定规矩的“骨架生成器”     | 搭建项目治理骨架（模块划分、角色护栏、提交前缀铁律、契约模板），所有其他 Skill 按它定的规则办事；骨架丢失时可重建 |
| `task-manager`      | 任务流转 | 管 AI 干活的“任务调度员” | 所有 AI 的活必须经过它派发，干完必须经过你审查才算完成，任务状态和进度可跟踪可检查（后台自动调用，无用户操作入口）  |
| `commit-check`      | 提交质检 | 卡交付的“最后一道关”     | AI 提交代码时自动查：提交记录是否真实存在？提交信息是否带对模块前缀？杜绝交“假作业”                 |
| `health-check`      | 合规巡检 | 查违规的“体检医生”      | 定期给项目做体检，查 AI 是否按规矩办事、治理骨架是否损坏，只诊断不修理，出问题第一时间报给你             |

---

## 它们怎么配合

1. `vibe-project-init` 搭好治理骨架（一次性，或骨架丢失时重建）。
2. 你要 AI 干活 → 对话框里描述需求，`task-manager` 派任务、给任务 ID。
3. AI 干完要提交 → `commit-check` 自动验证提交真实性 + 模块前缀合规。
4. 你定期说“给项目做个体检” → `health-check` 扫描隐患并分级报告。

四个 Skill 形成闭环：项目由project-init建立、任务经 task-manager 派发、提交经 commit-check 卡关、违规经 health-check 查出，所有操作落盘可追溯。

---

## 安装

**方式 A：在 WorkBuddy 推荐市场 / ClawHub / SkillHub 搜索对应 Skill 名，一键安装到 `~/.workbuddy/skills/<name>/`。

**方式 B（源码安装）**：

```bash
git clone https://gitee.com/beclancy/vibe-coding-toolkit.git
# 把需要的 skill 复制到用户级 skills 目录
cp -r vibe-coding-toolkit/skills/commit-check     ~/.workbuddy/skills/
cp -r vibe-coding-toolkit/skills/health-check     ~/.workbuddy/skills/
cp -r vibe-coding-toolkit/skills/task-manager     ~/.workbuddy/skills/
cp -r vibe-coding-toolkit/skills/vibe-project-init ~/.workbuddy/skills/
```

WorkBuddy 启动时会自动加载 `~/.workbuddy/skills/` 下所有含 `SKILL.md` 的目录。

---

## 目录结构

```
vibe-coding-toolkit/
├── README.md                # 本文档
├── skills/
│   ├── commit-check/        # 提交质检
│   ├── health-check/        # 合规巡检
│   ├── task-manager/        # 任务流转引擎（后台）
│   └── vibe-project-init/   # 治理骨架初始化
└── toolkit/                 # 聚合入口占位（规划中）
```

---

## 许可

MIT
