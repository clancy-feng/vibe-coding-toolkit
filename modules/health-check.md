# health-check 项目体检（子命令）

> 脚本：`scripts/health-check/check.sh`
> 在项目根目录（含 `.git`）下运行，脚本自动检测仓库路径与治理根目录（优先 `.vibe-coding/memory/`，仅旧项目回落 `.workbuddy/memory/`）。
> 是 Vibe 治理框架的巡检组件，与 `project-init` / `commit-check` / `task-manager` 并列（同属 `vibe-coding-toolkit` 单包）。

## 安全声明（如实披露）

- **零网络访问、零环境变量读取、零数据外传。**
- **写入范围（仅项目内，运行前会明确提示）**：
  - `.vibe-coding/memory/HEALTH_AUDIT.md`（审计留痕，记录每次巡检结果、人类选择、修复任务 ID）；若项目仅有旧版 `.workbuddy/memory/`，自动回落该路径。
  - `.vibe-coding/memory/.health_state`（连续未清除计数，仅作透明提示，不改变本次判定等级）；仅旧项目回落 `.workbuddy/memory/`。
- 不读取、不写入项目目录之外的任何文件；版本核对仅基于自身安装目录的 `skill.json`（同源定位，不写死 `~/.workbuddy/skills` 全局路径）。

## 核心定位（不可动摇）

**你是项目体检医生，不是修理工。**

1. **只诊断、不修理**：本子命令会写入上述审计日志与计数文件，但绝不修改任何业务/治理文件（`TASKS-*.md` / `CONTRACT.md` / `CROSS_IMPACT_LOG.md` / `SKILL_REGISTRY.md` 等）。
2. **唯一职责**：扫描隐患 → 用非技术语言报告 → 提供选项 → 等待人类授权。
3. **所有修复动作必须通过调用 `task-manager` 新开任务执行**，绝不允许直接改磁盘业务/治理文件。

> **重建边界**：本子命令仅检测治理骨架丢失（P0）。若需重建骨架，请调用 `project-init` 的重建模式，本子命令不负责生成治理文件。

## 触发条件（仅限以下三种明确短语）

| # | 触发方式 | 说明 |
| --- | --- | --- |
| 1 | **主动体检** | 人类说"给项目做个体检 / 项目体检 / 健康巡检" → 立即运行 `check.sh` |
| 2 | **后置巡检** | task-manager 将任务标记为 `✅ 已完成` 后自动触发（MVP 不接自动触发，留 TODO） |
| 3 | **定时巡检** | 人类明确授权开启后，每日固定时间触发（**默认关闭**） |

> 注：触发词已收紧为上述唯一明确的三种短语，避免误触发产生非预期写入。

## 巡检项（六项）

### 巡检项 1 — 任务状态一致性（防假成功）
- 扫描所有 `TASKS-*.md` 中标记 `✅ 已完成` 的任务，提取同任务块内的 `**commit**: <id>`。
- 对每个 commit_id 执行 `git log <commit_id>`；若不存在 → 判定 **P1**（假成功）。

### 巡检项 2 — 契约完整性（两步）
- **第一步（存在性）**：`CONTRACT.md` 或 `CROSS_IMPACT_LOG.md` 任一缺失 → 判定 **P0**（框架失效）。
- **第二步（超时）**：扫描 `CROSS_IMPACT_LOG.md` 的 `## 待裁决` 段下 `### [日期]` 条目，超 24 小时未更新 → 判定 **P1**。

### 巡检项 3 — 治理工具版本一致性（单包模型）
- **新逻辑（用户 2026-08-08 决策）**：vibe-coding-toolkit 为单包（4 子命令共享 1 个版本号），故本项仅比对：
  - 项目登记表 `SKILL_REGISTRY.md` 登记的 `vibe-coding-toolkit` 版本（向前兼容旧多 skill 登记表：取首个有效版本）；
  - 已安装的 umbrella `skill.json` 版本（由脚本自身路径同源推导，不读全局 `~/.workbuddy/skills`）。
