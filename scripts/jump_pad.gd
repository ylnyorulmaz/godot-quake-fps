class_name JumpPad
extends Area3D

var boost := Vector3(0.0, 18.0, 0.0)


func _ready() -> void:
	collision_layer = 16
	collision_mask = 2 | 4
	monitoring = true
	body_entered.connect(_on_body)

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 0.4, 2.2)
	col.shape = box
	col.position.y = 0.15
	add_child(col)

	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.2, 0.12, 2.2)
	mesh.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.9, 0.55)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 1.0, 0.45)
	mat.emission_energy_multiplier = 3.0
	mesh.material_override = mat
	add_child(mesh)

	var light := OmniLight3D.new()
	light.light_color = Color(0.2, 1.0, 0.5)
	light.light_energy = 2.5
	light.omni_range = 7.0
	add_child(light)


func _on_body(body: Node3D) -> void:
	if body is CharacterBody3D:
		(body as CharacterBody3D).velocity = boost
		AudioFx.play_at("pad", global_position)
