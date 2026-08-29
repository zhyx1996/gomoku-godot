# -*- coding: utf-8 -*-
src = open('rapfi_ai.gd', encoding='utf-8').read()
NL = chr(10)
T = chr(9)

def rep(old, new, name):
    global src
    assert src.count(old) == 1, 'FAILED: ' + name
    src = src.replace(old, new)
    print('ok', name)

# 1) 加载标记 + 预加载 API + 就绪查询
rep("var _web_ready := false          # 网页端：引擎已加载并完成初始化",
    "var _web_ready := false          # 网页端：引擎已加载并完成初始化" + NL +
    "var _web_load_started := false   # 网页端：引擎加载已发起（全局防重复）",
    'load flag')

rep("## 启动引擎并初始化棋盘。返回 true 表示成功。" + NL +
    "func start(difficulty: int = Difficulty.MEDIUM) -> bool:" + NL +
    "\t_difficulty = difficulty" + NL +
    "\tstop()" + NL +
    "\t# 设置难度参数（strength 与 timeout）" + NL +
    "\tstrength = DIFFICULTY_CONFIG[difficulty][\"strength\"]" + NL +
    "\ttimeout_turn = DIFFICULTY_CONFIG[difficulty][\"timeout_ms\"]" + NL +
    NL +
    "\tif IS_WEB:" + NL +
    "\t\t# 网页：触发异步加载 WASM 引擎，初始化由 poll_output() 完成" + NL +
    "\t\tJavaScriptBridge.eval(\"window.RapfiBridge && window.RapfiBridge.load('/gomoku/build/')\")" + NL +
    "\t\t_started = true" + NL +
    "\t\treturn true",
    "## 网页端预加载引擎：标题界面即开始下载（全局 flag 防重复触发）。" + NL +
    "static func preload_web_engine() -> void:" + NL +
    "\tif OS.has_feature(\"web\"):" + NL +
    "\t\tJavaScriptBridge.eval(\"if(!window.__rapfiLoading){window.__rapfiLoading=true;window.RapfiBridge&&window.RapfiBridge.load('/gomoku/build/')}\")" + NL +
    NL +
    "## 网页端引擎是否已就绪。" + NL +
    "func is_web_ready() -> bool:" + NL +
    "\treturn _web_ready" + NL +
    NL + NL +
    "## 启动引擎并初始化棋盘。返回 true 表示成功。" + NL +
    "func start(difficulty: int = Difficulty.MEDIUM) -> bool:" + NL +
    "\t_difficulty = difficulty" + NL +
    "\t# 设置难度参数（strength 与 timeout）" + NL +
    "\tstrength = DIFFICULTY_CONFIG[difficulty][\"strength\"]" + NL +
    "\ttimeout_turn = DIFFICULTY_CONFIG[difficulty][\"timeout_ms\"]" + NL +
    NL +
    "\tif IS_WEB:" + NL +
    "\t\t# 网页：引擎可能已由标题页预加载；_send_load 内部防重复，不会二次下载" + NL +
    "\t\t_send_load()" + NL +
    "\t\t_started = true" + NL +
    "\t\treturn true" + NL +
    NL +
    "\tstop()  # 原生：清掉旧进程",
    'start web')

# 2) _send_load helper + stop() 不再 END（保持已加载实例，页面关闭由浏览器回收）
rep("\tvar exe_path := _resolve_engine_path()",
    "\t_send_load()" + NL +
    NL +
    "\tvar exe_path := _resolve_engine_path()", 'send load call')

rep("## 启动引擎并初始化棋盘。返回 true 表示成功。",
    "## 网页端发起引擎加载（window.__rapfiLoading 防重复）。" + NL +
    "func _send_load() -> void:" + NL +
    "\tif not _web_load_started:" + NL +
    "\t\t_web_load_started = true" + NL +
    "\t\tJavaScriptBridge.eval(\"if(!window.__rapfiLoading){window.__rapfiLoading=true;window.RapfiBridge&&window.RapfiBridge.load('/gomoku/build/')}\")" + NL +
    NL + NL +
    "## 启动引擎并初始化棋盘。返回 true 表示成功。", 'send load fn')

old_stop = ("func stop() -> void:" + NL +
            "\tif IS_WEB:" + NL +
            "\t\t_send(\"END\")" + NL +
            "\t\t_started = false" + NL +
            "\t\t_web_ready = false" + NL +
            "\t\treturn")
new_stop = ("func stop() -> void:" + NL +
            "\tif IS_WEB:" + NL +
            "\t\t# 不发 END：已加载的引擎实例保留（新局会重置棋盘），页面关闭由浏览器回收" + NL +
            "\t\t_started = false" + NL +
            "\t\t_web_ready = false" + NL +
            "\t\treturn")
rep(old_stop, new_stop, 'stop web')

open('rapfi_ai.gd', 'w', encoding='utf-8').write(src)
print('PRELOAD APPLIED')
