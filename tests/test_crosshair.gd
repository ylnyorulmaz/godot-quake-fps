extends SceneTree
## Dynamic crosshair gap, colors, punch/hit, and weapon fire signals.
## Run: godot --headless --path . -s res://tests/test_crosshair.gd

const Cross := preload("res://scripts/crosshair.gd")
const Weapons := preload("res://scripts/weapon_manager.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed := 0
	failed += _test_rest_gaps()
	failed += _test_dynamic_gap()
	failed += _test_colors()
	failed += _test_punch_hit()
	failed += _test_fired_signal()
	if failed > 0:
		push_error("crosshair tests failed: %d" % failed)
		quit(1)
	else:
		print("crosshair tests passed")
		quit(0)


func _test_rest_gaps() -> int:
	var rail: float = Cross.rest_gap(Cross.Kind.RAIL)
	var mg: float = Cross.rest_gap(Cross.Kind.MG)
	var rocket: float = Cross.rest_gap(Cross.Kind.ROCKET)
	var sg: float = Cross.rest_gap(Cross.Kind.SHOTGUN)
	if not (rail < mg and mg < rocket and rocket < sg):
		push_error("rest gaps should be rail < mg < rocket < shotgun, got %s %s %s %s" % [rail, mg, rocket, sg])
		return 1
	print("ok   rest gaps rail < mg < rocket < shotgun")
	return 0


func _test_dynamic_gap() -> int:
	var rest: float = Cross.dynamic_gap(Cross.Kind.MG, 0.0, false, false, 0.0)
	var run: float = Cross.dynamic_gap(Cross.Kind.MG, 320.0, false, false, 0.0)
	var air: float = Cross.dynamic_gap(Cross.Kind.MG, 0.0, true, false, 0.0)
	var punch: float = Cross.dynamic_gap(Cross.Kind.MG, 0.0, false, false, 1.0)
	var crouch: float = Cross.dynamic_gap(Cross.Kind.MG, 0.0, false, true, 0.0)
	if run <= rest:
		push_error("running should open the gap: rest %s run %s" % [rest, run])
		return 1
	if air <= rest:
		push_error("airborne should open the gap: rest %s air %s" % [rest, air])
		return 1
	if punch <= rest:
		push_error("fire punch should open the gap: rest %s punch %s" % [rest, punch])
		return 1
	if crouch >= rest:
		push_error("crouch should tighten the gap: rest %s crouch %s" % [rest, crouch])
		return 1
	var clamped: float = Cross.dynamic_gap(Cross.Kind.SHOTGUN, 999.0, true, false, 1.0)
	if clamped > 28.0 + 0.001:
		push_error("gap should clamp at 28, got %s" % clamped)
		return 1
	print("ok   gap grows with speed/air/punch, tightens on crouch")
	return 0


func _test_colors() -> int:
	var empty := Cross.color_for(Cross.Kind.MG, 0)
	var full := Cross.color_for(Cross.Kind.MG, 100)
	var rail := Cross.color_for(Cross.Kind.RAIL, 10)
	if empty.g >= full.g:
		push_error("empty ammo should drop green vs loaded MG")
		return 1
	if rail.b <= rail.r:
		push_error("rail color should be cyan-leaning, got %s" % rail)
		return 1
	var low := Cross.color_for(Cross.Kind.MG, 5)
	if low == full:
		push_error("low ammo should shift color off the loaded hue")
		return 1
	print("ok   empty/low ammo and weapon colors")
	return 0


func _test_punch_hit() -> int:
	var xhair = Cross.new()
	root.add_child(xhair)
	if xhair.punch_amount() != 0.0 or xhair.hit_amount() != 0.0:
		push_error("fresh crosshair should start at rest punch/hit")
		return 1
	xhair.on_fired()
	xhair.on_hit()
	if xhair.punch_amount() < 0.99:
		push_error("on_fired should punch to 1, got %s" % xhair.punch_amount())
		return 1
	if xhair.hit_amount() < 0.99:
		push_error("on_hit should set hit to 1, got %s" % xhair.hit_amount())
		return 1
	print("ok   fire punch and hit flash")
	return 0


func _make_wm():
	var body := CharacterBody3D.new()
	body.name = "Owner"
	root.add_child(body)
	var wm = Weapons.new()
	wm.name = "Weapons"
	root.add_child(wm)
	wm.setup(body, false)
	return wm


func _test_fired_signal() -> int:
	var wm = _make_wm()
	var fired := [false]
	var hits := [0]
	wm.fired.connect(func() -> void:
		fired[0] = true
	)
	wm.hit_landed.connect(func() -> void:
		hits[0] += 1
	)
	wm.state = Weapons.State.IDLE
	if wm._fire_timer:
		wm._fire_timer.stop()
	if not wm.try_fire():
		push_error("MG try_fire should succeed with starting ammo")
		return 1
	if not fired[0]:
		push_error("try_fire should emit fired")
		return 1
	wm.notify_hit()
	if hits[0] != 1:
		push_error("notify_hit should emit hit_landed once, got %s" % hits[0])
		return 1
	print("ok   weapon fired and hit_landed signals")
	return 0
