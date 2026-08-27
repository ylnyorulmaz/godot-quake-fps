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

const PowerUpHold := preload("res://scripts/power_up_state.gd")

signal died(killer: Node)

@export_category("Identity")
@export var bot_name: String = "Bot"
@export var color: Color = Color(0.75, 0.18, 0.15)

@export_category("Visual")
## Drag a PackedScene here, or leave empty and drop `warrior.glb` in assets/.
@export var model_scene: PackedScene
@export var model_path: String = "res://assets/warrior.glb"
@export var target_height: float = 1.8
## Godot characters face -Z. Tripo/Blender meshes often face +Z.
@export var model_yaw_degrees: float = 180.0

@export_category("Movement")
@export var movement_speed: float = 8.0
@export var acceleration: float = 14.0
@export var gravity: float = 20.0
@export var strafe_speed: float = 7.0
@export var ideal_range: float = 12.0

@export_category("Personality")
## 0 Aggressive, 1 Defensive, 2 Sniper, 3 Normal, 4 Crazy
@export_enum("Agresif", "Savunmacı", "Sniper", "Normal", "Crazy") var personality: int = 3

@export_category("Combat")
@export var attack_cooldown: float = 0.6
@export var vision_range: float = 32.0
## Aim cone half-angle in degrees. 0.45 m world jitter used to sniper every shot.
@export var accuracy_error: float = 11.0
@export var attack_damage: float = 7.0
@export var attack_knockback: float = 3.5
@export var attack_range: float = 80.0

@export_category("Navigation")
@export var player_path: NodePath
@export var avoidance_enabled: bool = true

const EYE_HEIGHT := 1.5
const CHEST_HEIGHT := 1.15
const DEFAULT_SNAP := 0.12

const PERSONALITY_AGGRESSIVE := 0
const PERSONALITY_DEFENSIVE := 1
const PERSONALITY_SNIPER := 2
const PERSONALITY_NORMAL := 3
const PERSONALITY_CRAZY := 4

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
var _has_anim := false
var _visual_base_y := 0.0
var _bob_t := 0.0
var _player: Node3D
var _target: Node3D
var _alive := true
var _has_los := false
var _strafe_sign := 1.0
var _strafe_swap := 0.0
var _last_attacker: Node = null
var _wander_target := Vector3.ZERO
var _path_refresh := 0.0
var _retarget := 0.0
var _visual_base_rot := Vector3.ZERO
var _base_health := 100.0
var _base_damage := 7.0
var _scaled_damage := 7.0
var _crazy_swap := 0.0
var _crazy_mode := 0
var _crazy_dir := Vector3.FORWARD
var _power
var _power_overlay: StandardMaterial3D


func _ready() -> void:
	add_to_group("bots")
	collision_layer = 4
	collision_mask = 1 | 2 | 8 | 16 | 32
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
	_capture_base_stats()
	_apply_difficulty()
	if get_node_or_null("PowerUpState") == null:
		_power = PowerUpHold.new()
		_power.name = "PowerUpState"
		add_child(_power)
	else:
		_power = get_node_or_null("PowerUpState") as Node
	var gs := get_node_or_null("/root/GameState")
	if gs != null and gs.has_method("register_bot"):
		gs.register_bot(bot_name)
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
		_setup_locomotion_visual()
		return
	var packed := ImportedModel.load_packed(model_scene, model_path)
	if packed == null:
		return
	_visual = ImportedModel.instantiate_under(self, packed, target_height, model_yaw_degrees)
	if _visual == null:
		return
	_hide_placeholder_meshes()
	_setup_locomotion_visual()


func _hide_placeholder_meshes() -> void:
	for mesh_name in ["BodyMesh", "HeadMesh"]:
		var node := get_node_or_null(mesh_name) as Node3D
		if node:
			node.visible = false


