# -*- coding: utf-8 -*-
src = open('rapfi_ai.gd', encoding='utf-8').read()
NL = chr(10)
T = chr(9)

def rep(old, new, name):
    global src
    assert src.count(old) == 1, 'FAILED: ' + name
    src = src.replace(old, new)
    print('ok', name)

rep("var _web_warming := false        # 网页端：NNUE 预热搜索进行中（首搜前解压权重，避免第一手等待十余秒）",
    "var _web_warming := false        # 网页端：NNUE 预热搜索进行中（首搜前解压权重，避免第一手等待十余秒）" + NL +
    "var _web_inited := false         # 网页端：引擎实例已就绪并完成首配（与预热完成区分）",
    'inited member')

rep("\tif not _web_ready:" + NL +
    "\t\tvar ok: bool = JavaScriptBridge.eval(\"window.RapfiBridge ? window.RapfiBridge.isReady() : false\")" + NL +
    "\t\tif ok:" + NL +
    "\t\t\t_started = true" + NL +
    "\t\t\tthreads = mini(8, maxi(1, OS.get_processor_count()))" + NL +
    "\t\t\t# 注：实测线程>8 或发送大 TIMEOUT_MATCH 会让 WASM 引擎搜索异常拉长，保持 8 线程" + NL +
    "\t\t\t_apply_config()" + NL +
    "\t\t\tnew_game()" + NL +
    "\t\t\t# NNUE 预热：首搜需解压 40MB 权重（十余秒），用 10ms 短搜提前触发，" + NL +
    "\t\t\t# 完成前 is_web_ready()=false（状态栏显示「引擎加载中」，think_async 自动等待）" + NL +
    "\t\t\t_web_warming = true" + NL +
    "\t\t\t_send(\"INFO timeout_turn 10\")" + NL +
    "\t\t\t_send(\"BEGIN\")" + NL +
    "\t\telse:" + NL +
    "\t\t\treturn" + NL +
    "\tfor line in _poll_lines():",
    "\tif not _web_inited:" + NL +
    "\t\tvar ok: bool = JavaScriptBridge.eval(\"window.RapfiBridge ? window.RapfiBridge.isReady() : false\")" + NL +
    "\t\tif ok:" + NL +
    "\t\t\t_web_inited = true" + NL +
    "\t\t\t_started = true" + NL +
    "\t\t\tthreads = mini(8, maxi(1, OS.get_processor_count()))" + NL +
    "\t\t\t# 注：实测线程>8 或发送大 TIMEOUT_MATCH 会让 WASM 引擎搜索异常拉长，保持 8 线程" + NL +
    "\t\t\t_apply_config()" + NL +
    "\t\t\tnew_game()" + NL +
    "\t\t\t# NNUE 预热：首搜需解压 40MB 权重（十余秒），用 10ms 短搜提前触发，" + NL +
    "\t\t\t# 完成前 is_web_ready()=false（状态栏显示「引擎加载中」，think_async 自动等待）" + NL +
    "\t\t\t_web_warming = true" + NL +
    "\t\t\t_send(\"INFO timeout_turn 10\")" + NL +
    "\t\t\t_send(\"BEGIN\")" + NL +
    "\t\telse:" + NL +
    "\t\t\treturn" + NL +
    "\telif _web_warming:" + NL +
    "\t\treturn  # 预热搜索中：本帧只等结果（行处理在下方循环，出子后标记完成）" + NL +
    "\tfor line in _poll_lines():",
    'init state split')

# 预热完成分支里补 _web_inited 已真、无需改；同时 stop() 复位两个状态
rep("\t\t# 不发 END：已加载的引擎实例保留（新局会重置棋盘），页面关闭由浏览器回收" + NL +
    "\t\t_started = false" + NL +
    "\t\t_web_ready = false" + NL +
    "\t\treturn",
    "\t\t# 不发 END：已加载的引擎实例保留（新局会重置棋盘），页面关闭由浏览器回收" + NL +
    "\t\t_started = false" + NL +
    "\t\t_web_ready = false" + NL +
    "\t\t_web_inited = false" + NL +
    "\t\t_web_warming = false" + NL +
    "\t\treturn", 'stop reset')

open('rapfi_ai.gd', 'w', encoding='utf-8').write(src)
print('WARM STATE FIXED')
