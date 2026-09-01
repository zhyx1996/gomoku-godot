extends RefCounted
## Rapfi 五子棋引擎封装（Piskvork 协议）
## 通过持久子进程 stdin/stdout 与 Rapfi 引擎通信。
##
## 协议要点：
##   - START n           初始化 n×n 棋盘
##   - INFO RULE r       规则（0 无禁手 / 1 标准 / 2 有禁手）
##   - INFO STRENGTH n   棋力 0~100
##   - INFO TIMEOUT_TURN ms   每步思考时间上限（毫秒）
##   - INFO THREAD_NUM n 线程数
##   - INFO MAX_DEPTH n  最大深度
##   - INFO SHOW_DETAIL n  0 无 / 1 实时 / 2 详情 / 3 实时+详情
##   - INFO CAUTION_FACTOR n 选点范围 0~5
##   - INFO HASH_SIZE n  置换表大小（KB）
##   - BEGIN              引擎先手
##   - TURN x,y           玩家落子后引擎应手
##   - BOARD x,y,side ... DONE  重建局面
##   - YXBOARD            重建局面并思考
##   - YXNBEST n          多点分析（n 个最佳点）
##   - YXSTOP             停止思考
##   - 引擎 stdout：MESSAGE / INFO / FORBID / ERROR / "x,y"（走法）

const ENGINE_DIR := "engine"
# 引擎指令集候选（从快到慢）：启动时探测本机支持的最优版本，失败自动降级
const ENGINE_CANDIDATES := [
	"pbrain-rapfi-windows-avx512vnni.exe",
	"pbrain-rapfi-windows-avx512.exe",
	"pbrain-rapfi-windows-avxvnni.exe",
	"pbrain-rapfi-windows-avx2.exe",
	"pbrain-rapfi-windows-sse.exe",
]
const EXE_NAME := "pbrain-rapfi-windows-avx2.exe"  # 兜底（候选全部探测失败时）
var IS_WEB := OS.has_feature("web")

## 网页端引擎返回走法时发出（异步思考用）。
signal move_ready(move: Vector2i)

## 网页端引擎加载完成时发出。
signal web_ready

var board_size := 15

## 难度等级
enum Difficulty { EASY, MEDIUM, HARD }

## 各难度对应的 STRENGTH 与每步思考时间上限（毫秒）
const DIFFICULTY_CONFIG := {
	Difficulty.EASY:   {"strength": 30, "timeout_ms": 500},
	Difficulty.MEDIUM: {"strength": 70, "timeout_ms": 1500},
	Difficulty.HARD:   {"strength": 100, "timeout_ms": 5000},
}

# ---- 引擎配置状态 ----
var rule := 0                  # 0 无禁手 / 1 标准 / 2 有禁手
var strength := 70             # 棋力 0~100
var timeout_turn := 1500       # 每步思考时间（毫秒）
var threads := 0               # 线程数（0 表示启动时自动设为 CPU 核心数）
var max_depth := 100           # 最大深度
var show_detail := 3           # 输出详细度（3=实时+详情，驱动红点与面板）
var caution_factor := 3        # 选点范围 0~5
var hash_size := 128           # 置换表大小（MiB）
var nbest := 1                 # 多点分析数
var pondering := false         # 后台思考

var _pid: int = -1
var _stdio: FileAccess = null
var _stderr: FileAccess = null
var _difficulty: int = Difficulty.MEDIUM
var _started := false
var _web_ready := false          # 网页端：引擎已加载并完成初始化
var _web_warming := false        # 网页端：NNUE 预热搜索进行中（首搜需解压 40MB 权重）
var _web_inited := false         # 网页端：引擎实例已就绪并完成首配（与预热完成区分）
var _web_load_started := false   # 网页端：引擎加载已发起（全局防重复）
var _stop_requested := false     # 已请求停止当前思考（用于让异步 await 返回 -1）
var _think_thread: Thread = null      # 原生端：后台思考线程（主线程保持流畅）
var _on_thread := false               # 当前是否处于后台线程读循环（分析数据转 deferred 用）
var _zombie_threads: Array[Thread] = []  # 已停止但尚未自然退出的旧线程，防悬空释放
var _exe_name := ""                      # 探测选定的引擎 exe（空=未探测）

# 分析数据回调（引擎每输出一条 INFO，调用此 Callable）
var analysis_callback: Callable = Callable()


