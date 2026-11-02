# 登录失败：Incompatible (Public Key)

## 症状

- 45017 客户端点登录后弹出 **CONNECTION FAILED / Incompatible (Public Key)**，
  无法进入角色选择。
- 服务端日志（`docker compose logs server`）同时出现：

  ```
  WARN ...: client offered crypto key "\u{655}_..." ; it must run with cryptoPack=Placebo
  WARN ...: closed by the server: Handshake Failed - this server only speaks
            cryptoPack=Placebo; patch blue.dll and set it in common.ini
  ```

- 触发条件：客户端用零售出厂配置 `common.ini`（`cryptoPack=CryptoAPI`）连接本服务端。
- 受影响面：登录（全部账号）；服务端其它功能正常。

## 根因

两段独立的问题叠在一起：

1. **加密包不匹配。** 客户端在安全握手的第一步发送
   `(macho.publicKeyVersion, request)`（`tree/external/common/script/net/GPS.py:393`）。
   零售 `cryptoPack=CryptoAPI` 时，`macho.publicKeyVersion` 是
   `CryptoHash(public key blob)` 的原始摘要字节（`Crypto.py:39-48`、`public_key.py:6-12`），
   不是字符串 `placebo`。服务端 `crates/eve-server/src/conn/auth.rs:88-96` 只接受
   `placebo`，否则以 `HANDSHAKE_INCOMPATIBLEPUBLICKEY` 关闭连接；客户端把该代码
   （`mls.MACHONET_TRANSPORTCLOSED_HANDSHAKE_INCOMPATIBLEPUBLICKEY`，
   `GPS.py:214-217`）显示为 **Incompatible (Public Key)**。
   服务端当前实现不了 CryptoAPI：该模式要求服务端持有与客户端
   `public_key.py` 中 CCP 公钥配对的私钥，而私钥只在 CCP 服务器上。
   可行方向只有让客户端改跑零售同样内置的 `cryptoPack=Placebo`。

2. **改 `common.ini` 会触发客户端启动校验。** 45017 启动时用 `manifest.dat`
   校验被跟踪文件（`common.ini` 含在内）：每个条目是
   `(path, RSA signature, CRC32)`，由 `common/script/sys/lowdown.py` 的
   `CreateManifest` / `PackManifest` 生成；签名私钥 `GoldenCD.pikl` 未随客户端发布，
   无法重新签名。直接改 `common.ini` 后客户端弹窗：

   ```
   您的EVE 客户端安装程序可能已丢失，被修改或者被损坏。请重新装载游戏客户端。
   Verification failed:
   "M:\EVE-LOCAL\inputs\EVE-Online-45017\common.ini",
   crc:dc0ed6b6, expected:8f9939ef.
   ```

   所以必须同时跳过这条单文件签名检查，而不是伪造 `manifest.dat`。

`bin\blue.dll` 中的校验代码：单文件校验函数 `0x10025990` 在 `0x10025C8B` 调用
`CryptVerifySignature`；失败且 `GetLastError` 为 `NTE_BAD_SIGNATURE (0x80090006)` 时，
用宽字符格式串 `0x100A5CF8`（`Verification failed: "%s", crc:%x, expected:%x.`）
组装错误并弹出上面的对话框。

## 诊断步骤

```powershell
# 1. 服务端日志：看客户端报的 key version
docker compose logs server --tail 200 | Select-String "crypto key|logged in as|Handshake"

# 2. 客户端配置：确认是零售 CryptoAPI
Get-Content -Encoding UTF8 M:\EVE-LOCAL\inputs\EVE-Online-45017\common.ini

# 3. 客户端源码：key version 的来源与错误码
#    tree/external/common/script/net/GPS.py:214-217,393
#    tree/external/common/script/net/Crypto.py:39-48,345-355
#    tree/external/common/script/net/public_key.py:6-12

# 4. 若已改 common.ini，先看到的是文件校验失败弹窗；反汇编 blue.dll 定位
#    0x10025990（VerifyFile）与 0x100A5CF8 格式串。
```

## 修复内容

服务端代码不需要改动（`eve-proto::handshake` 与 `conn::auth` 的 Placebo 流程本身正确）。
客户端侧做两件事，工具在客户端代码仓库
`M:\EVE-LOCAL\inputs\EVE-Online-45017-code\tools\patch_blue_dll.py`：

1. `common.ini`：`cryptoPack=CryptoAPI` → `cryptoPack=Placebo`（走零售自带的
   `Placebo_CryptoContext`、`Placebo_CryptoHash`）。
