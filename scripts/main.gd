extends Node

var _world: Node3D
var _player: Player
var _menu: Control
var _end: Control
var _hud: HUD
var _bots: Array[EnemyBot] = []
const BOT_COUNT := 3
const BOT_NAMES := ["Grunt", "Ranger", "Visl"]
const BOT_COLORS := [Color(0.75, 0.18, 0.15), Color(0.2, 0.45, 0.8), Color(0.55, 0.2, 0.7)]
const BOT_MODELS := [
	"res://assets/warrior.glb",
	"res://assets/Warrior2.glb",
	"res://assets/female.glb",
]
## Grunt charges, Ranger camps, Visl panics.
const BOT_PERSONALITIES := [0, 2, 4]
const PERSONALITY_NAMES := ["Agresif", "Savunmacı", "Sniper", "Normal", "Crazy"]

var _bot_personalities: Array[int] = [0, 2, 4]
var _personality_btns: Array[Button] = []
var _diff_easy: Button
var _diff_normal: Button
var _diff_hard: Button
var _frag_btns: Array[Button] = []
var _time_btns: Array[Button] = []
var _sens_btns: Array[Button] = []
var _map_btns: Array[Button] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_world = Node3D.new()
	_world.name = "World"
	_world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_world)
	_build_menu()
	_build_end()
	GameState.match_ended.connect(_on_match_ended)
	call_deferred("_spawn_arena")


func _spawn_arena() -> void:
	var want := 0
	var gs := get_node_or_null("/root/GameState")
	if gs:
		want = int(gs.get("arena_layout"))
	var existing := _world.get_node_or_null("ArenaGenerator")
	if existing != null:
		if int(existing.get("layout")) == want:
			return
		existing.free()
	var arena: Node3D = null
	var packed := load("res://scenes/arena_generator.tscn") as PackedScene
	if packed != null:
		arena = packed.instantiate() as Node3D
	else:
		var gen_script: Script = load("res://scripts/arena_generator.gd")
		arena = gen_script.new() as Node3D
	arena.name = "ArenaGenerator"
	if "layout" in arena:
		arena.set("layout", want)
	_world.add_child(arena)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		var mode := DisplayServer.window_get_mode()
		if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	if _end.visible and event.is_action_pressed("restart"):
		_start_match()
		return
	if event.is_action_pressed("ui_cancel"):
		if _end.visible:
			_dismiss_end_screen()
			return
		if GameState.match_running:
			_toggle_pause()
		else:
			get_tree().quit()


func _build_menu() -> void:
	_menu = Control.new()
	_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_menu)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.03, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(bg)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.position = Vector2(-250, -360)
	col.custom_minimum_size = Vector2(500, 720)
	col.add_theme_constant_override("separation", 8)
	_menu.add_child(col)

	var title := Label.new()
	title.text = "QUAKE FPS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.12))
	col.add_child(title)

	var sub := Label.new()
	sub.text = "Godot 4.7 arena shooter  ·  air-strafe  ·  rocket jump"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color(0.8, 0.7, 0.55))
	col.add_child(sub)

	col.add_child(_build_difficulty_picker())
	col.add_child(_build_personality_picker())
	col.add_child(_build_choice_row("FRAG LIMIT", ["10", "20", "30"], _frag_btns, _on_frag_choice))
	col.add_child(_build_choice_row("TIME", ["OFF", "5:00", "10:00"], _time_btns, _on_time_choice))
	col.add_child(_build_choice_row("MOUSE", ["LOW", "MED", "HIGH"], _sens_btns, _on_sens_choice))
	col.add_child(_build_choice_row("MAP", ["YARD", "TIGHT"], _map_btns, _on_map_choice))
	col.add_child(_btn("PLAY", _start_match))
	col.add_child(_btn("QUIT", func() -> void: get_tree().quit()))
	_refresh_match_options()