## 网页端预加载引擎：标题界面即开始下载（window.__rapfiLoading 防重复触发）。
static func preload_web_engine() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if(!window.__rapfiLoading){window.__rapfiLoading=true;window.RapfiBridge&&window.RapfiBridge.load('/gomoku/build/')}")

## 网页端引擎是否已就绪。
func is_web_ready() -> bool:
	return _web_ready

## 网页端发起引擎加载（防重复）。
func _send_load() -> void:
	if not _web_load_started:
		_web_load_started = true
		JavaScriptBridge.eval("if(!window.__rapfiLoading){window.__rapfiLoading=true;window.RapfiBridge&&window.RapfiBridge.load('/gomoku/build/')}")

## 启动引擎并初始化棋盘。返回 true 表示成功。
func start(difficulty: int = Difficulty.MEDIUM) -> bool:
	_difficulty = difficulty

	# 设置难度参数（strength 与 timeout）
	strength = DIFFICULTY_CONFIG[difficulty]["strength"]
	timeout_turn = DIFFICULTY_CONFIG[difficulty]["timeout_ms"]

	if IS_WEB:
		# 网页：引擎可能已由标题页预加载；_send_load 防重复，不会二次下载
		_send_load()
		_started = true
		return true

	stop()  # 原生：清掉旧进程
	var exe_path := _resolve_engine_path()
	if exe_path == "" or not FileAccess.file_exists(exe_path):
		push_error("Rapfi 引擎不存在: %s" % exe_path)
		return false
	print("Rapfi 引擎: %s" % _exe_name)

	var result := OS.execute_with_pipe(exe_path, PackedStringArray(["--config", "config.toml"]), false)
	if result.is_empty():
		push_error("无法启动 Rapfi 引擎进程")
		return false

	_pid = result["pid"]
	_stdio = result["stdio"]
	_stderr = result["stderr"]
	_started = false

	_wait_msec(300)
	_drain()

	# 使用全部 CPU 核心（Rapfi 原生默认即多线程并行搜索，之前被压成 1 线程导致速度慢）
	threads = maxi(1, OS.get_processor_count())
	_apply_config()
	# 简单档：收窄选点并限深，保证新手面对的是「秒回」且明显放水的对手
	if difficulty == Difficulty.EASY:
		_send("INFO CAUTION_FACTOR 0")
		_send("INFO MAX_DEPTH 8")

	_wait_msec(80)
	_drain()

	if not new_game():
		return false

	_started = true
	warmup()
	return true


## 应用全部引擎配置（INFO 命令）。
func _apply_config() -> void:
	_send("INFO RULE %d" % rule)
	_send("INFO STRENGTH %d" % strength)
	_send("INFO TIMEOUT_TURN %d" % timeout_turn)
	_send("INFO THREAD_NUM %d" % threads)
	_send("INFO MAX_DEPTH %d" % max_depth)
	_send("INFO SHOW_DETAIL %d" % show_detail)
	_send("INFO CAUTION_FACTOR %d" % caution_factor)
	# INFO HASH_SIZE 单位为 KB，hash_size 按 MiB 存，故乘 1024（之前直接发 128 被当成 128KB）
	_send("INFO HASH_SIZE %d" % (hash_size * 1024))
	_send("INFO PONDERING %d" % (1 if pondering else 0))


## 重置引擎棋盘（不重启进程）。返回 true 表示成功。
func new_game() -> bool:
	if IS_WEB:
		_send("START %d" % board_size)
		return true
	if _stdio == null:
		return false
	_send("START %d" % board_size)
	_wait_msec(120)
	_drain()
	return true


## 更新难度参数（引擎复用时不重启进程）。
## 必须在「不在搜索中」时调用：完整配置含 THREAD_NUM/HASH_SIZE 等重分配型参数，
## 搜索中下发会让引擎丢弃当前搜索（软锁根因）。
## 预热中只记录数值，预热完成后的 _apply_config 会自动带上最新值。
func set_difficulty(difficulty: int) -> void:
	_difficulty = difficulty
	strength = DIFFICULTY_CONFIG[difficulty]["strength"]
	timeout_turn = DIFFICULTY_CONFIG[difficulty]["timeout_ms"]
	if _web_warming:
		return
	_apply_config()


