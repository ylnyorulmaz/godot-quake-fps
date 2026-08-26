extends SceneTree
## Headless checks for 60/40 armor split and mega-health clamp.
## Run: godot --headless --path . -s res://tests/test_health_component.gd


func _init() -> void:
	var failed := 0
	failed += _expect_hit(100.0, 100.0, 100.0, 60.0, 40.0, "100 dmg vs 100 armor")
	failed += _expect_hit(100.0, 10.0, 100.0, 10.0, 0.0, "100 dmg vs 10 armor (armor empties)")
	failed += _expect_hit(100.0, 0.0, 40.0, 60.0, 0.0, "40 dmg, no armor")
	failed += _expect_mega()
	if failed > 0:
		push_error("health tests failed: %d" % failed)
		quit(1)
	else:
		print("health tests passed")
		quit(0)


func _expect_hit(hp: float, armor: float, dmg: float, want_hp: float, want_armor: float, label: String) -> int:
	var h := HealthComponent.new()
	h.current_health = hp
	h.current_armor = armor
	h.take_damage(dmg)
	if absf(h.current_health - want_hp) > 0.01 or absf(h.current_armor - want_armor) > 0.01:
		push_error("%s: got hp=%.2f armor=%.2f want hp=%.2f armor=%.2f" % [label, h.current_health, h.current_armor, want_hp, want_armor])
		return 1
	print("ok  ", label)
	return 0


func _expect_mega() -> int:
	var h := HealthComponent.new()
	h.current_health = 100.0
	if not h.apply_mega_health(100.0) or absf(h.current_health - 200.0) > 0.01:
		push_error("mega health did not clamp to 200")
		return 1
	if h.apply_mega_health(100.0):
		push_error("mega health applied at cap")
		return 1
	print("ok   mega health clamp")
	return 0
