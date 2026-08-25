extends Node2D

var board_size := 15               # 棋盘大小（可变，5~22）
const CELL_SIZE := 40.0
const BOARD_PADDING := Vector2(48, 48)
const SIDE_PANEL_POSITION := Vector2(672, 24)
const SIDE_PANEL_SIZE := Vector2(264, 624)
const STONE_RADIUS := 16.0
const STAR_POINT_RADIUS := 3.5

## 计算棋盘跨度（随 board_size 变化）。
func _board_span() -> float:
	return _cell_size() * float(board_size - 1)


## 动态格距：大棋盘自动缩小，避免与右侧面板重叠（面板起点 684，棋盘起点 48）。
func _cell_size() -> float:
	var max_span := SIDE_PANEL_POSITION.x - BOARD_PADDING.x  # 636
	return minf(CELL_SIZE, max_span / (float(board_size) - 0.5))


## 棋子半径随格距等比缩放。
func _stone_radius() -> float:
	return STONE_RADIUS * (_cell_size() / CELL_SIZE)

# ---- 「星夜」主题配色 ----
const BG_TOP := Color("0a0d18")        # 深空蓝黑（顶部）
const BG_BOTTOM := Color("151b30")     # 蓝炭（底部）
const BOARD_COLOR := Color("1b2438")   # 深板岩棋盘
const BOARD_EDGE := Color("3f5788")    # 棋盘外框（蓝钢）
const BLACK_STONE := Color("0c0f16")   # 墨黑
const BLACK_STONE_DARK := Color("05070c") # 墨黑底部暗面
const BLACK_GLOSS := Color("3d4a63")   # 黑棋高光（冷灰蓝）
const BLACK_EDGE := Color("44536f")    # 黑棋描边（冷灰蓝，保证暗盘可见）
const WHITE_STONE := Color("e9edf6")   # 瓷白
const WHITE_GLOSS := Color("ffffff")   # 白棋高光
const STONE_SHADOW := Color(0, 0, 0, 0.4)
const BG_PARTICLE := Color("4a7dd6")   # 背景光点（电光蓝）

const ACCENT_CYAN := Color("38bdf8")   # 电光青（主强调）
const ACCENT_MAGENTA := Color("a78bfa")# 紫罗兰（次强调）
const ACCENT_GOLD := Color("fbbf24")   # 琥珀金（点缀）
const ACCENT_GREEN := Color("34d399")  # 翠绿（胜利/正向）
const LAST_MOVE_COLOR := Color("38bdf8")# 落子标记（电光青）
const WIN_LINE_COLOR := Color("34d399") # 胜利线（翠绿）

const RapfiAI := preload("res://rapfi_ai.gd")
const ClassicAI := preload("res://classic_ai.gd")
const UI_FONT := preload("res://fonts/NotoSansCJKsc-Regular.otf")

## 游戏模式
enum GameMode { PVP, PVE, EVE }  # EVE = 机机对战（古法编程 vs 推理引擎）

var board := []
var current_player := 1
var winner := 0
var move_count := 0
var last_move := Vector2i(-1, -1)
var winning_cells := []

var game_mode: int = GameMode.PVE
var human_color: int = 1          # 玩家执子（1=黑 2=白）
var ai_color: int = 2             # AI 执子
var ai_difficulty: int = RapfiAI.Difficulty.MEDIUM
var ai: RefCounted = null         # RapfiAI 实例
var ai_thinking := false          # AI 是否正在思考
var _rule_index := 0              # 规则索引 0/1/2

var status_label: Label
var info_label: Label
var mode_button: Button
var color_button: Button
var difficulty_button: Button
var restart_button: Button
var undo_button: Button
var stop_button: Button
var rule_button: Button
var board_size_button: Button
var analysis_label: Label
var think_time_button: Button
var cand_range_button: Button
var show_coord_button: Button
var show_index_button: Button
var show_winline_button: Button
var show_eval_button: Button
var theme_button: Button
var threads_button: Button
var hash_button: Button
var strength_button: Button
var pondering_button: Button
var ai_black_button: Button
var ai_white_button: Button

# ---- 分析数据缓存（由引擎回调更新）----
var _analysis_data := {}
var _move_history: Array = []  # 落子历史（用于悔棋）
var _think_time_index := 0     # 思考时间档位 0快/1中/2慢/3分析
var _cand_range_index := 3     # 选点范围 0~5
var _show_coord := true        # 显示坐标
var _show_index := false       # 显示落子序号
var _show_winline := true      # 显示胜利线
var _show_eval := false        # 显示实时估值
var _eval_history: Array = []  # 估值历史（用于图表）
var _theme_index := 0          # 主题索引 0深色/1木质/2浅色
var _threads_override := 0     # 手动线程数（0=自动=CPU 核心数）
var _hash_size_index := 0      # 置换表档位 0=128/1=256/2=512 MB
var _strength_index := 2       # 棋力档位 [30,50,70,85,100] 对应索引
var _pondering := false        # 后台思考
var _ai_black := false         # AI 执黑
var _ai_white := false         # AI 执白

# ---- DLC / 彩蛋：古法编程（老C算法移植）----
var _classic_ai: RefCounted = null  # 古法编程 AI 实例
var _classic_mode := false          # 是否启用古法编程难度
var _dlc_unlocked := false          # 彩蛋是否已解锁
var _eve_difficulty := 1            # 机机对战：推理引擎难度（0简单/1中等/2困难，默认中等）
var _toast_label: Label = null      # 彩蛋提示文字
var _toast_until := -1.0            # 提示消失时刻（fx 时钟）
var _subtitle_label: Label = null   # 标题界面副标题（彩蛋解锁提示用）
var _subtitle_note: Label = null     # 标题界面副标题小字（彩蛋括号内容）
var _title_difficulty_button: Button = null  # 标题界面难度按钮
var _title_eve_button: Button = null  # 标题界面「机机对战」按钮（解锁后显示）
var _difficulty_menu: PopupPanel = null  # 难度子菜单弹窗
var _difficulty_anchor: Button = null     # 当前展开难度菜单的触发按钮（用于高亮）
var _game_ui_layer: CanvasLayer = null    # 对局界面层（返回标题时释放）
var _ai_section_label: Label = null       # 设置里的「AI 执子」分区标题
var _ai_section_row: HBoxContainer = null # 设置里的 AI 执子按钮行
var _stop_pending := false                # 已请求停止 AI（停止后撤销玩家一手）
var _turn_generation := 0                 # 对局代数（新局/返回标题时递增，防陈旧协程落子）
var _mode_confirm: ConfirmationDialog = null  # 对局中切换模式的放弃确认框
var _reduced_fx := false                 # 减弱动效（无障碍）：关闭背景粒子与胜利彩带
var fx_button: Button = null             # 「动效」开关按钮
var _settings_scroll: ScrollContainer = null  # 设置弹窗滚动容器（视口自适应）
var _status_base := ""                   # 状态栏基础文案（思考中省略号动画基于它拼接）
var _status_pill: PanelContainer = null  # 对局状态胶囊（godot-ui：信息即时可读）
var _status_dot: Label = null            # 状态点：青=行动方 金=结束 品红=思考中
var _mode_badge: Label = null            # 侧栏模式徽章
var _win_dim: ColorRect = null           # 胜利时全屏压暗层
var _win_flash := -1.0                   # 胜利触发时刻（全屏微闪用，<0 关闭）
var _title_glow_label: Button = null     # 标题文字（呼吸流光作用对象）
var _plaque_ref: PanelContainer = null   # 标题牌匾（入场动画/裁切光带宿主）
var _sheen_rect: ColorRect = null        # 牌匾玻璃斜向流光带
var _win_center: CenterContainer = null  # 胜利卡片响应式居中容器
var _win_card: PanelContainer = null     # 胜利横幅玻璃卡片

# ---- 分析状态（引擎回调更新）----
var _realtime_best := Vector2i(-1, -1)  # 思考中引擎当前最佳候选点
var _realtime_lost: Array = []          # 思考中引擎已排除的点
var _forbid_cells: Array = []           # 禁手点
var _pv_list: Array = []                # MultiPV 列表 [{index,depth,eval,winrate,bestline}]
var _cur_pv := 0                        # 当前 NUMPV 索引

# 当前主题色（由 _apply_theme 设置，绘制时优先使用）
var _cur_bg_top := Color("0a0d18")
var _cur_bg_bottom := Color("151b30")
var _cur_board := Color("27314d")
var _cur_grid := Color("3f5788")
var _cur_star := Color("6f8fd0")
var _cur_black := Color("0c0f16")
var _cur_white := Color("e9edf6")

# ---- 特效状态 ----
var _fx_time := 0.0               # 特效时钟（秒），_process 累计
var _threat_cells := []           # 当前需要高亮的制胜棋型格子
var _threat_type := ""            # 制胜：open_four / double_four / four_three / double_three
var _attack_cells := []           # 进攻棋型格子（活三/冲四，延迟后不明显特效）
var _attack_type := ""            # 进攻：open_three / rushed_four
var _attack_time := -1.0          # 检测到进攻棋型的 fx 时刻
const ATTACK_DELAY := 2.5         # 进攻棋型延迟显示的秒数
var _win_anim := 0.0              # 胜利动画进度（0~1，1 表示完成）
var _win_label: Label = null      # 胜利横幅 Label
var _win_tween: Tween = null
var _hover_cell := Vector2i(-1, -1)  # 鼠标悬停格（幽灵棋子预览）
var _last_place_time := -1.0         # 最近一次落子的 fx 时刻（落子弹入动画）
var _bg_particles: Array = []        # 背景漂浮光点
var _confetti: Array = []            # 胜利彩带粒子
var _in_game := false                  # 是否在对局中（否则显示标题界面）
var _title_layer: CanvasLayer = null   # 标题界面层
var _settings_popup: PopupPanel = null # 设置弹窗
var _rematch_button: Button = null     # 胜利后的「再来一局」按钮
var _return_title_btn: Button = null   # 胜利后的「返回标题」按钮
var _win_buttons: HBoxContainer = null # 胜利后按钮行（再来一局 + 返回标题）
var _place_player: AudioStreamPlayer = null  # 落子音效
var _win_player: AudioStreamPlayer = null    # 胜利音效

# 四方向
const _DIRS := [
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(1, 1),
	Vector2i(1, -1),
]


func _ready() -> void:
	_spawn_bg_particles()
	_init_audio()
	_build_title_screen()


func _process(delta: float) -> void:
	_fx_time += delta
	_update_particles(delta)
	_update_toast()
	# 胜利连珠：弹性放大后回落（短暂夸张并回归静止）
	if _in_game and winner != 0 and _win_anim < 1.0:
		_win_anim = minf(_win_anim + delta * 2.2, 1.0)
	# AI 思考中：状态文字动态省略号（等待反馈）
	if _in_game and ai_thinking and winner == 0 and status_label != null:
		status_label.text = _status_base + ".".repeat(1 + int(_fx_time * 3.0) % 3)
	# 标题文字呼吸流光：青 ↔ 冰蓝缓慢往复（仅标题界面存在时）
	if _title_glow_label != null and is_instance_valid(_title_glow_label):
		var k := 0.5 + 0.5 * sin(_fx_time * 1.6)
		_title_glow_label.add_theme_color_override("font_color", ACCENT_CYAN.lerp(Color("bfe9ff"), k))
	if not _in_game:
		# 标题界面：只重绘背景粒子
		queue_redraw()
		return
	_update_hover()
	# 网页端：每帧泵取引擎输出（走法通过 move_ready 信号返回）
	if OS.has_feature("web") and ai != null:
		ai.poll_output()
	# 特效/落子标记脉冲/胜利动画/估值图表/实时候选点/悬停预览/彩带需要每帧重绘
	if not _threat_cells.is_empty() or winner != 0 or last_move.x >= 0 \
			or not _eval_history.is_empty() or _realtime_best.x >= 0 \
			or not _realtime_lost.is_empty() or not _forbid_cells.is_empty() \
			or _hover_cell.x >= 0 or not _confetti.is_empty() \
			or not _attack_cells.is_empty():
		queue_redraw()


## 生成背景漂浮光点（缓慢上升的微光）。
func _spawn_bg_particles() -> void:
	_bg_particles.clear()
	var size := get_viewport_rect().size
	for i in range(40):
		_bg_particles.append({
			"pos": Vector2(randf_range(0, size.x), randf_range(0, size.y)),
			"vel": Vector2(randf_range(-6.0, 6.0), randf_range(-14.0, -4.0)),
			"radius": randf_range(1.0, 2.4),
			"alpha": randf_range(0.05, 0.12),
			"phase": randf_range(0.0, TAU),
		})


## 更新悬停格（供幽灵棋子预览）。
func _update_hover() -> void:
	var cell := Vector2i(-1, -1)
	if winner == 0 and not ai_thinking and not _ai_plays(current_player):
		var c := _screen_to_cell(get_viewport().get_mouse_position())
		if c.x >= 0 and c.y >= 0 and board[c.y][c.x] == 0:
			cell = c
	if cell != _hover_cell:
		_hover_cell = cell
		queue_redraw()


