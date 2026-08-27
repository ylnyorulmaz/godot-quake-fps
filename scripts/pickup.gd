class_name Pickup
extends Area3D
## World pickups. Ammo/shells/weapons have distinct shapes so you can read
## them at a glance (Q3-style: shells, rockets, bullets, slugs).

enum Kind { HEALTH, MEGA_HEALTH, ARMOR, MG_AMMO, SG_AMMO, RL_AMMO, RAIL_AMMO, SHOTGUN, ROCKET, RAIL }

var kind: Kind = Kind.HEALTH
var respawn_time := 12.0
var _ready_item := true
var _visual: Node3D
var _light: OmniLight3D
var _spin := 0.0


func configure(p_kind: Kind, p_respawn: float = 12.0) -> void:
	kind = p_kind
	respawn_time = p_respawn
	if is_inside_tree():
		_build_visual()


func _ready() -> void:
	collision_layer = 16
	collision_mask = 2 | 4
	monitoring = true
	monitorable = true
	if not body_entered.is_connected(_on_body):
		body_entered.connect(_on_body)
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col == null:
		col = CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var sphere := SphereShape3D.new()
		sphere.radius = 0.7
		col.shape = sphere
		add_child(col)
	_build_visual()
	if get_node_or_null("Glow") == null:
		_light = OmniLight3D.new()
		_light.name = "Glow"
		_light.omni_range = 5.5
		_light.shadow_enabled = false
		add_child(_light)
	else:
		_light = get_node_or_null("Glow") as OmniLight3D
	_style_light()


func _build_visual() -> void:
	if _visual == null:
		_visual = get_node_or_null("Visual") as Node3D
		if _visual == null:
			_visual = Node3D.new()
			_visual.name = "Visual"
			add_child(_visual)
	for child in _visual.get_children():
		child.free()
	match kind:
		Kind.HEALTH:
			_plus(Color(0.2, 0.9, 0.3), 0.85)
		Kind.MEGA_HEALTH:
			_plus(Color(0.15, 1.0, 0.55), 1.15)
		Kind.ARMOR:
			_armor()
		Kind.MG_AMMO:
			_bullet_box()
		Kind.SG_AMMO:
			_shell_pack()
		Kind.RL_AMMO:
			_rocket_pack()
		Kind.RAIL_AMMO:
			_rail_slugs()
		Kind.SHOTGUN:
			_shotgun_gun()
		Kind.ROCKET:
			_rocket_gun()
		Kind.RAIL:
			_rail_gun()
		_:
			_bullet_box()
	_style_light()


func _style_light() -> void:
	if _light == null:
		return
	var c := _color()
	_light.light_color = c
	_light.light_energy = 2.4 if _is_energy() else 1.6


func _is_energy() -> bool:
	return kind == Kind.RAIL or kind == Kind.RAIL_AMMO


func _process(delta: float) -> void:
	_spin += delta
	if _visual:
		_visual.rotation.y = _spin * 1.6
		_visual.position.y = sin(_spin * 3.0) * 0.08


func _color() -> Color:
	match kind:
		Kind.HEALTH:
			return Color(0.2, 0.9, 0.3)
		Kind.MEGA_HEALTH:
			return Color(0.15, 1.0, 0.55)
		Kind.ARMOR:
			return Color(0.95, 0.8, 0.15)
		Kind.SHOTGUN, Kind.SG_AMMO:
			return Color(0.85, 0.45, 0.1)
		Kind.ROCKET, Kind.RL_AMMO:
			return Color(0.95, 0.2, 0.1)
		Kind.RAIL, Kind.RAIL_AMMO:
			return Color(0.2, 0.75, 1.0)
		_:
			return Color(0.75, 0.75, 0.35)


func mesh_count() -> int:
	if _visual == null:
		return 0
	return _visual.get_child_count()


func mesh_albedos() -> Array[Color]:
	var out: Array[Color] = []
	if _visual == null:
		return out
	for child in _visual.get_children():
		var mi := child as MeshInstance3D
		if mi == null:
			continue
		var mat := mi.material_override as StandardMaterial3D
		if mat:
			out.append(mat.albedo_color)
	return out


func _mat(color: Color, emit: float = 2.2) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = emit
	mat.roughness = 0.42
	return mat


func _box(size: Vector3, pos: Vector3, color: Color, emit: float = 2.0) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = _mat(color, emit)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(mi)


func _cyl(r_top: float, r_bot: float, height: float, pos: Vector3, color: Color, along_z: bool = false, emit: float = 2.0) -> void:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = r_top
	mesh.bottom_radius = r_bot
	mesh.height = height
	mesh.radial_segments = 10
	mi.mesh = mesh
	mi.position = pos
	if along_z:
		mi.rotation_degrees.x = 90.0
	mi.material_override = _mat(color, emit)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(mi)


