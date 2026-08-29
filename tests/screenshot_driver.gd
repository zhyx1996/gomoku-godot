extends SceneTree
## 视觉验收驱动：窗口运行游戏，脚本自动驱动界面与落子，保存各阶段截图。
## 用法：godot --path . --script tests/screenshot_driver.gd
## 产物：screenshots/qa-*.png（已 gitignore）

var frame := 0
var stage := 0
var game: Node = null


func _initialize() -> void:
	AudioServer.set_bus_mute(0, true)
	change_scene_to_file("res://node_2d.tscn")


func _shot(name_: String) -> void:
	var img := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://screenshots/" + name_)
	img.save_png(path)
	print("SHOT ", name_)


func _place(cell: Vector2i) -> void:
	game._place_stone(cell)


func _process(_delta: float) -> bool:
	frame += 1
	match stage:
		0:
			if frame > 45:
				game = root.get_node_or_null("Node2D")
				if game == null:
					print("ERROR: game node not found")
					return true
				# 确保从经典标题开始
				game._ui_style = 0
				game._apply_ui_style()
				stage = 1
		1:
			if frame > 90:
				_shot("qa-title-classic.png")
				game._on_ui_style_pressed()  # 切到流光
				stage = 2
		2:
			if frame > 130:
				_shot("qa-title-v2.png")
				stage = 3
		3:
			if frame > 230:
				_shot("qa-title-v2-later.png")
				game._start_game(0)  # PVP
				stage = 4
		4:
			if frame > 250:
				# 摆出活四（黑：7,7~7,10 两端空）
				_place(Vector2i(7, 7))
				_place(Vector2i(8, 7))
				_place(Vector2i(7, 8))
				_place(Vector2i(8, 8))
				_place(Vector2i(7, 9))
				_place(Vector2i(8, 9))
				_place(Vector2i(7, 10))
				stage = 5
		5:
			if frame > 280:
				_shot("qa-threat-flow-a.png")
				stage = 6
		6:
			if frame > 330:
				_shot("qa-threat-flow-b.png")
				stage = 7
		7:
			if frame > 340:
				_place(Vector2i(8, 12))  # 白棋闲着
				_place(Vector2i(7, 11))  # 黑棋五连获胜
				stage = 8
		8:
			if frame > 346:
				_shot("qa-win-beam.png")
				stage = 81
		81:
			if frame > 366:
				_shot("qa-win-rays.png")
				stage = 9
		9:
			if frame > 560:
				_shot("qa-win-banner.png")
				stage = 10
		10:
			if frame > 720:
				_shot("qa-win-line-flow.png")
				# 对局中切界面风格：验证强调色就地重建
				game._on_ui_style_pressed()
				stage = 11
		11:
			if frame > 780:
				_shot("qa-game-v2-accent.png")
				game._open_settings()
				stage = 12
		12:
			if frame > 840:
				_shot("qa-settings-v2.png")
				print("DONE")
				return true
	return false
