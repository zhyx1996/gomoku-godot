# Five-in-Row —— C 语言五子棋

一个用 C 语言写的 15×15 五子棋程序，支持双人对战与人机对战。

本目录包含：
- `Five-in-Row3.c` —— **GBK 编码**版（中文注释/字符串按 GBK 存储）。
- `Five-in-Row3-utf8.c` —— 忠实转码的 **UTF-8 版**（内容不变，含 GBK 时代的 `CHARSIZE 2` 常量，仅用于查看，勿直接编译）。
- `Five-in-Row3-win.c` —— **Windows 可编译版**（UTF-8 编码；`CHARSIZE 3`；棋盘每格 2 列使格子方正、与字母对齐；`system("clear")`→`system("cls")`；启动时把控制台切到 UTF-8，避免棋盘框线乱码）。
- `Five-in-Row.exe` —— 用 MSVC `/utf-8` 编译好的 **Windows 可执行文件**，双击即可运行。

## 编译（Win 版，MSVC）

```bat
cl /nologo /O2 /utf-8 /Fe:Five-in-Row.exe Five-in-Row3-win.c
```

> 提示：`-win.c` 版用 `/utf-8` 编译、中文按 UTF-8 输出，并会在启动时自动 `SetConsoleOutputCP(CP_UTF8)`；在 Windows Terminal 或 `chcp 65001` 的 cmd 里运行即可正常显示。

## 程序说明

- 15×15 棋盘，用 Unicode 符号（┏┯┓ 等）画棋盘，⬤ / ◯ 表示黑白子。
- 支持「双人对战」与「人机对战」两种模式。
- AI 算法：
  1. `getscore()` 判断每个空位能组成的棋型（五连/活四/冲四/活三/跳活三/眠三/活二/大跳活二），按棋型加权给每个位置打分；
  2. `AIgetchess()` 加入递归前瞻（VCT/VCF）：模拟落子后递归应子，几步之内能制胜就按这条路线下（`countdigui` 限制递归深度 ≤20）。
- 彩蛋：AI 前瞻算到能赢时会打印「嘿嘿」嘲讽；选模式输错会提示「大人再来一遍吧Orz…」等。

## 重要：文件编码是 GBK/GB2312

`Five-in-Row3.c` 是 GBK 编码（中文注释/字符串用 GBK 存的），**不是 UTF-8**。

- 用 VS Code / 记事本等打开若显示乱码，请把编码手动选为 **GB2312 / GBK**。
- 编译时（Windows 下 MinGW/GCC 或 MSVC）直接按 GBK 源码编译即可；若想转成 UTF-8 再编译，请先转码。

## 编译示例（MinGW GCC）

```bash
gcc Five-in-Row3.c -o Five-in-Row.exe
```

> 注意：程序用到 `system("clear")`（清屏），Windows 下建议改用 `system("cls")`；或用 `-finput-charset=GBK -fexec-charset=GBK` 保持中文输出正常。
