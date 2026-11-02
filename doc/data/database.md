# 数据库

角色、物品、军团、市场等全部持久化在 PostgreSQL 里；表结构来自 Trinity 时代的官方数据库转储。

## 布局

| 项 | 值 |
|---|---|
| 服务 | `postgres:16-alpine`（容器 `trinity-postgres`） |
| 库 / 用户 / 密码 | `trinity` / `trinity` / `trinity` |
| 命名卷 | `pgdata`（实际名 `trinity_pgdata`，`/var/lib/postgresql/data`） |
| 初始化脚本 | `./db`（只读挂到 `/docker-entrypoint-initdb.d`） |
| 宿主端口 | 5432 |
| 连接串 | `postgres://trinity:trinity@127.0.0.1:5432/trinity`（容器内用服务名 `postgres`） |

`db/*.sql.gz` 共 228 个文件，每表一个（`account`、`character_`、`invItems`、`staStations`、`agtAgents`、`crpNPCCorporations`、`mapSolarSystems`、`bot*` 等），`00_shared.sql.gz` 负责共享对象，末尾还有 `zz_foreign_keys.sql.gz`、`zz_seed_market.sql.gz`。**它们只在卷为空时导入一次**。

## 常用查询

```powershell
docker compose exec postgres psql -U trinity -d trinity -c "SELECT \"accountID\",\"accountName\",\"role\",\"banned\" FROM \"account\" LIMIT 20;"
docker compose exec postgres psql -U trinity -d trinity -c "SELECT count(*) FROM \"character_\";"
docker compose exec postgres psql -U trinity -d trinity -c "\dt" | Select-Object -First 40
```

字段名沿用零售：`account` 表用 `"accountID"`、`"accountName"`、`"password"`、`"role"`、`"banned"`（见 `crates/eve-server/src/db.rs`）。SQL 里大小写敏感列名必须加双引号。

## 备份 / 恢复

```powershell
# 备份整个库到宿主（PowerShell 重定向默认 UTF-16，必须指定编码）
docker compose exec -T postgres pg_dump -U trinity -d trinity | Out-File -Encoding utf8 M:\EVE-LOCAL\_scratch\trinity-backup.sql

# 恢复
Get-Content -Encoding UTF8 M:\EVE-LOCAL\_scratch\trinity-backup.sql | docker compose exec -T postgres psql -U trinity -d trinity
```

## 重置（破坏性）

清卷会**删除所有角色与角色资产**，只有确实要回到初始转储时才做，且先让用户确认：

```powershell
docker compose down
docker volume ls | Select-String trinity_pgdata      # 确认卷名（compose 项目名 + _pgdata；name: trinity 时是 trinity_pgdata）
docker volume rm trinity_pgdata
docker compose up -d
docker compose logs server --tail 50                 # 确认重新导入完成、无 ERROR
```

## 版本与溯源

`db/*.sql.gz` 是 EVE Trinity 时代服务端的运行库转储，**不是官方 SDE**；`schema_migrations` 存在但内容为空，dump 是近年用 PostgreSQL 重新导出的。转储内容与 45017 客户端/服务端协议的逐项对应关系尚未建立锚点：

- 数据与客户端冲突时以客户端字节码/行为为准。
- 新增/修改表结构前先确认零售转储里已有对应字段；没有则写明缺口。
- 建立版本锚点或溯源脚本后，在本文件与 `doc/knowledge-inventory.md` 登记。

## 修改表结构的规则

- 零售转储表结构是权威；新增列/表必须给出理由与零售依据，并同步更新本文档与相关代码。
- 迁移脚本不要塞进 `db/`（只在空卷生效）：写成一次性 SQL，经容器执行，并记录到本文档相关主题。
- 数据改动（补数据、修角色）走 `psql` 且在文档里留下可复现的 SQL。

存档数据的操作边界见 `AGENTS.md`「存档数据操作规则」；详细命令见 `AGENTS-DETAIL.md`。