func _setup_locomotion_visual() -> void:
	if _visual == null:
		return
	_visual_base_y = _visual.position.y
	_visual_base_rot = _visual.rotation
	_bob_t = 0.0
	var existing := get_node_or_null("LocomotionAnim")
	if existing:
		existing.queue_free()
	var loco := LocomotionAnim.new()
	loco.name = "LocomotionAnim"
	loco.walk_speed = 4.0
	loco.run_speed = movement_speed
	add_child(loco)
	if loco.bind(self, _visual):
		_has_anim = true
		return
	loco.queue_free()
	_has_anim = ImportedModel.play_idle(_visual)


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
	# World + player + other bots.
	_los.collision_mask = 1 | 2 | 4 | 32
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
	if not _alive or not _match_active():
		return
	_strafe_swap -= delta
	if _strafe_swap <= 0.0:
		_strafe_sign *= -1.0
		_strafe_swap = randf_range(0.55, 1.25)
	_tick_crazy(delta)
	if _power:
		_power.tick(delta)
		_refresh_power_visual()
		_agent.max_speed = _run_speed()

	var player := _resolve_player()
	_retarget -= delta
	if _retarget <= 0.0:
		_pick_target(player)
		_retarget = randf_range(0.4, 0.9)
	if not _is_usable_foe(_target):
		_target = null
	_update_los(_target)
	_update_nav_target(_target, delta)

	var desired := _movement_for_personality(_target)
	_look_toward(desired, _target, delta)

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	if _agent.avoidance_enabled:
		_agent.set_velocity(desired)
	else:
		_apply_horizontal(desired, delta)
		move_and_slide()
		_update_walk_bob(delta)


func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if not _alive:
		return
	_apply_horizontal(safe_velocity, get_physics_process_delta_time())
	move_and_slide()
	_update_walk_bob(get_physics_process_delta_time())


func _apply_horizontal(desired: Vector3, delta: float) -> void:
	var dt := delta if delta > 0.0 else 0.016
	velocity.x = move_toward(velocity.x, desired.x, acceleration * dt)
	velocity.z = move_toward(velocity.z, desired.z, acceleration * dt)


func _update_walk_bob(delta: float) -> void:
	if _visual == null or _has_anim or not _alive:
		return
	var dt := delta if delta > 0.0 else 0.016
	var spd := Vector2(velocity.x, velocity.z).length()
	if spd > 0.4:
		_bob_t += dt * (9.0 + spd * 0.85)
		var step := sin(_bob_t)
		var plant := absf(step)
		_visual.position.y = _visual_base_y + plant * 0.16
		_visual.rotation.x = _visual_base_rot.x - plant * 0.07
		_visual.rotation.z = _visual_base_rot.z + step * 0.2
	else:
		_bob_t = 0.0
		_visual.position.y = lerpf(_visual.position.y, _visual_base_y, 1.0 - exp(-12.0 * dt))
		_visual.rotation.x = lerp_angle(_visual.rotation.x, _visual_base_rot.x, 1.0 - exp(-10.0 * dt))
		_visual.rotation.z = lerp_angle(_visual.rotation.z, _visual_base_rot.z, 1.0 - exp(-10.0 * dt))


func _movement_for_personality(target: Node3D) -> Vector3:
	match personality:
		PERSONALITY_AGGRESSIVE:
			return _move_aggressive(target)
		PERSONALITY_DEFENSIVE:
			return _move_defensive(target)
		PERSONALITY_SNIPER:
			return _move_sniper(target)
		PERSONALITY_CRAZY:
			return _move_crazy(target)
		_:
			return _move_normal(target)


func _move_aggressive(target: Node3D) -> Vector3:
	if target == null:
		return _path_velocity()
	var to_target := target.global_position - global_position
	to_target.y = 0.0
	if to_target.length_squared() < 0.04:
		return Vector3.ZERO
	return to_target.normalized() * _run_speed()


func _move_defensive(target: Node3D) -> Vector3:
	if target == null:
		return _path_velocity()
	var away := global_position - target.global_position
	away.y = 0.0
	if away.length_squared() < 0.0001:
		away = Vector3.RIGHT
	return away.normalized() * _run_speed()


func _move_sniper(_target: Node3D) -> Vector3:
	return Vector3.ZERO


