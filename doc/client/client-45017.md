# 45017 客户端与代码仓库

> 状态：客户端目录与代码基线仓库均已就位。代码基线在
> `M:\EVE-LOCAL\inputs\EVE-Online-45017-code`，`main` = 零售基线（提交 `b74ecc1`），
> `plus` = 开发主线。容器格式与三代对比见
> [`version-lineage-3913-45017-3396210.md`](version-lineage-3913-45017-3396210.md)。

## 路径与版本

| 项 | 值 |
|---|---|
| 客户端 | `M:\EVE-LOCAL\inputs\EVE-Online-45017` |
| 启动器 / 游戏进程 | `eve.exe` / `bin\ExeFile.exe` |
| 版本 | 4.10 / build 45017 / codename LIVE（`common.ini`） |
| 代码基线仓库 | `M:\EVE-LOCAL\inputs\EVE-Online-45017-code` |
| 游戏日志 | `capture\Gamelogs`、`capture\Chatlogs` |

固定不升级；补丁只针对这一构建。

## 启动与登录

- `eve.exe` 是 bootstrapper（PE 里声明 `<GameExecutable path="bin\ExeFile.exe" />`），
  真正的游戏进程是 `bin\ExeFile.exe`；本地固定 45017，仓库根 `Play.bat` 直接启动后者，
  绕过引导器的更新检查。
- 登录地址来自 `boot.ini` 的 `server`/`port`，但零售代码支持命令行覆盖：
  `tree/ui/login/loginII.py:145-156` 解析 `/server:<name|ip>` 与 `/port:<n>`。
  `boot.ini` 当前是 `server=Tranquility`、`port=26000`，`Tranquility` 在
  `loginII.py:35-55` 解析成官方 `87.237.38.200`，所以连本地要传
  `/server:127.0.0.1 /port:26000`。
- 45017 没有 3913 的 `USERDOMAIN=CENTRAL` 隐藏服务器列表；登录界面显示哪个服务器由
  `boot.ini`/prefs 的 `server` 或 `/server:` 参数决定，`Play.bat` 传 `127.0.0.1`
  即显示本地服务器。

## 代码基线

| 来源 | 大小 | sha256 | 模块数 |
|---|---:|---|---:|
| `script/compiled.code` | 4,468,826 | `ed89bda059fea23c0c616ce60ad65cc09a1c95465f640826604b20d256aaa031` | 436 |
| `lib/lib.ccp` | 149,082 | `005babb0bfe9ac3bc5fca28a105bafa6c28633a82499c1d87a4b308c01e2f8af` | 23 |
| `lib/stdlib.ccp` | 857,185 | `b688f73ef8d090e282d8b235f2a7a622b4e7be553501dd0d3e87f0be857ffd9c` | 226 |

仓库布局：

| 路径 | 内容 |
|---|---|
| `dist/*` | 三个原始容器 + `manifest.json` + `decompile_failures.txt` |
| `tree/**` | `compiled.code` 的 436 个模块；`.pyc` 权威，`.py` 为 uncompyle6 阅读稿 |
| `lib/**`、`stdlib/**` | 23 / 226 个 `.ccp` 模块；同样 `.pyc` + `.py` |
| `tools/extract_compiled_code.py` | 解包 + 反编译 + 生成 manifest |
| `tools/verify_manifest.py` | 按 manifest 校验 pyc 大小与 sha256 |

反编译：685 个模块中 682 成功；3 个 `SourceWalkerError`（`tree/ui/control/combo.py`、
`tree/ui/services/menusvc.py`、`tree/ui/station/hangar.py`）。清单见
`dist/decompile_failures.txt`。**权威产物是 `.pyc` 与 `dist/*`**，`.py` 只作阅读。

## 容器与解密

- `script/compiled.code`：protocol-2 pickle，
  `(magic, pickle({code:[(path,(enc,sort))...], cargo, timestamp, preprocessed}), signature)`。
- `lib/*.ccp`：标准 ZIP，条目 `*.pyj`。
- 两类载荷都是 **RC4(zlib(...))**：
  - `compiled.code` 解出 marshal code object；
  - `.pyj` 解出 8 字节 pyc 头（magic `b3 f2 0d 0a`，Python 2.5）+ marshal。
- RC4 16 字节密钥在 `bin/blue.dll` 的 140 字节 SIMPLEBLOB 里
  （`01 02 00 00 01 68 00 00 00 a4 00 00 ...`，CALG_RC4 + CALG_RSA_KEYX），
  实际密钥 = `blob[12:28]` 反转；`tools/extract_compiled_code.py` 自动扫描并校验。
- 密钥不写入仓库；脚本运行时从 `blue.dll` 读取。

## 分支与改写

- `main` = 零售基线；`plus` = 开发主线；任务分支 `<前缀>/<功能>-<sessionid>`，独立 worktree。
- 远程 `gogs` = `http://10.10.10.1:3001/zhangxzh/EVE-Online-45017-code.git`（已配置，尚未推送）。
- **重打包/签名工具尚未实现**。当前只做解包、阅读与脚本/文档改动；在重打包落地前，
  不要声称已能把修改回写 `script\compiled.code`。
- 重打包落地后的流程：从零售基线重新生成 → 校验 → 覆盖客户端代码包（先备份）→
  **完全退出并重启客户端** → 证据看 `capture\Gamelogs`。
- 只改显示文本/本地化；不改类名、字典键、import 名、比较常量、单 token 标识符。
  `bin\ExeFile.exe`、`bin\*.dll`、`res*.stuff` 一律不改。
- 不得混用 3913 的 `compiled.code` 工具或现代 3396210 的 `.fsdbinary`/`code.ccp` 经验。

规则本体见 `AGENTS.md`「客户端代码修改」；操作细节见 skill `trinity-client-code`。
