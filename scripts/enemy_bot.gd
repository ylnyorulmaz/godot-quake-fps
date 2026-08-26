class_name EnemyBot
extends CharacterBody3D
## Arena combat bot: NavigationAgent3D chase, LOS strafe, paced hitscan.
##
## Tree:
##   EnemyBot (this)
##     CollisionShape3D (capsule)
##     NavigationAgent3D
##     RayCast3D
##     ShootTimer
##     HealthComponent
##     BodyMesh / HeadMesh (hidden when a Tripo GLB is present)
##     VisualModel (optional imported mesh)

signal died(killer: Node)

@export_category("Identity")
@export var bot_name: String = "Bot"
@export var color: Color = Color(0.75, 0.18, 0.15)

@export_category("Visual")
## Drag a PackedScene here, or leave empty and drop `orc.glb` in assets/models/.
@export var model_scene: PackedScene
@export var model_path: String = "res://assets/models/orc.glb"
@export var target_height: float = 1.8
## Godot characters face -Z. Tripo/Blender meshes often face +Z.
@export var model_yaw_degrees: float = 180.0

@export_category("Movement")
@export var movement_speed: float = 8.0
@export var acceleration: float = 14.0
@export var gravity: float = 20.0
@export var strafe_speed: float = 7.0
@export var ideal_range: float = 12.0

@export_category("Combat")
@export var attack_cooldown: float = 0.45
@export var vision_range: float = 40.0
@export var accuracy_error: float = 0.45
@export var attack_damage: float = 9.0
@export var attack_knockback: float = 3.5
@export var attack_range: float = 80.0

@export_category("Navigation")
@export var player_path: NodePath
@export var avoidance_enabled: bool = true

const EYE_HEIGHT := 1.5
const CHEST_HEIGHT := 1.15
const DEFAULT_SNAP := 0.12

var health_comp: HealthComponent

var health: float:
	get:
		return health_comp.current_health if health_comp else 0.0
var armor: float:
	get:
		return health_comp.current_armor if health_comp else 0.0

var _agent: NavigationAgent3D
var _los: RayCast3D
var _shoot_timer: Timer
var _mesh: MeshInstance3D
var _visual: Node3D
var _player: Node3D
var _alive := true
var _has_los := false
var _strafe_sign := 1.0
var _strafe_swap := 0.0
var _last_attacker: Node = null
var _wander_target := Vector3.ZERO
var _path_refresh := 0.0


func _ready() -> void:
	add_to_group("bots")
	collision_layer = 4
	collision_mask = 1 | 2 | 8 | 16
	floor_stop_on_slope = false
	floor_max_angle = deg_to_rad(60.0)
	floor_snap_length = DEFAULT_SNAP
	motion_mode = MOTION_MODE_GROUNDED
	_ensure_tree()
	_cache_nodes()
	_attach_imported_visual()
	_configure_agent()
	_configure_los()
	_configure_timer()
	if health_comp and not health_comp.died.is_connected(_on_vitals_died):
		health_comp.died.connect(_on_vitals_died)
	GameState.register_bot(bot_name)
	_strafe_sign = -1.0 if randf() < 0.5 else 1.0


func _ensure_tree() -> void:
	if get_node_or_null("CollisionShape3D") == null:
		var cap := CapsuleShape3D.new()
		cap.radius = 0.38
		cap.height = 1.8
		var col := CollisionShape3D.new()
		col.name = "CollisionShape3D"
		col.shape = cap
		col.position.y = 0.9
		add_child(col)
	if get_node_or_null("NavigationAgent3D") == null:
		var agent := NavigationAgent3D.new()
		agent.name = "NavigationAgent3D"
		add_child(agent)
	if get_node_or_null("RayCast3D") == null:
		var ray := RayCast3D.new()
		ray.name = "RayCast3D"
		ray.position = Vector3(0.0, EYE_HEIGHT, 0.0)
		add_child(ray)
	if get_node_or_null("ShootTimer") == null:
		var timer := Timer.new()
		timer.name = "ShootTimer"
		add_child(timer)
	if get_node_or_null("HealthComponent") == null:
		var hc := HealthComponent.new()
		hc.name = "HealthComponent"
		add_child(hc)
	if get_node_or_null("BodyMesh") == null:
		_mesh = MeshInstance3D.new()
		_mesh.name = "BodyMesh"
		var body := CapsuleMesh.new()
		body.radius = 0.38
		body.height = 1.8
		_mesh.mesh = body
		_mesh.position.y = 0.9
		add_child(_mesh)
	if get_node_or_null("HeadMesh") == null:
		var head := MeshInstance3D.new()
		head.name = "HeadMesh"
		var sm := SphereMesh.new()
		sm.radius = 0.22
		sm.height = 0.44
		head.mesh = sm
		head.position = Vector3(0.0, 1.55, -0.05)
		add_child(head)


