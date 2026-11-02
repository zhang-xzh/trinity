# 知识清单

Trinity 项目的知识索引：技能（skills）、仓库文档、脚本与工具，以及给后续 agent 的环境事实。

## 环境事实

- 服务端：`M:\EVE-LOCAL\trinity`（Rust workspace；镜像/容器 `trinity-server`，Postgres 容器 `trinity-postgres`；端口 26000 / 8080 / 5432）。
- 客户端：`M:\EVE-LOCAL\inputs\EVE-Online-45017`（EVE Trinity 4.10 / build 45017，`eve.exe`，永不升级）。**客户端尚未实际就绪，路径按约定预留。**
- 客户端代码仓库：`M:\EVE-LOCAL\inputs\EVE-Online-45017-code`（独立 git 仓库；尚未就绪）。
- 启动：当前没有 `Play.bat`；`docker compose up -d` 起服务端，客户端就绪后手动启动 `eve.exe`。
- 远端：`origin` = `github.com/zhang-xzh/trinity`；当前只有长期分支 `main`（没有 `plus`/上游基线双分支）。
- 数据库：PostgreSQL 16，命名卷 `trinity_pgdata`（compose 项目名 `trinity`），初始化数据 `db/*.sql.gz`（228 个表转储）。
- 技能目录：`M:\EVE-LOCAL\trinity\.opencode\skills\`（纳入 git）。
- 仓库文档：`M:\EVE-LOCAL\trinity\doc\`（按领域分目录，见下）。

## 技能

| Skill | 用途 |
|---|---|
| `agent-context-efficient-reads` | 大文件/大输出/多步骤时的上下文压缩与少往返策略 |
| `trinity-server-operations` | 构建、启动、配置（`trinity.yml`）、日志、数据库与 `fakeclient` 联调 |
| `trinity-client-code` | 45017 客户端代码仓库、改写流程与本地化边界（客户端就绪后核对） |
| `eve-online-university-wiki` | 查 EVE 玩法/机制（现代资料，取值仍需回到 45017 客户端） |

## 仓库文档

| 目录 | 放什么 |
|---|---|
| `doc/setup/` | 运行、构建、配置、启动、agent 规则迁移记录 |
| `doc/platform/` | crate 划分、连接与服务、世界状态、ballpark/destiny、bots、web |
| `doc/data/` | PostgreSQL 表转储、卷操作、备份/重置、版本溯源 |
| `doc/client/` | 45017 客户端目录、代码仓库、本地化（待补全） |
| `doc/issues/` | 已解决异常归档与索引 |

## 文档清单

| 文档 | 内容 |
|---|---|
| `doc/setup/server-operations.md` | 构建/运行/配置/日志/联调 |
| `doc/setup/agent-rules.md` | 本仓库 agent 规则（AGENTS.md/.opencode/skills/doc 约定）的来源、适配与生效方式 |
| `doc/platform/architecture.md` | 服务端架构总览（crate、模块、数据流） |
| `doc/data/database.md` | 数据库结构、初始化、备份、重置 |
| `doc/client/client-45017.md` | 45017 客户端与代码仓库的约定路径、待核对项、改写边界 |
| `doc/issues/INDEX.md` | 异常归档索引 |

## 脚本与工具

| 路径 | 用途 |
|---|---|
| `docker-compose.yml` / `Dockerfile` | Postgres + 服务端容器；镜像内带 `strings.txt` |
| `crates/eve-server/src/bin/fakeclient.rs` | 无头客户端：LLV 握手 + 脚本化服务调用 |
| `crates/eve-server/web/` | TypeScript 仪表盘（`npm run build` 产出 `web/dist/app.js`，随源提交） |
| `db/*.sql.gz` | 官方表转储，卷首次启动时导入 |
| `crates/eve-server/src/rmr.default.yml` | 内置默认配置（环境变量前缀仍为 `RMR_*`） |
