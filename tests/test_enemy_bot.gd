extends SceneTree
## Bot FFA targeting, aim cone, and walk stride.
## Run: godot --headless --path . -s res://tests/test_enemy_bot.gd

const Bot := preload("res://scripts/enemy_bot.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed := 0
	failed += _test_spread_misses()
	failed += _test_collects_other_bots()
	failed += _test_walk_stride_visible()
	failed += _test_personality_moves()
	failed += _test_difficulty_scales_vitals()
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


func _make_bot(bot_name: String, pos: Vector3):
	var bot = Bot.new()
	if bot == null:
		return null
	bot.name = bot_name
	bot.bot_name = bot_name
	bot.model_path = "res://does_not_exist.glb"
	bot.model_scene = null
	root.add_child(bot)
	bot.global_position = pos
	return bot


func _test_collects_other_bots() -> int:
	var a = _make_bot("Grunt", Vector3(0, 0, 0))
	var b = _make_bot("Ranger", Vector3(4, 0, 0))
	if a == null or b == null:
		push_error("EnemyBot failed to instantiate")
		return 1
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


func _dummy_foe(pos: Vector3) -> Node3D:
	var foe := Node3D.new()
	foe.name = "Foe"
	root.add_child(foe)
	foe.global_position = pos
	return foe


func _test_personality_moves() -> int:
	var bot = _make_bot("Grunt", Vector3.ZERO)
	if bot == null:
		push_error("EnemyBot failed to instantiate")
		return 1
	var foe := _dummy_foe(Vector3(10, 0, 0))
	bot.personality = Bot.PERSONALITY_AGGRESSIVE
	var rush: Vector3 = bot._move_aggressive(foe)
	if rush.x <= 0.0:
		push_error("aggressive should walk toward +X foe, got %s" % rush)
		return 1
	var dispatched: Vector3 = bot._movement_for_personality(foe)
	if dispatched.x <= 0.0:
		push_error("personality dispatch did not charge, got %s" % dispatched)
		return 1
	bot.personality = Bot.PERSONALITY_DEFENSIVE
	var kite: Vector3 = bot._move_defensive(foe)
	if kite.x >= 0.0:
		push_error("defensive should walk away from +X foe, got %s" % kite)
		return 1
	bot.personality = Bot.PERSONALITY_SNIPER
	var hold: Vector3 = bot._move_sniper(foe)
	if hold.length_squared() > 0.0001:
		push_error("sniper should stand still, got %s" % hold)
		return 1
	var sniper_disp: Vector3 = bot._movement_for_personality(foe)
	if sniper_disp.length_squared() > 0.0001:
		push_error("sniper dispatch should be zero, got %s" % sniper_disp)
		return 1
	print("ok   personality toward / away / stand still")
	foe.queue_free()
	bot.queue_free()
	return 0


func _test_difficulty_scales_vitals() -> int:
	var existing := root.get_node_or_null("GameManager")
	var gm = existing
	var spawned := false
	if gm == null:
		var gm_script: Script = load("res://scripts/game_manager.gd")
		gm = gm_script.new()
		gm.name = "GameManager"
		root.add_child(gm)
		spawned = true
	var previous: float = float(gm.get("difficulty_multiplier"))
	gm.set("difficulty_multiplier", 0.5)
	var bot = _make_bot("Ranger", Vector3.ZERO)
	if bot == null:
		push_error("EnemyBot failed to instantiate")
		gm.set("difficulty_multiplier", previous)
		if spawned:
			gm.queue_free()
		return 1
	var hp: float = bot.health_comp.max_health
	var dmg: float = bot.scaled_attack_damage()
	gm.set("difficulty_multiplier", previous)
	if spawned:
		gm.queue_free()
	bot.queue_free()
	if absf(hp - 50.0) > 0.01:
		push_error("0.5 difficulty should set bot HP to 50, got %s" % hp)
		return 1
	if absf(dmg - 3.5) > 0.01:
		push_error("0.5 difficulty should set bot damage to 3.5, got %s" % dmg)
		return 1
	print("ok   difficulty 0.5 halves bot health and damage")
	return 0
