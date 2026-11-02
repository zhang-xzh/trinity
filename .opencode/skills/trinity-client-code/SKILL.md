---
name: trinity-client-code
description: Use when reading or patching the EVE 45017 client code, Python views, strings or localization. Triggers: client code, compiled code, localize, pyo, 本地化
---

# 45017 客户端代码

规则见 `AGENTS.md`「客户端代码修改」；背景见 `doc/client/client-45017.md`。

> 客户端与客户端代码仓库尚未实际就绪；本 skill 按约定路径与 3913 的独立仓库策略先落地，**容器/字节码格式与工具链要在客户端到位后按实际核对**，核对前不得拿 3913 的 `compiled.code` 工具直接改写。

## 事实（按约定假设）

- 客户端：`M:\EVE-LOCAL\inputs\EVE-Online-45017`（Trinity 4.10 / build 45017，固定不升级）。
- 客户端代码仓库：`M:\EVE-LOCAL\inputs\EVE-Online-45017-code`（独立 git 仓库）。
- 运行时刻意区分：`eve.exe` 是启动器，游戏进程是 `bin\exefile.exe`。
- 客户端代码/工具/补丁/本地化流水线**不在本服务器仓库**；本仓库只保留规则与文档引用。

## 仓库策略

与 3913 / 新版客户端一致：

- `main` = 零售基线（客户端原始代码解包结果，只作对照与重置，不承载改动）。
- `plus` = 开发主线（补丁任务分支合入目标）。
- 每个任务用独立 worktree：`git worktree add -b <前缀>/<功能>-$OPENCODE_SESSION_ID M:\EVE-LOCAL\worktrees\wt-client-<功能> plus`。
- 一次补丁一条 `Local patch: <英文简述>` 提交；合并后保留分支，只清理 worktree。

## 改写流程

1. 备份当前客户端代码包（具体文件名以客户端实际布局为准）。
2. 从零售基线重新生成新包，不要在上一次产物上叠加。
3. 用客户端仓库的脚本改写 + 校验；只改显示文本，不改类名、字典键、import 名、比较常量。
4. 覆盖客户端代码包。
5. **完全退出并重启客户端**（字节码只在启动时载入），进游戏看效果；证据看 `capture\Gamelogs`。
6. 记录到 `doc/client/`：脚本、映射条目、改动的模块、验证结果。

## 约束

- `bin\exefile.exe`、`bin\*.dll`、`res\*.stuff` 一律不改。
- 改动必须由脚本可复现；没有版本控制前不要手改。
- 客户端运行时禁止重启服务端；改客户端后必须完全重启客户端。

## 就绪后要补的核对项

- 客户端实际目录结构与代码包文件名。
- 字节码/Python 版本、容器格式、解包与重打包工具。
- 本地化资源位置（`res\*.stuff`、messages、字体）与可改边界。
- 上述核对结果同步更新本 skill 与 `doc/client/client-45017.md`。

## 触发关键词

client code, 客户端代码, 45017, eve.exe, exefile, 代码包, 字节码, 本地化, 中文, 字体, 界面文字, capture/Gamelogs
