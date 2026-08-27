extends Node3D
## Spent brass / shotgun hull that arcs out of the gun and despawns.

var kind_id := "mg"
var velocity := Vector3.ZERO
var _life := 0.9
var _spin := Vector3.ZERO


func configure(kind: String, origin: Vector3, right: Vector3, forward: Vector3) -> void:
	kind_id = kind
	global_position = origin
	var side := right.normalized() if right.length_squared() > 0.0001 else Vector3.RIGHT
	var fwd := forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD
	velocity = side * randf_range(3.2, 5.0) + Vector3.UP * randf_range(2.4, 3.6) + fwd * randf_range(0.4, 1.2)
	_spin = Vector3(randf_range(-12.0, 12.0), randf_range(-8.0, 8.0), randf_range(-10.0, 10.0))
	_build(kind)


func mesh_count() -> int:
	return get_child_count()


func first_albedo() -> Color:
	for child in get_children():
		var mi := child as MeshInstance3D
		if mi == null:
			continue
		var mat := mi.material_override as StandardMaterial3D
		if mat:
			return mat.albedo_color
	return Color.BLACK


func _build(kind: String) -> void:
	if kind == "shotgun":
		_add_cyl(0.028, 0.12, Color(0.85, 0.2, 0.08), Vector3.ZERO)
		_add_cyl(0.03, 0.03, Color(0.9, 0.7, 0.2), Vector3(0.0, 0.055, 0.0))
	else:
		_add_cyl(0.012, 0.055, Color(0.85, 0.65, 0.2), Vector3.ZERO)


func _add_cyl(radius: float, height: float, color: Color, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.6
	mat.roughness = 0.4
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _process(delta: float) -> void:
	velocity.y -= 22.0 * delta
	global_position += velocity * delta
	rotation += _spin * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()
