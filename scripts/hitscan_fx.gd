class_name HitscanFx
extends MeshInstance3D

var _life := 0.08


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.35)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.2)
	mat.emission_energy_multiplier = 4.0
	material_override = mat


func configure(from: Vector3, to: Vector3, color: Color, thickness := 0.04) -> void:
	var length := from.distance_to(to)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(thickness, thickness, maxf(length, 0.05))
	self.mesh = mesh
	if material_override is StandardMaterial3D:
		var mat := material_override as StandardMaterial3D
		mat.albedo_color = color
		mat.emission = color
	_life = 0.22 if thickness >= 0.05 else 0.08
	global_position = (from + to) * 0.5
	if length > 0.05:
		var up := Vector3.UP
		var dir := (to - from).normalized()
		if absf(dir.dot(up)) > 0.99:
			up = Vector3.RIGHT
		look_at(to, up)


func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
