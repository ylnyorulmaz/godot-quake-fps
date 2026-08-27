class_name Player
extends CharacterBody3D

const PowerUpHold := preload("res://scripts/power_up_state.gd")

## Quake 3 style CharacterBody3D FPS controller.
##
## Tree:
##   Player (this)
##     CollisionShape3D (capsule)
##     HealthComponent
##     Head
##       Camera3D
##         WeaponManager
##           Shotgun / RocketLauncher / Muzzle / FireRay

signal died(killer: Node)
signal health_changed

@export_category("Look")
@export var MOUSE_SENSITIVITY := 0.0024
@export var MOUSE_SMOOTHING := 18.0
@export var PITCH_LIMIT_DEG := 89.0
@export var FOV := 100.0

@export_category("Dynamic FOV")
@export var base_fov: float = 100.0
@export var max_fov: float = 118.0
@export var fov_normal_speed: float = 10.0
@export var fov_max_speed: float = 35.0
@export var fov_change_speed: float = 8.0

@export_category("Movement")
@export var MOVE_SPEED := 10.0
@export var FRICTION := 6.0
@export var ACCELERATION := 10.0
@export var AIR_ACCEL := 1.0
@export var JUMP_FORCE := 8.6
@export var GRAVITY := 20.0
@export var TERMINAL_VELOCITY := 48.0
@export var SPRINT_MULTIPLIER := 1.3
@export var JUMP_BUFFER := 0.10
@export var AUTO_BHOP := true

@export_category("Body")
@export var STAND_HEIGHT := 1.8
@export var CROUCH_HEIGHT := 1.05
@export var EYE_HEIGHT := 1.55
@export var CROUCH_EYE_HEIGHT := 0.85

const MAX_HEALTH := 100.0
const MAX_OVERHEALTH := 200.0
const MAX_ARMOR := 100.0
## Quake-style units for HUD (10 m/s ground cap → 320 ups).
const UPS_SCALE := 32.0
const BLAST_VERTICAL_BIAS := 1.45
const BLAST_HORIZONTAL_SCALE := 1.05
const DEFAULT_FLOOR_SNAP := 0.12

var weapons: WeaponManager
var health_comp: HealthComponent

var health: float:
	get:
		return health_comp.current_health if health_comp else 0.0
var armor: float:
	get:
		return health_comp.current_armor if health_comp else 0.0

var _yaw := 0.0
var _pitch := 0.0
var _yaw_target := 0.0
var _pitch_target := 0.0
var _head: Node3D
var _cam: Camera3D
var _capsule: CollisionShape3D
var _shape: CapsuleShape3D
var _mesh: MeshInstance3D
var _hurt_flash := 0.0
var _alive := true
var _eye_height := 1.55
var _bob := 0.0
var _jump_buffer := 0.0
var _was_on_floor := false
var _launch_ignore_frames := 0
var _move := QuakeMoveParams.new()
var _last_attacker: Node = null
var _power
var _power_overlay: StandardMaterial3D
var _power_glow: OmniLight3D


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4 | 8 | 16 | 32
	floor_stop_on_slope = false
	floor_max_angle = deg_to_rad(60.0)
	floor_snap_length = DEFAULT_FLOOR_SNAP
	safe_margin = 0.08
	motion_mode = MOTION_MODE_GROUNDED
	_ensure_tree()
	_cache_nodes()
	_cam.fov = base_fov
	_eye_height = EYE_HEIGHT
	weapons.setup(self, true)
	_try_locomotion()
	if health_comp and not health_comp.died.is_connected(_on_vitals_died):
		health_comp.died.connect(_on_vitals_died)
	if health_comp and not health_comp.health_changed.is_connected(_on_vitals_health):
		health_comp.health_changed.connect(_on_vitals_health)