func _ring(radius: float, thick: float, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = maxf(radius - thick, 0.01)
	mesh.outer_radius = radius
	mesh.rings = 10
	mesh.ring_segments = 10
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees.x = 90.0
	mi.material_override = _mat(color, 3.2)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(mi)


func _plus(color: Color, scale: float) -> void:
	_box(Vector3(0.7, 0.2, 0.2) * scale, Vector3.ZERO, color, 2.6)
	_box(Vector3(0.2, 0.7, 0.2) * scale, Vector3.ZERO, color, 2.6)


func _armor() -> void:
	var gold := Color(0.95, 0.8, 0.15)
	_box(Vector3(0.55, 0.7, 0.22), Vector3(0.0, 0.05, 0.0), gold, 2.4)
	_box(Vector3(0.22, 0.35, 0.18), Vector3(-0.28, 0.05, 0.0), gold, 2.0)
	_box(Vector3(0.22, 0.35, 0.18), Vector3(0.28, 0.05, 0.0), gold, 2.0)


func _bullet_box() -> void:
	var crate := Color(0.75, 0.7, 0.28)
	var brass := Color(0.85, 0.62, 0.18)
	_box(Vector3(0.42, 0.22, 0.32), Vector3(0.0, -0.06, 0.0), crate, 1.8)
	for i in 4:
		var x := -0.12 + float(i) * 0.08
		_cyl(0.018, 0.018, 0.16, Vector3(x, 0.12, 0.0), brass, false, 2.2)


func _shell_pack() -> void:
	var red := Color(0.85, 0.18, 0.08)
	var brass := Color(0.9, 0.7, 0.2)
	var tray := Color(0.42, 0.28, 0.12)
	_box(Vector3(0.3, 0.05, 0.3), Vector3(0.0, -0.12, 0.0), tray, 1.4)
	var spots := [
		Vector3(-0.08, 0.0, -0.08), Vector3(0.08, 0.0, -0.08),
		Vector3(-0.08, 0.0, 0.08), Vector3(0.08, 0.0, 0.08),
		Vector3(0.0, 0.0, 0.0),
	]
	for p in spots:
		_cyl(0.035, 0.035, 0.18, p, red, false, 2.4)
		_cyl(0.036, 0.036, 0.04, p + Vector3(0.0, 0.1, 0.0), brass, false, 2.6)


func _rocket_pack() -> void:
	var crate := Color(0.42, 0.14, 0.08)
	var body := Color(0.78, 0.16, 0.08)
	var nose := Color(0.95, 0.45, 0.12)
	var fin := Color(0.32, 0.1, 0.06)
	_box(Vector3(0.32, 0.07, 0.24), Vector3(0.0, -0.18, 0.0), crate, 1.5)
	for x in [-0.08, 0.08]:
		_cyl(0.055, 0.055, 0.32, Vector3(x, 0.02, 0.0), body, false, 2.4)
		_cyl(0.016, 0.06, 0.12, Vector3(x, 0.24, 0.0), nose, false, 3.0)
		_box(Vector3(0.12, 0.08, 0.016), Vector3(x, -0.1, 0.0), fin, 1.5)


func _rail_slugs() -> void:
	var cyan := Color(0.2, 0.85, 1.0)
	var crate := Color(0.1, 0.22, 0.28)
	_box(Vector3(0.34, 0.06, 0.2), Vector3(0.0, -0.14, 0.0), crate, 1.6)
	_cyl(0.05, 0.05, 0.22, Vector3(-0.08, 0.0, 0.0), cyan, false, 3.4)
	_cyl(0.05, 0.05, 0.22, Vector3(0.08, 0.0, 0.0), cyan, false, 3.4)
	_ring(0.1, 0.018, Vector3(-0.08, 0.0, 0.0), cyan)
	_ring(0.1, 0.018, Vector3(0.08, 0.0, 0.0), cyan)


func _shotgun_gun() -> void:
	var wood := Color(0.55, 0.32, 0.12)
	var metal := Color(0.35, 0.35, 0.4)
	_cyl(0.03, 0.03, 0.42, Vector3(0.03, 0.04, 0.0), metal, true, 1.8)
	_cyl(0.03, 0.03, 0.42, Vector3(-0.03, 0.04, 0.0), metal, true, 1.8)
	_box(Vector3(0.1, 0.08, 0.18), Vector3(0.0, 0.0, 0.18), wood, 1.6)
	_box(Vector3(0.05, 0.1, 0.05), Vector3(0.0, -0.08, 0.12), wood, 1.4)


func _rocket_gun() -> void:
	var rust := Color(0.55, 0.18, 0.1)
	var steel := Color(0.4, 0.38, 0.36)
	_cyl(0.08, 0.08, 0.5, Vector3(0.0, 0.04, 0.0), rust, true, 2.2)
	_box(Vector3(0.12, 0.12, 0.18), Vector3(0.0, -0.04, 0.16), steel, 1.6)
	_box(Vector3(0.04, 0.12, 0.05), Vector3(0.0, -0.14, 0.1), steel, 1.4)
	_box(Vector3(0.14, 0.03, 0.08), Vector3(0.0, 0.1, -0.05), Color(0.9, 0.7, 0.15), 2.4)


func _rail_gun() -> void:
	var steel := Color(0.2, 0.28, 0.35)
	var glow := Color(0.15, 0.9, 1.0)
	_box(Vector3(0.08, 0.08, 0.2), Vector3(0.0, 0.0, 0.14), steel, 1.6)
	_cyl(0.02, 0.02, 0.55, Vector3(0.0, 0.02, -0.12), glow, true, 3.6)
	_ring(0.055, 0.012, Vector3(0.0, 0.02, -0.05), glow)
	_ring(0.055, 0.012, Vector3(0.0, 0.02, -0.2), glow)
	_box(Vector3(0.05, 0.1, 0.05), Vector3(0.0, -0.08, 0.1), steel, 1.4)


func _on_body(body: Node3D) -> void:
	if not _ready_item:
		return
	if not body.has_method("apply_pickup"):
		return
	if body.apply_pickup(kind):
		_ready_item = false
		if _visual:
			_visual.visible = false
		if _light:
			_light.visible = false
		var fx := get_node_or_null("/root/AudioFx")
		if fx and fx.has_method("play_at"):
			fx.call("play_at", "pickup", global_position)
		await get_tree().create_timer(respawn_time).timeout
		_ready_item = true
		if _visual:
			_visual.visible = true
		if _light:
			_light.visible = true