## 设置单项配置并立即下发到引擎。
func set_config(key: String, value: int) -> void:
	match key:
		"rule":
			rule = value
		"strength":
			strength = value
		"timeout_turn":
			timeout_turn = value
		"threads":
			# 网页端 >8 线程实测吞吐暴跌（依据见 poll_output 初始化注释），手动/自动档一并封顶
			threads = mini(8, value) if IS_WEB else value
		"max_depth":
			max_depth = value
		"show_detail":
			show_detail = value
		"caution_factor":
			caution_factor = value
		"hash_size":
			hash_size = value
		"pondering":
			pondering = value != 0
	_apply_config()


## 预热引擎：触发一次极短思考，让 NNUE 权重加载进内存。
func warmup() -> void:
	if IS_WEB:
		# 网页端 NNUE 权重在首次搜索时自动加载
		return
	if _stdio == null:
		return
	_send("INFO TIMEOUT_TURN 10")
	_send("START %d" % board_size)
	_wait_msec(50)
	_drain()
	_send("BEGIN")
	var deadline: int = Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline:
		var line := _stdio.get_line()
		if line != "":
			_send("YXSTOP")
			break
		_wait_msec(10)
	_drain()
	# 恢复正确时限并重置
	_apply_config()
	new_game()


## 停止引擎子进程。
func stop() -> void:
	if IS_WEB:
		# 不发 END：已加载实例保留（新局会重置棋盘），页面关闭由浏览器回收
		_started = false
		_web_ready = false
		_web_inited = false
		_web_warming = false
		return
	if _pid != -1:
		if _stdio != null:
			_send("END")
		OS.kill(_pid)
	_pid = -1
	_stdio = null
	_stderr = null
	_started = false


## 引擎进程是否仍然存活（Web 端视为存活）。
func is_engine_alive() -> bool:
	if IS_WEB:
		return _started
	return _pid != -1 and OS.is_process_running(_pid)


## 让 AI 执先手（棋盘为空时调用）。返回 AI 落子坐标。
func think_first() -> Vector2i:
	if not _started or _stdio == null:
		return Vector2i(-1, -1)
	_send("BEGIN")
	return _wait_coord()


## 玩家已落子后，让 AI 思考应手。返回 AI 落子坐标。
func think(player_move: Vector2i) -> Vector2i:
	if not _started or _stdio == null:
		return Vector2i(-1, -1)
	_send("TURN %d,%d" % [player_move.x, player_move.y])
	return _wait_coord()


## 异步思考应手：原生在后台线程阻塞等引擎，主线程零冻结；网页走 JS 桥轮询。
func think_async(player_move: Vector2i) -> Vector2i:
	if not _started:
		return Vector2i(-1, -1)
	if IS_WEB and not _web_ready:
		await web_ready
	if not IS_WEB and _think_thread != null and _think_thread.is_alive():
		return Vector2i(-1, -1)  # 上一步仍在收尾，丢弃本次请求
	_stop_requested = false
	_send("TURN %d,%d" % [player_move.x, player_move.y])
	if IS_WEB:
		var web_move: Vector2i = await move_ready
		return Vector2i(-1, -1) if _stop_requested else web_move
	_think_thread = Thread.new()
	_think_thread.start(_thread_wait_coord)
	var move: Vector2i = await move_ready
	if _think_thread != null and not _think_thread.is_alive():
		_think_thread.wait_to_finish()  # 已结束，回收以消除销毁警告
	if _stop_requested:
		return Vector2i(-1, -1)
	return move


## 异步先手（BEGIN），线程策略同上。
func think_first_async() -> Vector2i:
	if not _started:
		return Vector2i(-1, -1)
	if IS_WEB and not _web_ready:
		await web_ready
	if not IS_WEB and _think_thread != null and _think_thread.is_alive():
		return Vector2i(-1, -1)
	_stop_requested = false
	_send("BEGIN")
	if IS_WEB:
		var web_move: Vector2i = await move_ready
		return Vector2i(-1, -1) if _stop_requested else web_move
	_think_thread = Thread.new()
	_think_thread.start(_thread_wait_coord)
	var move: Vector2i = await move_ready
	if _think_thread != null and not _think_thread.is_alive():
		_think_thread.wait_to_finish()
	if _stop_requested:
		return Vector2i(-1, -1)
	return move


## 后台线程主体：阻塞读引擎输出直到走出法（主线程不受影响）。
func _thread_wait_coord() -> void:
	_on_thread = true
	var mv := _wait_coord()
	_on_thread = false
	call_deferred("_emit_move_ready", mv)