func _ensure_tree() -> void:
	if get_node_or_null("CollisionShape3D") == null:
		_shape = CapsuleShape3D.new()
		_shape.radius = 0.38
		_shape.height = STAND_HEIGHT
		_capsule = CollisionShape3D.new()
		_capsule.name = "CollisionShape3D"
		_capsule.shape = _shape
		_capsule.position.y = STAND_HEIGHT * 0.5
		add_child(_capsule)
	if get_node_or_null("BodyMesh") == null:
		_mesh = MeshInstance3D.new()
		_mesh.name = "BodyMesh"
		var cap := CapsuleMesh.new()
		cap.radius = 0.38
		cap.height = STAND_HEIGHT
		_mesh.mesh = cap
		_mesh.position.y = STAND_HEIGHT * 0.5
		_mesh.layers = 2
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.85, 0.55, 0.2)
		_mesh.material_override = mat
		add_child(_mesh)
	if get_node_or_null("Head") == null:
		_head = Node3D.new()
		_head.name = "Head"
		_head.position.y = EYE_HEIGHT
		add_child(_head)
		_cam = Camera3D.new()
		_cam.name = "Camera3D"
		_cam.fov = base_fov
		_cam.near = 0.05
		_cam.far = 250.0
		_head.add_child(_cam)
		weapons = WeaponManager.new()
		weapons.name = "WeaponManager"
		_cam.add_child(weapons)
	else:
		_head = $Head
		_cam = $Head/Camera3D
		weapons = $Head/Camera3D/WeaponManager as WeaponManager
		if weapons == null:
			weapons = WeaponManager.new()
			weapons.name = "WeaponManager"
			_cam.add_child(weapons)
	if get_node_or_null("HealthComponent") == null:
		health_comp = HealthComponent.new()
		health_comp.name = "HealthComponent"
		add_child(health_comp)
	if get_node_or_null("PowerUpState") == null:
		_power = PowerUpHold.new()
		_power.name = "PowerUpState"
		add_child(_power)
	if get_node_or_null("PowerGlow") == null:
		_power_glow = OmniLight3D.new()
		_power_glow.name = "PowerGlow"
		_power_glow.omni_range = 5.5
		_power_glow.light_energy = 0.0
		_power_glow.position.y = 1.1
		add_child(_power_glow)


func _cache_nodes() -> void:
	_capsule = $CollisionShape3D
	_shape = _capsule.shape as CapsuleShape3D
	_head = $Head
	_cam = $Head/Camera3D
	weapons = $Head/Camera3D/WeaponManager
	_mesh = get_node_or_null("BodyMesh") as MeshInstance3D
	health_comp = get_node_or_null("HealthComponent") as HealthComponent
	_power = get_node_or_null("PowerUpState") as Node
	_power_glow = get_node_or_null("PowerGlow") as OmniLight3D
	# Hide own capsule from the first-person camera.
	_cam.cull_mask = _cam.cull_mask & ~2


func _try_locomotion() -> void:
	var vis := get_node_or_null("VisualModel")
	if vis == null:
		return
	var loco := LocomotionAnim.new()
	loco.name = "LocomotionAnim"
	loco.walk_speed = MOVE_SPEED * 0.45
	loco.run_speed = MOVE_SPEED * SPRINT_MULTIPLIER
	add_child(loco)
	if not loco.bind(self, vis):
		loco.queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if not _alive or not GameState.match_running or GameState.paused:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := MOUSE_SENSITIVITY
		if GameState.mouse_sensitivity > 0.0:
			sens = GameState.mouse_sensitivity
		_yaw_target -= event.relative.x * sens
		_pitch_target -= event.relative.y * sens
		var lim := deg_to_rad(PITCH_LIMIT_DEG)
		_pitch_target = clampf(_pitch_target, -lim, lim)
	if event.is_action_pressed("weapon_1"):
		weapons.select(WeaponManager.Kind.MG)
	elif event.is_action_pressed("weapon_2"):
		weapons.select(WeaponManager.Kind.SHOTGUN)
	elif event.is_action_pressed("weapon_3"):
		weapons.select(WeaponManager.Kind.ROCKET)
	elif event.is_action_pressed("weapon_4"):
		weapons.select(WeaponManager.Kind.RAIL)
	elif event.is_action_pressed("next_weapon"):
		weapons.cycle(1)
	elif event.is_action_pressed("prev_weapon"):
		weapons.cycle(-1)


func _physics_process(delta: float) -> void:
	if not _alive or GameState.paused or not GameState.match_running:
		return
	_apply_look(delta)
	_sync_move_params()

	if Input.is_action_just_pressed("jump"):
		_jump_buffer = JUMP_BUFFER
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)

	var crouch := Input.is_action_pressed("crouch")
	_set_crouch(crouch)

	var wish := _wish_dir()
	var grounded := is_on_floor()
	var landing := grounded and not _was_on_floor
	var jumping := false
	if grounded and not crouch:
		var buffered := _jump_buffer > 0.0
		var held_bhop := AUTO_BHOP and Input.is_action_pressed("jump") and (landing or Input.is_action_just_pressed("jump"))
		if buffered or held_bhop:
			jumping = true
			_jump_buffer = 0.0
			AudioFx.play("jump")

	var sprinting := Input.is_action_pressed("sprint")
	var force_air := _launch_ignore_frames > 0
	if _launch_ignore_frames > 0:
		_launch_ignore_frames -= 1
		if _launch_ignore_frames <= 0:
			floor_snap_length = DEFAULT_FLOOR_SNAP
	QuakeMovement.move(self, wish, jumping, crouch, sprinting, delta, _move, force_air)
	_was_on_floor = is_on_floor() and not force_air

	_bob += Vector3(velocity.x, 0.0, velocity.z).length() * delta
	var bob_amt := 0.0 if not is_on_floor() else sin(_bob * 8.0) * 0.025
	_head.position.y = _eye_height + bob_amt

	if _wants_fire():
		weapons.try_fire()
	_hurt_flash = maxf(_hurt_flash - delta * 2.5, 0.0)
	_tick_power(delta)


