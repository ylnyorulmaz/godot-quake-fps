class_name QuakeMovement
extends RefCounted

## Quake 3 / CPM-inspired movement: ground accel, friction skip on jump, air-strafe.

const GRAVITY := 20.0
const JUMP_SPEED := 8.6
const MAX_SPEED := 10.0
const MAX_AIR_SPEED := 10.0
const GROUND_ACCEL := 14.0
const AIR_ACCEL := 3.2
const AIR_CONTROL := 5.5
const FRICTION := 6.0
const STOP_SPEED := 1.6
const AIR_SPEED_CAP := 2.4
const CROUCH_SPEED_SCALE := 0.45


static func move(body: CharacterBody3D, wish_dir: Vector3, jump_pressed: bool, crouching: bool, delta: float) -> void:
	wish_dir.y = 0.0
	if wish_dir.length_squared() > 1.0:
		wish_dir = wish_dir.normalized()

	var max_ground := MAX_SPEED * (CROUCH_SPEED_SCALE if crouching else 1.0)

	if body.is_on_floor():
		if jump_pressed and not crouching:
			body.velocity.y = JUMP_SPEED
			_air_accelerate(body, wish_dir, MAX_AIR_SPEED, delta)
		else:
			_friction(body, delta)
			_accelerate(body, wish_dir, max_ground, GROUND_ACCEL, delta)
			if body.velocity.y < 0.0:
				body.velocity.y = 0.0
	else:
		_air_accelerate(body, wish_dir, MAX_AIR_SPEED, delta)
		_air_control(body, wish_dir, delta)
		body.velocity.y -= GRAVITY * delta

	body.move_and_slide()


static func _accelerate(body: CharacterBody3D, wish_dir: Vector3, wish_speed: float, accel: float, delta: float) -> void:
	if wish_dir.length_squared() < 0.0001:
		return
	var current := body.velocity.dot(wish_dir)
	var add := wish_speed - current
	if add <= 0.0:
		return
	var acc := accel * wish_speed * delta
	if acc > add:
		acc = add
	body.velocity += wish_dir * acc


static func _air_accelerate(body: CharacterBody3D, wish_dir: Vector3, wish_speed: float, delta: float) -> void:
	var capped := minf(wish_speed, AIR_SPEED_CAP)
	_accelerate(body, wish_dir, capped, AIR_ACCEL, delta)


static func _air_control(body: CharacterBody3D, wish_dir: Vector3, delta: float) -> void:
	if wish_dir.length_squared() < 0.0001:
		return
	var horiz := Vector3(body.velocity.x, 0.0, body.velocity.z)
	var speed := horiz.length()
	if speed < 0.01:
		return
	var dot := horiz.normalized().dot(wish_dir)
	if dot > 0.0:
		var k := AIR_CONTROL * dot * dot * delta
		horiz = horiz.lerp(wish_dir * speed, clampf(k, 0.0, 1.0))
		body.velocity.x = horiz.x
		body.velocity.z = horiz.z


static func _friction(body: CharacterBody3D, delta: float) -> void:
	var speed := Vector3(body.velocity.x, 0.0, body.velocity.z).length()
	if speed < 0.05:
		body.velocity.x = 0.0
		body.velocity.z = 0.0
		return
	var control := speed if speed >= STOP_SPEED else STOP_SPEED
	var drop := control * FRICTION * delta
	var new_speed := maxf(speed - drop, 0.0)
	var scale := new_speed / speed
	body.velocity.x *= scale
	body.velocity.z *= scale