2. `bin\blue.dll` 文件偏移 `0x25CA0`，6 字节分支改为恒跳：

   ```
   0F 85 0B 02 00 00   jne 0x10025EB1   ; CryptVerifySignature 成功分支
   E9 0B 02 00 00 90   jmp 0x10025EB1   ; 恒跳，绕过 NTE_BAD_SIGNATURE 失败分支
   ```

   文件存在性与大小检查保持不变；被改动文件与未改动文件走同一条“验证通过”路径。
   零售 `blue.dll` sha256 `416f8d8b1e3fd1edcd67651fab73564b3fe9e63a360da0d6a54bc4d266858230`，
   补丁后 `51e58b729e007f3150c2585ee5bb77eb496bd5694bb774aa22661874802e3e72`。

命令：

```powershell
python M:\EVE-LOCAL\inputs\EVE-Online-45017-code\tools\patch_blue_dll.py status
python M:\EVE-LOCAL\inputs\EVE-Online-45017-code\tools\patch_blue_dll.py patch
```

`patch` 先写 `bin\blue.dll.retail.bak`、`common.ini.retail.bak`，再应用两处改动。
生效方式：**完全退出并重新启动客户端**（`Play.bat`，或
`bin\ExeFile.exe /server:127.0.0.1 /port:26000`）；不需要重启服务端。

## 验证

- 改前：服务端 `14:07:18`、`14:07:22` 两次 `client offered crypto key ...` +
  `closed by the server`，客户端弹 Incompatible (Public Key)。
- 改后：客户端正常通过启动校验、连上 26000；服务端日志：

  ```
  14:32:20.259 DEBUG ...: version exchange ok: build 45017 "LIVE@ccp"
  14:32:20.324  INFO ...: logged in as "a" role=3 sid=5
  ```

  随后 `character.GetCharactersToSelect`、`character.GetCharCreationInfo` 等
  调用正常返回，客户端进入角色选择。
- 工具自检（对临时副本）：`status` 能区分 retail / patched 与
  `cryptoPack=CryptoAPI` / `Placebo`；`patch` 幂等；`revert` 可还原到零售 sha256。

## 回滚 / 预防

- 回滚：`python tools\patch_blue_dll.py revert`（用同目录 `.retail.bak` 还原
  `bin\blue.dll` 与 `common.ini`）；或从
  `M:\EVE-LOCAL\_archive\backup\EVE-Online-45017` 复制原始文件。
- 客户端升级/换目录后补丁不会自动跟随：新客户端要重新跑 `status` / `patch`；
  工具只认 45017 的零售/补丁两个 sha256，不会误改其它版本。
- 不要在客户端运行时打补丁（`bin\blue.dll` 被加载会锁定写入）。
- 改 `common.ini` 后若又看到 “Verification failed / crc:... expected:...”，
  说明补丁未生效（blue.dll 被替换回零售版或没重启客户端）。

## 相关

- 服务端：`crates/eve-proto/src/handshake.rs:43-45`（Placebo key version）、
  `crates/eve-server/src/conn/auth.rs:88-96`（key version 校验与关闭码）。
- 客户端源码：`tree/external/common/script/net/GPS.py:214-217,393`、
  `Crypto.py:242-358`、`public_key.py:6-12`、`sys/lowdown.py:157-221`。
- 客户端补丁工具与说明：`M:\EVE-LOCAL\inputs\EVE-Online-45017-code\tools\patch_blue_dll.py`、
  同仓库 `README.md`「本地登录补丁（Placebo 握手）」。
- 参考做法：EveJS 对 3396210 的 `blue.dll` 同样是单字节分支补丁
  （`M:\EVE-LOCAL\EveJS\tools\ClientSETUP\blue_patch_recipe.json`、
  `doc/issues/evejs-issue-client-manifest-corrupt.md`），但 45017 的
  `manifest.dat` 带 RSA 签名，不能像 3396210 那样只重算哈希。

## 触发关键词

Use when the 45017 client shows CONNECTION FAILED / Incompatible (Public Key) at login,
or the server logs "client offered crypto key" / HANDSHAKE_INCOMPATIBLEPUBLICKEY, or the
client refuses to start after editing common.ini with "Verification failed ... crc ... expected".
Triggers: Incompatible (Public Key), CONNECTION FAILED, HANDSHAKE_INCOMPATIBLEPUBLICKEY,
cryptoPack, CryptoAPI, Placebo, manifest.dat, blue.dll, Verification failed, 登录失败, 客户端校验失败.
