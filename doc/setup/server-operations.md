# 服务端运行与配置

Trinity 服务端如何构建、启动、配置和观察。所有命令在仓库根 `M:\EVE-LOCAL\trinity` 执行（worktree 同）。

## 组成

| 组件 | 说明 |
|---|---|
| `eve-server` | 服务端二进制（crate `crates/eve-server`），监听 26000；可选 web 仪表盘 8080 |
| `postgres` | `postgres:16-alpine`，容器 `trinity-postgres`，库/用户/密码均 `trinity`，卷 `trinity_pgdata` |
| `fakeclient` | 无头客户端二进制（同 crate 的 `bin/fakeclient.rs`），用于握手与 service 调用验证 |

## 启动

```powershell
# 推荐：起 compose、等 26000 就绪，再拉起 45017 客户端（仓库根，已跟踪）
M:\EVE-LOCAL\trinity\Play.bat

# 只起服务端（不拉客户端）
M:\EVE-LOCAL\trinity\Play.bat --no-client

# 手动
docker compose up -d
docker compose logs -f server --tail 100

# 停
docker compose down
```

`Play.bat` 以脚本所在目录为 compose 目录（`%~dp0`）：先 `docker compose up -d`，再轮询 `127.0.0.1:26000`（最多 10 分钟，首次启动要导入数据库），就绪后用 `bin\ExeFile.exe /server:127.0.0.1 /port:26000` 启动客户端。客户端目录默认 `M:\EVE-LOCAL\inputs\EVE-Online-45017`，可用环境变量 `TRINITY_CLIENT_DIR` 覆盖；`--no-client` 只起服务端。

- 不经过 `eve.exe` 引导器：45017 的 `eve.exe` 是 bootstrapper（PE 里声明 `<GameExecutable path="bin\ExeFile.exe" />`），可能做更新检查；本地固定 45017，直接启动游戏进程 `bin\ExeFile.exe`。
- `/server:` 与 `/port:` 是零售客户端自带参数：`EVE-Online-45017-code\tree\ui\login\loginII.py:145-156` 用它们覆盖 `boot.ini` 的 `server`/`port`。`boot.ini` 当前是 `server=Tranquility`、`port=26000`；`Tranquility` 在 `loginII.py:35-55` 解析成官方 `87.237.38.200`，所以本地必须传 `/server:127.0.0.1`。
- 45017 的登录界面没有 3913 的 `USERDOMAIN=CENTRAL` 隐藏服务器列表，`Play.bat` 不设该变量；本地入口由 `/server:127.0.0.1` 直接指定。

先决条件：端口 26000/8080/5432 未被占用（EveJS / redmoonrising 等服务若在跑，先停对应容器）。

`docker-compose.yml` 固定项目名 `trinity`，所有 checkout 共用同一组容器，所以从 worktree 运行会用该 worktree 的代码重建 `trinity-server`；日常仍在主工作区 `M:\EVE-LOCAL\trinity` 运行。

## 本地构建（不走 Docker）

```powershell
cargo build --release -p eve-server --bins
cargo test -p eve-marshal -p eve-proto        # marshal/proto 的回归
cargo run -p eve-server --bin fakeclient -- 127.0.0.1:26000
```

服务端需要 Postgres（`RMR_DATABASE`）与字符串表（`RMR_STRINGS`，默认 `crates/eve-marshal/data/strings.txt`）。

> 裸 `cargo run` 默认读工作目录的 `rmr.yml`（不存在会按 `crates/eve-server/src/rmr.default.yml` 生成），数据库默认 `postgres://rmr:rmr@127.0.0.1:55432/rmr`。要复用仓库根的 `trinity.yml`，设 `RMR_CONFIG=trinity.yml` 并设 `RMR_DATABASE` 指向本地 Postgres。

Docker 构建从 `rust:1.97-slim-trixie` 与 crates.io 拉依赖；离线或直连不通时用本地 cargo 构建镜像外版本。

## 配置：`trinity.yml`

- 文件位置：仓库根 `trinity.yml`（compose 以只读挂载进容器 `/app/trinity.yml`，并设 `RMR_CONFIG=/app/trinity.yml`）；模板是 `crates/eve-server/src/rmr.default.yml`。
- 优先级：`RMR_*` 环境变量 > 配置文件 > 内置默认（见 `crates/eve-server/src/config.rs` 的 `Config` 字段注释与 `Config::load()`）。
- **改完要重启服务端**才生效（`docker compose restart server`）；客户端在跑时不得重启（见 `AGENTS.md`）。

