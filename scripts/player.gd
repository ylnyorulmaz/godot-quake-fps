class_name Player
extends CharacterBody3D

signal died(killer: Node)
signal health_changed

var health := 100.0
var armor := 0.0
const MAX_HEALTH := 100.0
const MAX_OVERHEALTH := 200.0
const MAX_ARMOR := 100.0
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.05

var yaw := 0.0
var pitch := 0.0
var weapons: WeaponManager
var _cam: Camera3D
var _pivot: Node3D
var _capsule: CollisionShape3D
var _shape: CapsuleShape3D
var _mesh: MeshInstance3D
var _hurt_flash := 0.0
var _alive := true
var _eye_height := 1.55
var _bob := 0.0


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4 | 8 | 16
	floor_stop_on_slope = false
	floor_max_angle = deg_to_rad(60.0)
	floor_snap_length = 0.12
	safe_margin = 0.08

	_shape = CapsuleShape3D.new()
	_shape.radius = 0.38
	_shape.height = STAND_HEIGHT
	_capsule = CollisionShape3D.new()
	_capsule.shape = _shape
	_capsule.position.y = STAND_HEIGHT * 0.5
	add_child(_capsule)

	_mesh = MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.38
	cap.height = STAND_HEIGHT
	_mesh.mesh = cap
	_mesh.position.y = STAND_HEIGHT * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.55, 0.2)
	_mesh.material_override = mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(_mesh)

	_pivot = Node3D.new()
	_pivot.position.y = _eye_height
	add_child(_pivot)
	_cam = Camera3D.new()
	_cam.fov = 100.0
	_cam.near = 0.05
	_cam.far = 250.0
	_pivot.add_child(_cam)

	weapons = WeaponManager.new()
	add_child(weapons)
	weapons.setup(self, true)
	_build_viewmodel()
	weapons._update_viewmodel()


func _build_viewmodel() -> void:
	var vm := Node3D.new()
	vm.name = "Viewmodel"
	vm.position = Vector3(0.28, -0.22, -0.45)
	_cam.add_child(vm)
	weapons.viewmodel = vm
	_gun_mesh(vm, "MACHINEGUN", Vector3(0.08, 0.08, 0.55), Color(0.25, 0.25, 0.28))
	_gun_mesh(vm, "SHOTGUN", Vector3(0.1, 0.1, 0.62), Color(0.45, 0.28, 0.12))
	_gun_mesh(vm, "ROCKET", Vector3(0.16, 0.16, 0.7), Color(0.35, 0.12, 0.08))
	_gun_mesh(vm, "RAILGUN", Vector3(0.07, 0.07, 0.8), Color(0.1, 0.45, 0.55))


func _gun_mesh(parent: Node3D, gun_name: String, size: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.name = gun_name
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.4
	mat.roughness = 0.4
	mi.material_override = mat
	mi.visible = gun_name == "MACHINEGUN"
	parent.add_child(mi)


func _unhandled_input(event: InputEvent) -> void:
	if not _alive or not GameState.match_running or GameState.paused:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * GameState.mouse_sensitivity
		pitch -= event.relative.y * GameState.mouse_sensitivity
		pitch = clampf(pitch, deg_to_rad(-89.0), deg_to_rad(89.0))
		rotation.y = yaw
		_pivot.rotation.x = pitch
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
	var crouch := Input.is_action_pressed("crouch")
	_set_crouch(crouch)

	var wish := Vector3.ZERO
	var basis_y := Basis(Vector3.UP, yaw)
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

	var jumping := Input.is_action_just_pressed("jump")
	if jumping and is_on_floor():
		AudioFx.play("jump")
	QuakeMovement.move(self, wish, jumping, crouch, delta)

	_bob += Vector3(velocity.x, 0.0, velocity.z).length() * delta
	var bob_amt := 0.0 if not is_on_floor() else sin(_bob * 8.0) * 0.025
	_pivot.position.y = _eye_height + bob_amt
	if weapons.viewmodel:
		weapons.viewmodel.position = weapons.viewmodel.position.lerp(Vector3(0.28, -0.22, -0.45), 8.0 * delta)
		weapons.viewmodel.rotation.x = lerp_angle(weapons.viewmodel.rotation.x, 0.0, 8.0 * delta)

	var eye := Transform3D(_cam.global_transform.basis, _cam.global_position)
	weapons.tick(delta, Input.is_action_pressed("attack"), eye)
	_hurt_flash = maxf(_hurt_flash - delta * 2.5, 0.0)


func _set_crouch(crouch: bool) -> void:
	var h := CROUCH_HEIGHT if crouch else STAND_HEIGHT
	_shape.height = h
	_capsule.position.y = h * 0.5
	_eye_height = 0.85 if crouch else 1.55
	if _mesh.mesh is CapsuleMesh:
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
	return Transform3D(_cam.global_transform.basis, _cam.global_position)


func is_alive() -> bool:
	return _alive


func hurt_alpha() -> float:
	return _hurt_flash
