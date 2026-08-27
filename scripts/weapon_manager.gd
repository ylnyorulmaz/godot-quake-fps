class_name WeaponManager
extends Node3D

## State-driven loadout under Head/Camera3D.
## Hitscan uses FireRay (RayCast3D). Projectiles spawn at Muzzle.

signal weapon_changed(data: WeaponData)
signal fired
signal hit_landed

enum Kind { MG, SHOTGUN, ROCKET, RAIL }
enum State { IDLE, FIRING, SWITCHING }

const KIND_IDS := {
	Kind.MG: "machinegun",
	Kind.SHOTGUN: "shotgun",
	Kind.ROCKET: "rocket",
	Kind.RAIL: "railgun",
}

const ViewGen := preload("res://scripts/weapon_viewmodel.gd")
const ExplosionHold := preload("res://scripts/explosion.gd")
const SHELL_CASING := preload("res://scripts/shell_casing.gd")

var current: Kind = Kind.MG
var state: State = State.IDLE
var owned := {Kind.MG: true, Kind.SHOTGUN: false, Kind.ROCKET: false, Kind.RAIL: false}
var ammo := {Kind.MG: 100, Kind.SHOTGUN: 0, Kind.ROCKET: 0, Kind.RAIL: 0}

var owner_body: CharacterBody3D
var is_player := false
var viewmodel: Node3D

var _catalog: Dictionary = {}
var _muzzle: Node3D
var _ray: RayCast3D
var _fire_timer: Timer
var _switch_timer: Timer
var _aim_override := Transform3D.IDENTITY
var _use_aim_override := false
var _view_kick := Vector3.ZERO
var _mg_spin_vel := 0.0
var _mg_flash := 0.0

const _KIND_ORDER: Array[Kind] = [Kind.MG, Kind.SHOTGUN, Kind.ROCKET, Kind.RAIL]
const HIT_MASK := 1 | 2 | 4 | 32
const SWITCH_TIME := 0.12
const ALT_SHOTGUN_PELLETS := 1
const ALT_SHOTGUN_SPREAD_DEG := 0.9
const ALT_ROCKET_RADIUS := 4.5
const ALT_ROCKET_KNOCKBACK := 12.0
const ALT_MG_PELLETS := 3
const ALT_MG_SPREAD_DEG := 6.5
const ALT_MG_AMMO := 3
const ALT_RAIL_AMMO := 2
const ALT_RAIL_DAMAGE_SCALE := 1.6
const ALT_RAIL_THICK := 0.14


func _ready() -> void:
	_catalog = {
		Kind.MG: WeaponData.machinegun(),
		Kind.SHOTGUN: WeaponData.shotgun(),
		Kind.ROCKET: WeaponData.rocket_launcher(),
		Kind.RAIL: WeaponData.railgun(),
	}
	_ensure_child("Shotgun")
	_ensure_child("RocketLauncher")
	_ensure_child("Machinegun")
	_ensure_child("Railgun")
	_muzzle = _ensure_child("Muzzle")
	if _muzzle.position == Vector3.ZERO:
		_muzzle.position = Vector3(0.28, -0.18, -0.55)

	_ray = get_node_or_null("FireRay") as RayCast3D
	if _ray == null:
		_ray = RayCast3D.new()
		_ray.name = "FireRay"
		add_child(_ray)
	_ray.target_position = Vector3(0.0, 0.0, -200.0)
	_ray.collision_mask = HIT_MASK
	_ray.collide_with_areas = false
	_ray.enabled = true

	_fire_timer = get_node_or_null("FireTimer") as Timer
	if _fire_timer == null:
		_fire_timer = Timer.new()
		_fire_timer.name = "FireTimer"
		add_child(_fire_timer)
	_fire_timer.one_shot = true
	_fire_timer.timeout.connect(_on_fire_timer)

	_switch_timer = Timer.new()
	_switch_timer.name = "SwitchTimer"
	_switch_timer.one_shot = true
	_switch_timer.timeout.connect(_on_switch_timer)
	add_child(_switch_timer)


