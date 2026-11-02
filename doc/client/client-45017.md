# 45017 客户端与代码仓库

> 状态：客户端目录已就位（`bin\ExeFile.exe`、`script\compiled.code`、`res*.stuff`）；代码仓库目录 `EVE-Online-45017-code` 尚未创建。客户端容器格式与三代谱系见 `doc/client/version-lineage-3913-45017-3396210.md`；本文保留约定路径、待核对项与改写边界。

## 约定路径

| 项 | 路径 |
|---|---|
| 客户端 | `M:\EVE-LOCAL\inputs\EVE-Online-45017` |
| 启动器 | `eve.exe` |
| 游戏进程 | `bin\exefile.exe` |
| 客户端代码仓库 | `M:\EVE-LOCAL\inputs\EVE-Online-45017-code` |
| 游戏日志 | `capture\Gamelogs`、`capture\Chatlogs` |

版本：EVE Trinity 4.10 / build 45017，固定不升级。

## 代码仓库策略（与 3913 一致）

- `main` = 零售基线（客户端原始代码解包结果，只对照与重置）。
- `plus` = 开发主线（补丁任务分支合入目标）。
- 每个任务独立 worktree：`M:\EVE-LOCAL\worktrees\wt-client-<功能>`；一次补丁一条 `Local patch: <英文简述>` 提交。
- 目标布局：`tree\`（逐模块代码，字节精确）、`patches\`（改写脚本/安装器）、`dist\`（打好的原始包）。

## 就绪后要核对的项

1. 客户端目录结构：`bin\`、`res\`、`script\`、`capture\` 等实际布局。
2. 客户端代码/数据的容器格式：文件名、压缩/序列化方式、Python 版本、是否可分模块读写。
3. 解包、反编译、重打包工具链；能否做到字节级 round-trip。
4. 本地化资源位置与可改边界（显示文本 vs 类名/键名/import 名）。
5. 启动与登录链路：`eve.exe` 是否只是启动器、真正的进程与参数。
6. 日志与证据位置。

核对前**不得**拿 3913 的 `compiled.code` 工具直接改写 45017 客户端；也不得把现代客户端（3396210）的 `.fsdbinary`/`code.ccp` 经验当成 45017 的事实。

## 改写边界

- 只改显示文本/本地化；类名、字典键、import 名、比较常量、单 token 标识符不改。
- `bin\exefile.exe`、`bin\*.dll`、`res\*.stuff` 一律不改。
- 改动必须由脚本可复现，并从零售基线重新生成，不叠加历史产物。
- 写完必须**完全退出并重启客户端**（字节码只在启动时载入），证据看 `capture\Gamelogs`。

规则本体见 `AGENTS.md`「客户端代码修改」；操作细节见 skill `trinity-client-code`。
