class_name ArenaBot
extends CharacterBody3D

signal died(killer: Node)

var bot_name := "Bot"
var health := 100.0
var armor := 25.0
var weapons: WeaponManager
var _alive := true
var _target: Node3D
var _wander: Vector3
var _retarget := 0.0
var _shoot_cd := 0.0
var _mesh: MeshInstance3D
var color := Color(0.7, 0.2, 0.2)


func _ready() -> void:
	add_to_group("bots")
	collision_layer = 4
	collision_mask = 1 | 2 | 8 | 16
	floor_stop_on_slope = false
	floor_max_angle = deg_to_rad(60.0)
	floor_snap_length = 0.12

	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.8
	shape.shape = cap
	shape.position.y = 0.9
	add_child(shape)

	_mesh = MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.38
	mesh.height = 1.8
	_mesh.mesh = mesh
	_mesh.position.y = 0.9
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	_mesh.material_override = mat
	add_child(_mesh)

	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.44
	head.mesh = sm
	head.position = Vector3(0, 1.55, -0.05)
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = color.darkened(0.2)
	head.material_override = hmat
	add_child(head)

	weapons = WeaponManager.new()
	add_child(weapons)
	weapons.setup(self, false)
	weapons.give_weapon(WeaponManager.Kind.SHOTGUN, 20)
	weapons.give_weapon(WeaponManager.Kind.ROCKET, 8)
	weapons.add_ammo(WeaponManager.Kind.MG, 80)

	GameState.register_bot(bot_name)


func _physics_process(delta: float) -> void:
	if not _alive or not GameState.match_running or GameState.paused:
		return
	_retarget -= delta
	if _retarget <= 0.0:
		_pick_target()
		_retarget = randf_range(0.35, 0.9)

	var wish := Vector3.ZERO
	var dest := _destination()
	var to_dest := dest - global_position
	to_dest.y = 0.0
	if to_dest.length() > 0.4:
		wish = to_dest.normalized()

	var jumping := false
	if is_on_floor():
		var ahead := global_position + wish * 1.4 + Vector3(0, 0.5, 0)
		var space := get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.5, 0), ahead)
		q.collision_mask = 1
		if space.intersect_ray(q):
			jumping = true
		if randf() < 0.01:
			jumping = true

	QuakeMovement.move(self, wish, jumping, false, delta)

	if wish.length_squared() > 0.01:
		var look := atan2(-wish.x, -wish.z)
		rotation.y = lerp_angle(rotation.y, look, 8.0 * delta)

	_try_shoot(delta)


func _destination() -> Vector3:
	if _target != null and is_instance_valid(_target) and _can_see(_target):
		return _target.global_position
	if _wander == Vector3.ZERO:
		_wander = _random_nav()
	if global_position.distance_to(_wander) < 2.0:
		_wander = _random_nav()
	return _wander


func _random_nav() -> Vector3:
	var spots := get_tree().get_nodes_in_group("nav_points")
	if spots.is_empty():
		return global_position + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8))
	return (spots[randi() % spots.size()] as Node3D).global_position


func _pick_target() -> void:
	var best: Node3D = null
	var best_d := 9999.0
	var player := get_tree().get_first_node_in_group("player")
	var candidates: Array = get_tree().get_nodes_in_group("bots")
	if player:
		candidates.append(player)
	for c in candidates:
		if c == self:
			continue
		if c.has_method("is_alive") and not c.is_alive():
			continue
		var d: float = global_position.distance_to(c.global_position)
		if d < best_d and _can_see(c):
			best = c
			best_d = d
	_target = best


func _can_see(other: Node3D) -> bool:
	var from := global_position + Vector3(0, 1.5, 0)
	var to := other.global_position + Vector3(0, 1.2, 0)
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1 | 2 | 4
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if not hit:
		return true
	return hit.collider == other


func _try_shoot(delta: float) -> void:
	_shoot_cd = maxf(_shoot_cd - delta, 0.0)
	if _target == null or not is_instance_valid(_target):
		return
	if not _can_see(_target):
		return
	var dist := global_position.distance_to(_target.global_position)
	if dist > 28.0:
		return
	if dist > 12.0 and weapons.has_weapon(WeaponManager.Kind.ROCKET) and weapons.ammo[WeaponManager.Kind.ROCKET] > 0:
		weapons.current = WeaponManager.Kind.ROCKET
	elif dist < 8.0 and weapons.has_weapon(WeaponManager.Kind.SHOTGUN) and weapons.ammo[WeaponManager.Kind.SHOTGUN] > 0:
		weapons.current = WeaponManager.Kind.SHOTGUN
	else:
		weapons.current = WeaponManager.Kind.MG

	var eye_pos := global_position + Vector3(0, 1.5, 0)
	var look_at_pos := _target.global_position + Vector3(0, 1.1, 0)
	var eye := Transform3D(Basis(), eye_pos).looking_at(look_at_pos, Vector3.UP)
	weapons.tick(delta, true, eye)


func take_damage(amount: float, dir: Vector3, knockback: float, attacker: Node = null) -> void:
	if not _alive:
		return
	var incoming := amount
	if armor > 0.0:
		var used := minf(armor, incoming * 0.66)
		armor -= used
		incoming -= used
	health -= incoming
	velocity += dir.normalized() * knockback
	if _mesh.material_override is StandardMaterial3D:
		(_mesh.material_override as StandardMaterial3D).emission_enabled = true
		(_mesh.material_override as StandardMaterial3D).emission = Color(1, 0.2, 0.1)
		(_mesh.material_override as StandardMaterial3D).emission_energy_multiplier = 2.0
	if health <= 0.0:
		_die(attacker)


func apply_pickup(kind: int) -> bool:
	match kind:
		Pickup.Kind.HEALTH:
			if health >= 100.0:
				return false
			health = minf(health + 25.0, 100.0)
		Pickup.Kind.MEGA_HEALTH:
			health = minf(health + 100.0, 200.0)
		Pickup.Kind.ARMOR:
			armor = minf(armor + 50.0, 100.0)
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
	return true


func _die(attacker: Node) -> void:
	_alive = false
	AudioFx.play_at("death", global_position)
	died.emit(attacker)
	visible = false
	collision_layer = 0


func respawn_at(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	health = 100.0
	armor = 25.0
	_alive = true
	visible = true
	collision_layer = 4
	if _mesh.material_override is StandardMaterial3D:
		(_mesh.material_override as StandardMaterial3D).emission_energy_multiplier = 0.0


func is_alive() -> bool:
	return _alive
