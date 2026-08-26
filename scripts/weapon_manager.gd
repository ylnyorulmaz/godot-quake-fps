class_name WeaponManager
extends Node

enum Kind { MG, SHOTGUN, ROCKET, RAIL }

var current: Kind = Kind.MG
var owned := {Kind.MG: true, Kind.SHOTGUN: false, Kind.ROCKET: false, Kind.RAIL: false}
var ammo := {Kind.MG: 100, Kind.SHOTGUN: 0, Kind.ROCKET: 0, Kind.RAIL: 0}
var _cooldown := 0.0
var owner_body: CharacterBody3D
var is_player := false
var viewmodel: Node3D

const NAMES := {
	Kind.MG: "MACHINEGUN",
	Kind.SHOTGUN: "SHOTGUN",
	Kind.ROCKET: "ROCKET",
	Kind.RAIL: "RAILGUN",
}


func setup(body: CharacterBody3D, player_flag: bool) -> void:
	owner_body = body
	is_player = player_flag


func has_weapon(kind: Kind) -> bool:
	return bool(owned.get(kind, false))


func give_weapon(kind: Kind, extra_ammo: int) -> void:
	owned[kind] = true
	ammo[kind] = int(ammo.get(kind, 0)) + extra_ammo
	if current == Kind.MG and kind != Kind.MG:
		current = kind


func add_ammo(kind: Kind, amount: int) -> void:
	ammo[kind] = int(ammo.get(kind, 0)) + amount


func select(kind: Kind) -> void:
	if has_weapon(kind) and int(ammo.get(kind, 0)) > 0:
		current = kind
		_update_viewmodel()


func cycle(dir: int) -> void:
	var order: Array = [Kind.MG, Kind.SHOTGUN, Kind.ROCKET, Kind.RAIL]
	var idx := order.find(current)
	for _i in 4:
		idx = (idx + dir + 4) % 4
		var k: Kind = order[idx]
		if has_weapon(k) and (k == Kind.MG or int(ammo.get(k, 0)) > 0):
			current = k
			_update_viewmodel()
			return


func tick(delta: float, shooting: bool, eye: Transform3D) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if not shooting:
		return
	if _cooldown > 0.0:
		return
	_fire(eye)


func _fire(eye: Transform3D) -> void:
	match current:
		Kind.MG:
			if ammo[Kind.MG] <= 0:
				return
			ammo[Kind.MG] -= 1
			_cooldown = 0.09
			_hitscan(eye, 9.0, 0.018, Color(1.0, 0.85, 0.3), 1)
			if is_player:
				AudioFx.play("mg")
			else:
				AudioFx.play_at("mg", eye.origin)
		Kind.SHOTGUN:
			if ammo[Kind.SHOTGUN] <= 0:
				cycle(-1)
				return
			ammo[Kind.SHOTGUN] -= 1
			_cooldown = 0.85
			_hitscan(eye, 8.0, 0.09, Color(1.0, 0.7, 0.25), 8)
			if is_player:
				AudioFx.play("shotgun")
			else:
				AudioFx.play_at("shotgun", eye.origin)
		Kind.ROCKET:
			if ammo[Kind.ROCKET] <= 0:
				cycle(-1)
				return
			ammo[Kind.ROCKET] -= 1
			_cooldown = 0.8
			_spawn_rocket(eye)
			if is_player:
				AudioFx.play("rocket")
			else:
				AudioFx.play_at("rocket", eye.origin)
		Kind.RAIL:
			if ammo[Kind.RAIL] <= 0:
				cycle(-1)
				return
			ammo[Kind.RAIL] -= 1
			_cooldown = 1.35
			_rail(eye)
			if is_player:
				AudioFx.play("rail")
			else:
				AudioFx.play_at("rail", eye.origin)
	_kick()


func _hitscan(eye: Transform3D, damage: float, spread: float, color: Color, pellets: int) -> void:
	var space := owner_body.get_world_3d().direct_space_state
	for _i in pellets:
		var dir := (eye.basis * Vector3(randf_range(-spread, spread), randf_range(-spread, spread), -1.0)).normalized()
		var from := eye.origin
		var to := from + dir * 200.0
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.collision_mask = 1 | 2 | 4
		query.exclude = [owner_body.get_rid()]
		var hit := space.intersect_ray(query)
		var end := to
		if hit:
			end = hit.position
			var collider: Object = hit.collider
			if collider != null and collider.has_method("take_damage"):
				var knock := dir * (4.0 if pellets == 1 else 1.6)
				collider.take_damage(damage, dir, knock.length(), owner_body)
		if is_player or pellets == 1:
			_tracer(from, end, color, 0.03 if pellets == 1 else 0.015)


func _rail(eye: Transform3D) -> void:
	var space := owner_body.get_world_3d().direct_space_state
	var dir := -eye.basis.z
	var from := eye.origin
	var to := from + dir * 250.0
	var exclude: Array[RID] = [owner_body.get_rid()]
	var end := to
	for _i in 8:
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.collision_mask = 1 | 2 | 4
		query.exclude = exclude
		var hit := space.intersect_ray(query)
		if not hit:
			break
		end = hit.position
		var collider: Object = hit.collider
		if collider != null and collider.has_method("take_damage"):
			collider.take_damage(80.0, dir, 8.0, owner_body)
			if collider is CollisionObject3D:
				exclude.append((collider as CollisionObject3D).get_rid())
			from = hit.position + dir * 0.05
		else:
			break
	_tracer(eye.origin, end, Color(0.25, 0.95, 1.0), 0.07)


func _spawn_rocket(eye: Transform3D) -> void:
	var rocket := Rocket.new()
	rocket.shooter = owner_body
	rocket.direction = -eye.basis.z
	var host := owner_body.get_tree().get_first_node_in_group("world_root")
	if host == null:
		host = owner_body.get_tree().current_scene
	host.add_child(rocket)
	rocket.global_position = eye.origin + rocket.direction * 0.7


func _tracer(from: Vector3, to: Vector3, color: Color, thickness: float) -> void:
	var fx := HitscanFx.new()
	var host := owner_body.get_tree().get_first_node_in_group("world_root")
	if host == null:
		host = owner_body.get_tree().current_scene
	host.add_child(fx)
	fx.configure(from, to, color, thickness)


func _kick() -> void:
	if viewmodel == null:
		return
	viewmodel.position.z += 0.04
	viewmodel.rotation.x -= 0.04


func _update_viewmodel() -> void:
	if viewmodel == null:
		return
	for child in viewmodel.get_children():
		child.visible = child.name == NAMES[current]


func current_name() -> String:
	return String(NAMES[current])


func current_ammo() -> int:
	return int(ammo.get(current, 0))
