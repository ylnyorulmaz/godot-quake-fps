class_name JumpPad
extends Area3D
## Launch pad. Q3-style acid-green pad with a pulsing column.

@export var launch_speed: float = 18.0
@export var launch_angle_deg: float = 75.0
## World-space velocity override. Used by the arena builders.
@export var boost: Vector3 = Vector3.ZERO
@export var pad_color: Color = Color(0.55, 1.0, 0.12)

var _glow_mat: StandardMaterial3D
var _column_mat: StandardMaterial3D
var _light: OmniLight3D
var _pulse := 0.0


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
		box.size = Vector3(2.6, 0.45, 2.6)
		col.shape = box
		col.position.y = 0.22
		add_child(col)

	var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh == null:
		mesh = MeshInstance3D.new()
		mesh.name = "MeshInstance3D"
		var bm := BoxMesh.new()
		bm.size = Vector3(2.5, 0.14, 2.5)
		mesh.mesh = bm
		mesh.position.y = 0.07
		add_child(mesh)
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.albedo_color = pad_color
	_glow_mat.emission_enabled = true
	_glow_mat.emission = pad_color
	_glow_mat.emission_energy_multiplier = 4.2
	mesh.material_override = _glow_mat

	if get_node_or_null("Column") == null:
		var column := MeshInstance3D.new()
		column.name = "Column"
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.55
		cyl.bottom_radius = 1.05
		cyl.height = 2.4
		column.mesh = cyl
		column.position.y = 1.25
		_column_mat = StandardMaterial3D.new()
		_column_mat.albedo_color = Color(pad_color.r, pad_color.g, pad_color.b, 0.28)
		_column_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_column_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_column_mat.emission_enabled = true
		_column_mat.emission = pad_color
		_column_mat.emission_energy_multiplier = 2.4
		column.material_override = _column_mat
		add_child(column)

	_light = get_node_or_null("OmniLight3D") as OmniLight3D
	if _light == null:
		_light = OmniLight3D.new()
		_light.name = "OmniLight3D"
		_light.light_color = pad_color
		_light.light_energy = 3.4
		_light.omni_range = 9.0
		_light.shadow_enabled = false
		add_child(_light)


func _process(delta: float) -> void:
	_pulse += delta * 4.2
	var pulse := 0.65 + 0.35 * (0.5 + 0.5 * sin(_pulse))
	if _glow_mat:
		_glow_mat.emission_energy_multiplier = 3.2 + pulse * 2.4
	if _column_mat:
		_column_mat.albedo_color.a = 0.16 + pulse * 0.18
		_column_mat.emission_energy_multiplier = 1.6 + pulse * 2.0
	if _light:
		_light.light_energy = 2.4 + pulse * 2.2


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
	var fx := get_node_or_null("/root/AudioFx")
	if fx and fx.has_method("play_at"):
		fx.call("play_at", "pad", global_position)