func _cache_nodes() -> void:
	_agent = $NavigationAgent3D
	_los = $RayCast3D
	_shoot_timer = $ShootTimer
	health_comp = $HealthComponent
	_mesh = get_node_or_null("BodyMesh") as MeshInstance3D
	_apply_color()


func _attach_imported_visual() -> void:
	if get_node_or_null("VisualModel") != null:
		_visual = get_node_or_null("VisualModel") as Node3D
		_hide_placeholder_meshes()
		return
	var packed := ImportedModel.load_packed(model_scene, model_path)
	if packed == null:
		return
	_visual = ImportedModel.instantiate_under(self, packed, target_height, model_yaw_degrees)
	if _visual == null:
		return
	_hide_placeholder_meshes()


func _hide_placeholder_meshes() -> void:
	for mesh_name in ["BodyMesh", "HeadMesh"]:
		var node := get_node_or_null(mesh_name) as Node3D
		if node:
			node.visible = false


func _apply_color() -> void:
	if _visual != null:
		return
	if _mesh:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		_mesh.material_override = mat
	var head := get_node_or_null("HeadMesh") as MeshInstance3D
	if head:
		var hmat := StandardMaterial3D.new()
		hmat.albedo_color = color.darkened(0.2)
		head.material_override = hmat


func _configure_agent() -> void:
	_agent.path_desired_distance = 0.8
	_agent.target_desired_distance = 1.6
	_agent.radius = 0.42
	_agent.height = 1.8
	_agent.max_speed = movement_speed
	_agent.avoidance_enabled = avoidance_enabled
	_agent.avoidance_layers = 1
	_agent.avoidance_mask = 1
	_agent.neighbor_distance = 6.0
	if not _agent.velocity_computed.is_connected(_on_velocity_computed):
		_agent.velocity_computed.connect(_on_velocity_computed)


func _configure_los() -> void:
	_los.enabled = true
	_los.collide_with_bodies = true
	_los.collide_with_areas = false
	# World + player only: other bots must not count as "seeing the player".
	_los.collision_mask = 1 | 2
	_los.exclude_parent = true
	_los.target_position = Vector3(0.0, 0.0, -1.0)


func _configure_timer() -> void:
	_shoot_timer.one_shot = false
	_shoot_timer.wait_time = maxf(attack_cooldown, 0.05)
	_shoot_timer.autostart = false
	if not _shoot_timer.timeout.is_connected(_on_shoot_timer):
		_shoot_timer.timeout.connect(_on_shoot_timer)
	_shoot_timer.start()


func _physics_process(delta: float) -> void:
	if not _alive or GameState.paused or not GameState.match_running:
		return
	_strafe_swap -= delta
	if _strafe_swap <= 0.0:
		_strafe_sign *= -1.0
		_strafe_swap = randf_range(0.55, 1.25)

	var player := _resolve_player()
	_update_los(player)
	_update_nav_target(player, delta)

	var desired := _desired_horizontal(player)
	_look_toward(desired, player, delta)

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	if _agent.avoidance_enabled:
		_agent.set_velocity(desired)
	else:
		_apply_horizontal(desired, delta)
		move_and_slide()


func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if not _alive:
		return
	_apply_horizontal(safe_velocity, get_physics_process_delta_time())
	move_and_slide()


func _apply_horizontal(desired: Vector3, delta: float) -> void:
	var dt := delta if delta > 0.0 else 0.016
	velocity.x = move_toward(velocity.x, desired.x, acceleration * dt)
	velocity.z = move_toward(velocity.z, desired.z, acceleration * dt)


func _desired_horizontal(player: Node3D) -> Vector3:
	# Aggro: break off the path and strafe while shooting.
	if _has_los and player != null:
		return _strafe_velocity(player)
	return _path_velocity()


