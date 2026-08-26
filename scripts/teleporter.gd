class_name Teleporter
extends Area3D

var target: Vector3 = Vector3.ZERO
var _cool := 0.0


func _ready() -> void:
	collision_layer = 16
	collision_mask = 2 | 4
	monitoring = true
	body_entered.connect(_on_body)

	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.0
	cyl.height = 2.4
	col.shape = cyl
	add_child(col)

	var mesh := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 0.15
	mesh.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.2, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.55, 0.15, 1.0)
	mat.emission_energy_multiplier = 3.5
	mesh.material_override = mat
	add_child(mesh)

	var light := OmniLight3D.new()
	light.light_color = Color(0.6, 0.25, 1.0)
	light.light_energy = 2.8
	light.omni_range = 6.0
	add_child(light)


func _process(delta: float) -> void:
	_cool = maxf(_cool - delta, 0.0)


func _on_body(body: Node3D) -> void:
	if _cool > 0.0:
		return
	if body is CharacterBody3D:
		body.global_position = target + Vector3(0, 0.2, 0)
		_cool = 0.8
		AudioFx.play_at("teleport", target)
