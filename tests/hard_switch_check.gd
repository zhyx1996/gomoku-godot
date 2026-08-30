extends SceneTree
## 定向验证：AI 思考中请求「困难」，下一手必须真的用 5000ms 预算。
var f := 0
var game: Node = null
var t_place := 0


func _initialize() -> void:
	AudioServer.set_bus_mute(0, true)
	change_scene_to_file("res://node_2d.tscn")


func _process(_d: float) -> bool:
	f += 1
	if f == 30:
		game = root.get_node_or_null("Node2D")
		game._start_game(1)
	if f == 45:
		game._place_stone(Vector2i(7, 7))
		t_place = Time.get_ticks_msec()
	# 第 2 帧：AI 刚开始思考 → 立刻请求困难
	if f == 47 and game.ai_thinking:
		game._on_difficulty_option(2)
		print("思考中请求困难, 挂起=%d, 当时超时=%d" % [game._pending_difficulty, game.ai.timeout_turn])
		return false
	# AI 应答后校验：必须已切到 5000ms
	if f > 47 and not game.ai_thinking and game.move_count >= 2 and game.winner == 0:
		var dt := Time.get_ticks_msec() - t_place
		var ok: bool = game.ai_difficulty == 2 and game.ai.timeout_turn == 5000 and game._pending_difficulty == -1
		print("%s: 应手 %d ms, 难度=%d, 实际超时=%d, 挂起=%d" % ["HARDSWITCH OK" if ok else "HARDSWITCH FAIL", dt, game.ai_difficulty, game.ai.timeout_turn, game._pending_difficulty])
		return true
	if Time.get_ticks_msec() - t_place > 20000:
		print("STUCK! mc=%d ai_thinking=%s" % [game.move_count, game.ai_thinking])
		return true
	return false
