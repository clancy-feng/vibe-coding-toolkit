# health-check 项目体检

> 脚本：`scripts/health-check/check.sh`
> 在任意 git 仓库内运行，脚本自动检测并 `cd` 到仓库根目录。治理记忆文件优先读 `.vibe-coding/memory/`，旧项目回落 `.workbuddy/memory/`。
> 是 VPG 框架的巡检组件，与 `project-init` / `commit-check` / `task-manager` 并列，同属 `vibe-coding-toolkit`。

## health-check模块铁律

- 必须如实向用户披露所有发现与安全声明。
- 核心定位不可动摇：本子命令是体检医生，不是修理工；只诊断不修理。
- 必须保持只读：仅写入审计日志与计数文件，绝不修改任何业务或治理文件；所有修复须经 task-manager 新开任务执行。
- 写入必须限定在项目目录内，运行前明确提示用户写入范围。
- 运行环境必须为离线本地：不发起任何网络请求，不读取环境变量作为行为输入，不向外部发送项目数据。
- 版本核对须从脚本自身安装目录同源推导 umbrella 根。
- 连续未清除计数仅用于透明提示，P1 超时/未清除后仍报 P1。
- 分级响应须严格执行，等级由脚本判定，AI 无升降级裁量权。
- 巡检判定须基于可核验的磁盘文件，真实状态优先于任何声称。

## 安全声明

- 离线本地运行：本工具在用户机器内完成全部检查，不发起网络请求、不读取环境变量作为输入、不向外部发送项目数据。
- 写入范围：运行前会明确提示用户写入范围：
  - `.vibe-coding/memory/HEALTH_AUDIT.md` 用于审计留痕，记录每次巡检结果、人类选择与修复任务 ID；若项目仅有旧版 `.workbuddy/memory/`，自动回落该路径。
  - `.vibe-coding/memory/.health_state` 记录连续未清除计数，仅作透明提示，不改变本次判定等级；仅旧项目回落 `.workbuddy/memory/`。
- 仅在被体检项目目录内读写文件。
- 核对自身版本时，仅读取工具自身安装目录下的 `skill.json`（从脚本自身路径推导位置）。

## 核心定位

你是项目体检医生，不是修理工。

1. 只诊断、不修理：本子命令会写入上述审计日志与计数文件，但绝不修改任何业务/治理文件，包括 `TASKS-*.md`、`CONTRACT.md`、`CROSS_IMPACT_LOG.md`、`SKILL_REGISTRY.md` 等。
2. 唯一职责：扫描隐患 → 用非技术语言报告 → 提供选项 → 等待人类授权。
3. 所有修复动作必须通过调用 `task-manager` 新开任务执行，绝不允许直接改磁盘业务/治理文件。

> 重建边界：本子命令仅检测治理骨架丢失（P0）。若需重建骨架，请调用 `project-init` 的重建模式，本子命令不负责生成治理文件。

## 触发条件

| #   | 触发方式 | 说明                                                      |
| --- | ---- | ------------------------------------------------------- |
| 1   | 主动体检 | 人类说"给项目做个体检 / 项目体检 / 健康巡检" → 立即运行 `check.sh`            |
| 2   | 后置巡检 | task-manager 将任务标记为 `✅ 已完成` 后自动触发；MVP 阶段暂不接入自动触发，留 TODO |
| 3   | 定时巡检 | 人类明确授权开启后，每日固定时间触发，默认关闭                                 |

> 注：触发词已收紧为上述唯一明确的三种短语，以免误触发产生非预期写入。

## 巡检项

### 巡检项 1 — 任务状态一致性，以防假提交

- 扫描所有 `TASKS-*.md` 中标记 `✅ 已完成` 的任务，提取同任务块内的 `commit: <id>`。
- 对每个 commit_id 执行 `git log <commit_id>`；若不存在 → 判定 P1 假成功。

### 巡检项 2 — 契约完整性，分两步

- 第一步存在性检查：`CONTRACT.md` 或 `CROSS_IMPACT_LOG.md` 任一缺失 → 判定 P0 框架失效。
- 第二步超时检查：扫描 `CROSS_IMPACT_LOG.md` 的 `## 待裁决` 段下 `### [日期]` 条目，超 24 小时未更新 → 判定 P1。

### 巡检项 3 — 治理工具版本一致性

- 新逻辑依据用户 2026-08-08 决策：vibe-coding-toolkit 为单包，4 子命令共享 1 个版本号，故本项仅比对：
  - 项目登记表 `SKILL_REGISTRY.md` 登记的 `vibe-coding-toolkit` 版本，向前兼容旧多 skill 登记表时取首个有效版本；
  - 已安装的 umbrella `skill.json` 版本由脚本自身路径同源推导。