func _build_end() -> void:
	_end = Control.new()
	_end.name = "EndScreen"
	_end.visible = false
	_end.process_mode = Node.PROCESS_MODE_ALWAYS
	_end.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_end)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.02, 0.9)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end.add_child(bg)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.position = Vector2(-280, -260)
	col.custom_minimum_size = Vector2(560, 520)
	col.add_theme_constant_override("separation", 12)
	_end.add_child(col)
	var winner := Label.new()
	winner.name = "Winner"
	winner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	winner.add_theme_font_size_override("font_size", 72)
	winner.add_theme_color_override("font_color", Color(1.0, 0.55, 0.12))
	winner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	winner.add_theme_constant_override("outline_size", 10)
	col.add_child(winner)
	var sub := Label.new()
	sub.name = "WinsLine"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 28)
	sub.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	col.add_child(sub)
	var board := Label.new()
	board.name = "Board"
	board.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board.add_theme_font_size_override("font_size", 26)
	board.add_theme_color_override("font_color", Color(0.95, 0.9, 0.78))
	col.add_child(board)
	var hint := Label.new()
	hint.name = "Hint"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color(0.75, 0.68, 0.55))
	hint.text = "PRESS  R  TO RESTART     ESC  MENU"
	col.add_child(hint)


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	b.pressed.connect(cb)
	return b


func _build_personality_picker() -> Control:
	_personality_btns.clear()
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 6)
	var title := Label.new()
	title.text = "BOT PERSONALITY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.85, 0.72, 0.5))
	wrap.add_child(title)
	for i in BOT_COUNT:
		wrap.add_child(_build_personality_row(i))
	return wrap


func _build_personality_row(index: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name := Label.new()
	name.text = BOT_NAMES[index]
	name.custom_minimum_size = Vector2(90, 40)
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name.add_theme_font_size_override("font_size", 18)
	name.add_theme_color_override("font_color", BOT_COLORS[index])
	row.add_child(name)
	var prev := _btn("<", _cycle_personality.bind(index, -1))
	prev.custom_minimum_size = Vector2(44, 40)
	row.add_child(prev)
	var value := Button.new()
	value.text = _personality_name(_bot_personalities[index])
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.custom_minimum_size = Vector2(0, 40)
	value.pressed.connect(_cycle_personality.bind(index, 1))
	row.add_child(value)
	_personality_btns.append(value)
	var next := _btn(">", _cycle_personality.bind(index, 1))
	next.custom_minimum_size = Vector2(44, 40)
	row.add_child(next)
	return row


func _personality_name(kind: int) -> String:
	if kind < 0 or kind >= PERSONALITY_NAMES.size():
		return PERSONALITY_NAMES[3]
	return PERSONALITY_NAMES[kind]


func _cycle_personality(index: int, step: int) -> void:
	if index < 0 or index >= _bot_personalities.size():
		return
	_bot_personalities[index] = posmod(_bot_personalities[index] + step, PERSONALITY_NAMES.size())
	_refresh_personality_picker()


func _refresh_personality_picker() -> void:
	for i in _personality_btns.size():
		if i >= _bot_personalities.size():
			break
		_personality_btns[i].text = _personality_name(_bot_personalities[i])


func _build_difficulty_picker() -> Control:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 6)
	var title := Label.new()
	title.text = "DIFFICULTY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.85, 0.72, 0.5))
	wrap.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_diff_easy = _btn("EASY", func() -> void: _set_difficulty(0.5))
	_diff_normal = _btn("NORMAL", func() -> void: _set_difficulty(1.0))
	_diff_hard = _btn("HARD", func() -> void: _set_difficulty(1.5))
	for b in [_diff_easy, _diff_normal, _diff_hard]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	wrap.add_child(row)
	var hint := Label.new()
	hint.name = "DiffHint"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.62, 0.55, 0.45))
	wrap.add_child(hint)
	_refresh_difficulty_picker()
	return wrap


func _difficulty_multiplier() -> float:
	var gm := get_node_or_null("/root/GameManager")
	if gm == null:
		return 1.0
	return float(gm.get("difficulty_multiplier"))


