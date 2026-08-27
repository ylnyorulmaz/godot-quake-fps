extends SceneTree
## Distinct ammo/shell pickups and ejected casings.
## Run: godot --headless --path . -s res://tests/test_ammo_visual.gd

const PickupScript := preload("res://scripts/pickup.gd")
const CasingScript := preload("res://scripts/shell_casing.gd")
const Weapons := preload("res://scripts/weapon_manager.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed := 0
	failed += _test_ammo_shapes_differ()
	failed += _test_weapons_differ_from_ammo()
	failed += _test_casings_differ()
	failed += _test_fire_ejects_brass()
	failed += _test_arena_lists_shells()
	if failed > 0:
		push_error("ammo visual tests failed: %d" % failed)
		quit(1)
	else:
		print("ammo visual tests passed")
		quit(0)


func _spawn_pickup(kind) -> Node:
	var p = PickupScript.new()
	p.configure(kind)
	root.add_child(p)
	return p


func _test_ammo_shapes_differ() -> int:
	var kinds := [
		PickupScript.Kind.MG_AMMO,
		PickupScript.Kind.SG_AMMO,
		PickupScript.Kind.RL_AMMO,
		PickupScript.Kind.RAIL_AMMO,
	]
	var counts: Dictionary = {}
	var palettes: Array[String] = []
	for kind in kinds:
		var p = _spawn_pickup(kind)
		var n: int = int(p.mesh_count())
		if n < 4:
			push_error("ammo kind %s too simple (%d meshes)" % [str(kind), n])
			p.queue_free()
			return 1
		counts[kind] = n
		var key := _palette_key(p.mesh_albedos())
		if key in palettes:
			push_error("ammo kind %s reuses another ammo palette" % str(kind))
			p.queue_free()
			return 1
		palettes.append(key)
		p.queue_free()
	if int(counts[PickupScript.Kind.SG_AMMO]) <= int(counts[PickupScript.Kind.MG_AMMO]):
		push_error("shotgun shells should be chunkier than MG bullets")
		return 1
	if int(counts[PickupScript.Kind.RL_AMMO]) == int(counts[PickupScript.Kind.SG_AMMO]):
		push_error("rockets and shells should not share a mesh count")
		return 1
	print("ok   four ammo packs have unique palettes and compound meshes")
	return 0


func _test_weapons_differ_from_ammo() -> int:
	var pairs := [
		[PickupScript.Kind.SHOTGUN, PickupScript.Kind.SG_AMMO],
		[PickupScript.Kind.ROCKET, PickupScript.Kind.RL_AMMO],
		[PickupScript.Kind.RAIL, PickupScript.Kind.RAIL_AMMO],
	]
	for pair in pairs:
		var gun = _spawn_pickup(pair[0])
		var ammo = _spawn_pickup(pair[1])
		var gun_key := _palette_key(gun.mesh_albedos())
		var ammo_key := _palette_key(ammo.mesh_albedos())
		var same_count := int(gun.mesh_count()) == int(ammo.mesh_count())
		if gun_key == ammo_key and same_count:
			push_error("weapon %s looks like its ammo pack" % str(pair[0]))
			gun.queue_free()
			ammo.queue_free()
			return 1
		gun.queue_free()
		ammo.queue_free()
	print("ok   weapon pickups are not the same as ammo packs")
	return 0


func _test_casings_differ() -> int:
	var brass = CasingScript.new()
	root.add_child(brass)
	brass.configure("mg", Vector3.ZERO, Vector3.RIGHT, Vector3.FORWARD)
	var hull = CasingScript.new()
	root.add_child(hull)
	hull.configure("shotgun", Vector3.ZERO, Vector3.RIGHT, Vector3.FORWARD)
	if int(brass.mesh_count()) < 1:
		push_error("MG casing missing mesh")
		return 1
	if int(hull.mesh_count()) <= int(brass.mesh_count()):
		push_error("shotgun hull should have a brass cap on top of the red body")
		return 1
	if brass.first_albedo().is_equal_approx(hull.first_albedo()):
		push_error("MG brass and shotgun hull should not share albedo")
		return 1
	print("ok   ejected brass and shotgun hulls are distinct")
	brass.queue_free()
	hull.queue_free()
	return 0


func _test_fire_ejects_brass() -> int:
	var body := CharacterBody3D.new()
	body.name = "Owner"
	root.add_child(body)
	var wm = Weapons.new()
	wm.name = "Weapons"
	root.add_child(wm)
	wm.setup(body, false)
	wm.current = Weapons.Kind.MG
	wm.state = Weapons.State.IDLE
	if wm._fire_timer:
		wm._fire_timer.stop()
	var before := _casing_count(wm)
	if not wm.try_fire():
		push_error("MG should fire and eject brass")
		return 1
	var after := _casing_count(wm)
	if after <= before:
		push_error("MG fire should spawn a casing, %d -> %d" % [before, after])
		return 1
	print("ok   MG fire ejects a casing")
	wm.queue_free()
	body.queue_free()
	return 0


func _test_arena_lists_shells() -> int:
	var src := FileAccess.get_file_as_string("res://scripts/arena_generator.gd")
	if src.is_empty() or not ("SG_AMMO" in src and "RAIL_AMMO" in src):
		push_error("live arena should spawn shotgun shells and rail slugs")
		return 1
	print("ok   live arena places shotgun and rail ammo")
	return 0


func _casing_count(host: Node) -> int:
	var n := 0
	for child in host.get_children():
		if str(child.get("kind_id")) in ["mg", "shotgun"]:
			n += 1
	return n


func _palette_key(colors: Array) -> String:
	var parts: Array[String] = []
	for c in colors:
		var col := c as Color
		parts.append("%.2f,%.2f,%.2f" % [col.r, col.g, col.b])
	parts.sort()
	return ",".join(parts)
