# Gomoku（五子棋）

基于 **Godot 4.7** 实现的五子棋游戏，支持人人对战与人机对战（NNUE 神经网络引擎），内置 Freestyle / Standard / Renju（连珠）三种规则，Renju 规则下完整实现黑方禁手（三三、四四、长连）判定。

## 特性

- 🎮 人人对战 / 人机对战（可调难度，AI 思考可中断）
- 🧠 强 AI：内置 [Rapfi](https://github.com/dhbloo/rapfi) NNUE 引擎（Piskvork 协议，自动选择 SSE/AVX2/AVX512 指令集）
- 📏 规则：Freestyle（无禁手）/ Standard（黑长连禁）/ Renju（黑三三、四四、长连禁手）
- ✨ 制胜棋型识别：活四、双冲四、四三、双活三自动触发「流光」特效（彗星光带沿棋型循环流动）
- 🎨 三套主题：星夜（默认）、木质、浅色；两套界面风格：流光（默认，非对称标题+装饰棋盘+紫金配色）/ 经典（可随时切回）
- 🖥️ 自适应布局：expand 拉伸，任意分辨率/宽高比下棋盘组自动居中、无黑边
- 💾 设置持久化：界面风格、主题、规则、棋盘、难度、思考档位等自动保存（user://settings.cfg）
- 🌐 支持 Web 导出（SharedArrayBuffer 跨域隔离）

## 目录结构

```
├── gomoku.gd          # 游戏主逻辑（棋型检测、禁手、UI、对战流程）
├── classic_ai.gd      # 本地经典 AI（棋型打分 + VCT/VCF 前瞻）
├── rapfi_ai.gd        # Rapfi 引擎封装（Piskvork 协议子进程通信）
├── node_2d.tscn       # 主场景
├── engine/            # Rapfi 引擎可执行文件与权重（第三方组件，见其 README）
├── fonts/             # 思源黑体（Noto Sans CJK SC，OFL 许可）
├── gomoku-c/          # 附：早期 C 语言控制台版五子棋（源码）
├── tests/             # headless 回归测试
│   └── threat_test.gd #   制胜棋型/禁手检测 14 用例
└── addons/godot_mcp/  # Godot MCP 调试插件（可选，不影响游戏）
```

## 运行

用 Godot 4.7+ 打开本项目，或：

```bash
godot --path .
```

## 运行测试

```bash
godot --headless --script tests/threat_test.gd --path .
```

14 个用例覆盖活三/跳活三/活四/冲四/双四/四三/双三及 Renju 禁手回落行为。

视觉与冒烟验收（需窗口环境，产物在 `screenshots/`）：

```bash
godot --path . --script tests/screenshot_driver.gd   # 自动驱动标题/棋型流光/胜利特效并截图
```

## 实时分析面板

对局中 AI 思考时，右侧面板实时显示引擎搜索状态（每行悬停有说明）：

| 指标 | 含义 |
| --- | --- |
| 搜索深度 | 引擎已搜索的层数，数字越大当前评估越可靠 |
| 局面评分 | 引擎对局面的打分：正数黑棋占优、负数白棋占优；出现 ±M\<n\> 表示已算出 n 步内强制取胜 |
| 胜率 | 引擎估算的黑棋获胜概率 |
| 计算速度 | 引擎每秒评估的局面数量 |
| 已算局面 | 本次思考累计计算过的局面总数 |
| 路线 1~5 | 引擎当前认为的最佳行棋路线（按顺序预测双方后续落子），随搜索实时更新 |

思考中棋盘上的红色脉冲圆点是引擎当前算出的最佳点（同官方 Gomocalc），落子后消失。以上数据由 Rapfi 的 REALTIME/INFO 消息驱动（`INFO DETAIL 3`）。

## Web 导出与部署

推送 master 自动构建并部署到 GitHub Pages（https://zhyx1996.github.io/gomoku-godot/，workflow: deploy-pages.yml）。
手动导出：

```bash
godot --headless --export-release "Web"
```

导出配置见 `export_presets.cfg`（输出至 `build/web/`，已排除 engine/tests/screenshots 等非运行时资源）。Web 版需要跨域隔离头（COOP/COEP）以启用多线程。

## 第三方组件

| 组件 | 许可 | 来源 |
| --- | --- | --- |
| [Rapfi](https://github.com/dhbloo/rapfi) 引擎 | GPL-3.0 | dhbloo/rapfi |
| Rapfi 神经网络权重 | CC0-1.0 | [dhbloo/rapfi-networks](https://github.com/dhbloo/rapfi-networks) |
| [Noto Sans CJK SC](https://fonts.google.com/noto) 字体 | SIL OFL 1.1 | Google Noto |
| godot_mcp 插件 | 见 addons/godot_mcp/LICENSE | Coding-Solo/GodotMCP |

详见 `engine/README.md`。
