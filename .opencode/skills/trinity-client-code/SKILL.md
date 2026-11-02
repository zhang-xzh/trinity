---
name: trinity-client-code
description: Use when reading or patching the EVE 45017 client code, .ccp/.pyj containers, decompile baseline or localization. Triggers: compiled.code, lib.ccp, RC4, blue.dll, uncompyle6
---

# 45017 客户端代码

规则见 `AGENTS.md`「客户端代码修改」；背景见 `doc/client/client-45017.md` 与 `doc/client/version-lineage-3913-45017-3396210.md`。

## 事实

- 客户端：`M:\EVE-LOCAL\inputs\EVE-Online-45017`（4.10 / build 45017 / codename LIVE，固定不升级）。
- 代码基线仓库：`M:\EVE-LOCAL\inputs\EVE-Online-45017-code`（`main` = 零售基线 `b74ecc1`，`plus` = 开发主线）。
- 运行进程：`eve.exe` 是启动器，游戏进程是 `bin\ExeFile.exe`（注意大小写）。

## 容器与解密（已确认）

| 来源 | 结构 |
|---|---|
| `script/compiled.code` | protocol-2 pickle：`(magic, pickle({code:[(path,(enc,sort))...], cargo, timestamp, preprocessed}), signature)`；436 个模块 |
| `lib/lib.ccp` | ZIP，23 个 `.pyj` 条目 |
| `lib/stdlib.ccp` | ZIP，226 个 `.pyj` 条目 |

两类载荷都是 **RC4(zlib(...))**：

- `compiled.code` 的 `enc` 解出 marshal code object（无 pyc 头）。
- `.pyj` 解出 8 字节 pyc 头（magic `b3 f2 0d 0a` = Python 2.5）+ marshal。

RC4 密钥在 `bin/blue.dll`：140 字节 SIMPLEBLOB
（`01 02 00 00 01 68 00 00 00 a4 00 00 ...`，CALG_RC4 + CALG_RSA_KEYX），
实际 16 字节密钥 = `blob[12:28]` 反转。`tools/extract_compiled_code.py` 会自动扫描并校验。

## 基线仓库

- 685 个模块：`tree/` 436、`lib/` 23、`stdlib/` 226。
- `tree|lib|stdlib/**/*.pyc` 是权威（字节精确）；`.py` 是 uncompyle6 阅读稿。
- 682 个反编译成功；3 个失败：`tree/ui/control/combo.py`、`tree/ui/services/menusvc.py`、`tree/ui/station/hangar.py`，见 `dist/decompile_failures.txt`。
- `dist/manifest.json` 记录路径、pyc/py、大小、sha256、来源与反编译状态。

## 工具

```powershell
cd M:\EVE-LOCAL\inputs\EVE-Online-45017-code
uv venv --python 3.11 .venv
uv pip install --python .venv\Scripts\python.exe uncompyle6

.venv\Scripts\python.exe tools\extract_compiled_code.py              # 全量
.venv\Scripts\python.exe tools\extract_compiled_code.py --no-decompile
.venv\Scripts\python.exe tools\extract_compiled_code.py --only lib
.venv\Scripts\python.exe tools\verify_manifest.py
```

`--blue-dll` 可覆盖 `bin/blue.dll` 路径。密钥不写入仓库。

## 分支与改写

- 任务走独立 worktree：`git -C M:\EVE-LOCAL\inputs\EVE-Online-45017-code worktree add -b <前缀>/<功能>-$env:OPENCODE_SESSION_ID M:\EVE-LOCAL\worktrees\wt-client-<功能> plus`。
- 一次补丁一条 `Local patch: <英文简述>` 提交；合并后保留分支，只清理 worktree。
- **重打包/签名工具尚未实现**：当前只能解包、阅读、改脚本/文档；不要声称已能把修改回写 `compiled.code`。
- 重打包落地后：从零售基线重新生成 → 校验 → 覆盖客户端代码包（先备份）→ **完全退出并重启客户端** → 证据看 `capture\Gamelogs`。
- 只改显示文本/本地化；不改类名、字典键、import 名、比较常量、单 token 标识符；`bin\ExeFile.exe`、`bin\*.dll`、`res*.stuff` 一律不改。
- 不得混用 3913 的 `compiled.code` 工具或现代 3396210 的 `.fsdbinary`/`code.ccp` 经验。

## 触发关键词

compiled.code, lib.ccp, stdlib.ccp, .pyj, RC4, blue.dll, SIMPLEBLOB, CryptoAPI, Python 2.5, pyc magic b3f20d0a, uncompyle6, 45017, 客户端代码, 解包, 反编译, 本地化