## 更新背景光点与胜利彩带。
func _update_particles(delta: float) -> void:
	var size := get_viewport_rect().size
	for p in _bg_particles:
		var pos: Vector2 = p["pos"]
		var vel: Vector2 = p["vel"]
		pos += vel * delta
		if pos.y < -10.0:
			pos = Vector2(randf_range(0, size.x), size.y + 10.0)
		p["pos"] = pos
	var kept: Array = []
	for c in _confetti:
		var pos: Vector2 = c["pos"]
		var vel: Vector2 = c["vel"]
		vel.y += c["gravity"] * delta
		pos += vel * delta
		c["pos"] = pos
		c["vel"] = vel
		c["rot"] = c["rot"] + c["spin"] * delta
		if pos.y < size.y + 20.0:
			kept.append(c)
	_confetti = kept


## 生成胜利彩带。
func _spawn_confetti() -> void:
	if _reduced_fx:
		return
	_confetti.clear()
	var size := get_viewport_rect().size
	var colors := [ACCENT_GOLD, ACCENT_GOLD, Color("fde68a"), ACCENT_CYAN, ACCENT_MAGENTA, ACCENT_GREEN, Color("f87171")]
	for i in range(140):
		_confetti.append({
			"pos": Vector2(randf_range(0, size.x), randf_range(-size.y * 0.25, -10.0)),
			"vel": Vector2(randf_range(-36.0, 36.0), randf_range(40.0, 110.0)),
			"gravity": randf_range(140.0, 220.0),
			"rot": randf_range(0.0, TAU),
			"spin": randf_range(-8.0, 8.0),
			"size": randf_range(3.0, 8.0),
			"color": colors[i % colors.size()],
		})


# ============================================================
# UI 构建
# ============================================================
# ============================================================
# 标题界面（主菜单）
# ============================================================
## 释放标题层前置空成员引用，避免悬空访问。
func _clear_title_refs() -> void:
	_title_glow_label = null
	_plaque_ref = null
	_sheen_rect = null


func _build_title_screen() -> void:
	_title_layer = CanvasLayer.new()
	add_child(_title_layer)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title_layer.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	# ── 牌匾：标题 + 朱砂印章（签名元素）──
	var plaque := PanelContainer.new()
	plaque.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	plaque.clip_contents = true
	_plaque_ref = plaque
	# 入场：布局完成后牌匾整体淡入（BACK 缓动，微回弹）
	plaque.modulate.a = 0.0
	plaque.resized.connect(func():
		if _plaque_ref != null and is_instance_valid(_plaque_ref):
			var et: Tween = _plaque_ref.create_tween()
			et.tween_property(_plaque_ref, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	, CONNECT_ONE_SHOT)
	# 玻璃斜向流光带：周期性扫过牌匾（clip 裁切出「玻璃反光」质感）
	_sheen_rect = ColorRect.new()
	_sheen_rect.color = Color(1, 1, 1, 0.075)
	_sheen_rect.size = Vector2(96, 620)
	_sheen_rect.rotation_degrees = 16.0
	_sheen_rect.pivot_offset = Vector2(48, 310)
	_sheen_rect.position = Vector2(-140, -90)
	plaque.add_child(_sheen_rect)
	var st: Tween = _sheen_rect.create_tween()
	st.set_loops()
	st.tween_interval(2.4)
	st.tween_property(_sheen_rect, "position:x", 620.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	st.tween_property(_sheen_rect, "position:x", -140.0, 0.0)
	var plaque_style := StyleBoxFlat.new()
	plaque_style.bg_color = Color(0.08, 0.11, 0.19, 0.72)   # 玻璃牌匾底
	plaque_style.border_color = Color(0.32, 0.52, 0.86, 0.5) # 蓝光描边
	plaque_style.set_border_width_all(1)
	plaque_style.set_corner_radius_all(18)
	plaque_style.shadow_color = Color(0.15, 0.35, 0.65, 0.35)
	plaque_style.shadow_size = 16
	plaque_style.content_margin_left = 8
	plaque_style.content_margin_top = 8
	plaque_style.content_margin_right = 8
	plaque_style.content_margin_bottom = 8
	plaque.add_theme_stylebox_override("panel", plaque_style)
	box.add_child(plaque)

	# 内层细框（传统牌匾的双层描边）
	var frame := PanelContainer.new()
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0, 0, 0, 0)
	frame_style.border_color = Color(0.32, 0.52, 0.86, 0.25)
	frame_style.set_border_width_all(1)
	frame_style.set_corner_radius_all(12)
	frame_style.content_margin_left = 34
	frame_style.content_margin_top = 16
	frame_style.content_margin_right = 34
	frame_style.content_margin_bottom = 14
	frame.add_theme_stylebox_override("panel", frame_style)
	plaque.add_child(frame)

	var plaque_box := VBoxContainer.new()
	plaque_box.add_theme_constant_override("separation", 10)
	frame.add_child(plaque_box)

	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 14)
	plaque_box.add_child(title_row)

	var title := Button.new()
	title.text = "五子棋"
	title.alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 76)
	# 立体感：深色描边垫底，呼吸流光在 _process 中驱动 font_color
	title.add_theme_color_override("font_outline_color", Color(0.01, 0.05, 0.12, 0.85))
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_color", ACCENT_CYAN)
	title.add_theme_color_override("font_hover_color", Color("eaf7ff"))
	title.add_theme_color_override("font_pressed_color", ACCENT_CYAN)
	_title_glow_label = title
	_style_ghost_button(title)
	title.pressed.connect(_on_title_secret_click)
	title_row.add_child(title)

	# 朱砂印章（右下角按压感，白色「棋」字）
	var seal := PanelContainer.new()
	seal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var seal_style := StyleBoxFlat.new()
	seal_style.bg_color = ACCENT_CYAN
	seal_style.set_corner_radius_all(3)
	seal_style.content_margin_left = 7
	seal_style.content_margin_top = 3
	seal_style.content_margin_right = 7
	seal_style.content_margin_bottom = 3
	seal.add_theme_stylebox_override("panel", seal_style)
	var seal_label := Label.new()
	seal_label.text = "棋"
	seal_label.add_theme_font_size_override("font_size", 19)
	seal_label.add_theme_color_override("font_color", Color("f7efe0"))
	seal.add_child(seal_label)
	title_row.add_child(seal)

	var sub := Label.new()
	sub.text = "五子连珠 · 妙手对弈"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(280, 0)
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", Color("a9c2e8"))
	plaque_box.add_child(sub)
	_subtitle_label = sub

	# 副标题小字（彩蛋解锁时显示括号里的内容，字号更小、另起一行）
	var sub_note := Label.new()
	sub_note.text = ""
	sub_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_note.add_theme_font_size_override("font_size", 11)
	sub_note.add_theme_color_override("font_color", Color("8aa0c0"))
	plaque_box.add_child(sub_note)
	_subtitle_note = sub_note

	# ── 操作区 ──
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 26)
	box.add_child(gap)

	# 人机对战：唯一主按钮（朱砂实心）
	var pve := _make_menu_button("人机对战")
	pve.add_theme_font_size_override("font_size", 17)
	_style_primary_button(pve)
	pve.pressed.connect(func(): _start_game(GameMode.PVE))
	box.add_child(pve)

	# 难度：附属在人机对战下方，居中弱化
	var diff_row := HBoxContainer.new()
	diff_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(diff_row)
	var difficulty_btn := _make_small_button(_difficulty_label() + " ▾")
	difficulty_btn.pressed.connect(func(): _show_difficulty_menu(difficulty_btn))
	diff_row.add_child(difficulty_btn)
	_title_difficulty_button = difficulty_btn

	var pvp := _make_menu_button("双人对战")
	pvp.pressed.connect(func(): _start_game(GameMode.PVP))
	box.add_child(pvp)

	var eve := _make_menu_button("机机对战（古法编程 vs 推理引擎）")
	eve.pressed.connect(func(): _start_game(GameMode.EVE))
	eve.visible = _dlc_unlocked
	box.add_child(eve)
	_title_eve_button = eve

	var settings_btn := _make_menu_button("设置")
	settings_btn.pressed.connect(_open_settings)
	_style_ghost_outline_button(settings_btn)
	box.add_child(settings_btn)

	# 引擎署名（底部弱化）
	var credit := Label.new()
	credit.text = "Rapfi AI · NNUE 神经网络"
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credit.add_theme_font_size_override("font_size", 11)
	credit.add_theme_color_override("font_color", Color("6f86a8"))
	box.add_child(credit)


func _make_menu_button(text: String) -> Button:
	var b := _make_button()
	b.text = text
	b.custom_minimum_size = Vector2(260, 48)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_font_size_override("font_size", 16)
	return b


## 小号按钮（紧凑、靠右用的次级按钮）。
func _make_small_button(text: String) -> Button:
	var b := _make_button()
	b.text = text
	b.add_theme_font_size_override("font_size", 12)
	return b


## 从标题界面进入对局。
func _start_game(mode: int) -> void:
	game_mode = mode
	# 离开标题界面时立即收起彩蛋提示，避免（如解锁提示）跟随进入对局
	if _toast_label != null:
		_toast_label.modulate.a = 0.0
	_toast_until = -1.0
	if _title_layer != null:
		_clear_title_refs()
		_title_layer.queue_free()
		_title_layer = null
	_in_game = true
	_build_ui()
	_build_settings_popup()
	_new_game()


## 打开设置弹窗。
func _open_settings() -> void:
	if _settings_popup == null:
		_build_settings_popup()
	_refresh_buttons()
	# 小窗口下限制设置面板高度，避免溢出屏幕（godot-ui 响应式建议）
	if _settings_scroll != null:
		var vp := get_viewport_rect().size
		_settings_scroll.custom_minimum_size = Vector2(360, clampf(vp.y * 0.72, 320.0, 560.0))
	_settings_popup.popup_centered()


## 返回标题界面（释放对局 UI，保留引擎进程避免重复加载权重）。
func _return_to_title() -> void:
	_in_game = false
	ai_thinking = false
	_stop_pending = false
	_turn_generation += 1
	game_mode = GameMode.PVE  # 退出机机对战等模式：标题界面的难度菜单恢复为人机档位
	_hide_win_banner()
	if ai != null:
		ai.stop_thinking()
	if _settings_popup != null:
		_settings_popup.hide()
	if _game_ui_layer != null:
		_game_ui_layer.queue_free()
		_game_ui_layer = null
	if _settings_popup != null:
		_settings_popup.queue_free()
		_settings_popup = null
	if _difficulty_menu != null:
		_difficulty_menu.queue_free()
		_difficulty_menu = null
		_difficulty_anchor = null
	_build_title_screen()
	# 解锁提示只在解锁瞬间以 toast 展示；标题副标语保持默认，不再常驻覆盖
	queue_redraw()


## 彩蛋入口：点击标题「五子棋」解锁隐藏难度「古法编程」，并直接切换为该难度。
func _on_title_secret_click() -> void:
	if _dlc_unlocked:
		return
	_dlc_unlocked = true
	_classic_mode = true  # 触发后直接切换到古法编程
	if _subtitle_label != null:
		_subtitle_label.text = "已解锁隐藏难度：古法编程"
	if _subtitle_note != null:
		_subtitle_note.text = "（初学C语言时写的）"
	if _title_eve_button != null:
		_title_eve_button.visible = true  # 显示「机机对战」
	_update_title_difficulty()
	_show_toast("已解锁隐藏难度：古法编程")


## 更新标题界面难度按钮显示。
func _update_title_difficulty() -> void:
	if _title_difficulty_button != null:
		_title_difficulty_button.text = _difficulty_label() + " ▾"


## 难度文字（含古法编程隐藏档）。
func _difficulty_label() -> String:
	if _classic_mode:
		return "难度：古法编程"
	return "难度：%s" % ["简单", "中等", "困难"][ai_difficulty]


