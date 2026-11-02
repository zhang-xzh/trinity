---
name: trinity-server-operations
description: Use when building, running, configuring or debugging the Trinity server (Rust, Docker, Postgres) for EVE 45017. Triggers: trinity.yml, docker compose, cargo build, postgres, fakeclient
---

# Trinity 服务端运维

规则与记录要求见 `AGENTS.md`；主题文档见 `doc/setup/server-operations.md`、`doc/data/database.md`。

## 一键运行

```powershell
cd M:\EVE-LOCAL\trinity
docker compose up -d
docker compose logs -f server --tail 100
```

当前仓库没有 `Play.bat`；需要拉客户端时先 `docker compose up -d`，等 26000 就绪后手动启动 `M:\EVE-LOCAL\inputs\EVE-Online-45017\eve.exe`。

端口：26000 游戏、8080 web、5432 Postgres。EveJS / RMR 等服务在跑会占 26000/5432——先停对应容器，不要改 Trinity 端口来“绕开”。

## 构建

```powershell
cargo build --release -p eve-server --bins
cargo test -p eve-marshal -p eve-proto
docker compose build server
```

- `target/` 在各自 worktree 内；并发构建要抢 `CARGO_TARGET_DIR` 锁。
- `Dockerfile` 需要拉 `rust:1.97-slim-trixie` 与 crates；断网时优先本地 cargo。
- web 前端：`cd crates/eve-server/web; npm run build` 生成 `dist/app.js`（随源提交，构建服务端不需要 Node）。

## 配置优先级

`RMR_*` 环境变量 > 配置文件 > `crates/eve-server/src/rmr.default.yml` 内置默认（`config.rs` 的 `Config::load()`）。

- 配置文件路径由 `RMR_CONFIG` 决定，未设置时默认工作目录的 `rmr.yml`（不存在会按默认值生成）。
- **Docker 里** `docker-compose.yml` 设 `RMR_CONFIG=/app/trinity.yml`，并只读挂载仓库根的 `trinity.yml`；改完必须重启服务端。
- **直接 `cargo run` 时**默认读 `rmr.yml`，不是 `trinity.yml`；数据库默认也是 `postgres://rmr:rmr@127.0.0.1:55432/rmr`。要么设 `RMR_CONFIG=trinity.yml` + `RMR_DATABASE`，要么另建 `rmr.yml`。
- 常用：`RMR_LOG=debug`、`RMR_LOG=trace`、`RMR_DATABASE`、`RMR_BOTS=0`（先关掉 10 万 bot 再看玩家路径性能）、`RMR_WEB=`（关仪表盘）。
- 账号在 `trinity.yml accounts:` 里声明，每次启动创建/对齐；`gm: true` 才能用 `/` 命令。

## 数据库

```powershell
docker compose exec postgres psql -U trinity -d trinity -c "SELECT count(*) FROM \"account\";"
docker compose exec -T postgres pg_dump -U trinity -d trinity | Out-File -Encoding utf8 backup.sql
```

- `db/*.sql.gz`（228 个文件）只在卷为空时导入；改它不会影响已有卷。
- 清卷 = 删所有角色，先确认：`docker compose down; docker volume rm trinity_pgdata; docker compose up -d`。
- PowerShell 重定向默认 UTF-16，恢复时用 `Get-Content -Encoding UTF8 ... | docker compose exec -T ... psql`。

## 无头验证

```powershell
cargo run -p eve-server --bin fakeclient -- 127.0.0.1:26000
cargo run -p eve-server --bin fakeclient -- 127.0.0.1:26000 testuser testpass --script calls.txt
```

位置参数依次是地址、用户名、密码（后两个默认 `testuser`/`testpass`）；`--script <file>` 按脚本发 service 调用并断言，`--no-cache` 跳过登录缓存对象。`fakeclient` 走完整 LLV 握手与登录，是客户端之外最可靠的回归入口。脚本语法见 `crates/eve-server/src/bin/fakeclient.rs` 的 `parse_script`。

## 排障顺序

1. `docker compose ps`：两个容器是否 healthy。
2. `docker compose logs server --tail 100`：`cannot reach PostgreSQL`、`string table`、`panic`。
3. 端口是否被占：`Get-NetTCPConnection -LocalPort 26000 -ErrorAction SilentlyContinue`。
4. 无法解码的帧在 `RMR_DUMP_DIR`（容器 `/app/logs/dumps`），`docker cp trinity-server:/app/logs/dumps .` 取出。
5. 客户端侧证据：`M:\EVE-LOCAL\inputs\EVE-Online-45017\capture\Gamelogs`。

## 禁止事项

- 客户端（`exefile` 进程）在跑时禁止重启服务端/数据库。
- 不提交 `dumps/`、`target/`、日志或本机备份。

## 触发关键词

trinity.yml, RMR_LOG, RMR_CONFIG, docker compose, trinity-server, trinity-postgres, trinity_pgdata, db 转储, cargo build, fakeclient, 26000, 8080, 5432, 启动失败, postgres 连不上, 服务端重启