func setup(body: CharacterBody3D, player_flag: bool) -> void:
	owner_body = body
	is_player = player_flag
	if is_player:
		_build_viewmodel()
		_update_viewmodel()
	_exclude_owner_from_ray()
	_apply_range(_data(current))


func _exclude_owner_from_ray() -> void:
	if owner_body != null and _ray != null:
		_ray.add_exception(owner_body)


func _ensure_child(node_name: String) -> Node3D:
	var n := get_node_or_null(node_name) as Node3D
	if n == null:
		n = Node3D.new()
		n.name = node_name
		add_child(n)
	return n


func _build_viewmodel() -> void:
	viewmodel = Node3D.new()
	viewmodel.name = "Viewmodel"
	viewmodel.position = Vector3(0.28, -0.22, -0.45)
	add_child(viewmodel)
	for kind in _KIND_ORDER:
		var data: WeaponData = _catalog[kind]
		var gun := ViewGen.build(data.id)
		gun.name = data.display_name
		gun.visible = kind == current
		viewmodel.add_child(gun)


func _process(delta: float) -> void:
	if viewmodel == null:
		return
	var rest := Vector3(0.28, -0.22, -0.45)
	viewmodel.position = viewmodel.position.lerp(rest + _view_kick, 1.0 - exp(-10.0 * delta))
	viewmodel.rotation.x = lerp_angle(viewmodel.rotation.x, 0.0, 1.0 - exp(-10.0 * delta))
	viewmodel.rotation.z = lerp_angle(viewmodel.rotation.z, 0.0, 1.0 - exp(-12.0 * delta))
	_view_kick = _view_kick.lerp(Vector3.ZERO, 1.0 - exp(-8.0 * delta))
	_tick_mg(delta)


func has_weapon(kind: Kind) -> bool:
	return bool(owned.get(kind, false))


func give_weapon(kind: Kind, extra_ammo: int) -> void:
	owned[kind] = true
	add_ammo(kind, extra_ammo)
	if current == Kind.MG and kind != Kind.MG:
		select(kind)


func add_ammo(kind: Kind, amount: int) -> void:
	var data: WeaponData = _catalog[kind]
	ammo[kind] = mini(int(ammo.get(kind, 0)) + amount, data.max_ammo)


func select(kind: Kind) -> void:
	if not has_weapon(kind):
		return
	if kind != Kind.MG and int(ammo.get(kind, 0)) <= 0:
		return
	if kind == current and state != State.SWITCHING:
		return
	current = kind
	state = State.SWITCHING
	_switch_timer.start(SWITCH_TIME)
	_apply_range(_data(current))
	_update_viewmodel()
	weapon_changed.emit(_data(current))


func cycle(dir: int) -> void:
	var idx := _KIND_ORDER.find(current)
	for _i in _KIND_ORDER.size():
		idx = (idx + dir + _KIND_ORDER.size()) % _KIND_ORDER.size()
		var k: Kind = _KIND_ORDER[idx]
		if has_weapon(k) and (k == Kind.MG or int(ammo.get(k, 0)) > 0):
			select(k)
			return


func tick(_delta: float, shooting: bool, eye: Transform3D) -> void:
	_aim_override = eye
	_use_aim_override = true
	if shooting:
		try_fire()


func try_fire() -> bool:
	if state == State.SWITCHING:
		return false
	if not _fire_timer.is_stopped():
		return false
	var data := _data(current)
	if current != Kind.MG and int(ammo.get(current, 0)) <= 0:
		cycle(-1)
		return false
	if int(ammo.get(current, 0)) <= 0:
		return false
	_fire(data)
	return true


func alt_fire() -> bool:
	if state == State.SWITCHING:
		return false
	if not _fire_timer.is_stopped():
		return false
	match current:
		Kind.SHOTGUN:
			return _alt_shotgun()
		Kind.ROCKET:
			return _alt_rocket()
		Kind.MG:
			return _alt_mg()
		Kind.RAIL:
			return _alt_rail()
		_:
			return false


