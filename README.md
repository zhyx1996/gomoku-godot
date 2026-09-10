# Gomoku（五子棋）

基于 Godot 4.7 的五子棋游戏，支持人人 / 人机对战，内置 [Rapfi](https://github.com/dhbloo/rapfi) NNUE 引擎，提供 Freestyle / Standard / Renju（连珠）三种规则，Renju 下完整实现黑方禁手（三三、四四、长连）判定。

## 特性

- 人人 / 人机对战，难度可调，AI 思考可中断
- 内置 Rapfi 引擎（Piskvork 协议，自动选择 SSE/AVX2/AVX512 指令集）
- 制胜棋型（活四 / 双冲四 / 四三 / 双活三）自动触发「流光」特效
- 流光 / 经典两套界面风格 × 星夜 / 木质 / 浅色三套主题，可随时切换
- 任意分辨率自适应布局，无黑边；设置自动持久化（user://settings.cfg）
- 实时分析面板：搜索深度 / 局面评分 / 胜率 / 计算速度 / 最佳路线 1~5

## 运行

用 Godot 4.7+ 打开本项目，或：

```bash
godot --path .
```

## 测试

```bash
godot --headless --script tests/threat_test.gd --path .   # 棋型 / 禁手检测 14 用例
godot --path . --script tests/screenshot_driver.gd        # 视觉冒烟（需窗口，产物在 screenshots/）
```

## 目录结构

```
gomoku.gd        # 游戏主逻辑（棋型检测、禁手、UI、对战流程）
classic_ai.gd    # 本地经典 AI（棋型打分 + VCT/VCF 前瞻）
rapfi_ai.gd      # Rapfi 引擎封装（Piskvork 协议子进程通信）
node_2d.tscn     # 主场景
engine/          # Rapfi 可执行文件与权重（第三方，见 engine/README.md）
tests/           # headless 回归测试（threat_test 等）
web/             # Web 导出用 COI Service Worker（仓库内修补版）
fonts/           # 思源黑体（Noto Sans CJK SC，OFL）
gomoku-c/        # 附：早期 C 语言控制台版五子棋
```

## 实时分析面板

AI 思考时，右侧面板实时显示搜索深度、局面评分（正数黑优 / 负数白优，±M\<n\> 表示已算出 n 步内强制取胜）、胜率、计算速度（nps）、已算局面数与最佳路线 1~5，随搜索实时更新；棋盘上的红色脉冲圆点为当前最佳点（同官方 Gomocalc），落子后消失。数据来自 Rapfi 的 REALTIME/INFO 消息（`INFO DETAIL 3`），每行悬停有详细说明。

## Web 导出与部署

- 推送 `master` 自动触发 [deploy-pages.yml](.github/workflows/deploy-pages.yml) 构建并部署到 GitHub Pages：[**https://zhyx1996.github.io/gomoku-godot/**](https://zhyx1996.github.io/gomoku-godot/)（也支持手动触发）
- **页面并非本仓库的自包含产物**：引擎权重 / WASM（`/gomoku/build/`）与桥接脚本（`/gomoku/rapfi_bridge.js`）由 **zhyx1996.github.io** 仓库在同一域名下提供，workflow 构建时会移除导出目录内的陈旧副本；更新引擎资源需改那个仓库
- 手动导出：`godot --headless --export-release "Web"`（配置见 `export_presets.cfg`，输出至 `build/web/`，已排除 engine / tests / screenshots 等非运行时资源）；Web 版需要 COOP/COEP 跨域隔离头以启用引擎多线程

## 第三方组件

| 组件 | 许可 | 来源 |
| --- | --- | --- |
| [Rapfi](https://github.com/dhbloo/rapfi) 引擎 | GPL-3.0 | dhbloo/rapfi |
| Rapfi 神经网络权重 | CC0-1.0 | [dhbloo/rapfi-networks](https://github.com/dhbloo/rapfi-networks) |
| [Noto Sans CJK SC](https://fonts.google.com/noto) 字体 | SIL OFL 1.1 | Google Noto |
| godot_mcp 插件 | 见 addons/godot_mcp/LICENSE | Coding-Solo/GodotMCP |
