extends SceneTree
## AI 响应时间测量：连续下 8 手，记录每手从玩家落子到 AI 应手的毫秒数。
var f := 0
var game: Node = null
var t_place := 0
var replies: Array = []
var placed := 1
var cell := Vector2i(7, 7)


func _initialize() -> void:
	AudioServer.set_bus_mute(0, true)
	change_scene_to_file("res://node_2d.tscn")


func _process(_d: float) -> bool:
	f += 1
	if f == 30:
		game = root.get_node_or_null("Node2D")
		game._start_game(1)
		t_place = Time.get_ticks_msec()
	if f == 45:
		game._place_stone(cell)
		t_place = Time.get_ticks_msec()
	if f > 45:
		if not game.ai_thinking and game.move_count >= placed * 2 and game.winner == 0:
			var dt := Time.get_ticks_msec() - t_place
			replies.append(dt)
			print("move %d: %d ms  (思考中状态还原)" % [placed, dt])
			placed += 1
			if placed > 8:
				print("TIMES=", replies)
				return true
			cell = Vector2i(2 + placed, 2 + placed % 7)
			game._place_stone(cell)
			t_place = Time.get_ticks_msec()
	return false