## 线程结果经 deferred 投递回主线程再发信号（信号跨线程直发不安全）。
func _emit_move_ready(mv: Vector2i) -> void:
	move_ready.emit(mv)


## 分析当前局面（不落子，只输出分析数据）。
## board: 二维数组 0/1/2；ai_color: AI 执子。
func analyze(board: Array, ai_color: int, nbest_count: int = 1) -> void:
	if not _started or (not IS_WEB and _stdio == null):
		return
	# 重建局面
	_send("START %d" % board_size)
	if not IS_WEB:
		_wait_msec(50)
		_drain()
	_send_board(board, ai_color)
	# 触发多点分析
	_send("YXNBEST %d" % nbest_count)


## 停止当前思考。原生：置停标志并给引擎 1.2s 宽限输出候着走法，随后后台线程自行退出。
func stop_thinking() -> void:
	_stop_requested = true
	_send("YXSTOP")


## 重建引擎棋盘（悔棋后同步用）：START 后重发全部棋子。
func sync_board(board: Array, ai_color: int) -> void:
	if not _started or (not IS_WEB and _stdio == null):
		return
	_send("START %d" % board_size)
	if not IS_WEB:
		_wait_msec(50)
		_drain()
	_send_board(board, ai_color)


## 阻塞等待引擎返回坐标走法，同时把 INFO 输出转发给 analysis_callback。
## 收到停止请求后最多再等 1.2s（YXSTOP 后引擎会尽快吐出当前最佳点）。
func _wait_coord() -> Vector2i:
	var timeout_ms: int = timeout_turn + 8000
	var deadline: int = Time.get_ticks_msec() + timeout_ms

	while Time.get_ticks_msec() < deadline:
		# 先把管道读空再等待：引擎 show_detail=2 时每秒产出数千行 INFO，
		# 若每读一行就 sleep(10ms)，管道写满会让引擎搜索被限速（50ms 的搜索被拖到 3.4s）
		var got_line := false
		while true:
			var line := _stdio.get_line()
			if line == "":
				break
			got_line = true
			var handled: Variant = _handle_output_line(line)
			if handled is Vector2i:
				return handled
		if got_line:
			continue
		elif _stop_requested and Time.get_ticks_msec() > deadline - timeout_ms + 1200:
			break
		_wait_msec(10)
	return Vector2i(-1, -1)


## 处理引擎 stdout 的一行输出。
## 返回：Vector2i（若为走法坐标）、或 null（继续等待）。
func _handle_output_line(line: String) -> Variant:
	var t := line.strip_edges()
	if t == "" or t == "OK":
		return null

	# 走法坐标（"x,y"）
	if not t.begins_with("MESSAGE") and not t.begins_with("INFO") \
			and not t.begins_with("FORBID") and not t.begins_with("ERROR") \
			and not t.begins_with("SWAP"):
		var parts := t.split(",")
		if parts.size() == 2:
			var x := parts[0].strip_edges().to_int()
			var y := parts[1].strip_edges().to_int()
			if x >= 0 and x < board_size and y >= 0 and y < board_size:
				return Vector2i(x, y)

	# INFO 分析输出（转发给回调）
	if t.begins_with("INFO"):
		_parse_info(t)
	elif t.begins_with("MESSAGE"):
		_parse_message(t)
	elif t.begins_with("FORBID"):
		_parse_forbid(t)

	return null


## 解析 INFO 输出（DEPTH/SELDEPTH/NODES/SPEED/EVAL/WINRATE/BESTLINE/PV）。
func _parse_info(line: String) -> void:
	var body := line.substr(5).strip_edges()  # 去掉 "INFO "
	var sp := body.find(" ")
	if sp == -1:
		return
	var key := body.substr(0, sp)
	var val := body.substr(sp + 1).strip_edges()

	var data := {}
	match key:
		"PV":
			data = {"pv": val}
		"NUMPV":
			data = {"numpv": val.to_int()}
		"DEPTH":
			data = {"depth": val.to_int()}
		"SELDEPTH":
			data = {"seldepth": val.to_int()}
		"NODES":
			data = {"nodes": val.to_int()}
		"TOTALNODES":
			data = {"totalnodes": val.to_int()}
		"TOTALTIME":
			data = {"totaltime": val.to_int()}
		"SPEED":
			data = {"speed": val.to_int()}
		"EVAL":
			data = {"eval": val}
		"WINRATE":
			data = {"winrate": val.to_float()}
		"BESTLINE":
			var coords := []
			for p in val.split(" "):
				var c := p.split(",")
				if c.size() == 2:
					coords.append(Vector2i(c[0].to_int(), c[1].to_int()))
			data = {"bestline": coords}
		_:
			return

	_dispatch_analysis(data)


