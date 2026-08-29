# -*- coding: utf-8 -*-
src = open('rapfi_ai.gd', encoding='utf-8').read()
NL = chr(10)
T = chr(9)

# 1) 常量改为候选列表
old = ('const ENGINE_DIR := "engine"' + NL +
       'var IS_WEB := OS.has_feature("web")')
new = ('const ENGINE_DIR := "engine"' + NL +
       '# 引擎指令集候选（从快到慢）：启动时探测本机支持的最优版本，失败自动降级' + NL +
       'const ENGINE_CANDIDATES := [' + NL +
       '\t"pbrain-rapfi-windows-avx512vnni.exe",' + NL +
       '\t"pbrain-rapfi-windows-avx512.exe",' + NL +
       '\t"pbrain-rapfi-windows-avxvnni.exe",' + NL +
       '\t"pbrain-rapfi-windows-avx2.exe",' + NL +
       '\t"pbrain-rapfi-windows-sse.exe",' + NL +
       ']' + NL +
       'const EXE_NAME := "pbrain-rapfi-windows-avx2.exe"  # 兜底（候选全部探测失败时）' + NL +
       'var IS_WEB := OS.has_feature("web")')
assert src.count(old) == 1, 'candidates'
src = src.replace(old, new)

# 2) 成员缓存
old = 'var _zombie_threads: Array[Thread] = []  # 已停止但尚未自然退出的旧线程，防悬空释放'
new = ('var _zombie_threads: Array[Thread] = []  # 已停止但尚未自然退出的旧线程，防悬空释放' + NL +
       'var _exe_name := ""                      # 探测选定的引擎 exe（空=未探测）')
assert src.count(old) == 1, 'member'
src = src.replace(old, new)

# 3) start() 里加探测日志
old = ('\tvar exe_path := _resolve_engine_path()' + NL +
       '\tif exe_path == "" or not FileAccess.file_exists(exe_path):' + NL +
       '\t\tpush_error("Rapfi 引擎不存在: %s" % exe_path)' + NL +
       '\t\treturn false')
new = ('\tvar exe_path := _resolve_engine_path()' + NL +
       '\tif exe_path == "" or not FileAccess.file_exists(exe_path):' + NL +
       '\t\tpush_error("Rapfi 引擎不存在: %s" % exe_path)' + NL +
       '\t\treturn false' + NL +
       '\tprint("Rapfi 引擎: %s" % _exe_name)')
assert src.count(old) == 1, 'start'
src = src.replace(old, new)

# 4) _resolve_engine_path 改为自动探测
old = ('## 解析引擎 exe 的绝对路径。' + NL +
       'func _resolve_engine_path() -> String:' + NL +
       '\treturn ProjectSettings.globalize_path("res://" + ENGINE_DIR + "/" + EXE_NAME)')
new = ('## 解析引擎 exe 的绝对路径：优先探测本机支持的最优指令集版本（每次进程生命周期只探测一次）。' + NL +
       'func _resolve_engine_path() -> String:' + NL +
       '\tif _exe_name != "":' + NL +
       '\t\treturn ProjectSettings.globalize_path("res://" + ENGINE_DIR + "/" + _exe_name)' + NL +
       '\tfor candidate in ENGINE_CANDIDATES:' + NL +
       '\t\tvar path := ProjectSettings.globalize_path("res://" + ENGINE_DIR + "/" + candidate)' + NL +
       '\t\tif not FileAccess.file_exists(path):' + NL +
       '\t\t\tcontinue' + NL +
       '\t\tif candidate == EXE_NAME:' + NL +
       '\t\t\tbreak  # 兜底版本无需探测' + NL +
       '\t\tif _probe_engine(path):' + NL +
       '\t\t\t_exe_name = candidate' + NL +
       '\t\t\treturn path' + NL +
       '\t\tprint("Rapfi 引擎探测失败，降级: %s" % candidate)' + NL +
       '\t_exe_name = EXE_NAME' + NL +
       '\treturn ProjectSettings.globalize_path("res://" + ENGINE_DIR + "/" + EXE_NAME)' + NL +
       NL +
       '## 探测引擎变体能否在本机正常运行（发一局快速试探，2.5s 内应手即可用）。' + NL +
       'func _probe_engine(path: String) -> bool:' + NL +
       '\tvar result := OS.execute_with_pipe(path, PackedStringArray(["--config", "config.toml"]), false)' + NL +
       '\tif result.is_empty():' + NL +
       '\t\treturn false' + NL +
       '\tvar io: FileAccess = result["stdio"]' + NL +
       '\tvar pid: int = result["pid"]' + NL +
       '\tvar ok := false' + NL +
       '\tio.store_line("START 15")' + NL +
       '\tio.flush()' + NL +
       '\tOS.delay_msec(900)  # 权重加载' + NL +
       '\tio.store_line("INFO timeout_turn 600")' + NL +
       '\tio.store_line("INFO thread_num 4")' + NL +
       '\tio.flush()' + NL +
       '\tOS.delay_msec(100)' + NL +
       '\tio.store_line("BEGIN")' + NL +
       '\tio.flush()' + NL +
       '\tvar deadline := Time.get_ticks_msec() + 2500' + NL +
       '\twhile Time.get_ticks_msec() < deadline:' + NL +
       '\t\tvar line := io.get_line()' + NL +
       '\t\tif line != "" and line[0].is_valid_int() and line.contains(","):' + NL +
       '\t\t\tok = true' + NL +
       '\t\t\tbreak' + NL +
       '\t\tOS.delay_msec(20)' + NL +
       '\tio.store_line("END")' + NL +
       '\tio.flush()' + NL +
       '\tOS.kill(pid)' + NL +
       '\treturn ok')
assert src.count(old) == 1, 'resolve'
src = src.replace(old, new)

open('rapfi_ai.gd', 'w', encoding='utf-8').write(src)
print('ISA auto-select applied')
