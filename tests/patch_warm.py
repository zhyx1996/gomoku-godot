# -*- coding: utf-8 -*-
"""rapfi_ai.gd 预热状态机补丁（短锚点版）。"""
src = open('rapfi_ai.gd', encoding='utf-8').read()
NL = chr(10)
T = chr(9)
done = 0


def rep(old, new, name):
    global src, done
    assert src.count(old) == 1, 'FAILED: ' + name
    src = src.replace(old, new)
    done += 1
    print('ok', name)


rep("var _web_warming := false",
    "var _web_warming := false" + NL +
    "var _web_inited := false         # 网页端：引擎实例已就绪并完成首配（与预热完成区分）",
    'inited member')

rep("\tif not _web_ready:", "\tif not _web_inited:", 'init cond')

rep("\t\t\t_web_ready = true", "\t\t\t_web_inited = true", 'init set')

rep("\t\t\tnew_game()" + NL + "\t\t\tweb_ready.emit()",
    "\t\t\tnew_game()" + NL +
    "\t\t\t# NNUE 预热：首搜需解压 40MB 权重（十余秒），用 10ms 短搜提前触发，" + NL +
    "\t\t\t# 完成前 is_web_ready()=false（状态栏显示「引擎加载中」，think_async 自动等待）" + NL +
    "\t\t\t_web_warming = true" + NL +
    "\t\t\t_send(\"INFO timeout_turn 10\")" + NL +
    "\t\t\t_send(\"BEGIN\")",
    'warmup trigger')

rep("\t\telse:" + NL +
    "\t\t\treturn" + NL +
    "\tfor line in _poll_lines():",
    "\t\telse:" + NL +
    "\t\t\treturn" + NL +
    "\telif _web_warming:" + NL +
    "\t\treturn  # 预热搜索中：本帧不处理输出（出子后在下方标记完成）" + NL +
    "\tfor line in _poll_lines():",
    'warming gate')

rep("\t\tif handled is Vector2i:" + NL +
    "\t\t\tmove_ready.emit(handled)",
    "\t\tif handled is Vector2i:" + NL +
    "\t\t\tif _web_warming:" + NL +
    "\t\t\t\t# 预热搜索出子：恢复配置并宣布就绪（该子无人监听，丢弃）" + NL +
    "\t\t\t\t_web_warming = false" + NL +
    "\t\t\t\t_web_ready = true" + NL +
    "\t\t\t\t_apply_config()" + NL +
    "\t\t\t\tnew_game()" + NL +
    "\t\t\t\tweb_ready.emit()" + NL +
    "\t\t\t\tcontinue" + NL +
    "\t\t\tmove_ready.emit(handled)",
    'warm complete')

rep("\t\t_started = false" + NL +
    "\t\t_web_ready = false" + NL +
    "\t\treturn",
    "\t\t_started = false" + NL +
    "\t\t_web_ready = false" + NL +
    "\t\t_web_inited = false" + NL +
    "\t\t_web_warming = false" + NL +
    "\t\treturn",
    'stop reset')

assert done == 7, done
open('rapfi_ai.gd', 'w', encoding='utf-8').write(src)
print('ALL %d APPLIED' % done)
