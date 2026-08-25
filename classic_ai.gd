extends RefCounted
## 古法编程 五子棋 AI（彩蛋 / DLC 难度）
## 忠实移植 Five-in-Row3.c 的算法逻辑：
##   1. gettype()   —— 判断每个空位在 4 个方向上能组成的棋型（五连/活四/冲四/活三/跳活三/眠三/活二/大跳活二）
##   2. getscore()  —— 按棋型加权给每个位置打分（进攻分 target_score + 防守分 other_score）
##   3. AIgetchess()—— 加入递归前瞻（VCT/VCF）：模拟落子后递归应子，几步之内能制胜就按这条路线下（countdigui ≤ 20）
##
## 坐标系：内部沿用 C 的 x=行、y=列（rec[row][col]），对外返回 Vector2i(列, 行)。

const MAX_DEPTH := 20
const MAX_THINK_MS := 4000   # 安全预算：超过则放弃前瞻，直接返回贪心最优（防极端局面卡死）

# 4 个方向（drow, dcol）：横 / 竖 / 左斜 / 右斜
const _DIRS := [
	[0, 1],
	[1, 0],
	[1, -1],
	[1, 1],
]

var size := 15

# 内部棋盘（row][col]，0 空 / 1 黑 / 2 白
var rec: Array = []

# 递归状态（对应 C 的全局 countdigui 与 static keyi）
var countdigui := 0
var _keyi := 0
var _computer_chess := 0
var _deadline := 0

# 彩蛋：AI 前瞻算到必胜时置为「嘿嘿」（对应 C 里的 printf("嘿嘿")）
var taunt := ""


func set_size(s: int) -> void:
	size = s


## 让 AI 选择一手（玩家已落子后调用）。返回 Godot 坐标 Vector2i(列, 行)。
func choose_move(board: Array, ai_color: int) -> Vector2i:
	_computer_chess = ai_color
	taunt = ""
	countdigui = 0
	_keyi = 0
	_deadline = Time.get_ticks_msec() + MAX_THINK_MS
	_copy_board(board)
	var rc := _ai_getchess(ai_color)
	return Vector2i(rc[1], rc[0])


## AI 先手：落天元（对应原 C 程序 mode==2 时的 x=7,y=7）。
func choose_first() -> Vector2i:
	@warning_ignore("integer_division")
	var c := size / 2
	return Vector2i(c, c)


func _copy_board(board: Array) -> void:
	rec.clear()
	for row in range(size):
		var r: Array = []
		r.resize(size)
		for col in range(size):
			r[col] = board[row][col]
		rec.append(r)


# ============================================================
# 棋型采集（gettype）
# ============================================================
func _gettype(types: Array, chess: int) -> void:
	for row in range(size):
		for col in range(size):
			if rec[row][col] != 0:
				continue
			for d in _DIRS:
				var neg := _scan_one(row, col, -d[0], -d[1], chess)
				var pos := _scan_one(row, col, d[0], d[1], chess)
				_analyse(types, row, col, neg, pos)


## 沿 (drow, dcol) 方向向外扫描，采集一段棋型数据。
func _scan_one(row: int, col: int, drow: int, dcol: int, chess: int) -> Dictionary:
	var other := 2 if chess == 1 else 1
	var number := 1    # 与假想落子相邻的连续同色子数（含假想子本身）
	var number2 := 0   # 跳过一段空格后的第二段同色子数
	var skip := 0      # 第一段之后的空格数
	var havespace := 0 # 第二段之后的空格数
	var i := 1
	while true:
		var r := row + drow * i
		var c := col + dcol * i
		if r < 0 or r >= size or c < 0 or c >= size or rec[r][c] == other:
			if number2 == 0:
				havespace = skip
				skip = 0
			break
		elif rec[r][c] == chess:
			if skip == 0:
				number += 1
			elif havespace == 0:
				number2 += 1
			else:
				break
		else:
			if number2 == 0:
				skip += 1
			else:
				havespace += 1
		i += 1
	return {"number": number, "number2": number2, "skip": skip, "havespace": havespace}