## 弹出难度子菜单（向下弹出，左缘与按钮对齐）。
func _show_difficulty_menu(anchor: Button) -> void:
	if _difficulty_menu == null:
		_difficulty_menu = PopupPanel.new()
		_difficulty_menu.name = "DifficultyMenu"
		var ps := StyleBoxFlat.new()
		ps.bg_color = Color(0.09, 0.12, 0.20, 0.97)
		ps.border_color = Color(0.32, 0.46, 0.72, 0.5)
		ps.set_border_width_all(1)
		ps.set_corner_radius_all(12)
		ps.shadow_color = Color(0.08, 0.30, 0.55, 0.35)
		ps.shadow_size = 14
		ps.content_margin_left = 6
		ps.content_margin_top = 6
		ps.content_margin_right = 6
		ps.content_margin_bottom = 6
		_difficulty_menu.add_theme_stylebox_override("panel", ps)
		add_child(_difficulty_menu)
		_difficulty_menu.popup_hide.connect(_on_difficulty_menu_closed)
	# 清空旧选项并重建
	for c in _difficulty_menu.get_children():
		_difficulty_menu.remove_child(c)
		c.queue_free()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	_difficulty_menu.add_child(box)
	var current := _current_difficulty_id()
	for opt in _difficulty_options():
		var b := Button.new()
		var id := int(opt["id"])
		b.custom_minimum_size = Vector2(150, 40)
		b.add_theme_font_size_override("font_size", 13)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if id == current:
			# 选中项：朱砂底纹 + 左侧强调条 + 勾选 + 朱砂文字
			b.text = "✓  " + str(opt["label"])
			b.add_theme_color_override("font_color", Color("8fdcff"))
			b.add_theme_color_override("font_hover_color", Color("8fdcff"))
			b.add_theme_color_override("font_pressed_color", Color("ffffff"))
			var sel := StyleBoxFlat.new()
			sel.bg_color = Color(0.20, 0.32, 0.55, 0.6)
			sel.border_color = Color(0.32, 0.78, 0.99, 0.8)
			sel.set_border_width_all(0)
			sel.border_width_left = 3
			sel.set_corner_radius_all(12)
			sel.content_margin_left = 12
			sel.content_margin_right = 12
			sel.content_margin_top = 8
			sel.content_margin_bottom = 8
			b.add_theme_stylebox_override("normal", sel)
			b.add_theme_stylebox_override("hover", sel)
			b.add_theme_stylebox_override("pressed", sel)
		else:
			# 未选项：透明底 + 米纸白 85%，悬停微亮
			b.text = str(opt["label"])
			b.add_theme_color_override("font_color", Color("c3cfe2"))
			b.add_theme_color_override("font_hover_color", Color("ffffff"))
			b.add_theme_color_override("font_pressed_color", Color("ffffff"))
			var flat := StyleBoxFlat.new()
			flat.bg_color = Color(0, 0, 0, 0)
			flat.set_corner_radius_all(12)
			flat.content_margin_left = 12
			flat.content_margin_right = 12
			flat.content_margin_top = 8
			flat.content_margin_bottom = 8
			b.add_theme_stylebox_override("normal", flat)
			var hover := flat.duplicate()
			hover.bg_color = Color(0.14, 0.20, 0.34, 0.6)
			b.add_theme_stylebox_override("hover", hover)
			b.add_theme_stylebox_override("pressed", hover)
		b.pressed.connect(_on_difficulty_option.bind(id))
		box.add_child(b)
	_difficulty_menu.reset_size()
	# 向下弹出，左缘与按钮对齐；越界则向左收
	var rect := anchor.get_global_rect()
	var viewport_w := get_viewport_rect().size.x
	var menu_w := _difficulty_menu.size.x
	var x := rect.position.x
	if x + menu_w > viewport_w - 8.0:
		x = maxf(8.0, viewport_w - 8.0 - menu_w)
	_difficulty_menu.position = Vector2(x, rect.position.y + rect.size.y + 4.0)
	# 展开时高亮触发按钮（朱砂边框）
	_difficulty_anchor = anchor
	_set_difficulty_open(true)
	_difficulty_menu.popup()


## 难度菜单关闭后恢复触发按钮样式。
func _on_difficulty_menu_closed() -> void:
	_set_difficulty_open(false)


## 切换难度触发按钮的高亮态（展开时为朱砂边框）。
func _set_difficulty_open(open_: bool) -> void:
	if _difficulty_anchor == null:
		return
	if open_:
		var s := _make_flat_style()
		s.border_color = ACCENT_CYAN
		_difficulty_anchor.add_theme_stylebox_override("normal", s)
		var h := _make_flat_style()
		h.bg_color = Color(0.16, 0.23, 0.38, 0.72)
		h.border_color = ACCENT_CYAN
		_difficulty_anchor.add_theme_stylebox_override("hover", h)
	else:
		_apply_button_styles(_difficulty_anchor)


## 当前选中的难度 id（用于子菜单勾选标记）。
func _current_difficulty_id() -> int:
	if game_mode == GameMode.EVE:
		return _eve_difficulty
	if _classic_mode:
		return 3
	return ai_difficulty


## 难度选项列表（机机对战只有推理引擎三档）。
func _difficulty_options() -> Array:
	var opts := [
		{"id": 0, "label": "简单"},
		{"id": 1, "label": "中等"},
		{"id": 2, "label": "困难"},
	]
	if game_mode != GameMode.EVE and _dlc_unlocked:
		opts.append({"id": 3, "label": "古法编程"})
	return opts


## 选择难度子菜单中的某项。
func _on_difficulty_option(id: int) -> void:
	if _difficulty_menu != null:
		_difficulty_menu.hide()
	_set_difficulty_open(false)
	if game_mode == GameMode.EVE:
		_eve_difficulty = id
	elif id == 3:
		_classic_mode = true
	else:
		_classic_mode = false
		ai_difficulty = id
	_refresh_buttons()
	_update_title_difficulty()
	if _in_game:
		_new_game()


func _build_ui() -> void:
	_game_ui_layer = CanvasLayer.new()
	var canvas_layer := _game_ui_layer
	add_child(canvas_layer)

	var panel := PanelContainer.new()
	panel.position = SIDE_PANEL_POSITION
	panel.size = SIDE_PANEL_SIZE
	canvas_layer.add_child(panel)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.10, 0.17, 0.78)
	panel_style.border_color = Color(0.30, 0.42, 0.68, 0.4)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(14)
	panel_style.shadow_color = Color(0.08, 0.30, 0.55, 0.35)
	panel_style.shadow_size = 18
	panel_style.content_margin_left = 18
	panel_style.content_margin_top = 18
	panel_style.content_margin_right = 18
	panel_style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", panel_style)

	# 按钮较多，用 ScrollContainer 包裹避免溢出裁切
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var layout := VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 7)
	scroll.add_child(layout)

	# 头部：标题 + 模式徽章同行（一眼可读当前对局类型）
	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 8)
	layout.add_child(head_row)
	var title_label := Label.new()
	title_label.text = "五子棋"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", ACCENT_CYAN)
	head_row.add_child(title_label)
	_mode_badge = Label.new()
	_mode_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mode_badge.add_theme_font_size_override("font_size", 12)
	_mode_badge.add_theme_color_override("font_color", Color("9db4d8"))
	head_row.add_child(_mode_badge)

	# 状态胶囊：圆点颜色编码 + 文字（比裸文本更快被读取）
	_status_pill = PanelContainer.new()
	var pill := StyleBoxFlat.new()
	pill.bg_color = Color(0.10, 0.15, 0.25, 0.66)
	pill.border_color = Color(0.36, 0.50, 0.78, 0.35)
	pill.set_border_width_all(1)
	pill.set_corner_radius_all(19)
	pill.content_margin_left = 14
	pill.content_margin_right = 14
	pill.content_margin_top = 7
	pill.content_margin_bottom = 7
	_status_pill.add_theme_stylebox_override("panel", pill)
	var pill_row := HBoxContainer.new()
	pill_row.add_theme_constant_override("separation", 8)
	_status_pill.add_child(pill_row)
	_status_dot = Label.new()
	_status_dot.text = "●"
	_status_dot.add_theme_font_size_override("font_size", 13)
	_status_dot.add_theme_color_override("font_color", Color("4ade80"))
	pill_row.add_child(_status_dot)
	status_label = Label.new()
	status_label.custom_minimum_size = Vector2(0, 24)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color("e8f0fc"))
	pill_row.add_child(status_label)
	layout.add_child(_status_pill)

	# ── 对局 ──
	layout.add_child(_section_label("对局"))
	mode_button = _make_button()
	mode_button.pressed.connect(_on_mode_pressed)
	layout.add_child(mode_button)

	color_button = _make_button()
	color_button.pressed.connect(_on_color_pressed)
	layout.add_child(color_button)

	difficulty_button = _make_button()
	difficulty_button.pressed.connect(_on_difficulty_pressed)
	layout.add_child(difficulty_button)

	# 设置弹窗按钮
	var settings_btn := _make_button()
	settings_btn.text = "设置选项"
	settings_btn.pressed.connect(_open_settings)
	layout.add_child(settings_btn)

	# ── 实时分析 ──
	layout.add_child(_section_label("实时分析"))
	analysis_label = Label.new()
	analysis_label.text = "等待引擎响应…"
	analysis_label.add_theme_font_size_override("font_size", 12)
	analysis_label.add_theme_color_override("font_color", Color("9db4d8"))
	analysis_label.add_theme_constant_override("line_spacing", 3)
	analysis_label.custom_minimum_size = Vector2(0, 70)
	layout.add_child(analysis_label)

	# ── 操作（分隔线 + 按钮行，置底）──
	var divider := ColorRect.new()
	divider.color = Color(0.30, 0.40, 0.60, 0.4)
	divider.custom_minimum_size = Vector2(0, 1)
	layout.add_child(divider)
	layout.add_child(_section_label("操作"))
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	layout.add_child(action_row)

	undo_button = _make_button()
	undo_button.text = "悔棋"
	undo_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	undo_button.pressed.connect(_on_undo_pressed)
	action_row.add_child(undo_button)

	stop_button = _make_button()
	stop_button.text = "停止"
	stop_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stop_button.pressed.connect(_on_stop_pressed)
	action_row.add_child(stop_button)

	restart_button = _make_button()
	restart_button.text = "新局"
	restart_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restart_button.pressed.connect(_on_restart_pressed)
	_style_primary_button(restart_button)
	action_row.add_child(restart_button)

	# 操作提示（置底，弱化）
	info_label = Label.new()
	info_label.text = "左键：落子\nR：重新开始\nCtrl+C / Ctrl+V：复制局面"
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.add_theme_font_size_override("font_size", 12)
	info_label.add_theme_color_override("font_color", Color("9db4d8"))
	layout.add_child(info_label)

	_refresh_buttons()


## 设置弹窗：把规则/引擎/显示/AI 执子等设置项收进 PopupPanel。
func _build_settings_popup() -> void:
	if _settings_popup != null:
		return
	_settings_popup = PopupPanel.new()
	_settings_popup.title = "设置"
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.08, 0.11, 0.18, 0.96)
	ps.border_color = Color(0.30, 0.45, 0.72, 0.5)
	ps.set_border_width_all(1)
	ps.set_corner_radius_all(14)
	ps.shadow_color = Color(0.08, 0.30, 0.55, 0.35)
	ps.shadow_size = 20
	ps.content_margin_left = 20
	ps.content_margin_top = 18
	ps.content_margin_right = 20
	ps.content_margin_bottom = 20
	_settings_popup.add_theme_stylebox_override("panel", ps)
	add_child(_settings_popup)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(360, 500)
	_settings_popup.add_child(scroll)
	_settings_scroll = scroll

	var layout := VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 6)
	scroll.add_child(layout)

	# 规则
	layout.add_child(_section_label("规则"))
	rule_button = _make_button()
	rule_button.pressed.connect(_on_rule_pressed)
	layout.add_child(rule_button)
	board_size_button = _make_button()
	board_size_button.pressed.connect(_on_board_size_pressed)
	layout.add_child(board_size_button)

	# AI 执子（机机对战下隐藏，双方本就是 AI）
	_ai_section_label = _section_label("AI 执子")
	layout.add_child(_ai_section_label)
	_ai_section_row = HBoxContainer.new()
	_ai_section_row.add_theme_constant_override("separation", 8)
	layout.add_child(_ai_section_row)
	ai_black_button = _make_button()
	ai_black_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ai_black_button.pressed.connect(_on_ai_black_pressed)
	_ai_section_row.add_child(ai_black_button)
	ai_white_button = _make_button()
	ai_white_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ai_white_button.pressed.connect(_on_ai_white_pressed)
	_ai_section_row.add_child(ai_white_button)

	# 引擎（常用）
	layout.add_child(_section_label("引擎"))
	think_time_button = _make_button()
	think_time_button.pressed.connect(_on_think_time_pressed)
	layout.add_child(think_time_button)
	strength_button = _make_button()
	strength_button.pressed.connect(_on_strength_pressed)
	layout.add_child(strength_button)

	# 引擎高级（一般无需调整）
	layout.add_child(_section_label("引擎高级"))
	cand_range_button = _make_button()
	cand_range_button.pressed.connect(_on_cand_range_pressed)
	layout.add_child(cand_range_button)
	threads_button = _make_button()
	threads_button.pressed.connect(_on_threads_pressed)
	layout.add_child(threads_button)
	hash_button = _make_button()
	hash_button.pressed.connect(_on_hash_pressed)
	layout.add_child(hash_button)
	pondering_button = _make_button()
	pondering_button.pressed.connect(_on_pondering_pressed)
	layout.add_child(pondering_button)

	# 显示
	layout.add_child(_section_label("显示"))
	var display_grid := GridContainer.new()
	display_grid.columns = 2
	display_grid.add_theme_constant_override("h_separation", 6)
	display_grid.add_theme_constant_override("v_separation", 6)
	layout.add_child(display_grid)
	show_coord_button = _make_button()
	show_coord_button.pressed.connect(_on_show_coord_pressed)
	display_grid.add_child(show_coord_button)
	show_index_button = _make_button()
	show_index_button.pressed.connect(_on_show_index_pressed)
	display_grid.add_child(show_index_button)
	show_winline_button = _make_button()
	show_winline_button.pressed.connect(_on_show_winline_pressed)
	display_grid.add_child(show_winline_button)
	show_eval_button = _make_button()
	show_eval_button.pressed.connect(_on_show_eval_pressed)
	display_grid.add_child(show_eval_button)
	fx_button = _make_button()
	fx_button.pressed.connect(_on_fx_pressed)
	display_grid.add_child(fx_button)
	theme_button = _make_button()
	theme_button.pressed.connect(_on_theme_pressed)
	layout.add_child(theme_button)

	# 返回标题
	var return_btn := _make_button()
	return_btn.text = "返回标题"
	return_btn.pressed.connect(_return_to_title)
	_style_ghost_outline_button(return_btn)
	layout.add_child(return_btn)

	_refresh_buttons()


