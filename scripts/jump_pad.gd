class_name JumpPad
extends Area3D
## Launch pad for movement tests.
##
## On overlap, builds a world-space launch velocity and calls `launch()` on
## the player so ground friction / floor-snap cannot eat the impulse.
## If `boost` is non-zero it is used as an absolute velocity; otherwise the
## pad fires along its -Z axis at `launch_angle_deg` / `launch_speed`.

@export var launch_speed: float = 18.0
@export var launch_angle_deg: float = 75.0
## World-space velocity override. Used by the arena builders.
@export var boost: Vector3 = Vector3.ZERO
@export var pad_color: Color = Color(0.15, 0.9, 0.55)


func _ready() -> void:
	collision_layer = 16
	collision_mask = 2 | 4
	monitoring = true
	monitorable = true
	if not body_entered.is_connected(_on_body):
		body_entered.connect(_on_body)
	_ensure_visuals()


func _ensure_visuals() -> void:
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col == null:
		col = CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var box := BoxShape3D.new()
		box.size = Vector3(2.4, 0.35, 2.4)
		col.shape = box
		col.position.y = 0.2
		add_child(col)

	var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh == null:
		mesh = MeshInstance3D.new()
		mesh.name = "MeshInstance3D"
		var bm := BoxMesh.new()
		bm.size = Vector3(2.4, 0.12, 2.4)
		mesh.mesh = bm
		mesh.position.y = 0.06
		add_child(mesh)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = pad_color
	mat.emission_enabled = true
	mat.emission = pad_color
	mat.emission_energy_multiplier = 3.0
	mesh.material_override = mat

	if get_node_or_null("OmniLight3D") == null:
		var light := OmniLight3D.new()
		light.name = "OmniLight3D"
		light.light_color = pad_color
		light.light_energy = 2.5
		light.omni_range = 7.0
		add_child(light)


func get_launch_velocity() -> Vector3:
	if boost.length_squared() > 0.0001:
		return boost
	var pitch := deg_to_rad(launch_angle_deg)
	var local := Vector3(0.0, sin(pitch), -cos(pitch)) * launch_speed
	return global_transform.basis * local


func _on_body(body: Node3D) -> void:
	var impulse := get_launch_velocity()
	if body.has_method("launch"):
		body.call("launch", impulse)
	elif body is CharacterBody3D:
		(body as CharacterBody3D).velocity = impulse
	else:
		return
	AudioFx.play_at("pad", global_position)