func _process(delta: float) -> void:
	if not _alive or GameState.paused or not GameState.match_running:
		return
	_calculate_dynamic_fov(delta)


func _calculate_dynamic_fov(delta: float) -> void:
	if _cam == null:
		return
	var current_speed := horizontal_speed()
	var target_fov := base_fov
	if current_speed > fov_normal_speed:
		var speed_factor := remap(current_speed, fov_normal_speed, fov_max_speed, 0.0, 1.0)
		speed_factor = clampf(speed_factor, 0.0, 1.0)
		target_fov = lerpf(base_fov, max_fov, speed_factor)
	var t := 1.0 - exp(-fov_change_speed * delta)
	_cam.fov = lerpf(_cam.fov, target_fov, t)


func _apply_look(delta: float) -> void:
	var lim := deg_to_rad(PITCH_LIMIT_DEG)
	_pitch_target = clampf(_pitch_target, -lim, lim)
	if MOUSE_SMOOTHING <= 0.0:
		_yaw = _yaw_target
		_pitch = _pitch_target
	else:
		var t := 1.0 - exp(-MOUSE_SMOOTHING * delta)
		_yaw = lerp_angle(_yaw, _yaw_target, t)
		_pitch = lerpf(_pitch, _pitch_target, t)
	rotation.y = _yaw
	_head.rotation.x = _pitch


func _sync_move_params() -> void:
	_move.MOVE_SPEED = MOVE_SPEED * outgoing_speed_scale()
	_move.FRICTION = FRICTION
	_move.ACCELERATION = ACCELERATION
	_move.AIR_ACCEL = AIR_ACCEL
	_move.JUMP_FORCE = JUMP_FORCE
	_move.GRAVITY = GRAVITY
	_move.TERMINAL_VELOCITY = TERMINAL_VELOCITY
	_move.SPRINT_MULTIPLIER = SPRINT_MULTIPLIER


func _wish_dir() -> Vector3:
	var basis_y := Basis(Vector3.UP, _yaw)
	var wish := Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		wish -= basis_y.z
	if Input.is_action_pressed("move_back"):
		wish += basis_y.z
	if Input.is_action_pressed("move_left"):
		wish -= basis_y.x
	if Input.is_action_pressed("move_right"):
		wish += basis_y.x
	if wish.length_squared() > 1.0:
		wish = wish.normalized()
	return wish


func _wants_fire() -> bool:
	if Input.is_action_pressed("fire"):
		return true
	return InputMap.has_action("attack") and Input.is_action_pressed("attack")


func _set_crouch(crouch: bool) -> void:
	var h := CROUCH_HEIGHT if crouch else STAND_HEIGHT
	if _shape:
		_shape.height = h
	_capsule.position.y = h * 0.5
	_eye_height = CROUCH_EYE_HEIGHT if crouch else EYE_HEIGHT
	if _mesh and _mesh.mesh is CapsuleMesh:
		(_mesh.mesh as CapsuleMesh).height = h
		_mesh.position.y = h * 0.5


func take_damage(amount: float, dir: Vector3, knockback: float, attacker: Node = null) -> void:
	if not _alive:
		return
	_last_attacker = attacker
	if health_comp:
		health_comp.take_damage(amount)
	if dir.length_squared() > 0.0001:
		velocity += dir.normalized() * knockback
	_hurt_flash = 0.55
	AudioFx.play("hurt")


func launch(impulse: Vector3) -> void:
	## Jump-pad / scripted launch: replace velocity and skip ground friction.
	if not _alive:
		return
	velocity = impulse
	_launch_ignore_frames = 8
	floor_snap_length = 0.0
	_was_on_floor = false


func apply_explosion_knockback(push_direction: Vector3, force: float) -> void:
	if not _alive or force <= 0.0:
		return
	var dir := push_direction
	if dir.length_squared() < 0.0001:
		dir = Vector3.UP
	else:
		dir = dir.normalized()
	var scaled := Vector3(
			dir.x * BLAST_HORIZONTAL_SCALE,
			dir.y * BLAST_VERTICAL_BIAS,
			dir.z * BLAST_HORIZONTAL_SCALE
	)
	if scaled.length_squared() > 0.0001:
		scaled = scaled.normalized()
	# A blast under the feet should cancel downward momentum (rocket jump).
	if scaled.y > 0.2 and velocity.y < 0.0:
		velocity.y *= 0.12
	velocity += scaled * force