## 分区小标题。
func _section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text.to_upper()
	lbl.custom_minimum_size = Vector2(0, 24)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color("6fb8e8"))
	return lbl


## 透明「幽灵」按钮：只保留文字与点击，视觉上像 Label（用于彩蛋入口）。
func _style_ghost_button(b: Button) -> void:
	var s := StyleBoxEmpty.new()
	b.add_theme_stylebox_override("normal", s)
	b.add_theme_stylebox_override("hover", s)
	b.add_theme_stylebox_override("pressed", s)
	b.add_theme_stylebox_override("focus", s)


## 次级「描边幽灵」按钮：透明底 + 细描边，用于设置等三级入口。
func _style_ghost_outline_button(b: Button) -> void:
	var normal := _make_flat_style()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.border_color = Color(0.40, 0.55, 0.85, 0.3)
	b.add_theme_stylebox_override("normal", normal)
	var hover := _make_flat_style()
	hover.bg_color = Color(0.14, 0.20, 0.34, 0.6)
	hover.border_color = Color(0.32, 0.78, 0.99, 0.5)
	b.add_theme_stylebox_override("hover", hover)
	var pressed := _make_flat_style()
	pressed.bg_color = Color(0.10, 0.15, 0.25, 0.7)
	pressed.border_color = Color(0.32, 0.78, 0.99, 0.6)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_color_override("font_color", Color("c3cfe2"))
	b.add_theme_color_override("font_hover_color", Color("ffffff"))
	b.add_theme_color_override("font_pressed_color", Color("ffffff"))


func _make_button() -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 38)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_apply_button_styles(b)
	b.add_theme_color_override("font_color", Color("dbe4f2"))
	b.add_theme_color_override("font_hover_color", Color("ffffff"))
	b.add_theme_color_override("font_pressed_color", Color("ffffff"))
	b.add_theme_font_size_override("font_size", 13)
	return b


## 棋谱控制行：玻璃拟态、较高圆角，避免所有控件都像独立卡片。
func _make_flat_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.10, 0.14, 0.22, 0.55)
	s.border_color = Color(0.40, 0.55, 0.85, 0.28)
	s.set_border_width_all(1)
	s.set_corner_radius_all(10)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 7
	s.content_margin_bottom = 7
	return s


## 应用统一交互态：悬停提亮边线，按下产生轻微内陷感。
func _apply_button_styles(b: Button) -> void:
	var normal := _make_flat_style()
	b.add_theme_stylebox_override("normal", normal)
	var hover := _make_flat_style()
	hover.bg_color = Color(0.16, 0.23, 0.38, 0.72)
	hover.border_color = Color(0.32, 0.78, 0.99, 0.65)
	b.add_theme_stylebox_override("hover", hover)
	var pressed := _make_flat_style()
	pressed.bg_color = Color(0.12, 0.18, 0.30, 0.9)
	pressed.border_color = Color(0.32, 0.78, 0.99, 0.9)
	b.add_theme_stylebox_override("pressed", pressed)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = Color(0.65, 0.55, 0.98, 0.9)
	focus.set_border_width_all(1)
	focus.set_corner_radius_all(10)
	focus.expand_margin_left = 2
	focus.expand_margin_top = 2
	focus.expand_margin_right = 2
	focus.expand_margin_bottom = 2
	b.add_theme_stylebox_override("focus", focus)
	var disabled := _make_flat_style()
	disabled.bg_color = Color(0.08, 0.11, 0.17, 0.4)
	disabled.border_color = Color(0.20, 0.26, 0.38, 0.3)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_color_override("font_disabled_color", Color("5b6474"))


## 主操作按钮（如「新局」）：实心朱砂，层级高于普通按钮。
func _style_primary_button(b: Button) -> void:
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var normal := _make_flat_style()
	normal.bg_color = Color("0ea5e9")
	normal.border_color = Color("7dd3fc")
	normal.set_corner_radius_all(12)
	normal.shadow_color = Color(0.22, 0.60, 0.96, 0.35)
	normal.shadow_size = 9
	b.add_theme_stylebox_override("normal", normal)
	var hover := _make_flat_style()
	hover.bg_color = Color("38bdf8")
	hover.border_color = Color("bae6fd")
	hover.set_corner_radius_all(12)
	hover.shadow_color = Color(0.30, 0.72, 0.98, 0.5)
	hover.shadow_size = 12
	b.add_theme_stylebox_override("hover", hover)
	var pressed := _make_flat_style()
	pressed.bg_color = Color("0284c7")
	pressed.border_color = Color("38bdf8")
	pressed.set_corner_radius_all(12)
	b.add_theme_stylebox_override("pressed", pressed)
	var disabled := _make_flat_style()
	disabled.bg_color = Color(0.10, 0.18, 0.28, 0.5)
	disabled.border_color = Color(0.30, 0.40, 0.55, 0.4)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_color_override("font_color", Color("ffffff"))
	b.add_theme_color_override("font_hover_color", Color("ffffff"))
	b.add_theme_color_override("font_pressed_color", Color("ffffff"))
	b.add_theme_color_override("font_disabled_color", Color("8fb2cc"))


## 二态设置的选中样式，在不增加额外控件的前提下清楚表达开关状态。
func _style_toggle_state(b: Button, enabled: bool) -> void:
	_apply_button_styles(b)
	if not enabled:
		b.add_theme_color_override("font_color", Color("8891a5"))
		return
	var selected := _make_flat_style()
	selected.bg_color = Color(0.20, 0.32, 0.55, 0.6)
	selected.border_color = Color(0.32, 0.78, 0.99, 0.8)
	selected.border_width_left = 3
	b.add_theme_stylebox_override("normal", selected)
	b.add_theme_color_override("font_color", Color("8fdcff"))


func _refresh_buttons() -> void:
	if mode_button:
		mode_button.text = "模式：%s" % _mode_name()
	if _mode_badge != null:
		_mode_badge.text = "· %s" % _mode_name()
	if color_button:
		color_button.text = "你执：%s" % ("黑棋" if human_color == 1 else "白棋")
		color_button.visible = game_mode == GameMode.PVE
	if difficulty_button:
		if game_mode == GameMode.EVE:
			difficulty_button.text = "推理引擎：%s" % ["简单", "中等", "困难"][_eve_difficulty]
		else:
			difficulty_button.text = _difficulty_label()
		difficulty_button.visible = game_mode == GameMode.PVE or game_mode == GameMode.EVE
	if rule_button:
		rule_button.text = "规则：%s" % ["无禁手", "标准（禁长连）", "有禁手"][_rule_index]
	if board_size_button:
		board_size_button.text = "棋盘：%d×%d" % [board_size, board_size]
	if think_time_button:
		think_time_button.text = "思考：%s" % ["快速", "中等", "慢速", "分析"][_think_time_index]
	if cand_range_button:
		cand_range_button.text = "选点：%s" % ["小范围", "较小", "中等", "较大", "大范围", "全盘"][_cand_range_index]
	if show_coord_button:
		show_coord_button.text = "坐标：%s" % ("开" if _show_coord else "关")
	if fx_button:
		fx_button.text = "动效：%s" % ("减弱" if _reduced_fx else "完整")
		_style_toggle_state(show_coord_button, _show_coord)
	if show_index_button:
		show_index_button.text = "序号：%s" % ("开" if _show_index else "关")
		_style_toggle_state(show_index_button, _show_index)
	if show_winline_button:
		show_winline_button.text = "胜线：%s" % ("开" if _show_winline else "关")
		_style_toggle_state(show_winline_button, _show_winline)
	if show_eval_button:
		show_eval_button.text = "估值：%s" % ("开" if _show_eval else "关")
		_style_toggle_state(show_eval_button, _show_eval)
	if theme_button:
		theme_button.text = "主题：%s" % ["深色", "木质", "浅色"][_theme_index]
	if threads_button:
		var thread_names: Array = ["自动", "1", "2", "4", "8"]
		var thread_opts: Array = [0, 1, 2, 4, 8]
		threads_button.text = "线程：%s" % thread_names[thread_opts.find(_threads_override)]
	if hash_button:
		hash_button.text = "置换表：%s" % ["128MB", "256MB", "512MB"][_hash_size_index]
	if strength_button:
		strength_button.text = "棋力：%s" % ["30", "50", "70", "85", "100"][_strength_index]
	if pondering_button:
		pondering_button.text = "后台思考：%s" % ("开" if _pondering else "关")
		_style_toggle_state(pondering_button, _pondering)
	if ai_black_button:
		ai_black_button.text = "AI执黑：%s" % ("开" if _ai_black else "关")
		_style_toggle_state(ai_black_button, _ai_black)
	if ai_white_button:
		ai_white_button.text = "AI执白：%s" % ("开" if _ai_white else "关")
		_style_toggle_state(ai_white_button, _ai_white)
	# 机机对战下双方本就是 AI，隐藏「AI 执子」分区
	var show_ai_side := game_mode != GameMode.EVE
	if _ai_section_label:
		_ai_section_label.visible = show_ai_side
	if _ai_section_row:
		_ai_section_row.visible = show_ai_side


func _on_mode_pressed() -> void:
	# 机机对战从标题进入；对局内点模式按钮则在 人机/双人 间切换（机机→人机）
	if move_count > 1 and winner == 0:
		_confirm_mode_switch()
		return
	_apply_mode_switch()

func _apply_mode_switch() -> void:
	if game_mode == GameMode.PVE:
		game_mode = GameMode.PVP
	else:
		game_mode = GameMode.PVE
	_refresh_buttons()
	_new_game()

## 对局进行中切模式：先确认放弃本局，避免误触丢局。
func _confirm_mode_switch() -> void:
	if _mode_confirm != null:
		_mode_confirm.queue_free()
	_mode_confirm = ConfirmationDialog.new()
	_mode_confirm.dialog_text = "当前对局尚未结束，切换模式将放弃本局。确定切换？"
	_mode_confirm.ok_button_text = "切换"
	_mode_confirm.cancel_button_text = "继续对局"
	add_child(_mode_confirm)
	_mode_confirm.confirmed.connect(_apply_mode_switch)
	_mode_confirm.popup_centered()


## 模式显示名。
func _mode_name() -> String:
	match game_mode:
		GameMode.PVE:
			return "人机"
		GameMode.EVE:
			return "机机对战"
		_:
			return "双人"


func _on_color_pressed() -> void:
	human_color = 2 if human_color == 1 else 1
	ai_color = 2 if human_color == 1 else 1
	_refresh_buttons()
	_new_game()


func _on_difficulty_pressed() -> void:
	# 难度改用子菜单选择，不再循环切换
	_show_difficulty_menu(difficulty_button)


func _on_rule_pressed() -> void:
	_rule_index = (_rule_index + 1) % 3
	if ai != null:
		ai.set_config("rule", _rule_index)
	_refresh_buttons()
	_new_game()


func _on_board_size_pressed() -> void:
	# 棋盘大小在 5~22 循环切换（常见：5/9/11/13/15/17/19）
	var sizes := [5, 9, 11, 13, 15, 17, 19]
	var idx := sizes.find(board_size)
	board_size = sizes[(idx + 1) % sizes.size()]
	if ai != null:
		ai.board_size = board_size
		ai.new_game()
	_refresh_buttons()
	_new_game()


func _on_think_time_pressed() -> void:
	_think_time_index = (_think_time_index + 1) % 4
	# 档位对应思考时间（毫秒）：快 300 / 中 1500 / 慢 5000 / 分析 10000
	var timeouts := [300, 1500, 5000, 10000]
	if ai != null:
		ai.set_config("timeout_turn", timeouts[_think_time_index])
	_refresh_buttons()


func _on_cand_range_pressed() -> void:
	_cand_range_index = (_cand_range_index + 1) % 6
	if ai != null:
		ai.set_config("caution_factor", _cand_range_index)
	_refresh_buttons()


func _on_show_coord_pressed() -> void:
	_show_coord = not _show_coord
	_refresh_buttons()
	queue_redraw()


func _on_show_index_pressed() -> void:
	_show_index = not _show_index
	_refresh_buttons()
	queue_redraw()


func _on_show_winline_pressed() -> void:
	_show_winline = not _show_winline
	_refresh_buttons()
	queue_redraw()


func _on_show_eval_pressed() -> void:
	_show_eval = not _show_eval
	_refresh_buttons()
	queue_redraw()


func _on_theme_pressed() -> void:
	_theme_index = (_theme_index + 1) % 3
	_apply_theme()
	_refresh_buttons()
	queue_redraw()


func _on_threads_pressed() -> void:
	# 线程：0 自动 / 1 / 2 / 4 / 8
	var opts := [0, 1, 2, 4, 8]
	var idx := opts.find(_threads_override)
	_threads_override = opts[(idx + 1) % opts.size()]
	if ai != null:
		ai.set_config("threads", _threads_override if _threads_override > 0 else OS.get_processor_count())
	_refresh_buttons()


