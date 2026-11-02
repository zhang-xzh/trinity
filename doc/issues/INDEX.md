# 异常归档索引

已定位/已解决的客户端或服务器异常。一篇正文 + 本表一行；命名 `trinity-issue-<英文简述>.md`，正文模板见 `AGENTS-DETAIL.md`。

| 文档 | 症状 / 触发词 |
|---|---|
| [`trinity-issue-handshake-incompatible-public-key.md`](trinity-issue-handshake-incompatible-public-key.md) | 登录弹 CONNECTION FAILED / Incompatible (Public Key)；服务端日志 `client offered crypto key`、`HANDSHAKE_INCOMPATIBLEPUBLICKEY`；改 `common.ini` 后报 `Verification failed ... crc ... expected`（cryptoPack / CryptoAPI / Placebo / manifest.dat / blue.dll） |