func _alt_shotgun() -> bool:
	if int(ammo.get(Kind.SHOTGUN, 0)) <= 0:
		cycle(-1)
		return false
	var data := _data(Kind.SHOTGUN)
	state = State.FIRING
	ammo[Kind.SHOTGUN] = int(ammo.get(Kind.SHOTGUN, 0)) - 1
	_fire_hitscan(data, _aim(), ALT_SHOTGUN_PELLETS, ALT_SHOTGUN_SPREAD_DEG)
	_play_fire_sound(data, _aim().origin)
	_eject_casing("shotgun")
	_kick()
	_fire_timer.start(maxf(data.fire_rate, 0.02))
	_apply_range(data)
	notify_fired()
	return true


func _alt_mg() -> bool:
	if int(ammo.get(Kind.MG, 0)) < ALT_MG_AMMO:
		return false
	var data := _data(Kind.MG)
	state = State.FIRING
	ammo[Kind.MG] = int(ammo.get(Kind.MG, 0)) - ALT_MG_AMMO
	_fire_hitscan(data, _aim(), ALT_MG_PELLETS, ALT_MG_SPREAD_DEG)
	_play_fire_sound(data, _aim().origin)
	_eject_casing("mg")
	_eject_casing("mg")
	_pulse_mg()
	_kick()
	_fire_timer.start(maxf(data.fire_rate, 0.02))
	_apply_range(data)
	notify_fired()
	return true


func _alt_rail() -> bool:
	if int(ammo.get(Kind.RAIL, 0)) < ALT_RAIL_AMMO:
		if int(ammo.get(Kind.RAIL, 0)) <= 0:
			cycle(-1)
		return false
	var data := _data(Kind.RAIL)
	state = State.FIRING
	ammo[Kind.RAIL] = int(ammo.get(Kind.RAIL, 0)) - ALT_RAIL_AMMO
	var charged: WeaponData = data.duplicate() as WeaponData
	charged.damage = data.damage * ALT_RAIL_DAMAGE_SCALE
	charged.trail_thickness = ALT_RAIL_THICK
	_fire_rail(charged, _aim())
	_play_fire_sound(data, _aim().origin)
	_kick()
	_fire_timer.start(maxf(data.fire_rate * 1.25, 0.02))
	_apply_range(data)
	notify_fired()
	return true


func _alt_rocket() -> bool:
	if int(ammo.get(Kind.ROCKET, 0)) <= 0:
		cycle(-1)
		return false
	var data := _data(Kind.ROCKET)
	state = State.FIRING
	ammo[Kind.ROCKET] = int(ammo.get(Kind.ROCKET, 0)) - 1
	_push_blast(_blast_origin())
	_play_fire_sound(data, _blast_origin())
	_kick()
	_fire_timer.start(maxf(data.fire_rate, 0.02))
	notify_fired()
	return true


func _blast_origin() -> Vector3:
	if owner_body:
		return owner_body.global_position + Vector3(0.0, 0.45, 0.0)
	return global_position


