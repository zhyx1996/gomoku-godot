extends SceneTree
## 面板宽度稳定性验收：模拟超长分析文字与思考态，验证面板不撑宽、不跳动。
var f := 0
var game: Node = null


func _initialize() -> void:
	AudioServer.set_bus_mute(0, true)
	change_scene_to_file("res://node_2d.tscn")


func _shot(name_: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://screenshots/" + name_))
	print("SHOT ", name_)


func _fake_analysis() -> void:
	game._analysis_data = {
		"depth": "24-31", "seldepth": "31", "eval": "-441", "winrate": 0.099,
		"speed": 6246430, "totalnodes": 19845231,
	}
	var line: Array = []
	for i in range(30):
		line.append(Vector2i(4 + (i * 3) % 7, 3 + (i * 5) % 9))
	game._pv_list = [
		{"bestline": line, "eval": "-441", "winrate": 0.099},
		{"bestline": line.slice(2), "eval": "-452", "winrate": 0.094},
		{"bestline": line.slice(4), "eval": "-468", "winrate": 0.088},
		{"bestline": line.slice(6), "eval": "-479", "winrate": 0.081},
		{"bestline": line.slice(8), "eval": "-490", "winrate": 0.075},
	]
	game.ai_thinking = true
	game._update_analysis_display()
	game._update_status_text()


func _process(_d: float) -> bool:
	f += 1
	if f == 30:
		game = root.get_node_or_null("Node2D")
		game._ui_style = 1
		game._apply_ui_style()
	if f == 45:
		game._start_game(0)
	if f == 55:
		_fake_analysis()
	if f == 90:
		_shot("panel-960.png")
		DisplayServer.window_set_size(Vector2i(1600, 900))
	if f == 140:
		_shot("panel-1600.png")
		print("PANEL TEST DONE")
		return true
	return false
