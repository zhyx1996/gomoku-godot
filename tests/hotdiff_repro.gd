extends SceneTree
## 验证：AI 思考中热切换难度是否出 bug（丢手/软锁/崩溃）。
## 策略：AI 一进入思考状态就每 2 帧反复切换难度，覆盖整个思考窗口；
## 每轮对手落子后再来一轮，共 6 轮。
var f := 0
var game: Node = null
var t_place := 0
var placed := 1
var cell := Vector2i(7, 7)
var round_no := 0
var switches := 0
var switches_in_round := 0


func _initialize() -> void:
	AudioServer.set_bus_mute(0, true)
	change_scene_to_file("res://node_2d.tscn")


func _switch_difficulty() -> void:
	game._on_difficulty_option((placed + switches) % 3)
	switches += 1
	switches_in_round += 1


func _process(_d: float) -> bool:
	f += 1
	if f == 30:
		game = root.get_node_or_null("Node2D")
		game._start_game(1)
	if f == 45:
		game._place_stone(cell)  # (7,7) 为空，安全
		t_place = Time.get_ticks_msec()
		switches_in_round = 0

	if f > 45:
		# 思考中：反复热切换（第一次一定落在思考窗口内）
		if game.ai_thinking and f % 2 == 0:
			_switch_difficulty()

		# AI 应手完成
		if not game.ai_thinking and game.move_count >= placed * 2 and game.winner == 0:
			var dt := Time.get_ticks_msec() - t_place
			var want: int = [500, 1500, 5000][game.ai_difficulty]  # 简单/中等/困难（与 DIFFICULTY_CONFIG 一致）
			print("round %d: 应手 %d ms, mc=%d, 切换累计 %d 次, 挂起=%d, 难度=%d(古法=%s) 实际超时=%d 期望=%d %s, cv=%s" % [round_no, dt, game.move_count, switches_in_round, game._pending_difficulty, game.ai_difficulty, str(game._classic_mode), game.ai.timeout_turn, want, "OK" if game.ai.timeout_turn == want else "MISMATCH", str(cell)])
			round_no += 1
			placed += 1
			if placed > 6:
				print("HOTSWITCH OK mc=%d total_switches=%d" % [game.move_count, switches])
				return true
			# 下一手：避开已占的格子（上一版驱动在此算错占位，误报 STUCK）
			cell = Vector2i(2 + placed, 2 + placed % 7)
			var tries := 0
			while game.board[cell.y][cell.x] != 0 and tries < 60:
				cell = Vector2i((cell.x + 5) % 15, (cell.y + 3) % 15)
				tries += 1
			game._place_stone(cell)
			t_place = Time.get_ticks_msec()

		# 卡死检测：12 秒无应手
		if Time.get_ticks_msec() - t_place > 12000 and game.winner == 0:
			print("STUCK! placed=%d mc=%d ai_thinking=%s 状态=%s" % [placed, game.move_count, game.ai_thinking, game.status_label.text])
			return true
	return false