func apply_pickup(kind: int) -> bool:
	match kind:
		Pickup.Kind.HEALTH:
			if health_comp == null or not health_comp.add_health(25.0, health_comp.max_health):
				return false
		Pickup.Kind.MEGA_HEALTH:
			if health_comp == null or not health_comp.apply_mega_health(100.0):
				return false
		Pickup.Kind.ARMOR:
			if health_comp == null or not health_comp.add_armor(50.0, health_comp.max_armor):
				return false
		Pickup.Kind.MG_AMMO:
			weapons.add_ammo(WeaponManager.Kind.MG, 50)
		Pickup.Kind.SG_AMMO:
			weapons.add_ammo(WeaponManager.Kind.SHOTGUN, 10)
		Pickup.Kind.RL_AMMO:
			weapons.add_ammo(WeaponManager.Kind.ROCKET, 5)
		Pickup.Kind.RAIL_AMMO:
			weapons.add_ammo(WeaponManager.Kind.RAIL, 5)
		Pickup.Kind.SHOTGUN:
			weapons.give_weapon(WeaponManager.Kind.SHOTGUN, 10)
		Pickup.Kind.ROCKET:
			weapons.give_weapon(WeaponManager.Kind.ROCKET, 5)
		Pickup.Kind.RAIL:
			weapons.give_weapon(WeaponManager.Kind.RAIL, 5)
		_:
			return false
	health_changed.emit()
	return true


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
	return true


func _tick_power(delta: float) -> void:
	if _power == null:
		return
	var was_on := _power.is_active()
	_power.tick(delta)
	if was_on or _power.is_active():
		_refresh_power_visual()


func _refresh_power_visual() -> void:
	var tint := Color(1.0, 1.0, 1.0, 0.0)
	if _power:
		tint = _power.overlay_color()
	if _power_overlay == null:
		_power_overlay = StandardMaterial3D.new()
		_power_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_power_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_power_overlay.albedo_color = tint
	var on := tint.a > 0.02
	if _mesh:
		_mesh.material_overlay = _power_overlay if on else null
		if _mesh.material_override is StandardMaterial3D:
			var body := _mesh.material_override as StandardMaterial3D
			if _power and _power.is_invisible():
				body.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				body.albedo_color.a = 0.18
			else:
				body.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				body.albedo_color.a = 1.0
	if _power_glow:
		_power_glow.light_color = Color(tint.r, tint.g, tint.b)
		_power_glow.light_energy = 3.4 if on and _power and _power.has_quad() else (2.2 if on else 0.0)
		_power_glow.visible = on
	if weapons and weapons.viewmodel:
		_tint_node(weapons.viewmodel, _power_overlay if on else null)


func _tint_node(root: Node, overlay: Material) -> void:
	if root == null:
		return
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node is MeshInstance3D:
			(node as MeshInstance3D).material_overlay = overlay


func outgoing_damage_scale() -> float:
	return _power.damage_scale() if _power else 1.0


func outgoing_speed_scale() -> float:
	return _power.speed_scale() if _power else 1.0


func is_stealthed() -> bool:
	return _power != null and _power.is_invisible()


func power_screen_tint() -> Color:
	return _power.screen_tint() if _power else Color(0, 0, 0, 0)


func power_status_text() -> String:
	return _power.status_text() if _power else ""


func _on_vitals_health(_new_health: float) -> void:
	health_changed.emit()


func _on_vitals_died() -> void:
	if _alive:
		_die(_last_attacker)


func _die(attacker: Node) -> void:
	_alive = false
	if _power:
		_power.clear()
		_refresh_power_visual()
	AudioFx.play("death")
	died.emit(attacker)
	visible = false
	collision_layer = 0


func respawn_at(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	_launch_ignore_frames = 0
	floor_snap_length = DEFAULT_FLOOR_SNAP
	if health_comp:
		health_comp.reset_to_spawn()
	_alive = true
	visible = true
	collision_layer = 2
	if _power:
		_power.clear()
		_refresh_power_visual()
	weapons.ammo[WeaponManager.Kind.MG] = 100
	health_changed.emit()


func eye_transform() -> Transform3D:
	return _cam.global_transform


func camera() -> Camera3D:
	return _cam


func look_yaw() -> float:
	return _yaw


func horizontal_velocity() -> Vector3:
	return Vector3(velocity.x, 0.0, velocity.z)


func horizontal_speed() -> float:
	return horizontal_velocity().length()


func speed_ups() -> float:
	return horizontal_speed() * UPS_SCALE


func air_wish_speed_cap() -> float:
	return _move.AIR_WISH_SPEED_CAP


func is_alive() -> bool:
	return _alive


func hurt_alpha() -> float:
	return _hurt_flash
