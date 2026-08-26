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
	if _world.get_node_or_null("ArenaGenerator") != null:
		return
	var arena: Node3D = null
	var packed := load("res://scenes/arena_generator.tscn") as PackedScene
	if packed != null:
		arena = packed.instantiate() as Node3D
	else:
		var gen_script: Script = load("res://scripts/arena_generator.gd")
		arena = gen_script.new() as Node3D
	arena.name = "ArenaGenerator"
	_world.add_child(arena)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		var mode := DisplayServer.window_get_mode()
		if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	if event.is_action_pressed("ui_cancel"):
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
	col.position = Vector2(-220, -140)
	col.custom_minimum_size = Vector2(440, 280)
	col.add_theme_constant_override("separation", 16)
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

	col.add_child(_btn("PLAY", _start_match))
	col.add_child(_btn("QUIT", func() -> void: get_tree().quit()))


func _build_end() -> void:
	_end = Control.new()
	_end.visible = false
	_end.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_end)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.02, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end.add_child(bg)
	var lab := Label.new()
	lab.name = "Msg"
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.set_anchors_preset(Control.PRESET_CENTER)
	lab.position = Vector2(-240, -40)
	lab.size = Vector2(480, 80)
	lab.add_theme_font_size_override("font_size", 40)
	lab.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
	_end.add_child(lab)


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	b.pressed.connect(cb)
	return b


func _start_match() -> void:
	get_tree().paused = false
	GameState.paused = false
	AudioFx.play("ui")
	_menu.visible = false
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
	_end.visible = true
	var msg := _end.get_node("Msg") as Label
	msg.text = "FRAG LIMIT  ·  %d kills" % GameState.player_kills
	await get_tree().create_timer(4.0).timeout
	_end.visible = false
	_menu.visible = true
	_clear_actors()
	get_tree().paused = false
	GameState.paused = false
