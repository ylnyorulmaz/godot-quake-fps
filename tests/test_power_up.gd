extends SceneTree
## Quad / Haste / Invis timers and multipliers.
## Run: godot --headless --path . -s res://tests/test_power_up.gd

const State := preload("res://scripts/power_up_state.gd")
const PickupScript := preload("res://scripts/power_up.gd")
const Bot := preload("res://scripts/enemy_bot.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed := 0
	failed += _test_multipliers()
	failed += _test_expiry()
	failed += _test_pickup_respawn()
	failed += _test_bot_haste()
	if failed > 0:
		push_error("power-up tests failed: %d" % failed)
		quit(1)
	else:
		print("power-up tests passed")
		quit(0)


func _test_multipliers() -> int:
	var s = State.new()
	if absf(s.damage_scale() - 1.0) > 0.001 or absf(s.speed_scale() - 1.0) > 0.001:
		push_error("idle scales should be 1")
		return 1
	if not s.apply(State.QUAD):
		push_error("quad apply failed")
		return 1
	if absf(s.damage_scale() - 4.0) > 0.001:
		push_error("quad should be x4 damage, got %s" % s.damage_scale())
		return 1
	if not s.apply(State.HASTE):
		push_error("haste apply failed")
		return 1
	if absf(s.speed_scale() - 2.0) > 0.001:
		push_error("haste should be x2 speed, got %s" % s.speed_scale())
		return 1
	if not s.apply(State.INVIS) or not s.is_invisible():
		push_error("invis did not stealth")
		return 1
	if s.overlay_color().a < 0.05:
		push_error("active overlay should tint the body")
		return 1
	print("ok   quad x4, haste x2, invis tint")
	s.free()
	return 0


func _test_expiry() -> int:
	var s = State.new()
	s.apply(State.QUAD, 1.0)
	s.tick(0.4)
	if not s.has_quad():
		push_error("quad expired too soon")
		return 1
	s.tick(0.7)
	if s.has_quad() or s.damage_scale() > 1.01:
		push_error("quad should expire after duration")
		return 1
	print("ok   power-up duration expires")
	s.free()
	return 0


func _test_pickup_respawn() -> int:
	var p = PickupScript.new()
	if absf(p.respawn_seconds - 30.0) > 0.001:
		push_error("power-up respawn should default to 30s, got %s" % p.respawn_seconds)
		p.free()
		return 1
	print("ok   pickup respawns in 30s")
	p.free()
	return 0


func _test_bot_haste() -> int:
	var bot = Bot.new()
	bot.name = "Grunt"
	bot.bot_name = "Grunt"
	bot.model_path = "res://does_not_exist.glb"
	bot.model_scene = null
	root.add_child(bot)
	var base: float = bot._run_speed()
	if not bot.apply_power_up(1, 8.0):
		push_error("bot haste apply failed")
		bot.queue_free()
		return 1
	var rushed: float = bot._run_speed()
	if absf(rushed - base * 2.0) > 0.01:
		push_error("bot haste should double move speed, base %s got %s" % [base, rushed])
		bot.queue_free()
		return 1
	if absf(bot.outgoing_damage_scale() - 1.0) > 0.01:
		push_error("haste should not change damage")
		bot.queue_free()
		return 1
	if not bot.apply_power_up(0, 8.0) or absf(bot.outgoing_damage_scale() - 4.0) > 0.01:
		push_error("bot quad should be x4 damage")
		bot.queue_free()
		return 1
	print("ok   bot haste x2 speed and quad x4 damage")
	bot.queue_free()
	return 0