func _set_difficulty(mul: float) -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm == null:
		return
	gm.set("difficulty_multiplier", mul)
	_refresh_difficulty_picker()


func _refresh_difficulty_picker() -> void:
	var mul := _difficulty_multiplier()
	_paint_diff_button(_diff_easy, mul <= 0.6)
	_paint_diff_button(_diff_normal, mul > 0.6 and mul < 1.4)
	_paint_diff_button(_diff_hard, mul >= 1.4)
	if _menu == null:
		return
	var hint := _menu.find_child("DiffHint", true, false) as Label
	if hint:
		hint.text = "Bot HP & damage  ×  %.1f" % mul


func _paint_diff_button(button: Button, selected: bool) -> void:
	if button == null:
		return
	if selected:
		button.modulate = Color(1.0, 0.58, 0.18)
	else:
		button.modulate = Color(0.72, 0.68, 0.6)


func _build_choice_row(title: String, labels: PackedStringArray, store: Array[Button], cb: Callable) -> Control:
	store.clear()
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 4)
	var head := Label.new()
	head.text = title
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 16)
	head.add_theme_color_override("font_color", Color(0.85, 0.72, 0.5))
	wrap.add_child(head)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for i in labels.size():
		var b := _btn(labels[i], cb.bind(i))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 36)
		row.add_child(b)
		store.append(b)
	wrap.add_child(row)
	return wrap


func _on_frag_choice(index: int) -> void:
	var limits := [10, 20, 30]
	if index < 0 or index >= limits.size():
		return
	GameState.frag_limit = limits[index]
	_refresh_match_options()


func _on_time_choice(index: int) -> void:
	var limits := [0.0, 300.0, 600.0]
	if index < 0 or index >= limits.size():
		return
	GameState.time_limit = limits[index]
	_refresh_match_options()


func _on_sens_choice(index: int) -> void:
	var vals := [GameState.SENS_LOW, GameState.SENS_MED, GameState.SENS_HIGH]
	if index < 0 or index >= vals.size():
		return
	GameState.mouse_sensitivity = vals[index]
	_refresh_match_options()


func _on_map_choice(index: int) -> void:
	GameState.arena_layout = GameState.LAYOUT_TIGHT if index == 1 else GameState.LAYOUT_YARD
	_refresh_match_options()


func _refresh_match_options() -> void:
	_paint_choice(_frag_btns, _frag_index())
	_paint_choice(_time_btns, _time_index())
	_paint_choice(_sens_btns, _sens_index())
	_paint_choice(_map_btns, 1 if GameState.arena_layout == GameState.LAYOUT_TIGHT else 0)


func _frag_index() -> int:
	if GameState.frag_limit <= 10:
		return 0
	if GameState.frag_limit >= 30:
		return 2
	return 1


func _time_index() -> int:
	if GameState.time_limit >= 500.0:
		return 2
	if GameState.time_limit >= 60.0:
		return 1
	return 0


func _sens_index() -> int:
	var s := GameState.mouse_sensitivity
	if s <= (GameState.SENS_LOW + GameState.SENS_MED) * 0.5:
		return 0
	if s >= (GameState.SENS_MED + GameState.SENS_HIGH) * 0.5:
		return 2
	return 1


func _paint_choice(buttons: Array[Button], selected: int) -> void:
	for i in buttons.size():
		_paint_diff_button(buttons[i], i == selected)