# ============================================================
# 棋型判定（analysedata）
# ============================================================
func _analyse(types: Array, row: int, col: int, neg: Dictionary, pos: Dictionary) -> void:
	var n11: int = neg["number"]
	var n12: int = neg["number2"]
	var s1: int = neg["skip"]
	var h1: int = neg["havespace"]
	var n21: int = pos["number"]
	var n22: int = pos["number2"]
	var s2: int = pos["skip"]
	var h2: int = pos["havespace"]
	var tot := n11 + n21 - 1  # 连在一起的棋子数

	# 五连
	if s1 != 1 and s2 != 1 and tot >= 5:
		_write_node(types, row, col, 1, 5, 1)
		return

	# 活四
	if tot == 4 and (
		(s1 == 0 and s2 == 0 and h1 != 0 and h2 != 0)
		or (s1 != 0 and s2 != 0)
		or (s1 != 0 and s2 == 0 and h2 != 0)
		or (s2 != 0 and s1 == 0 and h1 != 0)
	):
		_write_node(types, row, col, 1, 4, 1)
		return

	var a := s1 == 1 and (n11 + n12 + n21 - 1 >= 4)
	var b := s2 == 1 and (n21 + n22 + n11 - 1 >= 4)

	# 两个冲四
	if a and b:
		_write_node(types, row, col, 0, 4, 2)
		return

	# 一个冲四
	var one_rush := (a != b) or (
		tot == 4 and (
			((s1 == 0 and h1 == 0) and (s2 != 0 or (s2 == 0 and h2 != 0)))
			or ((s2 == 0 and h2 == 0) and (s1 != 0 or (s1 == 0 and h1 != 0)))
		)
	)
	if one_rush:
		_write_node(types, row, col, 0, 4, 1)
		return

	# 活三加眠三
	if (
		((h1 != 0 or h2 != 0) and s1 == 1 and s2 == 1 and tot == 2 and n12 == 1 and n22 == 1)
		or (s1 == 1 and s2 == 1 and tot == 1 and ((n12 == 2 and h1 != 0) or (n22 == 2 and h2 != 0)))
	):
		_write_node(types, row, col, 1, 3, 1)
		_write_node(types, row, col, 0, 3, 1)
		return

	# 连活三
	if tot == 3 and (
		(s1 == 0 and s2 == 0 and h1 != 0 and h2 != 0 and h1 + h2 >= 3)
		or (s1 == 0 and s2 >= 2 and h1 != 0)
		or (s2 == 0 and s1 >= 2 and h2 != 0)
		or (s1 >= 2 and s2 >= 2)
	):
		_write_node(types, row, col, 1, 3, 1)
		return

	# 跳活三（以 huo=2 表示）
	if (
		(s1 == 1 and n11 + n21 + n12 - 1 == 3 and h1 != 0 and (s2 != 0 or h2 != 0))
		or (s2 == 1 and n11 + n21 + n22 - 1 == 3 and h2 != 0 and (s1 != 0 or h1 != 0))
	):
		_write_node(types, row, col, 2, 3, 1)
		return

	# 不太完善的眠三
	if (
		((h2 == 0 and s1 >= 2 and tot == 3) or (h1 == 0 and s2 >= 2 and tot == 3))
		or ((h1 != 0 and h2 == 0 and s1 == 1 and tot + n12 == 3) or (h2 != 0 and h1 == 0 and s2 == 1 and tot + n22 == 3))
		or (s1 == 0 and s2 == 0 and tot == 3 and h1 == 1 and h2 == 1)
		or (tot == 1 and s1 == 1 and s2 == 1 and n12 == 1 and n22 == 1)
	):
		_write_node(types, row, col, 0, 3, 1)
		return

	if (s1 == 2 and tot <= 2 and tot + n12 >= 3) or (s2 == 2 and tot <= 2 and tot + n22 >= 3):
		if s1 == 2 and tot <= 2 and tot + n12 >= 3:
			_write_node(types, row, col, 0, 3, 1)
		if s2 == 2 and tot <= 2 and tot + n22 >= 3:
			_write_node(types, row, col, 0, 3, 1)
		return

	# 活二
	if (
		(tot == 2 and (s1 >= 3 or (s1 == 0 and h1 >= 3)) and (s2 >= 3 or (s2 == 0 and h2 >= 3)))
		or (
			tot == 1 and (
				(s1 == 1 and n12 == 1 and h1 != 0 and ((h2 != 0 and h1 + h2 >= 3) or s2 >= 2))
				or (s2 == 1 and n22 == 1 and h2 != 0 and ((h1 != 0 and h1 + h2 >= 3) or s1 >= 2))
			)
		)
	):
		_write_node(types, row, col, 1, 2, 1)
		return

	# 大跳活二（以 huo=0 表示）
	if tot == 1 and (
		(s1 == 2 and n12 == 1 and h1 >= 1 and (s2 >= 1 or (s2 == 0 and h2 >= 1)))
		or (s2 == 2 and n22 == 1 and h2 >= 1 and (s1 >= 1 or (s1 == 0 and h1 >= 1)))
	):
		_write_node(types, row, col, 0, 2, 1)