func _move_normal(target: Node3D) -> Vector3:
	return _desired_horizontal(target)


func _move_crazy(target: Node3D) -> Vector3:
	match _crazy_mode:
		0:
			return _move_aggressive(target)
		1:
			if target != null:
				return _strafe_velocity(target)
			return _path_velocity()
		_:
			var wish := _crazy_dir * _run_speed()
			wish.y = 0.0
			return wish


func _tick_crazy(delta: float) -> void:
	if personality != PERSONALITY_CRAZY:
		return
	_crazy_swap -= delta
	if _crazy_swap > 0.0:
		return
	_crazy_mode = randi() % 3
	var angle := randf() * TAU
	_crazy_dir = Vector3(cos(angle), 0.0, sin(angle))
	_crazy_swap = randf_range(0.25, 0.7)


func _desired_horizontal(target: Node3D) -> Vector3:
	# Aggro: break off the path and strafe while shooting.
	if _has_los and target != null:
		return _strafe_velocity(target)
	return _path_velocity()


func _path_velocity() -> Vector3:
	if _agent.is_navigation_finished():
		return Vector3.ZERO
	var next := _agent.get_next_path_position()
	var offset := next - global_position
	offset.y = 0.0
	if offset.length_squared() < 0.04:
		return Vector3.ZERO
	return offset.normalized() * _run_speed()


func _strafe_velocity(target: Node3D) -> Vector3:
	var to_target := target.global_position - global_position
	to_target.y = 0.0
	var dist := to_target.length()
	if dist < 0.001:
		return Vector3.ZERO
	var forward := to_target / dist
	var side := Vector3.UP.cross(forward)
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT
	else:
		side = side.normalized()
	var wish := side * _strafe_sign * strafe_speed
	if dist > ideal_range + 2.5:
		wish += forward * _run_speed() * 0.55
	elif dist < ideal_range - 3.0:
		wish -= forward * _run_speed() * 0.45
	wish.y = 0.0
	if wish.length() > _run_speed():
		wish = wish.normalized() * _run_speed()
	return wish


func _update_nav_target(target: Node3D, delta: float) -> void:
	_path_refresh -= delta
	var dest := Vector3.ZERO
	if personality == PERSONALITY_SNIPER:
		dest = global_position
	elif personality == PERSONALITY_DEFENSIVE and target != null:
		dest = _flee_point(target)
	elif target != null:
		dest = target.global_position
	else:
		dest = _wander_point()
	# Keep the agent informed even while strafing so chase resumes instantly.
	if _path_refresh <= 0.0 or global_position.distance_to(dest) < 0.5:
		_agent.set_target_position(dest)
		_path_refresh = 0.15


func _flee_point(target: Node3D) -> Vector3:
	var away := global_position - target.global_position
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3(1.0, 0.0, 0.0)
	else:
		away = away.normalized()
	var fallback := global_position + away * 16.0
	if not is_inside_tree():
		return fallback
	var spots := get_tree().get_nodes_in_group("nav_points")
	if spots.is_empty():
		return fallback
	var best := fallback
	var best_d := -1.0
	for s in spots:
		var p: Vector3 = (s as Node3D).global_position
		var d := p.distance_squared_to(target.global_position)
		if d > best_d:
			best_d = d
			best = p
	return best


func _wander_point() -> Vector3:
	if _wander_target == Vector3.ZERO or global_position.distance_to(_wander_target) < 2.0:
		var spots := get_tree().get_nodes_in_group("nav_points")
		if spots.is_empty():
			_wander_target = global_position + Vector3(randf_range(-12.0, 12.0), 0.0, randf_range(-12.0, 12.0))
		else:
			_wander_target = (spots[randi() % spots.size()] as Node3D).global_position
	return _wander_target


func _update_los(target: Node3D) -> void:
	_has_los = _has_line_to(target)