func _path_velocity() -> Vector3:
	if _agent.is_navigation_finished():
		return Vector3.ZERO
	var next := _agent.get_next_path_position()
	var offset := next - global_position
	offset.y = 0.0
	if offset.length_squared() < 0.04:
		return Vector3.ZERO
	return offset.normalized() * movement_speed


func _strafe_velocity(player: Node3D) -> Vector3:
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	if dist < 0.001:
		return Vector3.ZERO
	var forward := to_player / dist
	var side := Vector3.UP.cross(forward)
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT
	else:
		side = side.normalized()
	var wish := side * _strafe_sign * strafe_speed
	if dist > ideal_range + 2.5:
		wish += forward * movement_speed * 0.55
	elif dist < ideal_range - 3.0:
		wish -= forward * movement_speed * 0.45
	wish.y = 0.0
	if wish.length() > movement_speed:
		wish = wish.normalized() * movement_speed
	return wish


func _update_nav_target(player: Node3D, delta: float) -> void:
	_path_refresh -= delta
	var dest := Vector3.ZERO
	if player != null:
		dest = player.global_position
	else:
		dest = _wander_point()
	# Keep the agent informed even while strafing so chase resumes instantly.
	if _path_refresh <= 0.0 or global_position.distance_to(dest) < 0.5:
		_agent.set_target_position(dest)
		_path_refresh = 0.15


func _wander_point() -> Vector3:
	if _wander_target == Vector3.ZERO or global_position.distance_to(_wander_target) < 2.0:
		var spots := get_tree().get_nodes_in_group("nav_points")
		if spots.is_empty():
			_wander_target = global_position + Vector3(randf_range(-12.0, 12.0), 0.0, randf_range(-12.0, 12.0))
		else:
			_wander_target = (spots[randi() % spots.size()] as Node3D).global_position
	return _wander_target


func _update_los(player: Node3D) -> void:
	_has_los = false
	if player == null or _los == null:
		return
	if global_position.distance_to(player.global_position) > vision_range:
		return
	var aim := _chest_of(player)
	_los.target_position = _los.to_local(aim)
	_los.force_raycast_update()
	if not _los.is_colliding():
		# Clear shot through empty space still counts if the player is in range.
		_has_los = true
		return
	var hit := _los.get_collider()
	_has_los = _is_player_collider(hit, player)


func _is_player_collider(hit: Object, player: Node3D) -> bool:
	if hit == null or player == null:
		return false
	if hit == player:
		return true
	if hit is Node and player.is_ancestor_of(hit as Node):
		return true
	return false


func _resolve_player() -> Node3D:
	if _is_usable_player(_player):
		return _player
	_player = null
	if player_path != NodePath():
		var from_path := get_node_or_null(player_path)
		if _is_usable_player(from_path):
			_player = from_path as Node3D
			return _player
	if not is_inside_tree():
		return null
	var nodes := get_tree().get_nodes_in_group("player")
	for n in nodes:
		if _is_usable_player(n):
			_player = n as Node3D
			return _player
	return null