func _write_node(types: Array, row: int, col: int, huo: int, number: int, n: int) -> void:
	var key := "%d,%d" % [huo, number]
	var d: Dictionary = types[row][col]
	d[key] = int(d.get(key, 0)) + n


# ============================================================
# 评分（getscore）
# ============================================================
## 返回 temp（对应 C 里 getscore 的 *temp，实为「最后一个格子的原始进攻分」这一历史遗留值）。
func _getscore(target_score: Array, other_score: Array, target_type: Array, other_type: Array, want_temp: bool) -> int:
	var temp := 0
	# 进攻分（我方棋型）
	for row in range(size):
		for col in range(size):
			var d: Dictionary = target_type[row][col]
			var wulian := int(d.get("1,5", 0))
			var huosi := int(d.get("1,4", 0))
			var chongsi := int(d.get("0,4", 0))
			var huosan := int(d.get("1,3", 0))
			var tiaohuosan := int(d.get("2,3", 0))
			var miansan := int(d.get("0,3", 0))
			var huoer := int(d.get("1,2", 0))
			var datiaohuoer := int(d.get("0,2", 0))

			if wulian > 0:
				target_score[row][col] = 10000
			elif huosi > 0 or chongsi >= 2 or (chongsi == 1 and huosan + tiaohuosan > 0):
				target_score[row][col] = 8000
			elif huosan + tiaohuosan > 1:
				target_score[row][col] = 6000
			else:
				target_score[row][col] = chongsi * 49 + huosan * 100 + tiaohuosan * 99 + miansan * 25 + huoer * 30 + datiaohuoer * 29
				# 原 C 在此对 other_score 有加分，但随后 other 循环会用 = 覆盖，属死代码，此处省略

			if want_temp:
				temp = chongsi * 49 + huosan * 100 + tiaohuosan * 99 + miansan * 25 + huoer * 30 + datiaohuoer * 29
				if chongsi != 0 and miansan != 0:
					temp += miansan * 20
				if chongsi != 0 and (huoer + datiaohuoer) != 0:
					temp += (huoer + datiaohuoer) * 20

	# 防守分（对方棋型）
	for row in range(size):
		for col in range(size):
			var d: Dictionary = other_type[row][col]
			var wulian := int(d.get("1,5", 0))
			var huosi := int(d.get("1,4", 0))
			var chongsi := int(d.get("0,4", 0))
			var huosan := int(d.get("1,3", 0))
			var tiaohuosan := int(d.get("2,3", 0))
			var miansan := int(d.get("0,3", 0))
			var huoer := int(d.get("1,2", 0))

			var mul := 98 if huosan > 0 else 97
			if wulian > 0:
				other_score[row][col] = 9000 + chongsi * 50 + huosan * 98 + tiaohuosan * 97 + miansan * 20 + huoer * 30
			elif huosi > 0:
				other_score[row][col] = 7000 + chongsi * 50 + huosan * 98 + tiaohuosan * 97 + miansan * 20 + huoer * 30
			elif chongsi >= 2:
				other_score[row][col] = 7000 + (chongsi - 2) * 50 + huosan * 98 + tiaohuosan * 97 + miansan * 20 + huoer * 30
			elif chongsi == 1 and huosan + tiaohuosan >= 1:
				other_score[row][col] = 7000 + (chongsi - 1) * 50 + (huosan + tiaohuosan - 1) * mul + miansan * 20 + huoer * 30
			elif huosan + tiaohuosan > 1:
				other_score[row][col] = 5000 + chongsi * 50 + (huosan + tiaohuosan - 2) * mul + miansan * 20 + huoer * 30
			else:
				other_score[row][col] = chongsi * 50 + huosan * 98 + tiaohuosan * 97 + miansan * 20 + huoer * 30
				if chongsi != 0 and miansan != 0:
					other_score[row][col] += miansan * 20
				if chongsi != 0 and huoer != 0:
					other_score[row][col] += huoer * 20

	return temp