- 不一致 → 判定 **P2**（提示统一版本号）。项目无登记表属正常，仅提示已装版本，不报 P2。

### 巡检项 4 — 跨模块改文件（P1，AI 行为合规，无 AI 裁量）
- 扫描最近 50 条 commit，提取提交者（映射 AI 角色）与修改文件前缀：`ai-pc`→`pc/`；`ai-android`→`android/`；`ai-cloud`→`cloud/`；非 AI 提交跳过。
- AI 角色归属模块与修改文件前缀不匹配，且 `CROSS_IMPACT_LOG.md` 的 `## 待裁决` 段下无对应日期登记项 → 判定 **P1**（越权改非所属模块文件）。规则焊死，AI 只读。

### 巡检项 5 — 审计日志大小（P2，整洁类）
- `.vibe-coding/memory/HEALTH_AUDIT.md`（仅旧项目回落 `.workbuddy/memory/`）超过 10MB → 判定 **P2**（建议归档）。

### 巡检项 6 — TASKS 格式合规性（P2，纯规则）
- 扫所有 `TASKS-*.md`，每处 `**状态**: <取值>` 必须以合法状态 token 开头：`📋 待处理` / `🔄 处理中` / `✅ 已完成` / `⏸ 暂挂` / `✅ coordinator确认`。不在集合内 → **P2**。

### 连续未清除计数（仅透明提示，不自动升级）
- `.health_state` 记录连续出现 P0/P1 的次数；**仅用于透明提示「同一问题反复出现」**。
- **不自动升级严重度**：P1 保持 P1，绝不因隐藏历史计数把 P1 改成 P0（避免隐藏历史篡改当前仓库结论）。第 4 次体检仍老老实实说"之前 N 次也发现了同一 P1，现在还在"。

## 分级响应机制（严格执行，无 AI 裁量权）

| 等级 | 定义 | 对人类说的话 |
| --- | --- | --- |
| **P0 致命级** | 框架失效（如 CONTRACT.md 丢失、git 仓库损坏） | "发现致命问题（P0）：[描述]。任务流转已锁定（声明式）。必须立即新开紧急修复任务（通常需调用 project-init 重建骨架）。唯一选项：1. 同意新开紧急修复任务" |
| **P1 一般级** | 合规隐患（如假成功、Pending 超时） | "发现合规问题（P1）：[描述]。请选择处置方式：1. 立即新开修复任务　2. 稍后修复（24小时内必须处理）" |
| **P2 轻微级** | 规范偏差（如工具版本不一致） | "发现轻微偏差：[描述]。给你两个选项：1. 新开任务对齐　2. 忽略（默认）" |

> P0 定义已移除"连续 3 次 P1 未处理"字样（因不再自动升级）。兜底触发条件中的"下次巡检直接升 P0"亦已移除——P1 超时后下次仍报 P1 并再次提示。

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

### 错误判断识别（判定用户对某级别问题的选择是否违规）
```bash
bash scripts/health-check/check.sh --respond P0 "暂不处理"   # → 输出第一次警告话术
bash scripts/health-check/check.sh --respond P1 "稍后修复"   # → 提示 24h 时限并追问
bash scripts/health-check/check.sh --respond P2 "忽略"       # → 放行（默认）
```

## 铁律对齐
1. **只诊断不修理**：不改任何业务/治理文件，修复一律经 task-manager 新开任务。
2. **不猜测结果**：脚本判定什么等级就是什么，AI 无升降级裁量权。
3. **文件为唯一真相**：隐患结论指向可核验磁盘文件。
4. **POSIX 兼容**：`check.sh` 与 task-manager 一致，禁用 GNU AWK 三参数 match / PCRE lookbehind。
5. **同源路径**：版本核对从脚本自身安装目录推导 umbrella 根，不写死 `~/.workbuddy/skills` 全局路径。
