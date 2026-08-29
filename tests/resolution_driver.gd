extends SceneTree
## 多分辨率验收：逐档改窗口尺寸，分别截「流光标题」与「对局界面」。
## 用法：godot --path . --script tests/resolution_driver.gd
var sizes := [Vector2i(960, 720), Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(1024, 768)]
var idx := -1
var f := 0
var stage := 0
var game: Node = null


func _initialize() -> void:
	AudioServer.set_bus_mute(0, true)
	change_scene_to_file("res://node_2d.tscn")


func _shot(name_: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://screenshots/" + name_))
	print("SHOT ", name_)


func _apply_size(s: Vector2i) -> void:
	DisplayServer.window_set_size(s)
	var screen := DisplayServer.screen_get_usable_rect()
	DisplayServer.window_set_position(Vector2i(maxi(0, (screen.size.x - s.x) / 2), maxi(0, (screen.size.y - s.y) / 2)))


func _process(_d: float) -> bool:
	f += 1
	if stage == 0:
		if f > 30:
			game = root.get_node_or_null("Node2D")
			game._ui_style = 1
			game._apply_ui_style()
			idx = 0
			_apply_size(sizes[0])
			stage = 1
			f = 0
	elif stage == 1:  # 等布局稳定
		if f > 180:
			var s: Vector2i = sizes[idx]
			_shot("res-%dx%d-title.png" % [s.x, s.y])
			game._start_game(0)
			stage = 2
			f = 0
	elif stage == 2:
		if f > 25:
			var s: Vector2i = sizes[idx]
			_shot("res-%dx%d-game.png" % [s.x, s.y])
			game._return_to_title()
			stage = 3
			f = 0
	elif stage == 3:
		if f > 15:
			idx += 1
			if idx >= sizes.size():
				print("RES DONE")
				return true
			_apply_size(sizes[idx])
			stage = 1
			f = 0
	return false
