extends SceneTree
## Right-click alt-fire: shotgun slug, rocket shove.
## Run: godot --headless --path . -s res://tests/test_alt_fire.gd

const Weapons := preload("res://scripts/weapon_manager.gd")
const Data := preload("res://scripts/weapon_data.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed := 0
	failed += _test_alt_constants()
	failed += _test_mg_burst()
	failed += _test_rail_charge()
	failed += _test_shotgun_slug()
	failed += _test_rocket_shove()
	if failed > 0:
		push_error("alt-fire tests failed: %d" % failed)
		quit(1)
	else:
		print("alt-fire tests passed")
		quit(0)


func _make_wm():
	var body := CharacterBody3D.new()
	body.name = "Owner"
	root.add_child(body)
	var wm = Weapons.new()
	wm.name = "Weapons"
	root.add_child(wm)
	wm.setup(body, false)
	return wm


func _ready_weapon(wm, kind, shells: int) -> void:
	wm.give_weapon(kind, shells)
	wm.current = kind
	wm.state = Weapons.State.IDLE
	if wm._fire_timer:
		wm._fire_timer.stop()


func _test_alt_constants() -> int:
	if Weapons.ALT_SHOTGUN_PELLETS != 1:
		push_error("shotgun alt should be 1 pellet, got %s" % Weapons.ALT_SHOTGUN_PELLETS)
		return 1
	var primary: float = Data.shotgun().spread_deg
	if Weapons.ALT_SHOTGUN_SPREAD_DEG >= primary:
		push_error("shotgun alt spread should be tighter than primary %.2f vs %.2f" % [Weapons.ALT_SHOTGUN_SPREAD_DEG, primary])
		return 1
	if Weapons.ALT_ROCKET_KNOCKBACK >= 20.0:
		push_error("rocket alt shove should be light, got %s" % Weapons.ALT_ROCKET_KNOCKBACK)
		return 1
	if Weapons.ALT_MG_PELLETS < 2:
		push_error("MG alt should be a burst/spray, got %s pellets" % Weapons.ALT_MG_PELLETS)
		return 1
	if Weapons.ALT_RAIL_AMMO < 2:
		push_error("rail alt should cost extra ammo")
		return 1
	if Weapons.ALT_RAIL_DAMAGE_SCALE <= 1.0:
		push_error("rail alt should hit harder")
		return 1
	print("ok   shotgun slug is 1 tight pellet, rocket shove is light")
	return 0


func _test_mg_burst() -> int:
	var wm = _make_wm()
	wm.state = Weapons.State.IDLE
	var before: int = int(wm.ammo[Weapons.Kind.MG])
	if not wm.alt_fire():
		push_error("machinegun alt-fire should spray with ammo")
		return 1
	var after: int = int(wm.ammo[Weapons.Kind.MG])
	if after != before - Weapons.ALT_MG_AMMO:
		push_error("MG alt should spend %d, %d -> %d" % [Weapons.ALT_MG_AMMO, before, after])
		return 1
	print("ok   MG alt spends a burst of rounds")
	wm.queue_free()
	return 0


func _test_rail_charge() -> int:
	var wm = _make_wm()
	_ready_weapon(wm, Weapons.Kind.RAIL, 6)
	var before: int = int(wm.ammo[Weapons.Kind.RAIL])
	if not wm.alt_fire():
		push_error("rail alt-fire should fire a charged shot")
		return 1
	var after: int = int(wm.ammo[Weapons.Kind.RAIL])
	if after != before - Weapons.ALT_RAIL_AMMO:
		push_error("rail alt should spend %d, %d -> %d" % [Weapons.ALT_RAIL_AMMO, before, after])
		return 1
	print("ok   rail alt spends extra ammo for a charged shot")
	wm.queue_free()
	return 0


func _test_shotgun_slug() -> int:
	var wm = _make_wm()
	_ready_weapon(wm, Weapons.Kind.SHOTGUN, 6)
	var before: int = int(wm.ammo[Weapons.Kind.SHOTGUN])
	if not wm.alt_fire():
		push_error("shotgun alt-fire should fire with ammo")
		return 1
	var after: int = int(wm.ammo[Weapons.Kind.SHOTGUN])
	if after != before - 1:
		push_error("shotgun alt should spend 1 shell, %d -> %d" % [before, after])
		return 1
	print("ok   shotgun alt spends one shell")
	wm.queue_free()
	return 0


func _test_rocket_shove() -> int:
	var wm = _make_wm()
	_ready_weapon(wm, Weapons.Kind.ROCKET, 4)
	var before: int = int(wm.ammo[Weapons.Kind.ROCKET])
	if not wm.alt_fire():
		push_error("rocket alt-fire should shove with ammo")
		return 1
	var after: int = int(wm.ammo[Weapons.Kind.ROCKET])
	if after != before - 1:
		push_error("rocket alt should spend 1 rocket, %d -> %d" % [before, after])
		return 1
	print("ok   rocket alt spends one rocket for a shove blast")
	wm.queue_free()
	return 0
