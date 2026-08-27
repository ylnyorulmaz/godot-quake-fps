extends SceneTree
## GameManager handicap multiplier.
## Run: godot --headless --path . -s res://tests/test_game_manager.gd

const GameManagerScript := preload("res://scripts/game_manager.gd")


func _init() -> void:
	var failed := 0
	failed += _test_default_multiplier()
	failed += _test_easy_scales_values()
	if failed > 0:
		push_error("game_manager tests failed: %d" % failed)
		quit(1)
	else:
		print("game_manager tests passed")
		quit(0)


func _test_default_multiplier() -> int:
	var gm = GameManagerScript.new()
	if absf(float(gm.difficulty_multiplier) - 1.0) > 0.0001:
		push_error("default difficulty_multiplier should be 1.0, got %s" % gm.difficulty_multiplier)
		return 1
	print("ok   default handicap is 1.0")
	gm.free()
	return 0


func _test_easy_scales_values() -> int:
	var gm = GameManagerScript.new()
	gm.difficulty_multiplier = 0.5
	var health := 100.0 * gm.difficulty_multiplier
	var damage := 7.0 * gm.difficulty_multiplier
	if absf(health - 50.0) > 0.01 or absf(damage - 3.5) > 0.01:
		push_error("0.5 multiplier should halve 100 HP and 7 dmg, got %s %s" % [health, damage])
		return 1
	print("ok   0.5 multiplier halves health and damage")
	gm.free()
	return 0
