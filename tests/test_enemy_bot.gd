extends SceneTree
## Bot FFA targeting, aim cone, and walk stride.
## Run: godot --headless --path . -s res://tests/test_enemy_bot.gd

const Bot := preload("res://scripts/enemy_bot.gd")


func _init() -> void:
	var failed := 0
	failed += _test_spread_misses()
	failed += _test_collects_other_bots()
	failed += _test_walk_stride_visible()
	if failed > 0:
		push_error("enemy bot tests failed: %d" % failed)
		quit(1)
	else:
		print("enemy bot tests passed")
		quit(0)


func _test_spread_misses() -> int:
	var from := Vector3(0, 1.5, 0)
	var to := Vector3(0, 1.5, -12)
	var dead := Bot.spread_direction(from, to, 0.0, 0.0, 0.0)
	if dead.dot(Vector3(0, 0, -1)) < 0.999:
		push_error("zero spread should aim straight, got %s" % dead)
		return 1
	var wide := Bot.spread_direction(from, to, deg_to_rad(12.0), 1.0, 0.0)
	if wide.dot(Vector3(0, 0, -1)) > 0.995:
		push_error("12deg yaw spread should leave the center line, got %s" % wide)
		return 1
	print("ok   aim cone leaves the center line")
	return 0


func _make_bot(name: String, pos: Vector3):
	var bot = Bot.new()
	bot.name = name
	bot.bot_name = name
	bot.model_path = "res://does_not_exist.glb"
	bot.model_scene = null
	root.add_child(bot)
	bot.global_position = pos
	return bot


func _test_collects_other_bots() -> int:
	var a = _make_bot("Grunt", Vector3(0, 0, 0))
	var b = _make_bot("Ranger", Vector3(4, 0, 0))
	var player := CharacterBody3D.new()
	player.name = "Player"
	player.add_to_group("player")
	root.add_child(player)
	player.global_position = Vector3(80, 0, 0)
	var foes: Array = a._collect_foes(player)
	var names: PackedStringArray = PackedStringArray()
	for f in foes:
		names.append((f as Node).name)
	if not names.has("Ranger"):
		push_error("FFA list missing other bot, got %s" % ",".join(names))
		return 1
	if not names.has("Player"):
		push_error("FFA list missing player, got %s" % ",".join(names))
		return 1
	if names.has("Grunt"):
		push_error("bot listed itself as a foe")
		return 1
	print("ok   FFA foes include player and other bots")
	a.queue_free()
	b.queue_free()
	player.queue_free()
	return 0


func _test_walk_stride_visible() -> int:
	var bot = _make_bot("Visl", Vector3.ZERO)
	var vis := Node3D.new()
	vis.name = "Visual"
	bot.add_child(vis)
	bot._visual = vis
	bot._visual_base_y = 0.0
	bot._visual_base_rot = Vector3.ZERO
	bot._has_anim = false
	bot._alive = true
	bot.velocity = Vector3(8, 0, 0)
	var max_y := 0.0
	var max_roll := 0.0
	for _i in 20:
		bot._update_walk_bob(0.05)
		max_y = maxf(max_y, vis.position.y)
		max_roll = maxf(max_roll, absf(vis.rotation.z))
	if max_y < 0.1:
		push_error("walk bob too small to read as a stride, max y %s" % max_y)
		return 1
	if max_roll < 0.05:
		push_error("walk roll too small, max %s" % max_roll)
		return 1
	print("ok   walk stride bob height %.2f roll %.2f" % [max_y, max_roll])
	bot.queue_free()
	return 0