# ============================================================
# 选点 + 递归前瞻（AIgetchess）
# ============================================================
func _ai_getchess(targetchess: int) -> Array:
	var otherchess := 2 if targetchess == 1 else 1
	var target_score := _new_int_grid()
	var other_score := _new_int_grid()
	var target_type := _new_type_grid()
	var other_type := _new_type_grid()

	_gettype(target_type, targetchess)
	_gettype(other_type, otherchess)
	var temp: int = _getscore(target_score, other_score, target_type, other_type, true)

	# 选择当前最优落点
	var maxv := 0
	var bx := 0
	var by := 0
	for row in range(size):
		for col in range(size):
			if rec[row][col] != 0:
				continue
			var ts: int = target_score[row][col]
			var os: int = other_score[row][col]
			if ts > 1000:
				var cand := maxi(os + temp, ts)
				if cand > maxv:
					maxv = cand
					bx = row
					by = col
			elif os + temp > 1000:
				if os + temp > maxv:
					maxv = os + temp
					bx = row
					by = col
			else:
				if os + ts >= maxv:
					maxv = os + ts
					bx = row
					by = col

	# VCT / VCF 前瞻
	var remember := countdigui
	if maxv <= 1000 and countdigui <= MAX_DEPTH and _keyi == 0 and Time.get_ticks_msec() < _deadline:
		countdigui += 1

		# 我方（目标方）的制胜威胁
		for i1 in range(size):
			for j1 in range(size):
				var tdict: Dictionary = target_type[i1][j1]
				if not _is_threat(tdict):
					continue
				rec[i1][j1] = targetchess
				var ab := _ai_getchess(otherchess)
				rec[ab[0]][ab[1]] = otherchess

				var ts2 := _new_int_grid()
				var os2 := _new_int_grid()
				var tt2 := _new_type_grid()
				var ot2 := _new_type_grid()
				_gettype(tt2, targetchess)
				_gettype(ot2, otherchess)
				_getscore(ts2, os2, tt2, ot2, false)
				var dm1 := _grid_max(ts2)
				var dm2 := _grid_max(os2)

				rec[i1][j1] = 0
				rec[ab[0]][ab[1]] = 0

				if dm1 >= dm2 and dm1 > 1000:
					_keyi = 1
					if targetchess == _computer_chess:
						taunt = "嘿嘿"
				if countdigui == 1 and _keyi == 1:
					return [i1, j1]

		# 对方（另一方）的制胜威胁
		if _keyi == 0:
			for i1 in range(size):
				for j1 in range(size):
					var tdict: Dictionary = other_type[i1][j1]
					if not _is_threat(tdict):
						continue
					rec[bx][by] = targetchess
					rec[i1][j1] = otherchess
					var ab := _ai_getchess(targetchess)
					rec[ab[0]][ab[1]] = targetchess

					var ts2 := _new_int_grid()
					var os2 := _new_int_grid()
					var tt2 := _new_type_grid()
					var ot2 := _new_type_grid()
					_gettype(tt2, otherchess)
					_gettype(ot2, targetchess)
					_getscore(ts2, os2, tt2, ot2, false)
					var dm1 := _grid_max(ts2)
					var dm2 := _grid_max(os2)

					rec[i1][j1] = 0
					rec[ab[0]][ab[1]] = 0
					rec[bx][by] = 0

					if dm1 >= dm2 and dm1 > 1000:
						_keyi = 1
					if countdigui == 1 and _keyi == 1:
						return [i1, j1]

	countdigui = remember
	if countdigui == 0:
		_keyi = 0
	return [bx, by]


func _is_threat(d: Dictionary) -> bool:
	return int(d.get("1,3", 0)) > 0 or int(d.get("2,3", 0)) > 0 or int(d.get("0,4", 0)) > 0


func _grid_max(g: Array) -> int:
	var m := 0
	for row in range(size):
		for col in range(size):
			if g[row][col] > m:
				m = g[row][col]
	return m


func _new_int_grid() -> Array:
	var g := []
	for r in range(size):
		var row := []
		row.resize(size)
		for c in range(size):
			row[c] = 0
		g.append(row)
	return g


func _new_type_grid() -> Array:
	var g := []
	for r in range(size):
		var row := []
		row.resize(size)
		for c in range(size):
			row[c] = {}
		g.append(row)
	return g
