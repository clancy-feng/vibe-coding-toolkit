# Changelog

> English version at the bottom / 英文版见文件底部。

## [1.2.0] - 2026-08-26

- 版本管理统一本地 git，取消简易快照。
- 配置文件合并以adapter.cfg为唯一配置源。
- 模块代号英文化：模块标识符全部使用 PC、APP、CLOUD、WEB、SERVER 等英文代号，中文仅作展示说明。
- 强化运行日志功能。
- 项目初始交互流程脚本化，新增 ask 子命令。
- 其他文案及安全更新。

## [1.1.0] - 2026-08-12

- 针对Clawhub安全审计意见进行了安全方面的优化和加固。
- 文档内容优化，消歧义，增加可读性。
- **快照重构为"文件集"模式（破坏性变更）**：`snapshot create` 由整目录全量 `cp -r` 改为只备份 AI 通过 `--files` 传入的本次改动文件（语义对齐 git commit：文件集 + 描述），写 `snapshot.files` 清单；`snapshot rollback` 只按文件集还原；`snapshot list` 显示文件数；`snapshot init` 仅写开关、不再写备份目录且幂等。删除 `SNAPSHOT_BACKUP_DIRS` 全局目录概念。
- **安全校验**：`--files` 路径必须相对项目根、不含 `..`、非绝对路径、不在治理目录（`.git`/`.workbuddy`/`.vibe-coding`）内，且文件须存在；任一非法整条报错退出、不写半截；缺省 `--files` 报错退出（不再退回全量）。
- **task-manager 联动**：TASKS 任务条目新增 `**改动文件**` 字段（create 第 7 参 / complete 汇报可填）；`maybe_auto_snapshot` 读取该字段拼成 `--files` 传给 `snapshot create`，字段为空或 `[待补充]` 时跳过自动快照（debug 日志，不报错中断任务流）。
- **老版全量快照不兼容**：旧快照无 `snapshot.files`，回滚会明确报错提示清理后重打。

## [1.0.0] - 2026-08-08

- 单包发布形态确立：1 个 SKILL.md + 4 子命令（health-check / commit-check / task-manager / project-init）共享统一版本号。
- 初始上架 ClawHub / SkillHub。

---

# English Version

# Changelog

## [1.2.0] - 2026-08-26

- Version management unified on local git; the simple snapshot feature was removed.
- Configuration files merged; `adapter.cfg` is now the single configuration source.
- Module codes anglicized: module identifiers now all use English codes such as PC, APP, CLOUD, WEB, SERVER; Chinese is used only for display.
- Strengthened run logging.
- The project-init interaction flow is now script-driven; a new `ask` subcommand was added.
- Other copy and security updates.

## [1.1.0] - 2026-08-12

- Security hardening based on ClawHub security audit feedback.
- Documentation improvements: removed ambiguity, improved readability.
- **Snapshot refactored to "file-set" mode (breaking change)**: `snapshot create` changed from full-directory `cp -r` to backing up only the changed files passed by AI via `--files` (semantics aligned with git commit: file set + description), writing a `snapshot.files` manifest; `snapshot rollback` restores only by file set; `snapshot list` shows file counts; `snapshot init` only writes the toggle, no longer writes a backup directory, and is idempotent. The `SNAPSHOT_BACKUP_DIRS` global-directory concept was removed.
- **Security validation**: `--files` paths must be relative to the project root, must not contain `..`, must not be absolute, must not be inside governance directories (`.git`/`.workbuddy`/`.vibe-coding`), and the files must exist; any violation aborts the whole command with an error without writing partial data; a missing `--files` aborts with an error (no longer falls back to full backup).
- **task-manager integration**: TASKS entries gained a `**改动文件**` (changed files) field (create parameter 7 / fillable in the complete report); `maybe_auto_snapshot` reads this field and builds the `--files` list passed to `snapshot create`; when the field is empty or `[待补充]` (to be filled), the automatic snapshot is skipped (debug log, does not error out or interrupt the task flow).
- **Old full snapshots are incompatible**: legacy snapshots have no `snapshot.files`; rollback fails with a clear error telling you to clean up and recreate them.

## [1.0.0] - 2026-08-08

- Single-package release form established: 1 SKILL.md + 4 subcommands (health-check / commit-check / task-manager / project-init) sharing one unified version number.
- Initial release on ClawHub / SkillHub.
