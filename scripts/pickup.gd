class_name Pickup
extends Area3D

enum Kind { HEALTH, MEGA_HEALTH, ARMOR, MG_AMMO, SG_AMMO, RL_AMMO, RAIL_AMMO, SHOTGUN, ROCKET, RAIL }

var kind: Kind = Kind.HEALTH
var respawn_time := 12.0
var _ready_item := true
var _mesh: MeshInstance3D
var _light: OmniLight3D
var _spin := 0.0


func configure(p_kind: Kind, p_respawn: float = 12.0) -> void:
	kind = p_kind
	respawn_time = p_respawn


func _ready() -> void:
	collision_layer = 16
	collision_mask = 2 | 4
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body)

	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.55
	col.shape = sphere
	add_child(col)

	_mesh = MeshInstance3D.new()
	if kind == Kind.HEALTH or kind == Kind.MEGA_HEALTH:
		_mesh.mesh = _plus_mesh()
	else:
		var box := BoxMesh.new()
		box.size = Vector3(0.55, 0.55, 0.55)
		_mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _color()
	mat.emission_enabled = true
	mat.emission = _color()
	mat.emission_energy_multiplier = 2.2
	_mesh.material_override = mat
	if kind == Kind.HEALTH or kind == Kind.MEGA_HEALTH:
		var bar := MeshInstance3D.new()
		var upright := BoxMesh.new()
		upright.size = Vector3(0.22, 0.7, 0.22)
		bar.mesh = upright
		bar.material_override = mat
		_mesh.add_child(bar)
	add_child(_mesh)

	_light = OmniLight3D.new()
	_light.light_color = _color()
	_light.light_energy = 1.6
	_light.omni_range = 5.0
	add_child(_light)


func _process(delta: float) -> void:
	_spin += delta
	if _mesh:
		_mesh.rotation.y = _spin * 1.6
		_mesh.position.y = sin(_spin * 3.0) * 0.08


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


func _plus_mesh() -> BoxMesh:
	var box := BoxMesh.new()
	box.size = Vector3(0.7, 0.22, 0.22)
	return box


func _on_body(body: Node3D) -> void:
	if not _ready_item:
		return
	if not body.has_method("apply_pickup"):
		return
	if body.apply_pickup(kind):
		_ready_item = false
		_mesh.visible = false
		_light.visible = false
		var fx := get_node_or_null("/root/AudioFx")
		if fx and fx.has_method("play_at"):
			fx.call("play_at", "pickup", global_position)
		await get_tree().create_timer(respawn_time).timeout
		_ready_item = true
		_mesh.visible = true
		_light.visible = true
