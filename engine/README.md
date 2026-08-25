# Rapfi 五子棋引擎（第三方组件）

本目录包含 [Rapfi](https://github.com/dhbloo/rapfi) 五子棋引擎（版本 2025-06-15 / 250615），
用于本项目的「人机对战」功能。

## 许可

- Rapfi 引擎本体：**GPL-3.0**（见同目录 `Copying.txt`）。分发本引擎时须同时提供许可文本与源码指针。
- 权重文件（`model210901.bin`、`mix9svq*.bin.lz4`）：**CC0-1.0**（来自 [rapfi-networks](https://github.com/dhbloo/rapfi-networks)）。

源码地址：<https://github.com/dhbloo/rapfi>（引擎）与 <https://github.com/dhbloo/rapfi-networks>（权重）。

## 文件说明

| 文件 | 说明 |
| --- | --- |
| `pbrain-rapfi-windows-*.exe` | Windows 引擎可执行文件，5 个指令集版本（sse / avx2 / avxvnni / avx512 / avx512vnni） |
| `config.toml` | 引擎配置（`coord_conversion_mode = "none"`，Piskvork 协议） |
| `model210901.bin` | classical 传统估值权重 |
| `mix9svq*.bin.lz4` | NNUE 神经网络权重（Freestyle / Standard / Renju 规则） |
| `AUTHORS` | Rapfi 作者列表 |
| `Copying.txt` | GPL-3.0 许可证全文 |

## 使用方式

游戏代码通过 `rapfi_ai.gd` 启动引擎子进程，使用 **Piskvork 协议**（`START` / `TURN` / `BEGIN`）
通过 stdin/stdout 通信。默认使用 `pbrain-rapfi-windows-avx2.exe`（兼容性与速度均衡）。

如需更换指令集版本，修改 `rapfi_ai.gd` 中的 `EXE_NAME` 常量。