- 不一致 → 判定 P2，提示统一版本号。项目无登记表属正常，仅提示已装版本，不报 P2。

### 巡检项 4 — 跨模块改文件

- 扫描最近 50 条 commit，提取提交者并映射 AI 角色，同时提取修改文件前缀：`ai-pc`→`pc/`；`ai-android`→`android/`；`ai-cloud`→`cloud/`；非 AI 提交跳过。
- AI 角色归属模块与修改文件前缀不匹配，且 `CROSS_IMPACT_LOG.md` 的 `## 待裁决` 段下无对应日期登记项 → 判定 P1：越权修改非所属模块文件。规则焊死，AI 只读，无裁量权。

### 巡检项 5 — 审计日志大小

- `.vibe-coding/memory/HEALTH_AUDIT.md` 超过 10MB → 判定 P2，建议归档；仅旧项目回落 `.workbuddy/memory/`。

### 巡检项 6 — TASKS 格式合规性

- 扫所有 `TASKS-*.md`，每处 `状态: <取值>` 必须以合法状态 token 开头：`📋 待处理` / `🔄 处理中` / `✅ 已完成` / `⏸ 暂挂` / `✅ coordinator确认`。不在集合内则判 P2。

### 连续未清除计数

- `.health_state` 记录连续出现 P0/P1 的次数；仅用于透明提示「同一问题反复出现」。
- 不自动升级严重度：P1 保持 P1，绝不因隐藏历史计数把 P1 改成 P0，以免隐藏历史篡改当前仓库结论。第 4 次体检仍老老实实说"之前 N 次也发现了同一 P1，现在还在"。

## 分级响应机制

| 等级     | 定义                              | 对人类说的话                                                                                 |
| ------ | ------------------------------- | -------------------------------------------------------------------------------------- |
| P0 致命级 | 框架失效，如 CONTRACT.md 丢失或 git 仓库损坏 | "发现致命问题（P0）：[描述]。任务流转已锁定，属声明式。必须立即新开紧急修复任务，通常需调用 project-init 重建骨架。唯一选项：1. 同意新开紧急修复任务" |
| P1 一般级 | 合规隐患，如假成功或 Pending 超时           | "发现合规问题（P1）：[描述]。请选择处置方式：1. 立即新开修复任务　2. 稍后修复，24 小时内必须处理"                               |
| P2 轻微级 | 规范偏差，如工具版本不一致                   | "发现轻微偏差：[描述]。给你两个选项：1. 新开任务对齐　2. 忽略，此为默认选项"                                            |

> P0 定义已移除"连续 3 次 P1 未处理"字样，自动升级逻辑已取消；兜底触发条件中的"下次巡检直接升 P0"亦已移除——P1 超时后下次仍报 P1 并再次提示。

## 命令

### 全量体检

```bash
bash scripts/health-check/check.sh
```

输出分级结果并追加写入 `HEALTH_AUDIT.md`。

### 单项巡检

```bash
bash scripts/health-check/check.sh --only tasks     # 仅巡检项1
bash scripts/health-check/check.sh --only contract  # 仅巡检项2
bash scripts/health-check/check.sh --only skills    # 仅巡检项3 版本一致性
bash scripts/health-check/check.sh --only cross     # 仅巡检项4
bash scripts/health-check/check.sh --only log       # 仅巡检项5
bash scripts/health-check/check.sh --only fmt       # 仅巡检项6
```

### 错误判断识别：判定用户对某级别问题的选择是否违规

```bash
bash scripts/health-check/check.sh --respond P0 "暂不处理"   # → 输出第一次警告话术
bash scripts/health-check/check.sh --respond P1 "稍后修复"   # → 提示 24h 时限并追问
bash scripts/health-check/check.sh --respond P2 "忽略"       # → 放行（默认）
```

## 铁律对齐

1. 只诊断不修理：不改任何业务/治理文件，修复一律经 task-manager 新开任务。
2. 不猜测结果：脚本判定什么等级就是什么，AI 无升降级裁量权。
3. 文件为唯一真相：隐患结论指向可核验磁盘文件。
4. POSIX 兼容：`check.sh` 与 task-manager 一致，禁用 GNU AWK 三参数 match / PCRE lookbehind。
5. 同源路径：版本核对从脚本自身安装目录推导 umbrella 根。

### 版本

- 当前版本：v1.2.0