func _is_usable_player(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if not node.is_inside_tree():
		return false
	if node.has_method("is_alive") and not node.is_alive():
		return false
	return true


func _look_toward(desired: Vector3, player: Node3D, delta: float) -> void:
	var look := Vector3(desired.x, 0.0, desired.z)
	if _has_los and player != null:
		look = player.global_position - global_position
		look.y = 0.0
	if look.length_squared() < 0.01:
		return
	var yaw := atan2(-look.x, -look.z)
	rotation.y = lerp_angle(rotation.y, yaw, 10.0 * delta)


func _on_shoot_timer() -> void:
	if not _alive or GameState.paused or not GameState.match_running:
		return
	if absf(_shoot_timer.wait_time - attack_cooldown) > 0.001:
		_shoot_timer.wait_time = maxf(attack_cooldown, 0.05)
	if not _has_los:
		return
	var player := _resolve_player()
	if player == null:
		return
	_fire_hitscan(player)


func _fire_hitscan(player: Node3D) -> void:
	var from := global_position + Vector3(0.0, EYE_HEIGHT, 0.0)
	var aim := _chest_of(player)
	aim += Vector3(
			randf_range(-1.0, 1.0),
			randf_range(-0.35, 0.35),
			randf_range(-1.0, 1.0)
	) * accuracy_error
	var dir := aim - from
	if dir.length_squared() < 0.0001:
		return
	dir = dir.normalized()
	var to := from + dir * attack_range
	if not is_inside_tree():
		return
	var space := get_world_3d().direct_space_state
	if space == null:
		return
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1 | 2 | 4
	q.exclude = [get_rid()]
	q.collide_with_areas = false
	var hit := space.intersect_ray(q)
	var impact := to
	if hit:
		impact = hit.position
		var collider: Object = hit.collider
		if collider != null and collider.has_method("take_damage"):
			var kb := dir
			if hit.has("normal"):
				kb = -hit.normal
			collider.take_damage(attack_damage, kb, attack_knockback, self)
	_spawn_tracer(from, impact)
	AudioFx.play_at("mg", global_position)


func _chest_of(node: Node3D) -> Vector3:
	return node.global_position + Vector3(0.0, CHEST_HEIGHT, 0.0)


func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var fx := HitscanFx.new()
	var parent := get_tree().get_first_node_in_group("world_root")
	if parent == null:
		parent = get_parent()
	if parent == null:
		return
	parent.add_child(fx)
	fx.configure(from, to, Color(1.0, 0.45, 0.2), 0.03)


func take_damage(amount: float, dir: Vector3, knockback: float, attacker: Node = null) -> void:
	if not _alive:
		return
	_last_attacker = attacker
	if health_comp:
		health_comp.take_damage(amount)
	if dir.length_squared() > 0.0001:
		velocity += dir.normalized() * knockback
	_flash_hurt()


func apply_explosion_knockback(push_direction: Vector3, force: float) -> void:
	if not _alive or force <= 0.0:
		return
	var dir := push_direction
	if dir.length_squared() < 0.0001:
		dir = Vector3.UP
	else:
		dir = dir.normalized()
	var scaled := Vector3(dir.x, dir.y * 1.45, dir.z)
	if scaled.length_squared() > 0.0001:
		scaled = scaled.normalized()
	if scaled.y > 0.2 and velocity.y < 0.0:
		velocity.y *= 0.12
	velocity += scaled * force


func apply_pickup(kind: int) -> bool:
	if health_comp == null:
		return false
	match kind:
		Pickup.Kind.HEALTH:
			return health_comp.add_health(25.0, health_comp.max_health)
		Pickup.Kind.MEGA_HEALTH:
			return health_comp.apply_mega_health(100.0)
		Pickup.Kind.ARMOR:
			return health_comp.add_armor(50.0, health_comp.max_armor)
		_:
			return false


func launch(impulse: Vector3) -> void:
	if not _alive:
		return
	velocity = impulse


func _on_vitals_died() -> void:
	if _alive:
		_die(_last_attacker)


func _die(attacker: Node) -> void:
	_alive = false
	_has_los = false
	if _shoot_timer:
		_shoot_timer.stop()
	AudioFx.play_at("death", global_position)
	died.emit(attacker)
	visible = false
	collision_layer = 0


func respawn_at(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	_alive = true
	visible = true
	collision_layer = 4
	_has_los = false
	_wander_target = Vector3.ZERO
	if health_comp:
		health_comp.reset_to_spawn()
		if health_comp.current_armor <= 0.0:
			health_comp.add_armor(25.0, health_comp.max_armor)
	if _shoot_timer:
		_shoot_timer.start()
	if _mesh and _mesh.material_override is StandardMaterial3D:
		(_mesh.material_override as StandardMaterial3D).emission_energy_multiplier = 0.0


func is_alive() -> bool:
	return _alive


func _flash_hurt() -> void:
	if _visual != null:
		_flash_imported()
		return
	if _mesh == null or not (_mesh.material_override is StandardMaterial3D):
		return
	var mat := _mesh.material_override as StandardMaterial3D
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.2, 0.1)
	mat.emission_energy_multiplier = 2.0


func _flash_imported() -> void:
	if _visual == null:
		return
	var overlay := StandardMaterial3D.new()
	overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay.albedo_color = Color(1.0, 0.25, 0.12, 0.45)
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(_visual, meshes)
	for mesh in meshes:
		mesh.material_overlay = overlay
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	await tree.create_timer(0.12).timeout
	if not is_instance_valid(self):
		return
	for mesh in meshes:
		if is_instance_valid(mesh) and mesh.material_overlay == overlay:
			mesh.material_overlay = null


func _collect_meshes(root: Node, out: Array[MeshInstance3D]) -> void:
	if root == null:
		return
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node is MeshInstance3D:
			out.append(node)
