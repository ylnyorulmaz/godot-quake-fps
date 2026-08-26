class_name QuakeMovement
extends RefCounted

## Quake 3 Arena PMove, scaled to Godot meters.
##
## Ground: friction, then accelerate toward MOVE_SPEED. Speed already above the
## cap (from a bunny hop) is kept — accelerate only adds speed along wishdir
## when currentspeed < wishspeed.
##
## Air: wish speed for accel is clamped to AIR_WISH_SPEED_CAP. Strafing so
## wishdir is off-axis from velocity makes currentspeed small, so you still
## add speed and turn — classic strafe-jump / circle-jump.
##
## Bunny hop: the landing frame that jumps skips friction entirely so horizontal
## momentum is not bled off before you leave the ground again.


static func move(
		body: CharacterBody3D,
		wish_dir: Vector3,
		jumping: bool,
		crouching: bool,
		sprinting: bool,
		delta: float,
		p: QuakeMoveParams
) -> void:
	wish_dir.y = 0.0
	if wish_dir.length_squared() > 1.0:
		wish_dir = wish_dir.normalized()
	elif wish_dir.length_squared() > 0.0001:
		wish_dir = wish_dir.normalized()

	var wish_speed := p.MOVE_SPEED
	if crouching:
		wish_speed *= p.CROUCH_MULTIPLIER
	elif sprinting and body.is_on_floor():
		wish_speed *= p.SPRINT_MULTIPLIER

	if body.is_on_floor():
		if jumping and not crouching:
			# Exact landing hop: no friction this frame.
			body.velocity.y = p.JUMP_FORCE
			_air_accelerate(body, wish_dir, wish_speed, delta, p)
		else:
			_friction(body, delta, p)
			_accelerate(body, wish_dir, wish_speed, p.ACCELERATION, delta)
			if body.velocity.y < 0.0:
				body.velocity.y = 0.0
	else:
		_air_accelerate(body, wish_dir, wish_speed, delta, p)
		body.velocity.y -= p.GRAVITY * delta
		if body.velocity.y < -p.TERMINAL_VELOCITY:
			body.velocity.y = -p.TERMINAL_VELOCITY

	body.move_and_slide()


static func _accelerate(
		body: CharacterBody3D,
		wish_dir: Vector3,
		wish_speed: float,
		accel: float,
		delta: float
) -> void:
	if wish_dir.length_squared() < 0.0001 or wish_speed <= 0.0:
		return
	# Instant ground accel toward cap; extra bhop speed along wishdir is kept.
	var current := body.velocity.dot(wish_dir)
	var add := wish_speed - current
	if add <= 0.0:
		return
	var acc := accel * wish_speed * delta
	if acc > add:
		acc = add
	body.velocity += wish_dir * acc


static func _air_accelerate(
		body: CharacterBody3D,
		wish_dir: Vector3,
		wish_speed: float,
		delta: float,
		p: QuakeMoveParams
) -> void:
	if wish_dir.length_squared() < 0.0001:
		return
	var wishspd := minf(wish_speed, p.AIR_WISH_SPEED_CAP)
	var current := body.velocity.dot(wish_dir)
	var add := wishspd - current
	if add <= 0.0:
		return
	# Accel uses full wish_speed (Q3: accel * wishspeed * frametime).
	var acc := p.AIR_ACCEL * wish_speed * delta
	if acc > add:
		acc = add
	body.velocity += wish_dir * acc


static func _friction(body: CharacterBody3D, delta: float, p: QuakeMoveParams) -> void:
	var horiz := Vector3(body.velocity.x, 0.0, body.velocity.z)
	var speed := horiz.length()
	if speed < 0.05:
		body.velocity.x = 0.0
		body.velocity.z = 0.0
		return
	var control := speed if speed >= p.STOP_SPEED else p.STOP_SPEED
	var drop := control * p.FRICTION * delta
	var new_speed := maxf(speed - drop, 0.0)
	var scale := new_speed / speed
	body.velocity.x *= scale
	body.velocity.z *= scale
