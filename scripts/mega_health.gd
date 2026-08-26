class_name MegaHealth
extends Area3D
## +100 health pickup, clamped to the mega limit, respawns after 30 seconds.

@export var heal_amount: float = 100.0
@export var respawn_seconds: float = 30.0

@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _timer: Timer = $Timer

var _available := true


func _ready() -> void:
	collision_layer = 16
	collision_mask = 2 | 4
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_timer.one_shot = true
	_timer.timeout.connect(_on_respawn)
	_style_visual()


func _style_visual() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.45, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.55, 1.0)
	mat.emission_energy_multiplier = 2.6
	_mesh.material_override = mat
	if get_node_or_null("CrossH") != null:
		return
	var bar_mat := mat.duplicate() as StandardMaterial3D
	var h := MeshInstance3D.new()
	h.name = "CrossH"
	var box_h := BoxMesh.new()
	box_h.size = Vector3(1.15, 0.22, 0.22)
	h.mesh = box_h
	h.material_override = bar_mat
	add_child(h)
	var v := MeshInstance3D.new()
	v.name = "CrossV"
	var box_v := BoxMesh.new()
	box_v.size = Vector3(0.22, 1.15, 0.22)
	v.mesh = box_v
	v.material_override = bar_mat
	add_child(v)


func _on_body_entered(body: Node3D) -> void:
	_try_pickup(body)


func _on_area_entered(area: Area3D) -> void:
	_try_pickup(area.get_parent())


func _try_pickup(node: Node) -> void:
	if not _available or node == null:
		return
	var vitals := _find_health(node)
	if vitals:
		if not vitals.can_pickup_mega_health():
			return
		if not vitals.apply_mega_health(heal_amount):
			return
		_consume()
		return
	_try_legacy_pickup(node)


func _try_legacy_pickup(node: Node) -> void:
	if node.has_method("apply_pickup") and node.apply_pickup(Pickup.Kind.MEGA_HEALTH):
		_consume()


func _consume() -> void:
	_available = false
	_set_visuals(false)
	_collision.disabled = true
	monitoring = false
	_timer.start(respawn_seconds)


func _on_respawn() -> void:
	_available = true
	_set_visuals(true)
	_collision.disabled = false
	monitoring = true


func _set_visuals(on: bool) -> void:
	_mesh.visible = on
	for n in ["CrossH", "CrossV"]:
		var node := get_node_or_null(n)
		if node:
			node.visible = on


func _find_health(node: Node) -> HealthComponent:
	if node is HealthComponent:
		return node as HealthComponent
	var direct := node.get_node_or_null("HealthComponent")
	if direct is HealthComponent:
		return direct
	var parent := node.get_parent()
	if parent != null:
		var from_parent := parent.get_node_or_null("HealthComponent")
		if from_parent is HealthComponent:
			return from_parent
	return null