| 键 | 环境变量 | 作用 / 当前值 |
|---|---|---|
| `server.bind` | `RMR_BIND` | 客户端连接地址，`0.0.0.0:26000` |
| `server.web` | `RMR_WEB` | 仪表盘地址，`0.0.0.0:8080`（空 = 关闭；无登录，只在本机暴露） |
| `server.database` | `RMR_DATABASE` | PostgreSQL URL；compose 里覆盖为 `postgres://trinity:trinity@postgres:5432/trinity` |
| `server.nodeId` | `RMR_NODE_ID` | machoNet 节点 ID，保持 1 |
| `server.autoCreateAccounts` | `RMR_AUTO_CREATE_ACCOUNTS` | 未知用户名登录即建号；`trinity.yml` 为 `true` |
| `server.strings` | `RMR_STRINGS` | 客户端共享字符串表路径；未设时用 `crates/eve-marshal/data/strings.txt` |
| `server.dumpDir` | `RMR_DUMP_DIR` | 无法解码帧的落盘目录；容器内 `/app/logs/dumps` |
| `log.level` | `RMR_LOG`（或 `RUST_LOG`） | `off`/`error`/`warn`/`info`/`debug`/`trace`，支持 filter（如 `info,eve_server::svc=trace`）；`trinity.yml` 为 `debug` |
| `log.file` | `RMR_LOG_FILE` | 额外写文件；空 = 不写。compose 设为 `/app/logs/server.log` |
| `game.startingIsk` | `RMR_STARTING_ISK` | 新角色初始 ISK，5000 |
| `game.allianceJoinDelaySeconds` | `RMR_ALLIANCE_JOIN_DELAY` | 联盟加入延迟（客户端说 24 小时），86400 |
| `game.starbaseSpeedup` | `RMR_STARBASE_SPEEDUP` | 建筑锚定/上线加速倍率 |
| `game.sovClaimDelaySeconds` | `RMR_SOV_CLAIM_DELAY` | 主权宣称延迟（客户端说最多 6 天），518400 |
| `game.jumpCloneMinStanding` | `RMR_JUMP_CLONE_STANDING` | NPC 站给飞行员装跳克隆所需声望，8.0 |
| `bots.count` | `RMR_BOTS` | bot 角色数量；**`trinity.yml` 为 100000**（首次启动生成，之后保留） |
| `bots.speed` | `RMR_BOTS_SPEED` | bot 时钟倍速 |
| `bots.shownPerSystem` | `RMR_BOTS_SHOWN` | 同一星系最多显示的 bot 船数，`trinity.yml` 为 200 |
| `bots.piratesAttackPlayers` | `RMR_BOTS_PIRATES_ATTACK` | 海盗 bot 是否主动打玩家 |
| `bots.dashboardControls` | `RMR_BOTS_CONTROLS` | 仪表盘是否可操纵 bot（无登录，慎开）；`trinity.yml` 为 `true` |
| `accounts[]` | — | 每次启动创建/对齐的账号（`gm`、`banned`、`startingIsk`、`role`）；`trinity.yml` 含 `testuser`/`testpass` 与 `root`/`root`(GM) |

`trinity.yml` 会随仓库提交；账号密码属于本地测试凭据，不要换成本机真实密码。环境变量前缀仍沿用 `RMR_*`（代码如此，不是笔误）。

## 观察与排障

```powershell
docker compose logs server --tail 100
docker compose logs server --since 10m | Select-String 'ERROR|WARN|panic'
docker compose exec postgres psql -U trinity -d trinity -c "SELECT count(*) FROM \"account\";"
```

- 启动日志会打印字符串表条目数、账号数、bulk 数据规模、services 数量等；`debug` 级别逐条打印 service 调用。
- 无法解码的帧落到 `RMR_DUMP_DIR`（容器 `/app/logs/dumps`，`docker cp trinity-server:/app/logs/dumps .` 取出）。
- 客户端侧证据：`M:\EVE-LOCAL\inputs\EVE-Online-45017\capture\Gamelogs`（游戏事件）与 `capture\Chatlogs`。

## 验证清单（改动后）

1. `cargo fmt --check`；改到协议/marshal 时 `cargo test -p eve-marshal -p eve-proto`。
2. `cargo build -p eve-server`（或 `docker compose build server`）通过。
3. `docker compose up -d` 后日志无 `ERROR`/`panic`，26000 可连。
4. `fakeclient` 完成 LLV 握手并调通目标 service（无头断言）。
5. 进客户端实际走一遍受影响流程；证据落 `capture\Gamelogs`。

数据库初始化、备份与重置见 `doc/data/database.md`；客户端侧见 `doc/client/client-45017.md`。