func _on_hash_pressed() -> void:
	_hash_size_index = (_hash_size_index + 1) % 3
	var sizes := [128, 256, 512]
	if ai != null:
		ai.set_config("hash_size", sizes[_hash_size_index])
	_refresh_buttons()


func _on_strength_pressed() -> void:
	_strength_index = (_strength_index + 1) % 5
	var strengths := [30, 50, 70, 85, 100]
	if ai != null:
		ai.set_config("strength", strengths[_strength_index])
	_refresh_buttons()


func _on_pondering_pressed() -> void:
	_pondering = not _pondering
	if ai != null:
		ai.set_config("pondering", 1 if _pondering else 0)
	_refresh_buttons()


func _on_ai_black_pressed() -> void:
	_ai_black = not _ai_black
	_refresh_buttons()
	_new_game()


func _on_ai_white_pressed() -> void:
	_ai_white = not _ai_white
	_refresh_buttons()
	_new_game()


## 应用主题配色（0深色 / 1木质 / 2浅色）。
func _apply_theme() -> void:
	match _theme_index:
		0:  # 星夜·极光（默认）—— 深空蓝 + 电光青
			_cur_bg_top = Color("0a0d18")
			_cur_bg_bottom = Color("151b30")
			_cur_board = Color("27314d")
			_cur_grid = Color("3f5788")
			_cur_star = Color("6f8fd0")
			_cur_black = Color("0c0f16")
			_cur_white = Color("e9edf6")
		1:  # 木质
			_cur_bg_top = Color("2a1f14")
			_cur_bg_bottom = Color("1a120b")
			_cur_board = Color("d4a156")
			_cur_grid = Color("5b371b")
			_cur_star = Color("3b2410")
			_cur_black = Color("1f1f1f")
			_cur_white = Color("f5efe2")
		2:  # 浅色
			_cur_bg_top = Color("e8ecf3")
			_cur_bg_bottom = Color("d5dbe6")
			_cur_board = Color("c9b28a")
			_cur_grid = Color("6b5b3e")
			_cur_star = Color("4a3d28")
			_cur_black = Color("1a1a1a")
			_cur_white = Color("ffffff")


func _on_undo_pressed() -> void:
	if _move_history.is_empty() or ai_thinking:
		return
	# 悔棋：撤销最后一步（或人机模式下撤销两步：AI+玩家）
	var steps := 1
	if game_mode == GameMode.PVE and _move_history.size() >= 2:
		steps = 2
	for i in range(steps):
		if _move_history.is_empty():
			break
		var cell: Vector2i = _move_history.pop_back()
		board[cell.y][cell.x] = 0
		move_count -= 1
		last_move = Vector2i(-1, -1) if _move_history.is_empty() else _move_history.back()
		current_player = 2 if current_player == 1 else 1
	winning_cells.clear()
	winner = 0
	_threat_cells.clear()
	_threat_type = ""
	_attack_cells.clear()
	_attack_type = ""
	_attack_time = -1.0
	# 悔棋后同步推理引擎棋盘，避免引擎仍按旧局面应子（古法编程读的是当前 board，无需同步）
	if ai != null:
		ai.sync_board(board, ai_color)
	_update_status_text()
	queue_redraw()


func _on_stop_pressed() -> void:
	if ai != null and ai_thinking:
		_stop_pending = true
		ai.stop_thinking()


## 停止 AI 后：撤销玩家刚下的一手，回到玩家回合（PVE）。
func _apply_stop_undo() -> void:
	if game_mode == GameMode.PVE and not _move_history.is_empty():
		var cell: Vector2i = _move_history.pop_back()
		board[cell.y][cell.x] = 0
		move_count -= 1
		last_move = Vector2i(-1, -1) if _move_history.is_empty() else _move_history.back()
		current_player = human_color
		winning_cells.clear()
		winner = 0
		_threat_cells.clear()
		_threat_type = ""
		_attack_cells.clear()
		_attack_type = ""
		_attack_time = -1.0
		if ai != null:
			ai.sync_board(board, ai_color)
		_show_toast("已停止，可重下这一手")
	else:
		if game_mode == GameMode.PVE:
			current_player = human_color
		_show_toast("已停止")
	_update_status_text()
	queue_redraw()


# ============================================================
# 游戏流程
# ============================================================
## 判断某颜色是否由 AI 落子（AI 执黑/执白开关优先，其次人机模式的 AI 方）。
func _ai_plays(player: int) -> bool:
	if game_mode == GameMode.EVE:
		return true  # 机机对战：双方都是 AI
	if _ai_black and player == 1:
		return true
	if _ai_white and player == 2:
		return true
	if game_mode == GameMode.PVE:
		return player == ai_color
	return false


## 某颜色是否由古法编程（老C算法）执子：机机对战黑=古法编程、白=推理引擎。
func _classic_side(player: int) -> bool:
	if game_mode == GameMode.EVE:
		return player == 1
	return _classic_mode


## 请求禁手点（有禁手规则时引擎输出 FORBID）。
func _request_forbid() -> void:
	_forbid_cells.clear()
	if _classic_mode or ai == null or _rule_index != 2:
		return
	ai.show_forbid(board, ai_color)
	queue_redraw()


func _new_game() -> void:
	if not _in_game:
		return
	_turn_generation += 1
	_stop_pending = false
	# 不再重启引擎进程：复用已有引擎，只重置棋盘（引擎进程只启动一次，避免反复加载 NNUE 权重）
	board.clear()
	for y in range(board_size):
		var row := []
		row.resize(board_size)
		for x in range(board_size):
			row[x] = 0
		board.append(row)

	current_player = 1
	winner = 0
	move_count = 0
	last_move = Vector2i(-1, -1)
	winning_cells.clear()
	ai_thinking = false
	_threat_cells.clear()
	_threat_type = ""
	_attack_cells.clear()
	_attack_type = ""
	_attack_time = -1.0
	_win_anim = 0.0
	_move_history.clear()
	_analysis_data.clear()
	_eval_history.clear()
	_realtime_best = Vector2i(-1, -1)
	_realtime_lost.clear()
	_forbid_cells.clear()
	_pv_list.clear()
	_cur_pv = 0
	_update_analysis_display()
	_hide_win_banner()

	_update_status_text()
	queue_redraw()

	if game_mode == GameMode.PVE or game_mode == GameMode.EVE or _ai_black or _ai_white:
		_start_ai_and_maybe_first_move()


## 启动/复用推理引擎（Rapfi）。返回是否成功。
func _ensure_rapfi(difficulty: int) -> bool:
	if ai == null:
		ai = RapfiAI.new()
		ai.analysis_callback = _on_engine_analysis
		ai.board_size = board_size
		var ok: bool = ai.start(difficulty)
		if not ok:
			push_error("AI 引擎启动失败，已退回双人对战")
			_teardown_ai()
			game_mode = GameMode.PVP
			_refresh_buttons()
			_update_status_text()
			return false
	else:
		# 复用引擎：重置棋盘 + 刷新难度参数
		ai.analysis_callback = _on_engine_analysis
		ai.board_size = board_size
		ai.set_difficulty(difficulty)
		ai.new_game()
	return true


func _start_ai_and_maybe_first_move() -> void:
	if game_mode == GameMode.EVE:
		# 机机对战：古法编程（黑）+ 推理引擎（白），推理引擎独立难度（默认中等）
		ai_color = 2  # 推理引擎执白
		if _classic_ai == null:
			_classic_ai = ClassicAI.new()
		_classic_ai.set_size(board_size)
		if not _ensure_rapfi(_eve_difficulty):
			return
	elif _classic_mode:
		# 古法编程：纯 GDScript，无需启动 Rapfi 引擎
		if _classic_ai == null:
			_classic_ai = ClassicAI.new()
		_classic_ai.set_size(board_size)
		_update_analysis_display()
	else:
		if not _ensure_rapfi(ai_difficulty):
			return

	if _ai_plays(1):
		_ai_turn_first()
	else:
		_request_forbid()


func _teardown_ai() -> void:
	if ai != null:
		ai.stop()
		ai = null
	ai_thinking = false


func _on_restart_pressed() -> void:
	_new_game()


func _unhandled_input(event: InputEvent) -> void:
	if not _in_game:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_try_place_stone(event.position)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_new_game()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C and event.ctrl_pressed:
		_copy_position()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_V and event.ctrl_pressed:
		_paste_position()


## 复制当前局面为坐标字符串（如 "H8H7J6..."）。
func _copy_position() -> void:
	var parts := []
	for c in _move_history:
		if c is Vector2i:
			parts.append("%s%d" % [char(65 + c.x), c.y + 1])
	DisplayServer.clipboard_set(" ".join(parts))
	status_label.text = "已复制局面（%d 手）" % parts.size()


## 从剪贴板粘贴局面字符串并重建棋盘。
func _paste_position() -> void:
	var text: String = DisplayServer.clipboard_get().strip_edges()
	if text.is_empty():
		return
	# 支持 "H8 H7 J6" 或 "H8H7J6" 两种格式
	var cleaned := text.replace(" ", "").replace(",", "")
	var cells: Array = []
	var i := 0
	while i + 1 < cleaned.length():
		var letter := cleaned[i]
		var num_start := i + 1
		var num_end := num_start
		while num_end < cleaned.length() and cleaned[num_end].is_valid_int():
			num_end += 1
		if num_end > num_start:
			var x := letter.unicode_at(0) - 65
			var y := cleaned.substr(num_start, num_end - num_start).to_int() - 1
			if x >= 0 and x < board_size and y >= 0 and y < board_size:
				cells.append(Vector2i(x, y))
			i = num_end
		else:
			i += 1
	if cells.is_empty():
		return
	# 重建棋盘
	_new_game()
	for idx in range(cells.size()):
		var cell: Vector2i = cells[idx]
		if board[cell.y][cell.x] == 0:
			board[cell.y][cell.x] = current_player
			last_move = cell
			move_count += 1
			_move_history.append(cell)
			if _has_five_in_a_row(cell, current_player):
				winner = current_player
				_trigger_win_fx()
				break
			current_player = 2 if current_player == 1 else 1
	_update_status_text()
	queue_redraw()


func _try_place_stone(mouse_position: Vector2) -> void:
	if winner != 0:
		return
	if ai_thinking or _ai_plays(current_player):
		return

	var cell := _screen_to_cell(mouse_position)
	if cell.x < 0 or cell.y < 0:
		return
	if board[cell.y][cell.x] != 0:
		return

	_place_stone(cell)


## 在指定格落下当前玩家棋子，并推进游戏状态。
func _place_stone(cell: Vector2i) -> void:
	board[cell.y][cell.x] = current_player
	last_move = cell
	move_count += 1
	_move_history.append(cell)
	_last_place_time = _fx_time  # 触发落子弹入动画
	if _place_player:
		_place_player.play()

	if _has_five_in_a_row(cell, current_player):
		winner = current_player
		_trigger_win_fx()
	elif move_count == board_size * board_size:
		winner = 3
	else:
		current_player = 2 if current_player == 1 else 1
		# 检测制胜棋型（四三/活四等），触发特效提示
		_detect_threat_fx(cell)

	_update_status_text()
	queue_redraw()

	# 若轮到 AI，先让本帧把落子渲染出来，再异步启动 AI 思考
	if winner == 0 and _ai_plays(current_player):
		_ai_turn_deferred()
	elif winner == 0:
		_request_forbid()


## 延迟到下一帧再触发 AI 回合，确保玩家落子先渲染出来。
func _ai_turn_deferred() -> void:
	await get_tree().process_frame
	_ai_turn()


func _ai_turn() -> void:
	if ai_thinking:
		return
	if _classic_side(current_player):
		_classic_turn()
		return
	if ai == null:
		return
	ai_thinking = true
	_update_status_text()
	queue_redraw()

	var gen := _turn_generation

	# 再让出几帧，确保「AI 思考中」状态渲染出来，然后同步阻塞思考
	await get_tree().process_frame
	await get_tree().process_frame

	var move: Vector2i
	if OS.has_feature("web"):
		move = await ai.think_async(last_move)
	else:
		move = ai.think(last_move)
	ai_thinking = false

	if not _in_game or gen != _turn_generation:
		return  # 已返回标题或新局，丢弃陈旧结果

	if _stop_pending:
		_stop_pending = false
		_apply_stop_undo()
		return

	if winner == 0 and move.x >= 0:
		if board[move.y][move.x] == 0:
			_place_stone(move)
		else:
			push_warning("AI 返回非法落子: %s" % str(move))
	else:
		_update_status_text()
		queue_redraw()


## 古法编程 AI 应手（纯 GDScript 同步计算）。
func _classic_turn() -> void:
	ai_thinking = true
	_update_status_text()
	queue_redraw()

	var gen := _turn_generation
	await get_tree().process_frame
	await get_tree().process_frame

	# 用 current_player 而非 ai_color：AI 执黑/执白/双 AI 时也能按实际行棋方计算
	var move: Vector2i = _classic_ai.choose_move(board, current_player)
	ai_thinking = false

	if not _in_game or gen != _turn_generation:
		return

	if _stop_pending:
		_stop_pending = false
		_apply_stop_undo()
		return

	if _classic_ai.taunt != "":
		_show_toast("嘿嘿")

	if winner == 0 and move.x >= 0:
		if board[move.y][move.x] == 0:
			_place_stone(move)
		else:
			push_warning("古法编程 AI 返回非法落子: %s" % str(move))


