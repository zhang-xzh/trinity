# Agent 规则（来源、落地与生效）

本仓库的 agent 规则从 EveJS 工作区（`M:\EVE-LOCAL\EveJS`）与 Red Moon Rising 工作区（`M:\EVE-LOCAL\redmoonrising`）迁移，并按 Trinity 的技术栈重写，2026-11-02 一次落地。本文记录“现在有哪些规则文件、为什么这样改、怎么生效”。

## 落地文件

| 路径 | 作用 |
|---|---|
| `AGENTS.md` | 规则本体：worktree、提交、异常归档、功能记录、零售优先、验证、数据库、客户端重启、客户端代码、性能前提、目录、Shell、上下文效率 |
| `AGENTS-DETAIL.md` | 按需读取的详细操作：worktree 命令、Postgres 卷操作、异常正文模板、skill 规范 |
| `.opencode/plugins/session-id.js` | 把会话 id 注入 `$OPENCODE_SESSION_ID`，供分支命名使用 |
| `.opencode/skills/agent-context-efficient-reads/` | 大文件/大输出的上下文压缩策略 |
| `.opencode/skills/trinity-server-operations/` | 构建、启动、配置、排障 |
| `.opencode/skills/trinity-client-code/` | 45017 客户端代码仓库与本地化边界 |
| `.opencode/skills/eve-online-university-wiki/` | 外部玩法资料查询（现代资料，取值仍需回到 45017） |
| `doc/` | 文档体系：`README.md`、`knowledge-inventory.md`、`issues/INDEX.md` 与各领域主题文档 |

## 保留的通用规则

以下规则与具体游戏版本无关，按原意保留：

- 每任务独立 worktree、分支命名带 session id、完成后 `--no-ff` 合并并保留分支。
- 完成即自动提交；提交信息英文祈使句；不自动 push；不提交密钥/日志/临时产物。
- 异常归档（`doc/issues/` 一篇一异常 + 索引）。
- 功能修改必须有文档记录，写成“当前状态”。
- 零售版本优先、仔细验证、不写兼容层、破坏性变更先列受影响清单。
- 客户端在运行时禁止重启服务端。
- 性能分析默认「单机单用户、无客户端升级」前提。
- 工具使用与上下文效率（少往返、并行、子代理、定点读）。

## 按 Trinity 技术栈改写的规则

| 来源规则 | Trinity 对应 |
|---|---|
| RMR 客户端 build 3913、`script\compiled.code` | Trinity 客户端 build 45017、`M:\EVE-LOCAL\inputs\EVE-Online-45017`（已解包：pickle v2 + RC4 + zlib + Python 2.5） |
| RMR `plus` 开发主线 / `main` 上游基线 | 一致：`plus` = 开发主线（任务分支合入目标，主工作区固定检出）；`main` = 上游基线（跟踪 `upstream/main` = `pixelcatburglar/trinity`），只对照与重置 |
| RMR 容器 `rmr-postgres`/`rmr-server`、卷 `pgdata` | Trinity 容器 `trinity-postgres`/`trinity-server`、卷 `trinity_pgdata` |
| RMR 配置 `rmr.yml` | Trinity 配置 `trinity.yml`（compose 内 `RMR_CONFIG=/app/trinity.yml`；裸 `cargo run` 默认仍读 `rmr.yml`） |
| RMR `db/*.sql.gz` 212 个文件 | Trinity `db/*.sql.gz` 228 个文件 |
| PowerShell 5.1 命令 | 保持一致（本工作区实测为 PowerShell 5.1） |
| 验证用 `fakeclient` | 保持一致；参数为 `[addr] [user] [pass] [--script <file>] [--no-cache]` |

## 未导入的内容

- **RMR `doc/platform/implementation-*.md`（7 篇逐模块实现手册）**：写的是 RMR 3913 代码，Trinity 多出 `jumps`/`scan`/`lp`/`outposts`/`corphangar`/`trinity` 等服务，行号也已漂移；未复制，避免过期文档冒充当前状态。需要时按 Trinity 代码另写。
- **RMR `doc/client/*`、`doc/data/provenance-3913.md`、`doc/client-localization-3913.md`**：绑定 3913 客户端与本地化产物；45017 已按实际重建为 `doc/client/client-45017.md` 与代码基线仓库。
- **EveJS 专属 skill**（elysian importer、external mod merge、fsd-dogma-editor、gm-menu、gridcheck、server-debugging 等）：绑定 JS 服务端、现代 FSD/SDE 或 `code.ccp`，不适用于 Rust 老客户端服务端。
- **`eve-online-everef` / `eve-online-resfiles`**：面向现代 EVE 数据集与 `.fsdbinary`/`code.ccp`；45017 已核对，但仍不引入，避免现代数值被当成 45017 的取值依据。
- **EveJS `opencode.json` 的 gridcheck MCP**：Trinity 无对应工具；验证用 `fakeclient`。

## 生效方式

- 从 `M:\EVE-LOCAL\trinity`（或其它 worktree）启动 opencode，会自动读取该目录的 `AGENTS.md` 与 `.opencode/skills/`。
- 新增/修改 skill 后需**重启 opencode** 才会出现在会话里（部分版本会自动热加载，重启最稳妥）。
- `AGENTS-DETAIL.md` 不常驻，只在执行对应任务时读取。

## 验证

- `git status` 干净、`git log --oneline -3` 有本次提交。
- 文件存在性：`AGENTS.md`、`AGENTS-DETAIL.md`、四个 skill 的 `SKILL.md`、`doc/README.md`、`doc/knowledge-inventory.md`、`doc/issues/INDEX.md`、主题文档。
- `Get-Content .opencode/plugins/session-id.js` 与 `.opencode/package.json` 可解析（JSON 合法）。
- 每个 skill 的 `name` 与目录名一致。

## 回滚

- 规则文件全部是新增文件，回滚只需 `git revert <commit>`（或在分支上删除）。
- `trinity.yml`、服务端代码与数据库未做任何改动。

## 已知缺口

- 客户端代码基线已落地（685 个模块），但**重打包/签名工具尚未实现**；当前只能解包、阅读与改脚本/文档，不能回写 `compiled.code`。
- 反编译有 3 个 `SourceWalkerError`；权威产物以 `.pyc` 为准。
- `platform/` 仍只有架构总览；逐模块实现手册待按 Trinity 代码补写。
- 文档只有 `doc/` 一个入口（权威、当前状态）；`platform/` 目前只有架构总览，逐模块手册待按 Trinity 代码补写。
- 迁移未引入任何 MCP 服务；需要无头测试时直接用 `fakeclient`。