func _push_blast(at: Vector3) -> void:
	var host := _fx_host()
	if host:
		var fx = ExplosionHold.new()
		host.add_child(fx)
		if fx is Node3D:
			(fx as Node3D).global_position = at
	if owner_body == null or not owner_body.is_inside_tree():
		return
	var world := owner_body.get_world_3d()
	if world == null:
		return
	var space := world.direct_space_state
	if space == null:
		return
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = ALT_ROCKET_RADIUS
	query.shape = sphere
	query.transform = Transform3D(Basis(), at)
	query.collision_mask = 2 | 4
	query.collide_with_areas = false
	query.collide_with_bodies = true
	if owner_body is CollisionObject3D:
		query.exclude = [(owner_body as CollisionObject3D).get_rid()]
	var results := space.intersect_shape(query, 24)
	var seen: Array[Object] = []
	var shoved := false
	for item in results:
		var collider: Object = item.get("collider")
		if collider == null or collider in seen or collider == owner_body:
			continue
		seen.append(collider)
		var body := collider as Node3D
		if body == null:
			continue
		var to_body := body.global_position + Vector3(0.0, 0.45, 0.0) - at
		var dist := to_body.length()
		if dist >= ALT_ROCKET_RADIUS:
			continue
		var falloff := (ALT_ROCKET_RADIUS - dist) / ALT_ROCKET_RADIUS
		var dir := Vector3.UP if dist < 0.08 else to_body.normalized()
		var push := ALT_ROCKET_KNOCKBACK * falloff
		shoved = true
		if collider.has_method("apply_explosion_knockback"):
			collider.apply_explosion_knockback(dir, push)
		elif collider.has_method("take_damage"):
			collider.take_damage(0.0, dir, push, owner_body)
	if shoved:
		notify_hit()


func _fire(data: WeaponData) -> void:
	state = State.FIRING
	ammo[current] = int(ammo.get(current, 0)) - 1
	var aim := _aim()
	if data.is_hitscan:
		_fire_hitscan(data, aim)
	else:
		_fire_projectile(data, aim)
	_play_fire_sound(data, aim.origin)
	if current == Kind.MG:
		_eject_casing("mg")
		_pulse_mg()
	elif current == Kind.SHOTGUN:
		_eject_casing("shotgun")
	_kick()
	_fire_timer.start(maxf(data.fire_rate, 0.02))
	_apply_range(data)
	notify_fired()


func notify_fired() -> void:
	fired.emit()


func notify_hit() -> void:
	hit_landed.emit()


func _on_fire_timer() -> void:
	if state == State.FIRING:
		state = State.IDLE


func _on_switch_timer() -> void:
	state = State.IDLE


func _aim() -> Transform3D:
	if _use_aim_override:
		return _aim_override
	return global_transform


func _fire_hitscan(data: WeaponData, aim: Transform3D, pellet_override: int = -1, spread_override: float = -1.0) -> void:
	if data.pierce:
		_fire_rail(data, aim)
		return
	var pellets := data.pellet_count if pellet_override < 0 else pellet_override
	var spread := data.spread_deg if spread_override < 0.0 else spread_override
	var landed := false
	for i in pellets:
		var is_center := i == 0
		var from := aim.origin
		var dir := -aim.basis.z
		if (not is_center) or (spread > 0.0 and pellets > 1):
			dir = _spread_dir(aim, spread if not is_center else spread * 0.25)
		var to := from + dir * data.range
		var hit_pos := to
		var collider: Object = null
		if is_center and is_player and _ray != null:
			_ray.target_position = Vector3(0.0, 0.0, -data.range)
			_ray.force_raycast_update()
			if _ray.is_colliding():
				hit_pos = _ray.get_collision_point()
				collider = _ray.get_collider()
		else:
			var result := _ray_query(from, to)
			if result:
				hit_pos = result.position
				collider = result.collider
		if collider != null and collider.has_method("take_damage"):
			collider.take_damage(_outgoing_damage(data.damage), dir, data.knockback, owner_body)
			if collider != owner_body:
				landed = true
		if is_player or is_center:
			var trail_from := from
			if is_player and current == Kind.MG and _muzzle != null and _muzzle.is_inside_tree():
				trail_from = _muzzle.global_position
			_spawn_trail(trail_from, hit_pos, data)
	if landed:
		notify_hit()


