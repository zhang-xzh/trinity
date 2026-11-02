# 知识清单

Trinity 项目的知识索引：技能（skills）、仓库文档、脚本与工具，以及给后续 agent 的环境事实。

## 环境事实

- 服务端：`M:\EVE-LOCAL\trinity`（Rust workspace；镜像/容器 `trinity-server`，Postgres 容器 `trinity-postgres`；端口 26000 / 8080 / 5432）。
- 客户端：`M:\EVE-LOCAL\inputs\EVE-Online-45017`（EVE Trinity 4.10 / build 45017，`eve.exe` / `bin\ExeFile.exe`，永不升级）；容器格式见 `doc/client/version-lineage-3913-45017-3396210.md`。
- 客户端代码基线：`M:\EVE-LOCAL\inputs\EVE-Online-45017-code`（独立 git 仓库；`main` = 零售基线提交 `b74ecc1`，`plus` = 开发主线；685 个模块，3 个反编译失败；重打包/签名工具待实现）。
- 启动：仓库根 `Play.bat` 一键起 compose、等 26000，再用 `bin\ExeFile.exe /server:127.0.0.1 /port:26000` 拉起客户端；`Play.bat --no-client` 只起服务端。
- 远端：`origin` = `github.com/zhang-xzh/trinity`；当前只有长期分支 `main`（没有 `plus`/上游基线双分支）。
- 数据库：PostgreSQL 16，命名卷 `trinity_pgdata`（compose 项目名 `trinity`），初始化数据 `db/*.sql.gz`（228 个表转储）。
- 技能目录：`M:\EVE-LOCAL\trinity\.opencode\skills\`（纳入 git）。
- 仓库文档：`M:\EVE-LOCAL\trinity\doc\`（按领域分目录，见下）。

## 技能

| Skill | 用途 |
|---|---|
| `agent-context-efficient-reads` | 大文件/大输出/多步骤时的上下文压缩与少往返策略 |
| `trinity-server-operations` | 构建、启动、配置（`trinity.yml`）、日志、数据库与 `fakeclient` 联调 |
| `trinity-client-code` | 45017 `.ccp`/`.pyj` 容器、RC4 解密、基线仓库与改写边界 |
| `eve-online-university-wiki` | 查 EVE 玩法/机制（现代资料，取值仍需回到 45017 客户端） |

## 仓库文档

| 目录 | 放什么 |
|---|---|
| `doc/setup/` | 运行、构建、配置、启动、agent 规则迁移记录 |
| `doc/platform/` | crate 划分、连接与服务、世界状态、ballpark/destiny、bots、web |
| `doc/data/` | PostgreSQL 表转储、卷操作、备份/重置、版本溯源 |
| `doc/client/` | 45017 客户端目录、代码基线仓库、容器格式与本地化 |
| `doc/issues/` | 已解决异常归档与索引 |

## 文档清单

| 文档 | 内容 |
|---|---|
| `doc/setup/server-operations.md` | 构建/运行/配置/日志/联调 |
| `doc/setup/agent-rules.md` | 本仓库 agent 规则（AGENTS.md/.opencode/skills/doc 约定）的来源、适配与生效方式 |
| `doc/platform/architecture.md` | 服务端架构总览（crate、模块、数据流） |
| `doc/data/database.md` | 数据库结构、初始化、备份、重置 |
| `doc/client/client-45017.md` | 45017 客户端与代码基线：路径、容器、哈希、分支、工具与改写边界 |
| `doc/client/version-lineage-3913-45017-3396210.md` | 3913/45017/3396210 三代客户端技术对比与 45017 的中间态定位 |
| `doc/issues/INDEX.md` | 异常归档索引 |

## 脚本与工具

| 路径 | 用途 |
|---|---|
| `Play.bat` | 一键启动：`docker compose up -d` → 等 26000 → 启动 45017 客户端（`--no-client` 只起服务端；`TRINITY_CLIENT_DIR` 覆盖客户端目录） |
| `docker-compose.yml` / `Dockerfile` | Postgres + 服务端容器；镜像内带 `strings.txt` |
| `crates/eve-server/src/bin/fakeclient.rs` | 无头客户端：LLV 握手 + 脚本化服务调用 |
| `crates/eve-server/web/` | TypeScript 仪表盘（`npm run build` 产出 `web/dist/app.js`，随源提交） |
| `db/*.sql.gz` | 官方表转储，卷首次启动时导入 |
| `crates/eve-server/src/rmr.default.yml` | 内置默认配置（环境变量前缀仍为 `RMR_*`） |
