# commit-check AI Commit 验证（子命令）

> 脚本：`scripts/commit-check/commit-check.sh`
> 在任意 git 仓库内运行，脚本自动检测并 `cd` 到仓库根目录。

## 用途

AI 开发窗口声称"已提交"后，用确定性脚本验证三件事：

1. **真实性**：commit 是否真实存在于本地仓库（且工作区干净）。
2. **合规性**：commit message 前缀是否符合项目规定。
3. **归属**：commit 是否属于当前项目（防止套用别的仓库的 hash）。

**注意**：本子命令仅验证 commit 本身的属性，不涉及代码内容审查或业务逻辑校验。

## 前缀校验说明

**规则来源（关键）**：本子命令**不硬编码任何项目特定前缀**。允许哪些提交前缀，完全由被检查项目根目录下的 `commit-rules.yaml` 决定。查找顺序（三级回落）：① `.vibe-coding/adapter.cfg` 的 `COMMIT_RULES`（自定义路径）；② `.vibe-coding/commit-rules.yaml`；③ `.workbuddy/commit-rules.yaml`（兼容未迁移旧项目）。该文件由 `project-init` 在初始化项目时生成，也可手动创建。

配置文件字段：

- `prefix_check: true|false` —— 是否启用前缀校验。
- `prefixes: [...]` —— 允许的前缀列表（不含方括号），如 `[FEAT]/[FIX]/[DOCS]`。

**行为约定**：

- 有配置文件且 `prefix_check: true`：校验最新一次提交的 message 是否以 `prefixes` 中的某个 `[XXX]` 开头，否则判不合规。
- 无配置文件 / `prefix_check: false` / `prefixes` 为空：前缀校验**自动跳过**，仅提示（⏭️），**不阻塞**提交。
- 配置文件格式错误：脚本做容错解析，不会崩溃；遇到无法读取的情况按"跳过"处理并提示。
- **只校验最新一次已提交（HEAD）**，历史 commit 完全豁免。

**自定义方式**：编辑项目根 `commit-rules.yaml` 的 `prefixes` 列表即可，无需改动本子命令代码。参考模板见 `templates/commit-rules.yaml.example`。

## 命令

### 全量检查

```bash
bash scripts/commit-check/commit-check.sh
```

检查全部三项（真实性 + 前缀 + 归属），输出总结。

### 单项检查

```bash
bash scripts/commit-check/commit-check.sh -s   # 仅检查工作区干净 + commit 存在（真实性）
bash scripts/commit-check/commit-check.sh -m   # 仅检查 commit message 前缀（合规性）
bash scripts/commit-check/commit-check.sh -o   # 仅检查 commit 是否属于当前项目（归属）
```

> 推荐用法：在 WorkBuddy 中对 AI 说"检查 commit" / "验证提交"，由 WorkBuddy 自动加载并执行。手动运行请确保终端当前目录在目标项目仓库内。

## 触发场景

| 用户说                  | 系统执行                                             |
| -------------------- | ------------------------------------------------ |
| "检查 commit" / "验证提交" | 全量检查 `bash scripts/commit-check/commit-check.sh` |
| "检查提交前缀"             | `.../commit-check.sh -m`                         |
| "是否属于当前项目" / "检查归属"  | `.../commit-check.sh -o`                         |
| "工作区是否干净"            | `.../commit-check.sh -s`                         |

## 输出格式

全部通过时：

```
[✅ 通过] commit-check

结果：
✅ commit 真实性: 通过 (xxxxxxx)
✅ commit 前缀:   通过 ([PC])
✅ commit 归属:   通过 (属于当前项目)
```

不通过时输出具体问题清单与修复指引（请将结果复制给对应 AI 窗口修复后再次运行）。

## 铁律对齐

1. **每次 commit 后必须自查**：各窗口提交前运行此脚本（由 `task-manager` 在标记任务完成时自动触发）。
2. **不猜测结果**：脚本输出什么就是什么，真实状态优先于 AI 声称。
3. **脏工作区不等于 commit 不存在**：可能只是有未提交的文档改动，需区分对待。
4. **历史 commit 前缀不合规不阻塞**：只校验最新一次已提交（HEAD）。
5. **职责分离**：不负责代码内容审查或业务逻辑验证。

## 版本

- 当前版本：**v1.0.0**（随 vibe-coding-toolkit 单包统一版本）
- 此前独立发布的 v1.1.0 已并入本包；前缀规则三级回落逻辑保持不变。