func _ai_turn_first() -> void:
	if ai_thinking:
		return
	var gen := _turn_generation
	if _classic_side(1):
		ai_thinking = true
		_update_status_text()
		queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
		@warning_ignore("integer_division")
		var c := board_size / 2
		ai_thinking = false
		if not _in_game or gen != _turn_generation:
			return
		if _stop_pending:
			_stop_pending = false
			_apply_stop_undo()
			return
		_place_stone(Vector2i(c, c))
		return
	if ai == null:
		return
	ai_thinking = true
	_update_status_text()
	queue_redraw()

	await get_tree().process_frame
	await get_tree().process_frame

	var move: Vector2i
	if OS.has_feature("web"):
		move = await ai.think_first_async()
	else:
		move = ai.think_first()
	ai_thinking = false

	if not _in_game or gen != _turn_generation:
		return

	if _stop_pending:
		_stop_pending = false
		_apply_stop_undo()
		return

	if winner == 0 and move.x >= 0:
		if board[move.y][move.x] == 0:
			_place_stone(move)
		else:
			push_warning("AI 先手返回非法落子: %s" % str(move))
	else:
		_update_status_text()
		queue_redraw()


func _update_status_text() -> void:
	if winner == 1:
		_status_base = "%s获胜！" % ("古法编程" if game_mode == GameMode.EVE else "黑棋")
	elif winner == 2:
		_status_base = "%s获胜！" % ("推理引擎" if game_mode == GameMode.EVE else "白棋")
	elif winner == 3:
		_status_base = "平局"
	elif ai_thinking:
		if game_mode == GameMode.EVE:
			_status_base = "「%s」思考中" % _ai_name(current_player)
		else:
			_status_base = "AI 思考中"
	else:
		if game_mode == GameMode.EVE:
			_status_base = "「%s」落子" % _ai_name(current_player)
		else:
			_status_base = "轮到%s落子" % _player_name(current_player)
	if status_label != null:
		status_label.text = _status_base
	if _status_dot != null:
		var dot_color := Color("4ade80")
		if winner != 0:
			dot_color = ACCENT_GOLD
		elif ai_thinking:
			dot_color = ACCENT_MAGENTA
		_status_dot.add_theme_color_override("font_color", dot_color)
	# 停止按钮仅在引擎思考时可用
	if stop_button:
		stop_button.disabled = not ai_thinking


## 减弱动效开关（无障碍）。
func _on_fx_pressed() -> void:
	_reduced_fx = not _reduced_fx
	if _reduced_fx:
		_confetti.clear()
		queue_redraw()
	_refresh_buttons()


func _player_name(player: int) -> String:
	return "黑棋" if player == 1 else "白棋"


## 机机对战模式下，某颜色的 AI 名称（推理引擎附带难度档位）。
func _ai_name(player: int) -> String:
	if player == 1:
		return "古法编程"
	return "推理引擎·%s" % ["简单", "中等", "困难"][_eve_difficulty]


## 获取 MultiPV 列表第 index 项（自动扩展）。
func _pv_entry(index: int) -> Dictionary:
	while _pv_list.size() <= index:
		_pv_list.append({})
	return _pv_list[index]


## 引擎分析数据回调（由 rapfi_ai 的 analysis_callback 调用）。
func _on_engine_analysis(data: Dictionary) -> void:
	# 实时候选点 / 禁手（单独处理，不进分析面板）
	if data.has("realtime"):
		if data["realtime"] == "BEST" and data.has("pos"):
			_realtime_best = data["pos"]
			_realtime_lost.clear()
		elif data["realtime"] == "LOST" and data.has("pos"):
			_realtime_lost.append(data["pos"])
		queue_redraw()
		return
	if data.has("forbid"):
		_forbid_cells = data["forbid"]
		queue_redraw()
		return

	# NUMPV：切换当前 PV 索引
	if data.has("numpv"):
		_cur_pv = int(data["numpv"])
		return

	# 常规分析键：写入当前 PV 项（MultiPV）
	var entry := _pv_entry(_cur_pv)
	for key in data:
		entry[key] = data[key]
		_analysis_data[key] = data[key]

	# 记录估值历史（用于图表）
	if data.has("eval"):
		var e := str(data["eval"])
		if e.is_valid_int():
			_eval_history.append(e.to_int())
			if _eval_history.size() > 60:
				_eval_history.pop_front()
	_update_analysis_display()


## 刷新分析面板显示（含 MultiPV 多点分析）。
func _update_analysis_display() -> void:
	if analysis_label == null:
		return
	# 空状态：尚无分析数据
	if _analysis_data.is_empty() and _pv_list.is_empty():
		analysis_label.text = "等待引擎响应…"
		return
	var depth := "%s-%s" % [str(_analysis_data.get("depth", "-")), str(_analysis_data.get("seldepth", "-"))]
	var eval_s: String = str(_analysis_data.get("eval", "-"))
	var winrate: float = float(_analysis_data.get("winrate", -1.0))
	var winrate_s := "-"
	if winrate >= 0.0:
		winrate_s = "%.1f%%" % (winrate * 100.0)
	var speed := str(_analysis_data.get("speed", "-"))
	var nodes := str(_analysis_data.get("totalnodes", _analysis_data.get("nodes", "-")))

	var lines := [
		"深度 %s" % depth,
		"估值 %s" % eval_s,
		"胜率 %s" % winrate_s,
		"速度 %s" % speed,
		"节点 %s" % nodes,
	]

	# MultiPV 多点分析：每条 PV 一行（估值/胜率 + 最佳线）
	var shown := 0
	for entry in _pv_list:
		if not entry.has("bestline"):
			continue
		var bl: Array = entry["bestline"]
		if bl.is_empty():
			continue
		var parts := []
		for c in bl:
			if c is Vector2i:
				parts.append("%s%d" % [char(65 + c.x), c.y + 1])
		var meta := ""
		if entry.has("eval"):
			meta = str(entry["eval"])
		if entry.has("winrate"):
			meta += (" " if meta != "" else "") + "%.1f%%" % (float(entry["winrate"]) * 100.0)
		lines.append("PV%d %s %s" % [shown + 1, meta, " ".join(parts)])
		shown += 1
		if shown >= 5:
			break
	if shown == 0:
		lines.append("最佳线 -")

	analysis_label.text = "\n".join(lines)


# ============================================================
# 棋型分析器
# ============================================================
## 制胜棋型检测（模拟放子法，与 web 版 game.js 同源算法）。
## 制胜：活四级(open_four，含跳活四) / 双冲四(double_four) / 四三(four_three) / 双活三(double_three)
## 进攻（延迟弱显示）：单冲四(rushed_four) / 单活三(open_three)
func _detect_threat_fx(cell: Vector2i) -> void:
	var r := _compute_threat(cell)
	_threat_type = r["threat_type"]
	_threat_cells = r["threat_cells"]
	_attack_type = r["attack_type"]
	_attack_cells = r["attack_cells"]
	if _attack_type != "":
		_attack_time = _fx_time


func _compute_threat(cell: Vector2i) -> Dictionary:
	var player: int = board[cell.y][cell.x]
	var renju_like := _rule_index >= 1 and player == 1   # 黑棋禁长连（标准/有禁手）
	var foul_rule := _rule_index == 2 and player == 1    # 有禁手：黑双三/双四是禁手，不算制胜

	var open_four := false
	var has_four := false
	var four_cells: Array = []
	var three_cells: Array = []
	var four_dir_flags := []                # 与 _DIRS 对齐
	var three_dir_flags := []
	var five_point_set := {}                # 全方向成五点并集（Vector2i 去重）

	for d in range(_DIRS.size()):
		var dir: Vector2i = _DIRS[d]
		var r := _analyze_dir_ex(cell, dir, player, renju_like)
		four_dir_flags.append(r["five_count"] > 0)
		if r["five_count"] > 0:
			has_four = true
			if r["open_four"]:
				open_four = true
			for i in r["five_idx"]:
				var k: int = i - _SEQ_OFF
				five_point_set[cell + dir * k] = true
			four_cells = _merge_cells(four_cells, _collect_line_stones(cell, dir, player, 4))
		three_dir_flags.append(r["open_three"])
		if r["open_three"]:
			three_cells = _merge_cells(three_cells, _collect_line_stones(cell, dir, player, 4))

	var four_three_cross := false
	for f in range(four_dir_flags.size()):
		if not four_dir_flags[f]:
			continue
		for t in range(three_dir_flags.size()):
			if t != f and three_dir_flags[t]:
				four_three_cross = true
				break
		if four_three_cross:
			break
	var three_dir_count := 0
	for v in three_dir_flags:
		if v:
			three_dir_count += 1

	var threat_type := ""
	var threat_cells: Array = []
	var attack_type := ""
	var attack_cells: Array = []

	# 制胜棋型优先级：活四 > 双四 > 四三 > 双三
	if open_four:
		threat_type = "open_four"
		threat_cells = four_cells
	elif has_four and five_point_set.size() >= 2:
		# 跨方向/同线分离的两个成五点 → 对手一手只能挡一个
		threat_type = "double_four"
		threat_cells = four_cells
	elif four_three_cross:
		threat_type = "four_three"
		threat_cells = _merge_cells(four_cells, three_cells)
	elif three_dir_count >= 2:
		threat_type = "double_three"
		threat_cells = three_cells
	# 有禁手规则下，黑棋的双四/双三是禁手（走出即判负），不作制胜高亮
	if foul_rule and (threat_type == "double_four" or threat_type == "double_three"):
		threat_type = ""
		threat_cells.clear()
	# 进攻棋型（常见，延迟几秒后不明显特效）
	if threat_type == "":
		if has_four:
			attack_type = "rushed_four"
			attack_cells = four_cells
		elif three_dir_count == 1:
			attack_type = "open_three"
			attack_cells = three_cells
	return {
		"threat_type": threat_type,
		"threat_cells": threat_cells,
		"attack_type": attack_type,
		"attack_cells": attack_cells,
	}


## 合并两个格子数组（去重）。
func _merge_cells(a: Array, b: Array) -> Array:
	var out := a.duplicate()
	for c in b:
		if not out.has(c):
			out.append(c)
	return out


# ── 线扫描工具：编码 1=己方 / 0=空 / -1=对手或边界；中心（最后落子）下标 _SEQ_OFF ──
const _SEQ_R := 5
const _SEQ_OFF := 5


func _build_line(cell: Vector2i, dir: Vector2i, player: int) -> Array:
	var seq := []
	for k in range(-_SEQ_R, _SEQ_R + 1):
		var c := cell + dir * k
		if not _is_inside_board(c):
			seq.append(-1)
			continue
		var v: int = board[c.y][c.x]
		seq.append(1 if v == player else (0 if v == 0 else -1))
	return seq


## 与中心相关的「成五点」：试放一子后过该子的五连须包含中心，
## 黑棋在禁长连规则下连长 >5 不算成五。返回成五点在 seq 中的下标数组。
func _five_points_c(seq: Array, renju_like: bool) -> Array:
	var pts := []
	for i in range(_SEQ_OFF - 4, _SEQ_OFF + 5):
		if seq[i] != 0:
			continue
		seq[i] = 1
		var run := 1
		var lo := i
		var hi := i
		while lo > 0 and seq[lo - 1] == 1:
			lo -= 1
			run += 1
		while hi < seq.size() - 1 and seq[hi + 1] == 1:
			hi += 1
			run += 1
		var ok := run == 5 or (run > 5 and not renju_like)
		if ok:
			ok = lo <= _SEQ_OFF and _SEQ_OFF <= hi   # 五连须包含最后落子
		seq[i] = 0
		if ok:
			pts.append(i)
	return pts


## 单方向分析：{five_count, five_idx, open_four, open_three}
## 活三判定 = 存在空点 e，放子后该线出现 ≥2 个含中心的成五点（一步成活四级），
## 天然覆盖跳活三 .X.XX. / .XX.X.
func _analyze_dir_ex(cell: Vector2i, dir: Vector2i, player: int, renju_like: bool) -> Dictionary:
	var seq := _build_line(cell, dir, player)
	var five_pts := _five_points_c(seq, renju_like)
	var open_three := false
	if five_pts.is_empty():     # 已有四的线不再当三看
		for i in range(_SEQ_OFF - 4, _SEQ_OFF + 5):
			if open_three or seq[i] != 0:
				continue
			seq[i] = 1
			var pts2 := _five_points_c(seq, renju_like)
			seq[i] = 0
			if pts2.size() >= 2:
				open_three = true
	return {
		"five_count": five_pts.size(),
		"five_idx": five_pts,
		"open_four": five_pts.size() >= 2,
		"open_three": open_three,
	}


## 收集某方向上最后落子附近 ±radius 内的同色棋子（用于高亮）。
func _collect_line_stones(cell: Vector2i, dir: Vector2i, player: int, radius: int) -> Array:
	var cells := []
	for k in range(-radius, radius + 1):
		var c := cell + dir * k
		if _is_inside_board(c) and board[c.y][c.x] == player:
			if not cells.has(c):
				cells.append(c)
	return cells