func _fire_rail(data: WeaponData, aim: Transform3D) -> void:
	var dir := -aim.basis.z
	var from := aim.origin
	var end := from + dir * data.range
	var exclude: Array[RID] = []
	var landed := false
	if owner_body:
		exclude.append(owner_body.get_rid())
	if is_player and _ray != null:
		_ray.target_position = Vector3(0.0, 0.0, -data.range)
		_ray.force_raycast_update()
		if _ray.is_colliding():
			var first := _ray.get_collider()
			if first != null and first.has_method("take_damage"):
				first.take_damage(_outgoing_damage(data.damage), dir, data.knockback, owner_body)
				if first != owner_body:
					landed = true
				if first is CollisionObject3D:
					exclude.append((first as CollisionObject3D).get_rid())
				from = _ray.get_collision_point() + dir * 0.05
			else:
				end = _ray.get_collision_point()
				_spawn_trail(aim.origin, end, data)
				if landed:
					notify_hit()
				return
	for _i in 8:
		var result := _ray_query(from, from + dir * data.range, exclude)
		if not result:
			end = from + dir * data.range
			break
		end = result.position
		var collider: Object = result.collider
		if collider != null and collider.has_method("take_damage"):
			collider.take_damage(_outgoing_damage(data.damage), dir, data.knockback, owner_body)
			if collider != owner_body:
				landed = true
			if collider is CollisionObject3D:
				exclude.append((collider as CollisionObject3D).get_rid())
			from = result.position + dir * 0.05
		else:
			break
	_spawn_trail(aim.origin, end, data)
	if landed:
		notify_hit()


func _fire_projectile(data: WeaponData, aim: Transform3D) -> void:
	var scene := data.projectile_scene
	var rocket: Node
	if scene != null:
		rocket = scene.instantiate()
	else:
		rocket = Rocket.new()
	var dir := -aim.basis.z
	var spawn := aim.origin + dir * 0.55
	if is_player and _muzzle != null:
		spawn = _muzzle.global_position
		var look := _aim_point(aim, data.range)
		dir = (look - spawn).normalized()
	if rocket.has_method("configure"):
		rocket.configure(
				owner_body,
				dir,
				_outgoing_damage(data.damage),
				data.splash_radius,
				data.splash_knockback,
				data.projectile_speed,
				data.self_damage_scale
		)
	else:
		rocket.shooter = owner_body
		rocket.direction = dir
	var host := _fx_host()
	host.add_child(rocket)
	if rocket is Node3D:
		(rocket as Node3D).global_position = spawn


func _aim_point(aim: Transform3D, range: float) -> Vector3:
	if is_player and _ray != null:
		_ray.target_position = Vector3(0.0, 0.0, -range)
		_ray.force_raycast_update()
		if _ray.is_colliding():
			return _ray.get_collision_point()
	return aim.origin + (-aim.basis.z) * range


func _spread_dir(aim: Transform3D, spread_deg: float) -> Vector3:
	var rad := deg_to_rad(spread_deg)
	var offset := Vector3(randf_range(-rad, rad), randf_range(-rad, rad), -1.0)
	return (aim.basis * offset).normalized()


func _ray_query(from: Vector3, to: Vector3, extra_exclude: Array[RID] = []) -> Dictionary:
	if owner_body == null:
		return {}
	var space := owner_body.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = HIT_MASK
	query.collide_with_areas = false
	var exclude: Array[RID] = extra_exclude.duplicate()
	exclude.append(owner_body.get_rid())
	query.exclude = exclude
	return space.intersect_ray(query)


func _spawn_trail(from: Vector3, to: Vector3, data: WeaponData) -> void:
	var host := _fx_host()
	if host == null:
		return
	var fx := HitscanFx.new()
	host.add_child(fx)
	var tracer := current == Kind.MG
	fx.configure(from, to, data.trail_color, data.trail_thickness, tracer)


func _eject_casing(kind: String) -> void:
	var host := _fx_host()
	if host == null:
		return
	var aim := _aim()
	var origin := aim.origin + aim.basis.x * 0.12 - aim.basis.y * 0.06
	if is_player and _muzzle != null and _muzzle.is_inside_tree():
		origin = _muzzle.global_position + aim.basis.x * 0.08
	var casing = SHELL_CASING.new()
	host.add_child(casing)
	casing.configure(kind, origin, aim.basis.x, -aim.basis.z)