## 后台线程产生的分析数据经 deferred 回主线程再分发（跨线程直调不安全）。
func _emit_analysis(data: Dictionary) -> void:
	if not analysis_callback.is_null():
		analysis_callback.call(data)


## 解析 MESSAGE 输出（REALTIME BEST/LOST、Depth 等）。
func _parse_message(line: String) -> void:
	var body := line.substr(8).strip_edges()  # 去掉 "MESSAGE "
	if body.begins_with("REALTIME"):
		var parts := body.split(" ")
		if parts.size() >= 3:
			var coord := parts[2].split(",")
			if coord.size() == 2:
				var data := {
					"realtime": parts[1],
					"pos": Vector2i(coord[0].to_int(), coord[1].to_int()),
				}
				_dispatch_analysis(data)


## 解析 FORBID 输出（禁手点列表，每点 4 字符：两位 x + 两位 y）。
func _parse_forbid(line: String) -> void:
	var body := line.substr(7).strip_edges().replace(" ", "")
	var cells: Array = []
	var i := 0
	while i + 3 < body.length():
		var x := body.substr(i, 2).to_int()
		var y := body.substr(i + 2, 2).to_int()
		if x >= 0 and x < board_size and y >= 0 and y < board_size:
			cells.append(Vector2i(x, y))
		i += 4
	if not analysis_callback.is_null():
		_dispatch_analysis({"forbid": cells})


## 统一分析回调分发：后台线程产生的一律 deferred 回主线程再调（回调里会动 UI，跨线程直调不安全）。
func _dispatch_analysis(data: Dictionary) -> void:
	if analysis_callback.is_null():
		return
	if _on_thread:
		_emit_analysis.call_deferred(data)
	else:
		analysis_callback.call(data)


## 请求禁手点：重建局面后 YXSHOWFORBID，引擎会输出 FORBID。
func show_forbid(board: Array, ai_color: int) -> void:
	if not _started or (not IS_WEB and _stdio == null):
		return
	_send("START %d" % board_size)
	if not IS_WEB:
		_wait_msec(50)
		_drain()
	_send_board(board, ai_color)
	_send("YXSHOWFORBID")


## 重建局面（BOARD ... DONE）。原生走管道逐行写，网页走单条命令。
func _send_board(board: Array, ai_color: int) -> void:
	if IS_WEB:
		var parts: Array = ["BOARD"]
		for y in range(board_size):
			for x in range(board_size):
				var v: int = board[y][x]
				if v == 0:
					continue
				var side := 1 if v == ai_color else 2
				parts.append("%d,%d,%d" % [x, y, side])
		parts.append("DONE")
		_send(" ".join(parts))
	else:
		_send("BOARD")
		for y in range(board_size):
			for x in range(board_size):
				var v: int = board[y][x]
				if v == 0:
					continue
				var side := 1 if v == ai_color else 2
				_stdio.store_line("%d,%d,%d" % [x, y, side])
		_stdio.store_line("DONE")
		_stdio.flush()


## 清空引擎当前已产生的 stdout 输出。
func _drain() -> void:
	if IS_WEB:
		_poll_lines()
		return
	if _stdio == null:
		return
	var n := 0
	while n < 10000:
		var line := _stdio.get_line()
		if line == "":
			break
		n += 1


## 发送一行命令到引擎 stdin 并 flush。
func _send(cmd: String) -> void:
	if IS_WEB:
		JavaScriptBridge.eval("window.RapfiBridge && window.RapfiBridge.send(%s)" % _js_quote(cmd))
	elif _stdio != null:
		_stdio.store_line(cmd)
		_stdio.flush()


