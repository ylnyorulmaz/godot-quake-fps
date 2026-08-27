class_name NeutralCreature
extends CharacterBody3D
## Neutral melee critter: hunts the nearest player or enemy in range.
## Physics layer 32 so health/armor/power-up Areas (mask 2|4) ignore it.

signal died(killer: Node)

const LAYER := 32
const DEFAULT_HP := 100.0

@export var activation_radius: float = 22.0
@export var melee_range: float = 1.85
@export var melee_damage: float = 12.0
@export var melee_cooldown: float = 0.7
@export var move_speed: float = 5.5
@export var gravity: float = 20.0

## Current chase victim: a Player or an Enemy (bot).
var attack_target: Node3D = null

var health_comp: HealthComponent
var _mesh: MeshInstance3D
var _alive := true
var _swing := 0.0
var _retarget := 0.0


func _ready() -> void:
	add_to_group("neutrals")
	collision_layer = LAYER
	# World + player + enemy + projectiles. Not pickups (16).
	collision_mask = 1 | 2 | 4 | 8
	floor_stop_on_slope = false
	motion_mode = MOTION_MODE_GROUNDED
	_ensure_tree()
	if health_comp and not health_comp.died.is_connected(_on_vitals_died):
		health_comp.died.connect(_on_vitals_died)


func _ensure_tree() -> void:
	if get_node_or_null("CollisionShape3D") == null:
		var cap := CapsuleShape3D.new()
		cap.radius = 0.4
		cap.height = 1.2
		var col := CollisionShape3D.new()
		col.name = "CollisionShape3D"
		col.shape = cap
		col.position.y = 0.6
		add_child(col)
	if get_node_or_null("BodyMesh") == null:
		_mesh = MeshInstance3D.new()
		_mesh.name = "BodyMesh"
		var mesh := CapsuleMesh.new()
		mesh.radius = 0.4
		mesh.height = 1.2
		_mesh.mesh = mesh
		_mesh.position.y = 0.6
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.45, 0.7, 0.28)
		mat.emission_enabled = true
		mat.emission = Color(0.2, 0.45, 0.12)
		mat.emission_energy_multiplier = 0.6
		_mesh.material_override = mat
		add_child(_mesh)
	else:
		_mesh = get_node_or_null("BodyMesh") as MeshInstance3D
	if get_node_or_null("HealthComponent") == null:
		health_comp = HealthComponent.new()
		health_comp.name = "HealthComponent"
		health_comp.max_health = DEFAULT_HP
		health_comp.current_health = DEFAULT_HP
		add_child(health_comp)
	else:
		health_comp = $HealthComponent
		health_comp.max_health = DEFAULT_HP
		health_comp.current_health = DEFAULT_HP


func _physics_process(delta: float) -> void:
	if not _alive or not _match_active():
		return
	_swing = maxf(_swing - delta, 0.0)
	_retarget -= delta
	if _retarget <= 0.0 or not _is_usable(attack_target):
		attack_target = _nearest_entity()
		_retarget = 0.25
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
	if attack_target == null:
		velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
		move_and_slide()
		return
	var to := attack_target.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	if dist > 0.05:
		var wish := to / dist * move_speed
		velocity.x = wish.x
		velocity.z = wish.z
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 8.0 * delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()
	if dist <= melee_range:
		_try_melee()


func _nearest_entity() -> Node3D:
	if not is_inside_tree():
		return null
	var best: Node3D = null
	var best_d := activation_radius
	for node in _candidates():
		if not _is_usable(node):
			continue
		var d := global_position.distance_to(node.global_position)
		if d <= best_d:
			best = node
			best_d = d
	return best


func _candidates() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n in get_tree().get_nodes_in_group("player"):
		if n is Node3D:
			out.append(n as Node3D)
	for n in get_tree().get_nodes_in_group("bots"):
		if n is Node3D:
			out.append(n as Node3D)
	return out


func _is_usable(node: Node) -> bool:
	if node == null or node == self or not is_instance_valid(node):
		return false
	if not node.is_inside_tree():
		return false
	if node.has_method("is_alive") and not node.is_alive():
		return false
	return true


func _try_melee() -> void:
	if _swing > 0.0 or not _is_usable(attack_target):
		return
	_swing = melee_cooldown
	var dir := attack_target.global_position - global_position
	if dir.length_squared() < 0.0001:
		dir = Vector3.FORWARD
	else:
		dir = dir.normalized()
	if attack_target.has_method("take_damage"):
		attack_target.take_damage(melee_damage, dir, 2.5, self)


func take_damage(amount: float, dir: Vector3, knockback: float, attacker: Node = null) -> void:
	if not _alive:
		return
	if health_comp:
		health_comp.take_damage(amount)
	if dir.length_squared() > 0.0001:
		velocity += dir.normalized() * knockback
	if health_comp and health_comp.current_health <= 0.0:
		_die(attacker)


func _on_vitals_died() -> void:
	if _alive:
		_die(null)


func _die(_killer: Node) -> void:
	_alive = false
	attack_target = null
	died.emit(_killer)
	visible = false
	collision_layer = 0
	queue_free()


func is_alive() -> bool:
	return _alive


func _match_active() -> bool:
	var gs := get_node_or_null("/root/GameState")
	if gs == null:
		return true
	return not bool(gs.get("paused")) and bool(gs.get("match_running"))
