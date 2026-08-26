class_name Player
extends CharacterBody3D

## Quake 3 style CharacterBody3D FPS controller.
##
## Tree:
##   Player (this)
##     CollisionShape3D (capsule)
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

var health := 100.0
var armor := 0.0
var weapons: WeaponManager

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
var _move := QuakeMoveParams.new()


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4 | 8 | 16
	floor_stop_on_slope = false
	floor_max_angle = deg_to_rad(60.0)
	floor_snap_length = 0.12
	safe_margin = 0.08
	motion_mode = MOTION_MODE_GROUNDED
	_ensure_tree()
	_cache_nodes()
	_cam.fov = FOV
	_eye_height = EYE_HEIGHT
	weapons.setup(self, true)


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
		_cam.fov = FOV
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


func _cache_nodes() -> void:
	_capsule = $CollisionShape3D
	_shape = _capsule.shape as CapsuleShape3D
	_head = $Head
	_cam = $Head/Camera3D
	weapons = $Head/Camera3D/WeaponManager
	_mesh = get_node_or_null("BodyMesh") as MeshInstance3D
	# Hide own capsule from the first-person camera.
	_cam.cull_mask = _cam.cull_mask & ~2


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
	QuakeMovement.move(self, wish, jumping, crouch, sprinting, delta, _move)
	_was_on_floor = is_on_floor()

	_bob += Vector3(velocity.x, 0.0, velocity.z).length() * delta
	var bob_amt := 0.0 if not is_on_floor() else sin(_bob * 8.0) * 0.025
	_head.position.y = _eye_height + bob_amt

	if _wants_fire():
		weapons.try_fire()
	_hurt_flash = maxf(_hurt_flash - delta * 2.5, 0.0)


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
	_move.MOVE_SPEED = MOVE_SPEED
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
	var incoming := amount
	if armor > 0.0:
		var absorbed := incoming * 0.66
		var used := minf(armor, absorbed)
		armor -= used
		incoming -= used
	health -= incoming
	if dir.length_squared() > 0.0001:
		velocity += dir.normalized() * knockback
	_hurt_flash = 0.55
	AudioFx.play("hurt")
	health_changed.emit()
	if health <= 0.0:
		_die(attacker)


func apply_pickup(kind: int) -> bool:
	match kind:
		Pickup.Kind.HEALTH:
			if health >= MAX_HEALTH:
				return false
			health = minf(health + 25.0, MAX_HEALTH)
		Pickup.Kind.MEGA_HEALTH:
			health = minf(health + 100.0, MAX_OVERHEALTH)
		Pickup.Kind.ARMOR:
			if armor >= MAX_ARMOR:
				return false
			armor = minf(armor + 50.0, MAX_ARMOR)
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


func _die(attacker: Node) -> void:
	_alive = false
	AudioFx.play("death")
	died.emit(attacker)
	visible = false
	collision_layer = 0


func respawn_at(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	health = MAX_HEALTH
	armor = 0.0
	_alive = true
	visible = true
	collision_layer = 2
	weapons.ammo[WeaponManager.Kind.MG] = 100
	health_changed.emit()


func eye_transform() -> Transform3D:
	return _cam.global_transform


func is_alive() -> bool:
	return _alive


func hurt_alpha() -> float:
	return _hurt_flash
