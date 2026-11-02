# 架构总览

Trinity 是 EVE Online 4.10 / build 45017 的 machoNet 服务端。协议与玩法尽量以零售客户端行为为准；这里只描述“客户端连上来之后服务端怎么组织”。

本文件是 crates/模块级的架构总览。协议细节、世界模拟、玩法与 bot 见 `crates/eve-server/src/**` 的模块头注释；需要逐模块手册时按当前代码另写。

## Crate 划分

| Crate | 职责 | 关键入口 |
|---|---|---|
| `crates/eve-marshal` | EVE marshal 编解码：值模型、字符串表、CRC、序列化 | `Value`、`StringTable`、`load`/`save`（`crates/eve-marshal/src/lib.rs`） |
| `crates/eve-proto` | LLV 版本握手、machoNet 帧、压缩/解压、包与地址 | `VersionChallenge`、`FrameReader`、`MachoPacket`（`crates/eve-proto/src/lib.rs`） |
| `crates/eve-server` | 连接、服务分发、世界状态、模拟、bot、web | `main.rs`、`conn/`、`services.rs`、`svc/`、`world.rs`、`ballpark.rs`、`bots/`、`web.rs` |

## 启动顺序

`crates/eve-server/src/main.rs`：

1. 读配置：`config::Config::load()`（`RMR_CONFIG` 指 YAML，默认工作目录 `rmr.yml`；环境变量覆盖），然后初始化日志。
2. `run()`：读字符串表（`RMR_STRINGS`）→ 连 PostgreSQL（`db::connect`）→ 统计账号 → `db::sync_accounts` 对齐配置文件账号 → `config::set_rules`。
3. `schema::ensure` 把数据库表补到当前代码需要的状态。
4. `BulkData::load` 预构建登录时下发的 bulk 对象；`dogma::Catalog::load` 载入属性/效果目录。
5. `svc::registry()` 注册全部 service。
6. 装 `Arc<Server>`，起常驻任务：`heartbeat::run`（250 ms 脉冲）、`bots::run`、`web::run`。
7. 监听 `RMR_BIND`（默认 `0.0.0.0:26000`），每个连接 `tokio::spawn(Conn::new(..).run())`。

## 连接与协议

`crates/eve-server/src/conn/mod.rs`：一条客户端连接 = 帧读取 + 地址解析 + 请求分发 + 通知队列。

- `conn/auth.rs`：LLV 版本握手、账号登录（`db::authenticate`）。客户端上报的 build/codename 会校验；账号密码直接比对 `account."password"`（老式明文，无哈希）。
- `conn/location.rs`：会话移动——选角色、进站/出站、跳跃；每次移动把新会话对象/位置同步给 ballpark。
- 角色/会话数据在 `session.rs`（`ROLE_LOGIN`/`ROLE_PLAYER`/`ROLE_PETITIONEE` 等位与 `PERSIST_VARS` 客户端会话字段）。

## 服务分发

- `services.rs`：`Call`（service、method、args、kwargs）与 `service_name()`（从 bound object 前缀取，如 `N=1:invbroker#60000004`）。
- `svc/mod.rs` 的 `registry()` 把 service 名映射到 handler；同名 service 可由多个模块按注册顺序依次尝试。
- handler 分布在 `crates/eve-server/src/svc/*.rs`：登录、角色创建、市场、合同、军团/联盟、战争、聊天、邮件、制造（RAM）、POS/主权、扫描、跳跃、LP、前哨、GM 等。
- 有些调用改变会话（`character::SelectCharacterID`、`ship::Undock`、`beyonce::Dock`/`StargateJump`/移动），**不经过 registry**，由 `conn` 直接接住。
- 大数据在 `bulkdata.rs` 预构建成 rowset/tuple，避免单帧超限；`main.rs` 的 `BULK_WARN_BYTES` 会对接近 1 MB 帧上限的对象告警。
- GM 指令在 `svc/gm.rs`（`/create`、`/giveisk`、`/giveskill`、`/setstanding`、`/spawn`、`/tr me`、`/bots ...`、`/help`），只对带 `ROLE_GML`/`ROLE_LEGIONEER` 的会话可用（`config.rs` 的 `GM_ROLES`）。

## 世界与模拟

- `world.rs`：所有连接共享的世界状态——在线角色、打开的频道、星系内 ballpark、每分钟的推送通知队列。**一把锁保护全量**；持锁期间不 `await`，通知只入队。
- `ballpark.rs`：星系级 destiny 模拟，每个对象的位置与运动；从 `destiny.dll` 的 `Ballpark::Evolve` 移植，每个 tick 推进。偏差过大会被客户端拉回，所以模拟只保证近似。
- `destiny.rs`：`SetState`/`AddBalls` 等 wire 格式与 ball 状态读写。
- `combat.rs`/`fight.rs`/`drones.rs`/`npc.rs`/`sites.rs`/`pos.rs`/`loot.rs`/`losses.rs`/`gates.rs`/`concord.rs`/`guard.rs`：战斗、NPC、无人机、死亡空间、POS、掉落、击杀、星门、CONCORD 等玩法。
- `items.rs`/`dogma.rs`：物品实例、属性与衍生数值。

## Bot 人口

`bots/`：由服务器自己扮演的角色，让宇宙不空。

- `bots.count`（`RMR_BOTS`）首次启动生成并保留；`bots.speed` 加速时钟，便于测试。
- 每个 bot 按 `behaviour::step` 推进，状态每几秒批量写回；玩家所在星系的 bot 以船只形式显示（`presence`）。
- 大部分 bot 属于 bot 军团/联盟，会打仗（`battle`/`politics`/`sov`）、赚钱（`economy`）、升级船只（`ships`）、记仇（`relations`）、被雇佣（`hire`）、参与事件（`events`）。
- `/bots on|off|status` 与 `/bots event|war|density|follow`、web 仪表盘都能操纵它们（`bots/control.rs`）。

## Web 仪表盘

`web.rs`：内置页面（`web/index.html` + `style.css` + 编译后的 `web/dist/app.js`）与 JSON 接口：

`/api/summary`、`/api/news`、`/api/sieges`、`/api/wars`、`/api/players`、`/api/alliances`、`/api/corporations`、`/api/systems`、`/api/kills`、`/api/killboard`、`/api/market`、`/api/relations`、`/api/followed`、`/api/events`、`/api/pilots` 等。

唯一写操作是 `POST /api/control`（操纵 bot），需要 `bots.dashboardControls` 打开。前端是 TypeScript（`web/src/app.ts`），`npm run build` 产出 `web/dist/app.js` 并随源提交；构建服务端不需要 Node。

## 无头验证

`crates/eve-server/src/bin/fakeclient.rs`：连 26000 → LLV 握手 → 登录 → 按脚本调用 service 并断言，是客户端之外最可靠的回归入口。参数：`[addr] [user] [pass] [--script <file>] [--no-cache]`；脚本语法见 `parse_script`。
