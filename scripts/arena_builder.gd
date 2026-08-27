class_name ArenaBuilder
extends Node
## Legacy enclosed deathmatch hull. The live map is `ArenaGenerator`.

var world: Node3D


func build(parent: Node3D) -> void:
	world = parent
	world.add_to_group("world_root")
	_environment()
	_hull()
	_pit()
	_ramps()
	_upper()
	_cover()
	_lights()
	_spawns()
	_pads()
	_teleporters()
	_pickups()
	_nav_points()


func _environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.03, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.18, 0.16)
	env.ambient_light_energy = 0.35
	env.fog_enabled = true
	env.fog_light_color = Color(0.07, 0.06, 0.05)
	env.fog_density = 0.012
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	we.environment = env
	world.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_color = Color(1.0, 0.82, 0.65)
	sun.light_energy = 0.55
	sun.shadow_enabled = true
	world.add_child(sun)


func _hull() -> void:
	var wall := Color(0.22, 0.2, 0.18)
	var floor_c := Color(0.16, 0.15, 0.14)
	var ceil_c := Color(0.12, 0.11, 0.1)
	var comb := CSGCombiner3D.new()
	comb.use_collision = true
	comb.collision_layer = 1
	comb.collision_mask = 0
	# Godot 4.7 CSG autosmooth (ignored on older editors).
	if "autosmooth" in comb:
		comb.autosmooth = true
	world.add_child(comb)
	var floor_box := CSGBox3D.new()
	floor_box.size = Vector3(80, 1, 80)
	floor_box.position = Vector3(0, -0.5, 0)
	floor_box.material = _mat(floor_c)
	comb.add_child(floor_box)
	var hole := CSGBox3D.new()
	hole.operation = CSGShape3D.OPERATION_SUBTRACTION
	hole.size = Vector3(16, 2.4, 16)
	hole.position = Vector3(0, -0.5, 0)
	comb.add_child(hole)
	_box(Vector3(0, 16.5, 0), Vector3(80, 1, 80), ceil_c)
	_box(Vector3(-40.5, 8, 0), Vector3(1, 16, 80), wall)
	_box(Vector3(40.5, 8, 0), Vector3(1, 16, 80), wall)
	_box(Vector3(0, 8, -40.5), Vector3(80, 16, 1), wall)
	_box(Vector3(0, 8, 40.5), Vector3(80, 16, 1), wall)


func _pit() -> void:
	var pit := Color(0.12, 0.11, 0.1)
	_box(Vector3(0, -3.0, 0), Vector3(16, 1, 16), pit)
	_box(Vector3(-8.5, -1.75, 0), Vector3(1, 3.5, 16), pit)
	_box(Vector3(8.5, -1.75, 0), Vector3(1, 3.5, 16), pit)
	_box(Vector3(-6.0, -1.75, -8.5), Vector3(4, 3.5, 1), pit)
	_box(Vector3(6.0, -1.75, -8.5), Vector3(4, 3.5, 1), pit)
	_box(Vector3(-6.0, -1.75, 8.5), Vector3(4, 3.5, 1), pit)
	_box(Vector3(6.0, -1.75, 8.5), Vector3(4, 3.5, 1), pit)


func _ramps() -> void:
	var c := Color(0.3, 0.18, 0.1)
	_ramp(Vector3(0, 0.2, 14), 10.0, 3.2, 2.4, 0.0, c)
	_ramp(Vector3(0, 0.2, -14), 10.0, 3.2, 2.4, 180.0, c)
	_ramp(Vector3(14, 0.2, 0), 10.0, 3.2, 2.4, -90.0, c)
	_ramp(Vector3(-14, 0.2, 0), 10.0, 3.2, 2.4, 90.0, c)
	# into pit (north/south gaps carved by leaving wall openings via ramps over the rim)
	_ramp(Vector3(0, -1.2, 10.5), 9.0, 2.6, 3.0, 180.0, c)
	_ramp(Vector3(0, -1.2, -10.5), 9.0, 2.6, 3.0, 0.0, c)


func _upper() -> void:
	var plat := Color(0.24, 0.22, 0.2)
	# catwalk ring pieces
	_box(Vector3(0, 6.0, 28), Vector3(36, 0.4, 6), plat)
	_box(Vector3(0, 6.0, -28), Vector3(36, 0.4, 6), plat)
	_box(Vector3(28, 6.0, 0), Vector3(6, 0.4, 36), plat)
	_box(Vector3(-28, 6.0, 0), Vector3(6, 0.4, 36), plat)
	# corner platforms
	for x in [-28.0, 28.0]:
		for z in [-28.0, 28.0]:
			_box(Vector3(x, 6.0, z), Vector3(8, 0.4, 8), plat)
	# ramps to upper
	_ramp(Vector3(18, 3.1, 28), 14.0, 6.2, 3.0, 90.0, Color(0.32, 0.2, 0.1))
	_ramp(Vector3(-18, 3.1, -28), 14.0, 6.2, 3.0, -90.0, Color(0.32, 0.2, 0.1))
	# center spire
	_box(Vector3(0, 4.5, 0), Vector3(3.2, 9, 3.2), Color(0.35, 0.16, 0.08))
	_box(Vector3(0, 9.2, 0), Vector3(5.5, 0.35, 5.5), plat)


func _cover() -> void:
	var crate := Color(0.38, 0.22, 0.1)
	var spots := [
		Vector3(18, 1, 12), Vector3(-16, 1, 14), Vector3(12, 1, -18),
		Vector3(-20, 1, -10), Vector3(22, 1, -8), Vector3(-8, 1, 22),
	]
	for p in spots:
		_box(p, Vector3(2.4, 2.0, 2.4), crate)