## 从引擎批量读取输出（网页走 JS 队列一次取空，原生走管道单行）。
func _poll_lines() -> PackedStringArray:
	if IS_WEB:
		var all := str(JavaScriptBridge.eval("window.RapfiBridge ? window.RapfiBridge.pollAll() : ''"))
		if all == "":
			return PackedStringArray()
		return all.split("\n")
	if _stdio == null:
		return PackedStringArray()
	var line := _stdio.get_line()
	if line == "":
		return PackedStringArray()
	return PackedStringArray([line])


## 网页端每帧轮询：引擎就绪后完成初始化；处理输出；收到走法时发信号。
func poll_output() -> void:
	if not IS_WEB:
		return
	if not _web_inited:
		var ok: bool = JavaScriptBridge.eval("window.RapfiBridge ? window.RapfiBridge.isReady() : false")
		if ok:
			_web_inited = true
			_started = true
			# 实测线程>8 会让 WASM 搜索吞吐暴跌（32 核机 16 线程仅 7 万 nps、8 线程 116 万+），上限保持 8
			threads = mini(8, maxi(1, OS.get_processor_count()))
			_apply_config()
			_send("INFO TIMEOUT_MATCH 9999000")
			new_game()
			# NNUE 预热：首搜需解压 40MB 权重（十余秒），用短搜提前触发。
			# 300ms 足够解压权重；加长到 1s 实测无额外收益（线程池瓶颈不在预热时长，
			# 而是游戏进程首次 think 的稀疏棋盘搜索与 FPS 帧速率共同决定）。
			# 完成前 is_web_ready()=false（状态栏显示「引擎加载中」，think_async 自动等待）
			_web_warming = true
			_send("INFO timeout_turn 300")
			_send("BEGIN")
		else:
			return
	for line in _poll_lines():
		var handled: Variant = _handle_output_line(line)
		if handled is Vector2i:
			if _web_warming:
				# 预热搜索出子：恢复配置并宣布就绪（该子无人监听，丢弃）
				_web_warming = false
				_web_ready = true
				_apply_config()
				new_game()
				web_ready.emit()
				continue
			move_ready.emit(handled)


func _wait_msec(ms: int) -> void:
	if not IS_WEB:
		OS.delay_msec(ms)


## 把字符串转成 JS 单引号字面量。
func _js_quote(s: String) -> String:
	return "'" + s.replace("\\", "\\\\").replace("'", "\\'").replace("\n", "\\n") + "'"


## 解析引擎 exe 的绝对路径：优先探测本机支持的最优指令集版本（每次进程生命周期只探测一次）。
func _resolve_engine_path() -> String:
	if _exe_name != "":
		return ProjectSettings.globalize_path("res://" + ENGINE_DIR + "/" + _exe_name)
	for candidate in ENGINE_CANDIDATES:
		var path := ProjectSettings.globalize_path("res://" + ENGINE_DIR + "/" + candidate)
		if not FileAccess.file_exists(path):
			continue
		if candidate == EXE_NAME:
			break  # 兜底版本无需探测
		if _probe_engine(path):
			_exe_name = candidate
			return path
		print("Rapfi 引擎探测失败，降级: %s" % candidate)
	_exe_name = EXE_NAME
	return ProjectSettings.globalize_path("res://" + ENGINE_DIR + "/" + EXE_NAME)

## 探测引擎变体能否在本机正常运行（发一局快速试探，2.5s 内应手即可用）。
func _probe_engine(path: String) -> bool:
	var result := OS.execute_with_pipe(path, PackedStringArray(["--config", "config.toml"]), false)
	if result.is_empty():
		return false
	var io: FileAccess = result["stdio"]
	var pid: int = result["pid"]
	var ok := false
	io.store_line("START 15")
	io.flush()
	for i in range(18):  # 等权重加载（最多 900ms），崩溃的变体提前退出
		if not OS.is_process_running(pid):
			return false
		OS.delay_msec(50)
	io.store_line("INFO timeout_turn 600")
	io.store_line("INFO thread_num 4")
	io.flush()
	OS.delay_msec(100)
	io.store_line("BEGIN")
	io.flush()
	var deadline := Time.get_ticks_msec() + 2500
	while Time.get_ticks_msec() < deadline:
		if not OS.is_process_running(pid):
			break  # 指令集不受支持等导致的崩溃：立即换下一个候选
		var line := io.get_line()
		if line != "" and line[0].is_valid_int() and line.contains(","):
			ok = true
			break
		OS.delay_msec(20)
	io.store_line("END")
	io.flush()
	OS.kill(pid)
	return ok