func _fx_host() -> Node:
	if owner_body == null:
		return self
	if not owner_body.is_inside_tree():
		return self
	var host := owner_body.get_tree().get_first_node_in_group("world_root")
	if host == null:
		host = owner_body.get_tree().current_scene
	if host == null:
		return self
	return host


func _outgoing_damage(base: float) -> float:
	if owner_body != null and owner_body.has_method("outgoing_damage_scale"):
		return base * float(owner_body.call("outgoing_damage_scale"))
	return base


func _play_fire_sound(data: WeaponData, at: Vector3) -> void:
	var fx := get_node_or_null("/root/AudioFx")
	if fx == null or not fx.has_method("play"):
		return
	if is_player:
		fx.play(data.sound_key)
	elif fx.has_method("play_at"):
		fx.play_at(data.sound_key, at)


func _kick() -> void:
	if viewmodel == null:
		return
	if current == Kind.MG:
		_view_kick.z += 0.016
		_view_kick.x += randf_range(-0.012, 0.012)
		_view_kick.y += randf_range(0.0, 0.008)
		viewmodel.rotation.x -= 0.016
		viewmodel.rotation.z += randf_range(-0.014, 0.014)
		return
	_view_kick.z += 0.05
	viewmodel.rotation.x -= 0.05


func _pulse_mg() -> void:
	_mg_spin_vel = maxf(_mg_spin_vel, 26.0)
	_mg_flash = 1.0


func _mg_view() -> Node3D:
	if viewmodel == null:
		return null
	return viewmodel.get_node_or_null("MACHINEGUN") as Node3D


func _tick_mg(delta: float) -> void:
	var gun := _mg_view()
	if gun == null:
		_mg_flash = 0.0
		return
	var firing := current == Kind.MG and state == State.FIRING
	if firing:
		_mg_spin_vel = maxf(_mg_spin_vel, 18.0)
	else:
		_mg_spin_vel = maxf(_mg_spin_vel - delta * 16.0, 0.0)
	ViewGen.spin_barrels(gun, _mg_spin_vel * delta)
	_mg_flash = maxf(_mg_flash - delta * 18.0, 0.0)
	ViewGen.set_muzzle_flash(gun, _mg_flash)


func _apply_range(data: WeaponData) -> void:
	if _ray != null:
		_ray.target_position = Vector3(0.0, 0.0, -data.range)


func _update_viewmodel() -> void:
	if viewmodel == null:
		return
	var name_now := _data(current).display_name
	for child in viewmodel.get_children():
		child.visible = child.name == name_now
	for slot_name in ["Shotgun", "RocketLauncher", "Machinegun", "Railgun"]:
		var slot := get_node_or_null(slot_name) as Node3D
		if slot:
			slot.visible = _slot_matches(slot_name)
	if _muzzle:
		if current == Kind.MG:
			_muzzle.position = Vector3(0.28, -0.22, -0.45) + ViewGen.MG_MUZZLE_LOCAL
		else:
			_muzzle.position = Vector3(0.28, -0.18, -0.55)


func _slot_matches(slot_name: String) -> bool:
	match current:
		Kind.SHOTGUN:
			return slot_name == "Shotgun"
		Kind.ROCKET:
			return slot_name == "RocketLauncher"
		Kind.MG:
			return slot_name == "Machinegun"
		Kind.RAIL:
			return slot_name == "Railgun"
	return false


func _data(kind: Kind) -> WeaponData:
	return _catalog[kind]


func current_name() -> String:
	return _data(current).display_name


func current_ammo() -> int:
	return int(ammo.get(current, 0))


func ammo_hud_color() -> Color:
	match current:
		Kind.SHOTGUN:
			return Color(0.95, 0.45, 0.12)
		Kind.ROCKET:
			return Color(0.95, 0.22, 0.12)
		Kind.RAIL:
			return Color(0.25, 0.85, 1.0)
		_:
			return Color(0.95, 0.85, 0.4)
