class_name PowerUp
extends Area3D
## Timed arena power-up: Quad (x4 dmg), Haste (x2 speed), Invis. 30s respawn.

enum Kind { QUAD, HASTE, INVIS }

@export var kind: Kind = Kind.QUAD
@export var respawn_seconds: float = 30.0
@export var effect_seconds: float = 15.0
@export var relocate_on_respawn: bool = false
@export var randomize_kind_on_respawn: bool = false

var _available := true
var _mesh: MeshInstance3D
var _light: OmniLight3D
var _col: CollisionShape3D
var _timer: Timer
var _spin := 0.0


func configure(p_kind: Kind, p_respawn: float = 30.0, p_effect: float = 15.0) -> void:
	kind = p_kind
	respawn_seconds = p_respawn
	effect_seconds = p_effect


func _ready() -> void:
	collision_layer = 16
	collision_mask = 2 | 4
	monitoring = true
	monitorable = true
	if not body_entered.is_connected(_on_body):
		body_entered.connect(_on_body)
	_ensure_visuals()
	_style()
	_timer = Timer.new()
	_timer.name = "RespawnTimer"
	_timer.one_shot = true
	_timer.timeout.connect(_on_respawn)
	add_child(_timer)


func _ensure_visuals() -> void:
	if _col == null:
		_col = CollisionShape3D.new()
		_col.name = "CollisionShape3D"
		var sphere := SphereShape3D.new()
		sphere.radius = 0.6
		_col.shape = sphere
		add_child(_col)
	if _mesh == null:
		_mesh = MeshInstance3D.new()
		_mesh.name = "Mesh"
		add_child(_mesh)
	if _light == null:
		_light = OmniLight3D.new()
		_light.name = "Glow"
		_light.omni_range = 6.5
		add_child(_light)


func _style() -> void:
	var col := _color()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 3.2
	if kind == Kind.INVIS:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = 0.45
	match kind:
		Kind.HASTE:
			var prism := PrismMesh.new()
			prism.size = Vector3(0.7, 0.9, 0.7)
			_mesh.mesh = prism
		Kind.INVIS:
			var sm := SphereMesh.new()
			sm.radius = 0.42
			sm.height = 0.84
			_mesh.mesh = sm
		_:
			var box := BoxMesh.new()
			box.size = Vector3(0.62, 0.62, 0.62)
			_mesh.mesh = box
	_mesh.material_override = mat
	_light.light_color = col
	_light.light_energy = 2.2


func _color() -> Color:
	match kind:
		Kind.HASTE:
			return Color(1.0, 0.88, 0.12)
		Kind.INVIS:
			return Color(0.55, 0.9, 1.0)
		_:
			return Color(1.0, 0.18, 0.08)


func _process(delta: float) -> void:
	if not _available or _mesh == null:
		return
	_spin += delta
	_mesh.rotation.y = _spin * 2.1
	_mesh.position.y = 0.15 + sin(_spin * 3.2) * 0.1


func _on_body(body: Node3D) -> void:
	if not _available or body == null:
		return
	if not body.has_method("apply_power_up"):
		return
	if not body.apply_power_up(int(kind), effect_seconds):
		return
	_consume()


func _consume() -> void:
	_available = false
	_set_shown(false)
	var fx := get_node_or_null("/root/AudioFx")
	if fx != null and fx.has_method("play_at"):
		fx.play_at("pickup", global_position)
	_timer.start(maxf(respawn_seconds, 0.05))


func _on_respawn() -> void:
	if randomize_kind_on_respawn:
		kind = (randi() % 3) as Kind
		_style()
	if relocate_on_respawn:
		_relocate()
	_available = true
	_set_shown(true)


func _relocate() -> void:
	if not is_inside_tree():
		return
	var spots := get_tree().get_nodes_in_group("nav_points")
	if spots.is_empty():
		return
	var marker := spots[randi() % spots.size()] as Node3D
	if marker:
		global_position = marker.global_position + Vector3(0.0, 0.25, 0.0)


func _set_shown(on: bool) -> void:
	if _mesh:
		_mesh.visible = on
	if _light:
		_light.visible = on
	if _col:
		_col.disabled = not on
	monitoring = on