func _has_line_to(target: Node3D) -> bool:
	if target == null or _los == null:
		return false
	if global_position.distance_to(target.global_position) > vision_range:
		return false
	if target.has_method("is_stealthed") and bool(target.call("is_stealthed")):
		if global_position.distance_to(target.global_position) > 3.5:
			return false
	var aim := _chest_of(target)
	_los.target_position = _los.to_local(aim)
	_los.force_raycast_update()
	if not _los.is_colliding():
		return true
	return _is_target_collider(_los.get_collider(), target)


func _is_target_collider(hit: Object, target: Node3D) -> bool:
	if hit == null or target == null:
		return false
	if hit == target:
		return true
	if hit is Node and target.is_ancestor_of(hit as Node):
		return true
	return false


func _pick_target(player: Node3D) -> void:
	if _is_usable_foe(_target) and _has_line_to(_target) and randf() < 0.6:
		return
	if _is_usable_foe(_last_attacker) and _has_line_to(_last_attacker as Node3D):
		_target = _last_attacker as Node3D
		return
	var best: Node3D = null
	var best_d := INF
	for foe in _collect_foes(player):
		var d := global_position.distance_squared_to(foe.global_position)
		if d > vision_range * vision_range:
			continue
		if not _has_line_to(foe):
			continue
		if d < best_d:
			best = foe
			best_d = d
	_target = best


func _collect_foes(player: Node3D) -> Array[Node3D]:
	var out: Array[Node3D] = []
	if _is_usable_foe(player):
		out.append(player)
	if not is_inside_tree():
		return out
	for n in get_tree().get_nodes_in_group("bots"):
		if _is_usable_foe(n):
			out.append(n as Node3D)
	for n in get_tree().get_nodes_in_group("neutrals"):
		if _is_usable_foe(n):
			out.append(n as Node3D)
	return out


func _is_usable_foe(node: Node) -> bool:
	if node == null or node == self or not is_instance_valid(node):
		return false
	if not node.is_inside_tree():
		return false
	if node.has_method("is_alive") and not node.is_alive():
		return false
	return true


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


func _look_toward(desired: Vector3, target: Node3D, delta: float) -> void:
	var look := Vector3(desired.x, 0.0, desired.z)
	if _has_los and target != null:
		look = target.global_position - global_position
		look.y = 0.0
	if look.length_squared() < 0.01:
		return
	var yaw := atan2(-look.x, -look.z)
	rotation.y = lerp_angle(rotation.y, yaw, 10.0 * delta)


func _on_shoot_timer() -> void:
	if not _alive or not _match_active():
		return
	if absf(_shoot_timer.wait_time - attack_cooldown) > 0.001:
		_shoot_timer.wait_time = maxf(attack_cooldown, 0.05)
	if not _has_los:
		return
	if not _is_usable_foe(_target):
		return
	_fire_hitscan(_target)


