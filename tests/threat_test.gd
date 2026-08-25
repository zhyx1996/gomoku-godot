## 制胜棋型检测单元测试（headless 运行）
## 用法：godot --headless --path . --script tests/threat_test.gd
extends SceneTree

const GSCRIPT := preload("res://gomoku.gd")


func _mk(stones: Array) -> Array:
	var b := []
	for y in range(15):
		var row := []
		for x in range(15):
			row.append(0)
		b.append(row)
	for s in stones:
		b[s[1]][s[0]] = s[2]
	return b


func _initialize() -> void:
	var g: Node2D = GSCRIPT.new()
	g.board_size = 15
	# [名称, 棋子列表, 落子x, 落子y, 执子方, 规则, 期望制胜型, 期望进攻型]
	var cases := [
		["lian3", [[5,7,1],[6,7,1],[7,7,1]], 7,7,1,0, "", "open_three"],
		["tiao3", [[5,7,1],[7,7,1],[8,7,1]], 7,7,1,0, "", "open_three"],
		["huo4", [[4,7,1],[5,7,1],[6,7,1],[7,7,1]], 7,7,1,0, "open_four", ""],
		["cross44", [[4,7,1],[5,7,1],[6,7,1],[7,7,1],[3,7,2],[7,5,1],[7,6,1],[7,8,1],[7,4,2]], 7,7,1,0, "double_four", ""],
		["line44", [[0,7,2],[1,7,1],[2,7,1],[4,7,1],[5,7,1],[7,7,1],[8,7,1],[9,7,2]], 5,7,1,0, "open_four", ""],
		["43-lian", [[4,7,1],[5,7,1],[6,7,1],[7,7,1],[3,7,2],[7,5,1],[7,6,1]], 7,7,1,0, "four_three", ""],
		["43-tiao", [[4,7,1],[5,7,1],[6,7,1],[7,7,1],[3,7,2],[7,4,1],[7,6,1]], 7,7,1,0, "four_three", ""],
		["33-lian", [[5,7,1],[6,7,1],[7,7,1],[7,5,1],[7,6,1]], 7,7,1,0, "double_three", ""],
		["33-tiao", [[5,7,1],[6,7,1],[7,7,1],[7,4,1],[7,6,1]], 7,7,1,0, "double_three", ""],
		["rush4", [[4,7,1],[5,7,1],[6,7,1],[7,7,1],[3,7,2]], 7,7,1,0, "", "rushed_four"],
		["mian3", [[4,7,2],[5,7,1],[6,7,1],[7,7,1]], 7,7,1,0, "", ""],
		["renju-33", [[5,7,1],[6,7,1],[7,7,1],[7,5,1],[7,6,1]], 7,7,1,2, "", ""],
		["renju-44", [[4,7,1],[5,7,1],[6,7,1],[7,7,1],[3,7,2],[7,5,1],[7,6,1],[7,8,1],[7,4,2]], 7,7,1,2, "", "rushed_four"],
	]
	# 白棋有禁手不受影响
	cases.append(["renju-white44", [[0,7,1],[1,7,2],[2,7,2],[4,7,2],[5,7,2],[7,7,2],[8,7,2],[9,7,1]], 5,7,2,2, "open_four", ""])

	var fail := 0
	for c in cases:
		g.board = _mk(c[1])
		g._rule_index = c[5]
		g._detect_threat_fx(Vector2i(c[2], c[3]))
		var ok: bool = g._threat_type == c[6] and g._attack_type == c[7]
		if not ok:
			fail += 1
		print(("PASS " if ok else "FAIL ") + str(c[0]).lpad(14) + " got=" + g._threat_type + "/" + g._attack_type + " want=" + c[6] + "/" + c[7])
	print("RESULT: %s" % ("ALL %d PASSED" % cases.size() if fail == 0 else "%d FAILED" % fail))
	quit(1 if fail > 0 else 0)