func _has_five_in_a_row(origin: Vector2i, player: int) -> bool:
	winning_cells.clear()
	for direction in _DIRS:
		var line: Array = [origin]
		var cursor: Vector2i = origin + direction
		while _is_inside_board(cursor) and board[cursor.y][cursor.x] == player:
			line.append(cursor)
			cursor += direction
		cursor = origin - direction
		while _is_inside_board(cursor) and board[cursor.y][cursor.x] == player:
			line.insert(0, cursor)
			cursor -= direction
		if line.size() >= 5:
			winning_cells = line
			return true
	return false


# ============================================================
# 特效
# ============================================================
func _trigger_win_fx() -> void:
	_win_anim = 0.0
	_win_flash = _fx_time
	_spawn_confetti()
	if _win_player:
		_win_player.play()
	_show_win_banner()


func _show_win_banner() -> void:
	## 卡片化胜利横幅（game-ui-design：聚焦 + 层级；godot-ui/godot-master：
	## CenterContainer 响应式居中，不用绝对像素；容器 mouse_filter=IGNORE 不挡棋盘）
	if _game_ui_layer == null:
		return
	if _win_dim == null:
		_win_dim = ColorRect.new()
		_win_dim.color = Color(0.02, 0.04, 0.09, 0.45)
		_win_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_game_ui_layer.add_child(_win_dim)
	if _win_center == null:
		_win_center = CenterContainer.new()
		_win_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_win_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_game_ui_layer.add_child(_win_center)
	if _win_card == null:
		_win_card = PanelContainer.new()
		var card := StyleBoxFlat.new()
		card.bg_color = Color(0.07, 0.10, 0.17, 0.92)
		card.border_color = Color(ACCENT_GOLD, 0.55)
		card.set_border_width_all(1)
		card.set_corner_radius_all(20)
		card.shadow_color = Color(0, 0, 0, 0.5)
		card.shadow_size = 24
		card.content_margin_left = 44
		card.content_margin_right = 44
		card.content_margin_top = 30
		card.content_margin_bottom = 30
		_win_card.add_theme_stylebox_override("panel", card)
		_win_center.add_child(_win_card)

		var card_box := VBoxContainer.new()
		card_box.alignment = BoxContainer.ALIGNMENT_CENTER
		card_box.add_theme_constant_override("separation", 10)
		_win_card.add_child(card_box)

		_win_label = Label.new()
		_win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_win_label.add_theme_font_size_override("font_size", 54)
		_win_label.add_theme_color_override("font_color", ACCENT_GOLD)
		_win_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
		_win_label.add_theme_constant_override("outline_size", 8)
		card_box.add_child(_win_label)

		var sub := Label.new()
		sub.name = "WinSub"
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.add_theme_font_size_override("font_size", 14)
		sub.add_theme_color_override("font_color", Color("9db4d8"))
		card_box.add_child(sub)

		_win_buttons = HBoxContainer.new()
		_win_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
		_win_buttons.add_theme_constant_override("separation", 14)
		card_box.add_child(_win_buttons)

		_rematch_button = Button.new()
		_rematch_button.text = "再来一局"
		_rematch_button.custom_minimum_size = Vector2(170, 50)
		_rematch_button.add_theme_font_size_override("font_size", 18)
		_style_primary_button(_rematch_button)
		_rematch_button.pressed.connect(_on_rematch_pressed)
		_win_buttons.add_child(_rematch_button)

		_return_title_btn = Button.new()
		_return_title_btn.text = "返回标题"
		_return_title_btn.custom_minimum_size = Vector2(150, 50)
		_return_title_btn.add_theme_font_size_override("font_size", 18)
		_style_ghost_outline_button(_return_title_btn)
		_return_title_btn.pressed.connect(_return_to_title)
		_win_buttons.add_child(_return_title_btn)

	var msg := "黑棋获胜！" if winner == 1 else "白棋获胜！"
	if winner == 3:
		msg = "平局"
	_win_label.text = msg
	for n in _win_card.get_children():
		if n is VBoxContainer:
			for c in n.get_children():
				if c is Label and c != _win_label:
					c.text = "共 %d 手" % move_count
	_win_dim.visible = true
	_win_dim.modulate.a = 0.0
	_win_card.modulate.a = 0.0

	if _win_tween != null and _win_tween.is_valid():
		_win_tween.kill()
	# 等一帧让 CenterContainer 完成布局，再取尺寸定缩放中心（避免从左上角缩放）
	await get_tree().process_frame
	if _win_card == null or not is_instance_valid(_win_card):
		return
	_win_card.pivot_offset = _win_card.size / 2.0
	_win_card.scale = Vector2(0.88, 0.88)
	_win_tween = create_tween()
	_win_tween.set_parallel(true)
	_win_tween.tween_property(_win_dim, "modulate:a", 1.0, 0.35)
	_win_tween.tween_property(_win_card, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_win_tween.tween_property(_win_card, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_rematch_pressed() -> void:
	_new_game()


func _hide_win_banner() -> void:
	if _win_tween != null and _win_tween.is_valid():
		_win_tween.kill()
		_win_tween = null
	for n in [_win_dim, _win_center]:
		if n != null:
			n.queue_free()
	_win_dim = null
	_win_center = null
	_win_card = null
	_win_label = null
	_win_buttons = null


# ============================================================
# 彩蛋提示（toast）
# ============================================================
## 屏幕下方短暂显示一条提示（用于彩蛋解锁 / 「嘿嘿」嘲讽）。
func _show_toast(text: String) -> void:
	if _toast_label == null:
		_toast_label = Label.new()
		_toast_label.add_theme_font_size_override("font_size", 18)
		_toast_label.add_theme_color_override("font_color", ACCENT_GOLD)
		_toast_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
		_toast_label.add_theme_constant_override("outline_size", 4)
		_toast_label.z_index = 100
		add_child(_toast_label)
	_toast_label.text = text
	_toast_label.reset_size()
	_toast_label.modulate.a = 1.0
	var vp := get_viewport_rect().size
	_toast_label.position = Vector2((vp.x - _toast_label.size.x) / 2.0, 26.0)
	_toast_until = _fx_time + 2.5


## 每帧更新 toast 淡出。
func _update_toast() -> void:
	if _toast_label == null or _toast_until < 0.0:
		return
	if _fx_time >= _toast_until:
		_toast_label.modulate.a = 0.0
		_toast_until = -1.0
	elif _fx_time >= _toast_until - 0.4:
		_toast_label.modulate.a = clampf((_toast_until - _fx_time) / 0.4, 0.0, 1.0)


# ============================================================
# 音效（程序生成，无需外部资源）
# ============================================================
func _init_audio() -> void:
	_place_player = AudioStreamPlayer.new()
	_place_player.stream = _make_click_sound()
	add_child(_place_player)
	_win_player = AudioStreamPlayer.new()
	_win_player.stream = _make_win_sound()
	add_child(_win_player)


## 生成落子音效（短促的「嗒」声）。
func _make_click_sound() -> AudioStreamWAV:
	var rate := 22050
	var duration := 0.09
	var n := int(rate * duration)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / rate
		var env := exp(-t * 55.0)
		var s := sin(TAU * 190.0 * t) * 0.7 + sin(TAU * 380.0 * t) * 0.3
		s *= env
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


## 生成胜利音效（上行琶音 C5-E5-G5-C6）。
func _make_win_sound() -> AudioStreamWAV:
	var rate := 22050
	var notes := [523.25, 659.25, 783.99, 1046.5]
	var note_dur := 0.15
	var total := note_dur * notes.size() + 0.25
	var n := int(rate * total)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / rate
		var idx := mini(int(t / note_dur), notes.size() - 1)
		var local_t := t - idx * note_dur
		var env := exp(-local_t * 9.0)
		var s := sin(TAU * notes[idx] * t) * env
		s += sin(TAU * notes[idx] * 2.0 * t) * env * 0.25
		data.encode_s16(i * 2, int(clampf(s * 0.5, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


# ============================================================
# 坐标换算
# ============================================================
func _screen_to_cell(mouse_position: Vector2) -> Vector2i:
	var cs := _cell_size()
	var min_point := BOARD_PADDING - Vector2.ONE * (cs * 0.5)
	var max_point := BOARD_PADDING + Vector2.ONE * _board_span() + Vector2.ONE * (cs * 0.5)
	if mouse_position.x < min_point.x or mouse_position.y < min_point.y:
		return Vector2i(-1, -1)
	if mouse_position.x > max_point.x or mouse_position.y > max_point.y:
		return Vector2i(-1, -1)

	var scaled := (mouse_position - BOARD_PADDING) / cs
	var cell := Vector2i(roundi(scaled.x), roundi(scaled.y))
	if not _is_inside_board(cell):
		return Vector2i(-1, -1)
	if mouse_position.distance_to(_cell_to_screen(cell)) > cs * 0.45:
		return Vector2i(-1, -1)
	return cell


func _cell_to_screen(cell: Vector2i) -> Vector2:
	return BOARD_PADDING + Vector2(cell.x, cell.y) * _cell_size()


func _is_inside_board(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < board_size and cell.y < board_size


# ============================================================
# 绘制
# ============================================================
func _draw() -> void:
	_draw_background()
	if not _in_game:
		return
	_draw_board()
	_draw_stones()
	_draw_win_beam()
	_draw_hover()
	_draw_forbid()
	_draw_realtime()
	_draw_attack_highlight()
	_draw_threat_highlight()
	_draw_overlays()
	_draw_win_glow()
	_draw_confetti()
	_draw_eval_chart()
	_draw_win_flash()


func _draw_background() -> void:
	var size := get_viewport_rect().size
	# 垂直渐变背景（分 32 段插值）
	var segments := 32
	for i in range(segments):
		var t := float(i) / float(segments - 1)
		var color := _cur_bg_top.lerp(_cur_bg_bottom, t)
		var y0 := size.y * float(i) / float(segments)
		var y1 := size.y * float(i + 1) / float(segments)
		draw_rect(Rect2(0, y0, size.x, y1 - y0 + 1), color)
	# 漂浮光点（减弱动效时不绘制）
	if not _reduced_fx:
		for p in _bg_particles:
			var glow := 0.5 + 0.5 * sin(_fx_time * 0.8 + p["phase"])
			draw_circle(p["pos"], p["radius"], Color(BG_PARTICLE, p["alpha"] * (0.4 + 0.6 * glow)))


func _draw_board() -> void:
	var cs := _cell_size()
	# 棋盘外框（带圆角感的双层）
	var board_rect := Rect2(
		BOARD_PADDING - Vector2.ONE * (cs * 0.5),
		Vector2(_board_span() + cs, _board_span() + cs)
	)
	# 外发光
	draw_rect(board_rect.grow(6), Color(ACCENT_CYAN, 0.08))
	# 底板
	draw_rect(board_rect, _cur_board)
	# 边框
	draw_rect(board_rect, BOARD_EDGE, false, 2.0)

	# 网格线
	for index in range(board_size):
		var offset := index * cs
		draw_line(
			BOARD_PADDING + Vector2(offset, 0),
			BOARD_PADDING + Vector2(offset, _board_span()),
			_cur_grid,
			1.5
		)
		draw_line(
			BOARD_PADDING + Vector2(0, offset),
			BOARD_PADDING + Vector2(_board_span(), offset),
			_cur_grid,
			1.5
		)

	# 星位点（按棋盘大小动态计算，参考 gomoku-calculator 的 starPad 规则）
	var star_points: Array = []
	if board_size >= 7:
		@warning_ignore("integer_division")
		var star_pad := board_size / 5
		@warning_ignore("integer_division")
		var star_center := board_size / 2
		var far := board_size - 1 - star_pad
		star_points = [
			Vector2i(star_pad, star_pad),
			Vector2i(far, star_pad),
			Vector2i(star_pad, far),
			Vector2i(far, far),
			Vector2i(star_center, star_center),
		]
	for point in star_points:
		draw_circle(_cell_to_screen(point), STAR_POINT_RADIUS * (cs / CELL_SIZE), _cur_star)

	# 坐标标注（字母横向 + 数字纵向）
	if _show_coord:
		var font := UI_FONT
		var coord_color := Color("6f86a8")
		for i in range(board_size):
			# 横向字母（A~）
			var letter := char(65 + i)
			var top_pos := BOARD_PADDING + Vector2(i * cs, -30)
			draw_string(font, top_pos, letter, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, coord_color)
			# 纵向数字（1~）
			var num := str(i + 1)
			var left_pos := BOARD_PADDING + Vector2(-34, i * cs + 4)
			draw_string(font, left_pos, num, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, coord_color)


func _draw_stones() -> void:
	if board.size() != board_size:
		return

	# 先用 _move_history 建立「落子序号」映射（第几步落子）
	var step_index := {}
	var step := 1
	for c in _move_history:
		if c is Vector2i:
			step_index[c] = step
			step += 1

	# 最近落子的弹入动画比例（0.35s 内从 0.4 弹到 1.0）
	var place_scale := 1.0
	if _last_place_time >= 0.0:
		var age := _fx_time - _last_place_time
		if age < 0.35:
			var t := age / 0.35
			place_scale = 0.4 + 0.6 * (1.0 - pow(1.0 - t, 3.0))

	for y in range(board_size):
		for x in range(board_size):
			var value = board[y][x]
			if value == 0:
				continue
			var center := _cell_to_screen(Vector2i(x, y))
			var sc := place_scale if Vector2i(x, y) == last_move else 1.0
			# 获胜连珠：弹性放大后回落（ease-back pop）
			if winner != 0 and winning_cells.has(Vector2i(x, y)):
				sc *= 1.0 + 0.22 * sin(clampf(_win_anim, 0.0, 1.0) * PI)
			var r := _stone_radius() * sc

			# 阴影
			draw_circle(center + Vector2(2.5, 3) * sc, r, STONE_SHADOW)

			if value == 1:
				# 黑棋：径向渐变感（外圈微亮 → 内芯深黑）+ 柔和小高光
				draw_circle(center, r, _cur_black)
				# 内芯深黑（右下偏移，模拟立体光影）
				draw_circle(center + Vector2(2, 3) * sc, r * 0.70, BLACK_STONE_DARK)
				draw_circle(center + Vector2(1, 2) * sc, r * 0.42, Color("0a0908"))
				# 顶部受光弧 + 细描边
				draw_arc(center, r - 1, 0.0, TAU, 48, BLACK_EDGE, 1.2, true)
				draw_arc(center, r * 0.86, -2.6, -0.9, 24, Color("5a6b8c", 0.25), 1.4, true)
				# 小而柔和的高光点
				draw_circle(center + Vector2(-4, -5) * sc, r * 0.14, Color("ffffff", 0.30))
				draw_circle(center + Vector2(-3, -4) * sc, r * 0.07, Color(WHITE_GLOSS, 0.55))
				# 落子序号
				if _show_index and step_index.has(Vector2i(x, y)):
					draw_string(UI_FONT, center + Vector2(-3, 6), str(step_index[Vector2i(x, y)]), HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color("ffffff"))
			else:
				# 白棋：宣纸白（亮顶 → 暖暗底）+ 顶部高光 + 暖轮廓
				draw_circle(center, r, _cur_white)
				# 底部暖暗面（右下，营造体积）
				draw_circle(center + Vector2(2, 3) * sc, r * 0.78, Color("b8c4d8", 0.5))
				draw_arc(center, r - 1, 0.0, TAU, 48, Color("8fa3c0", 0.5), 1.2, true)
				draw_circle(center + Vector2(-4, -5) * sc, r * 0.30, Color(WHITE_GLOSS, 0.85))
				if _show_index and step_index.has(Vector2i(x, y)):
					draw_string(UI_FONT, center + Vector2(-3, 6), str(step_index[Vector2i(x, y)]), HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color("1f2937"))


## 绘制悬停幽灵棋子预览（半透明 + 青色描边）。
func _draw_hover() -> void:
	if _hover_cell.x < 0 or _hover_cell.y < 0:
		return
	var center := _cell_to_screen(_hover_cell)
	var col := _cur_black if current_player == 1 else _cur_white
	draw_circle(center, _stone_radius(), Color(col, 0.35))
	draw_arc(center, _stone_radius(), 0.0, TAU, 48, Color(ACCENT_CYAN, 0.65), 1.8, true)


## 绘制胜利彩带（旋转的小色块下落）。
## 必胜连珠特效：金色能量束渐进贯穿五子 + 波前逐子白闪 + 震中双冲击波环。
## 减弱动效模式下整体跳过（无障碍：保留信息性辉光，去除强刺激层）。
func _draw_win_beam() -> void:
	if winner == 0 or winning_cells.size() < 5 or _reduced_fx:
		return
	var t := clampf(_win_anim, 0.0, 1.0)
	var pts: Array[Vector2] = []
	for c in winning_cells:
		pts.append(_cell_to_screen(c))
	var total := 0.0
	var cum: Array[float] = [0.0]
	for i in range(1, pts.size()):
		total += pts[i - 1].distance_to(pts[i])
		cum.append(total)
	if total <= 0.0:
		return
	# 光束推进：ease-out 先疾后缓
	var reach := total * (1.0 - pow(1.0 - t, 2.4))
	var seg: Array[Vector2] = [pts[0]]
	for i in range(1, pts.size()):
		if reach >= cum[i] - 0.001:
			if seg[seg.size() - 1].distance_to(pts[i]) > 0.01:
				seg.append(pts[i])
		else:
			var k := clampf((reach - cum[i - 1]) / maxf(cum[i] - cum[i - 1], 0.001), 0.0, 1.0)
			var p := pts[i - 1].lerp(pts[i], k)
			if seg[seg.size() - 1].distance_to(p) > 0.01:
				seg.append(p)
			break
	if seg.size() >= 2 and seg[0].distance_to(seg[seg.size() - 1]) > 0.01:
		var cs := _cell_size()
		for layer in [[cs * 0.85, 0.10], [cs * 0.48, 0.20], [cs * 0.22, 0.45], [cs * 0.09, 0.95]]:
			draw_polyline(PackedVector2Array(seg), Color(ACCENT_GOLD, layer[1]), layer[0])
	# 波前经过的棋子闪白（高斯衰减）
	for i in range(pts.size()):
		var local := cum[i] / total
		var flash := exp(-pow((reach / total - local) * 6.5, 2.0))
		if flash > 0.02:
			draw_circle(pts[i], _cell_size() * 0.52, Color(1.0, 1.0, 0.9, flash * 0.85))
	# 震中双环冲击波（错峰扩散、随进程消散）
	var center := pts[pts.size() - 1]
	var r1 := (1.0 - pow(1.0 - t, 3.0)) * _cell_size() * 7.0
	draw_arc(center, r1, 0.0, TAU, 48, Color(ACCENT_GOLD, (1.0 - t) * 0.5), 3.0)
	var t2 := clampf(t * 1.35 - 0.25, 0.0, 1.0)
	if t2 > 0.0:
		var r2 := (1.0 - pow(1.0 - t2, 3.0)) * _cell_size() * 4.5
		draw_arc(center, r2, 0.0, TAU, 40, Color("ffffff", (1.0 - t2) * 0.30), 2.0)


## 胜利触发瞬间的全屏微闪（0.18s 消退），强化定格冲击感。
func _draw_win_flash() -> void:
	if _win_flash < 0.0 or _reduced_fx:
		return
	var age := _fx_time - _win_flash
	if age < 0.18:
		draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(1.0, 0.98, 0.9, 0.30 * (1.0 - age / 0.18)))


func _draw_confetti() -> void:
	if _confetti.is_empty():
		return
	for c in _confetti:
		var s: float = c["size"]
		var pos: Vector2 = c["pos"]
		var col: Color = c["color"]
		var rot: float = c["rot"]
		var half := Vector2(s * 0.5, s * 0.25).rotated(rot)
		draw_colored_polygon(PackedVector2Array([
			pos - half, pos + Vector2(half.x, -half.y),
			pos + half, pos + Vector2(-half.x, half.y),
		]), col)


func _draw_forbid() -> void:
	if _forbid_cells.is_empty():
		return
	for c in _forbid_cells:
		var center := _cell_to_screen(c)
		var r := _cell_size() * 0.32
		draw_line(center + Vector2(-r, -r), center + Vector2(r, r), Color("f87171", 0.85), 2.5)
		draw_line(center + Vector2(r, -r), center + Vector2(-r, r), Color("f87171", 0.85), 2.5)


func _draw_realtime() -> void:
	# 思考中引擎当前最佳候选点（金色脉冲环）
	if _realtime_best.x >= 0:
		var center := _cell_to_screen(_realtime_best)
		var pulse := 0.5 + 0.5 * sin(_fx_time * 8.0)
		draw_arc(center, _stone_radius() + 4.0 + pulse * 3.0, 0.0, TAU, 48, ACCENT_GOLD, 3.0, true)
		draw_circle(center, 4.0, Color(ACCENT_GOLD, 0.6 + 0.4 * pulse))
	# 引擎已排除的点（暗红小点）
	for c in _realtime_lost:
		draw_circle(_cell_to_screen(c), 3.0, Color("f87171", 0.45))


func _draw_threat_highlight() -> void:
	if _threat_cells.is_empty():
		return

	var color := Color("f87171")  # 亮红，最威胁
	if _threat_type == "open_four":
		color = ACCENT_GOLD
	elif _threat_type == "double_four":
		color = Color("f87171")
	elif _threat_type == "four_three":
		color = Color("f87171")
	elif _threat_type == "double_three":
		color = Color("fb923c")  # 橙

	# 脉冲强度随时间正弦变化
	var pulse := 0.5 + 0.5 * sin(_fx_time * 6.0)

	for c in _threat_cells:
		var center := _cell_to_screen(c)
		# 光晕环
		var glow_radius := _stone_radius() + 3.0 + pulse * 4.0
		draw_arc(center, glow_radius, 0.0, TAU, 48, Color(color, 0.8), 3.0, true)
		# 内圈闪烁
		draw_circle(center, 3.0, Color(color, 0.5 + 0.5 * pulse))


## 进攻棋型（活三/冲四）延迟几秒后显示不明显的特效。
func _draw_attack_highlight() -> void:
	if _attack_cells.is_empty() or _attack_time < 0.0:
		return
	if _fx_time - _attack_time < ATTACK_DELAY:
		return
	var color := ACCENT_CYAN
	if _attack_type == "rushed_four":
		color = ACCENT_MAGENTA
	# 轻微的呼吸，透明度低
	var pulse := 0.5 + 0.5 * sin(_fx_time * 3.0)
	for c in _attack_cells:
		var center := _cell_to_screen(c)
		draw_arc(center, _stone_radius() + 2.0, 0.0, TAU, 48, Color(color, 0.22 + 0.10 * pulse), 1.5, true)


func _draw_overlays() -> void:
	# 最后落子标记（小朱砂点 + 细白环，避免盖过棋子材质）
	if last_move.x >= 0 and last_move.y >= 0:
		var center := _cell_to_screen(last_move)
		var pulse := 1.0 + 0.15 * sin(_fx_time * 5.0)
		draw_circle(center, 3.2 * pulse, LAST_MOVE_COLOR)
		draw_arc(center, 5.0, 0.0, TAU, 32, Color("ffffff", 0.8), 1.2, true)

	# 胜利连线（金色描边 + 内部发光）
	if _show_winline and winning_cells.size() >= 2:
		var start_cell: Vector2i = winning_cells[0]
		var end_cell: Vector2i = winning_cells[winning_cells.size() - 1]
		var s := _cell_to_screen(start_cell)
		var e := _cell_to_screen(end_cell)
		draw_line(s, e, Color(WIN_LINE_COLOR, 0.4), 12.0)
		draw_line(s, e, WIN_LINE_COLOR, 5.0)
		# 两端闪光
		draw_circle(s, 7.0, ACCENT_GOLD)
		draw_circle(e, 7.0, ACCENT_GOLD)


func _draw_win_glow() -> void:
	if winner != 1 and winner != 2:
		return
	# 胜利时全屏微光（缓慢呼吸）
	var size := get_viewport_rect().size
	var alpha := 0.04 + 0.03 * sin(_fx_time * 2.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(WIN_LINE_COLOR, alpha))


## 绘制估值走势迷你图表（棋盘下方）。
func _draw_eval_chart() -> void:
	if _eval_history.size() < 2 or not _show_eval:
		return
	var chart_y := BOARD_PADDING.y + _board_span() + _cell_size() + 30
	var chart_w := _board_span()
	var chart_h := 80.0
	# 收进视口，避免底部被裁切
	var vp_h := get_viewport_rect().size.y
	if chart_y + chart_h > vp_h - 8.0:
		chart_h = maxf(24.0, vp_h - 8.0 - chart_y)
	var chart_pos := Vector2(BOARD_PADDING.x, chart_y)

	# 背景
	draw_rect(Rect2(chart_pos, Vector2(chart_w, chart_h)), Color(_cur_board, 0.6))

	# 零线
	var zero_y := chart_pos.y + chart_h / 2.0
	draw_line(Vector2(chart_pos.x, zero_y), Vector2(chart_pos.x + chart_w, zero_y), Color(_cur_grid, 0.5), 1.0)

	# 找估值范围（对称）
	var max_abs := 1
	for v in _eval_history:
		max_abs = max(max_abs, abs(v))
	max_abs = max(max_abs, 100)

	# 绘制折线
	var n := _eval_history.size()
	var step_x := chart_w / float(n - 1)
	for i in range(n - 1):
		var x0: float = chart_pos.x + step_x * i
		var x1: float = chart_pos.x + step_x * (i + 1)
		var y0: float = zero_y - (float(_eval_history[i]) / float(max_abs)) * (chart_h / 2.0)
		var y1: float = zero_y - (float(_eval_history[i + 1]) / float(max_abs)) * (chart_h / 2.0)
		var col: Color = ACCENT_GREEN if _eval_history[i + 1] >= 0 else Color("f87171")
		draw_line(Vector2(x0, y0), Vector2(x1, y1), col, 2.0)

	# 当前估值标注
	if _show_eval and _analysis_data.has("eval"):
		var eval_s: String = str(_analysis_data["eval"])
		draw_string(UI_FONT, chart_pos + Vector2(8, 16), "估值 " + eval_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ACCENT_GOLD)


func _exit_tree() -> void:
	_teardown_ai()