func _fire_hitscan(target: Node3D) -> void:
	var from := global_position + Vector3(0.0, EYE_HEIGHT, 0.0)
	var aim := _chest_of(target)
	var cone := deg_to_rad(accuracy_error)
	cone += Vector2(velocity.x, velocity.z).length() * 0.012
	var dir := spread_direction(from, aim, cone, randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	var to := from + dir * attack_range
	if not is_inside_tree():
		return
	var space := get_world_3d().direct_space_state
	if space == null:
		return
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1 | 2 | 4 | 32
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
			collider.take_damage(scaled_attack_damage(), kb, attack_knockback, self)
	_spawn_tracer(from, impact)
	_play_fx("mg", global_position)


func _chest_of(node: Node3D) -> Vector3:
	return node.global_position + Vector3(0.0, CHEST_HEIGHT, 0.0)


static func spread_direction(from: Vector3, to: Vector3, spread_rad: float, u: float, v: float) -> Vector3:
	var dir := to - from
	if dir.length_squared() < 0.0001:
		return Vector3(0.0, 0.0, -1.0)
	dir = dir.normalized()
	var yaw_axis := Vector3.UP
	var pitch_axis := dir.cross(yaw_axis)
	if pitch_axis.length_squared() < 0.0001:
		pitch_axis = dir.cross(Vector3.RIGHT)
	pitch_axis = pitch_axis.normalized()
	dir = dir.rotated(pitch_axis, spread_rad * clampf(v, -1.0, 1.0))
	dir = dir.rotated(yaw_axis, spread_rad * clampf(u, -1.0, 1.0))
	return dir.normalized()


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
	_play_fx("hurt", global_position)


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
		0: # Pickup.Kind.HEALTH
			return health_comp.add_health(25.0, health_comp.max_health)
		1: # Pickup.Kind.MEGA_HEALTH
			return health_comp.apply_mega_health(100.0)
		2: # Pickup.Kind.ARMOR
			return health_comp.add_armor(50.0, health_comp.max_armor)
		_:
			return false


func apply_power_up(kind: int, seconds: float = -1.0) -> bool:
	if not _alive:
		return false
	if _power == null:
		_power = PowerUpHold.new()
		_power.name = "PowerUpState"
		add_child(_power)
	if not _power.apply(kind, seconds):
		return false
	_refresh_power_visual()
	if _agent:
		_agent.max_speed = _run_speed()
	return true


func _run_speed() -> float:
	return movement_speed * outgoing_speed_scale()


func outgoing_damage_scale() -> float:
	return _power.damage_scale() if _power else 1.0


func outgoing_speed_scale() -> float:
	return _power.speed_scale() if _power else 1.0


func is_stealthed() -> bool:
	return _power != null and _power.is_invisible()


func _refresh_power_visual() -> void:
	var tint := Color(1.0, 1.0, 1.0, 0.0)
	if _power:
		tint = _power.overlay_color()
	if _power_overlay == null:
		_power_overlay = StandardMaterial3D.new()
		_power_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_power_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_power_overlay.albedo_color = tint
	var overlay: Material = _power_overlay if tint.a > 0.02 else null
	if _mesh:
		_mesh.material_overlay = overlay
	if _visual:
		var meshes: Array[MeshInstance3D] = []
		_collect_meshes(_visual, meshes)
		for mesh in meshes:
			mesh.material_overlay = overlay


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
	if _power:
		_power.clear()
		_refresh_power_visual()
	if _shoot_timer:
		_shoot_timer.stop()
	_play_fx("death", global_position)
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
	if _power:
		_power.clear()
		_refresh_power_visual()
	_apply_difficulty()
	if health_comp:
		health_comp.reset_to_spawn()
		if health_comp.current_armor <= 0.0:
			health_comp.add_armor(25.0, health_comp.max_armor)
	if _shoot_timer:
		_shoot_timer.start()
	if _visual:
		_visual.position.y = _visual_base_y
		_visual.rotation = _visual_base_rot
		_bob_t = 0.0
	if _mesh and _mesh.material_override is StandardMaterial3D:
		(_mesh.material_override as StandardMaterial3D).emission_energy_multiplier = 0.0


func is_alive() -> bool:
	return _alive


func scaled_attack_damage() -> float:
	return _scaled_damage * outgoing_damage_scale()


func _capture_base_stats() -> void:
	if health_comp:
		_base_health = health_comp.max_health
	_base_damage = attack_damage


func _apply_difficulty() -> void:
	var mul := _difficulty_multiplier()
	if health_comp:
		health_comp.max_health = maxf(1.0, _base_health * mul)
		health_comp.current_health = health_comp.max_health
	_scaled_damage = _base_damage * mul


func _difficulty_multiplier() -> float:
	var gm := get_node_or_null("/root/GameManager")
	if gm == null:
		return 1.0
	var value = gm.get("difficulty_multiplier")
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		return 1.0
	return maxf(0.0, float(value))


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


func _match_active() -> bool:
	var gs := get_node_or_null("/root/GameState")
	if gs == null:
		return true
	return not bool(gs.get("paused")) and bool(gs.get("match_running"))


func _play_fx(kind: String, at: Vector3) -> void:
	var fx := get_node_or_null("/root/AudioFx")
	if fx != null and fx.has_method("play_at"):
		fx.play_at(kind, at)