func _lights() -> void:
	var positions := [
		Vector3(0, 10, 0), Vector3(24, 8, 24), Vector3(-24, 8, 24),
		Vector3(24, 8, -24), Vector3(-24, 8, -24), Vector3(0, 4, 0),
		Vector3(28, 8, 0), Vector3(-28, 8, 0),
	]
	for p in positions:
		var light := OmniLight3D.new()
		light.position = p
		light.light_color = Color(1.0, 0.55, 0.22)
		light.light_energy = 2.8
		light.omni_range = 22.0
		light.shadow_enabled = false
		world.add_child(light)


func _spawns() -> void:
	var pts := [
		Vector3(30, 1.2, 30), Vector3(-30, 1.2, 30), Vector3(30, 1.2, -30),
		Vector3(-30, 1.2, -30), Vector3(0, 1.2, 32), Vector3(0, 1.2, -32),
		Vector3(32, 7.4, 0), Vector3(-32, 7.4, 0),
	]
	for p in pts:
		var m := Marker3D.new()
		m.position = p
		m.add_to_group("spawn_points")
		world.add_child(m)


func _pads() -> void:
	_jump(Vector3(32, 0.2, 32), Vector3(-6, 16, -6))
	_jump(Vector3(-32, 0.2, 32), Vector3(6, 16, -6))
	_jump(Vector3(32, 0.2, -32), Vector3(-6, 16, 6))
	_jump(Vector3(-32, 0.2, -32), Vector3(6, 16, 6))
	_jump(Vector3(0, -2.4, 0), Vector3(0, 22, 0))


func _jump(pos: Vector3, boost: Vector3) -> void:
	var pad := JumpPad.new()
	pad.boost = boost
	pad.position = pos
	world.add_child(pad)


func _teleporters() -> void:
	var a := Teleporter.new()
	a.position = Vector3(36, 1.0, 0)
	a.target = Vector3(-34, 7.5, 0)
	world.add_child(a)
	var b := Teleporter.new()
	b.position = Vector3(-36, 1.0, 0)
	b.target = Vector3(34, 7.5, 0)
	world.add_child(b)


func _pickups() -> void:
	_item(Vector3(0, 9.8, 0), Pickup.Kind.MEGA_HEALTH, 30.0)
	_item(Vector3(0, -2.2, 0), Pickup.Kind.ROCKET, 20.0)
	_item(Vector3(28, 6.6, 28), Pickup.Kind.RAIL, 25.0)
	_item(Vector3(-28, 6.6, -28), Pickup.Kind.SHOTGUN, 15.0)
	_item(Vector3(28, 6.6, -28), Pickup.Kind.ARMOR, 20.0)
	_item(Vector3(-28, 6.6, 28), Pickup.Kind.ARMOR, 20.0)
	_item(Vector3(18, 1.2, 0), Pickup.Kind.HEALTH, 10.0)
	_item(Vector3(-18, 1.2, 0), Pickup.Kind.HEALTH, 10.0)
	_item(Vector3(0, 1.2, 18), Pickup.Kind.HEALTH, 10.0)
	_item(Vector3(0, 1.2, -18), Pickup.Kind.HEALTH, 10.0)
	_item(Vector3(12, 1.2, 12), Pickup.Kind.MG_AMMO, 10.0)
	_item(Vector3(-12, 1.2, -12), Pickup.Kind.SG_AMMO, 12.0)
	_item(Vector3(12, 1.2, -12), Pickup.Kind.RL_AMMO, 15.0)
	_item(Vector3(-12, 1.2, 12), Pickup.Kind.RAIL_AMMO, 15.0)
	_item(Vector3(0, 6.6, 28), Pickup.Kind.SHOTGUN, 15.0)
	_item(Vector3(0, 6.6, -28), Pickup.Kind.ROCKET, 20.0)


func _item(pos: Vector3, kind: Pickup.Kind, respawn: float) -> void:
	var p := Pickup.new()
	p.configure(kind, respawn)
	p.position = pos
	world.add_child(p)


func _nav_points() -> void:
	var pts := [
		Vector3(20, 1, 20), Vector3(-20, 1, 20), Vector3(20, 1, -20), Vector3(-20, 1, -20),
		Vector3(0, -1, 0), Vector3(28, 7, 0), Vector3(-28, 7, 0), Vector3(0, 7, 28),
		Vector3(0, 7, -28), Vector3(0, 10, 0), Vector3(16, 1, 0), Vector3(-16, 1, 0),
	]
	for p in pts:
		var m := Marker3D.new()
		m.position = p
		m.add_to_group("nav_points")
		world.add_child(m)


func _mat(color: Color) -> StandardMaterial3D:
	var mat := ArenaPlateMaterial.make_material(ArenaPlateMaterial.Kind.FLOOR)
	mat.albedo_color = color
	return mat


func _box(center: Vector3, size: Vector3, color: Color, collision := true) -> void:
	var b := CSGBox3D.new()
	b.size = size
	b.position = center
	b.use_collision = collision
	if collision:
		b.collision_layer = 1
		b.collision_mask = 0
	b.material = _mat(color)
	world.add_child(b)


func _ramp(center: Vector3, length: float, height: float, width: float, yaw_deg: float, color: Color) -> void:
	var b := CSGBox3D.new()
	b.size = Vector3(length, 0.35, width)
	b.position = center
	var angle := atan(height / length)
	b.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	b.rotate_object_local(Vector3.RIGHT, -angle)
	b.use_collision = true
	b.collision_layer = 1
	b.collision_mask = 0
	var mat := ArenaPlateMaterial.make_material(ArenaPlateMaterial.Kind.TRIM)
	mat.albedo_color = color
	b.material = mat
	world.add_child(b)