func _start_match() -> void:
	get_tree().paused = false
	GameState.paused = false
	AudioFx.play("ui")
	_menu.visible = false
	_end.visible = false
	_spawn_arena()
	GameState.reset_match()
	_clear_actors()
	var packed := load("res://scenes/player.tscn") as PackedScene
	if packed != null:
		_player = packed.instantiate() as Player
	else:
		_player = Player.new()
	_player.name = "Player"
	_player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_player)
	_player.respawn_at(_spawn_pos())
	_player.died.connect(_on_player_died)

	_hud = HUD.new()
	_hud.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_hud)
	_hud.setup(_player)

	_bots.clear()
	for i in BOT_COUNT:
		var bot: EnemyBot
		var bot_packed := load("res://scenes/enemy_bot.tscn") as PackedScene
		if bot_packed != null:
			bot = bot_packed.instantiate() as EnemyBot
		else:
			var bot_script: Script = load("res://scripts/enemy_bot.gd")
			bot = bot_script.new() as EnemyBot
		bot.bot_name = BOT_NAMES[i]
		bot.color = BOT_COLORS[i]
		bot.model_path = BOT_MODELS[i]
		bot.personality = _bot_personalities[i]
		bot.name = BOT_NAMES[i]
		bot.player_path = NodePath("../Player")
		bot.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(bot)
		bot.respawn_at(_spawn_pos())
		bot.died.connect(_on_bot_died.bind(bot))
		_bots.append(bot)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameState.start_match()


func _clear_actors() -> void:
	if _player != null and is_instance_valid(_player):
		_player.queue_free()
	for b in _bots:
		if is_instance_valid(b):
			b.queue_free()
	_bots.clear()
	if _hud != null and is_instance_valid(_hud):
		_hud.queue_free()
		_hud = null


func _spawn_pos() -> Vector3:
	var spots := get_tree().get_nodes_in_group("spawn_points")
	if spots.is_empty():
		return Vector3(20, 2, 20)
	var best: Vector3 = (spots[randi() % spots.size()] as Node3D).global_position
	var best_d := -1.0
	for s in spots:
		var p: Vector3 = (s as Node3D).global_position
		var nearest := 9999.0
		if _player != null and is_instance_valid(_player) and _player.is_alive():
			nearest = minf(nearest, p.distance_to(_player.global_position))
		for b in _bots:
			if is_instance_valid(b) and b.is_alive():
				nearest = minf(nearest, p.distance_to(b.global_position))
		if nearest > best_d:
			best_d = nearest
			best = p
	return best


func _on_player_died(killer: Node) -> void:
	GameState.add_frag(_actor_name(killer), "YOU", false, true)
	await get_tree().create_timer(1.6).timeout
	if is_instance_valid(_player) and GameState.match_running:
		_player.respawn_at(_spawn_pos())


func _on_bot_died(killer: Node, bot: EnemyBot) -> void:
	var is_player := killer == _player
	GameState.add_frag(_actor_name(killer), bot.bot_name, is_player, false)
	await get_tree().create_timer(1.8).timeout
	if is_instance_valid(bot) and GameState.match_running:
		bot.respawn_at(_spawn_pos())


func _actor_name(node: Node) -> String:
	if node == _player:
		return "YOU"
	if node != null and is_instance_valid(node) and "bot_name" in node:
		return str(node.bot_name)
	return "world"


func _toggle_pause() -> void:
	GameState.paused = not GameState.paused
	get_tree().paused = GameState.paused
	if GameState.paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_menu.visible = true
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_menu.visible = false


func _on_match_ended() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameState.paused = true
	get_tree().paused = true
	_end.visible = true
	var winner := GameState.last_winner
	if winner.is_empty():
		winner = GameState.PLAYER_NAME
	var name_lab := _end.find_child("Winner", true, false) as Label
	if name_lab:
		name_lab.text = winner
	var wins := _end.find_child("WinsLine", true, false) as Label
	if wins:
		if GameState.ended_by_time:
			wins.text = "WINS  ·  TIME UP  ·  %d FRAGS" % GameState.winner_frags()
		else:
			wins.text = "WINS  ·  %d FRAGS" % GameState.winner_frags()
	var board := _end.find_child("Board", true, false) as Label
	if board:
		board.text = GameState.scoreboard_text()


func _dismiss_end_screen() -> void:
	_end.visible = false
	_menu.visible = true
	_clear_actors()
	get_tree().paused = false
	GameState.paused = false
