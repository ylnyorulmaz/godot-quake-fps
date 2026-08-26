class_name Rocket
extends Area3D

## High-speed projectile. Explodes on world / actor contact with splash.

@export var rocket_speed: float = 40.0
@export var splash_radius: float = 6.0
@export var blast_force: float = 28.0
@export var direct_damage: float = 100.0

var direction := Vector3.FORWARD
var shooter: Node3D
var speed := 40.0
var max_damage := 100.0
var knockback := 28.0
var self_damage_scale := 0.55

var _alive := true
var _splash: ShapeCast3D


func configure(
		p_shooter: Node3D,
		p_dir: Vector3,
		p_damage: float,
		p_radius: float,
		p_knockback: float,
		p_speed: float,
		p_self_scale: float = 0.55
) -> void:
	shooter = p_shooter
	direction = p_dir.normalized()
	max_damage = p_damage
	direct_damage = p_damage
	splash_radius = p_radius
	knockback = p_knockback
	blast_force = p_knockback
	speed = p_speed
	rocket_speed = p_speed
	self_damage_scale = p_self_scale


func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 8
	collision_mask = 1 | 2 | 4
	if not body_entered.is_connected(_on_body):
		body_entered.connect(_on_body)

	if get_node_or_null("CollisionShape3D") == null:
		var shape := CollisionShape3D.new()
		shape.name = "CollisionShape3D"
		var sphere := SphereShape3D.new()
		sphere.radius = 0.18
		shape.shape = sphere
		add_child(shape)

	var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh == null:
		mesh = MeshInstance3D.new()
		mesh.name = "MeshInstance3D"
		add_child(mesh)
	if mesh.mesh == null:
		var sm := SphereMesh.new()
		sm.radius = 0.16
		sm.height = 0.32
		mesh.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.95, 0.35, 0.08)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.35, 0.05)
		mat.emission_energy_multiplier = 3.5
		mesh.material_override = mat

	if get_node_or_null("OmniLight3D") == null:
		var light := OmniLight3D.new()
		light.name = "OmniLight3D"
		light.light_color = Color(1.0, 0.45, 0.1)
		light.light_energy = 2.4
		light.omni_range = 6.0
		add_child(light)

	_splash = get_node_or_null("SplashCast") as ShapeCast3D
	if _splash == null:
		_splash = ShapeCast3D.new()
		_splash.name = "SplashCast"
		add_child(_splash)
	var splash_shape := SphereShape3D.new()
	splash_shape.radius = splash_radius
	_splash.shape = splash_shape
	_splash.target_position = Vector3.ZERO
	_splash.collision_mask = 2 | 4
	_splash.collide_with_areas = false
	_splash.collide_with_bodies = true
	_splash.enabled = false
	_splash.max_results = 32

	var timer := get_tree().create_timer(4.0)
	timer.timeout.connect(func() -> void:
		if _alive:
			_explode(global_position)
	)


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	var from := global_position
	var to := from + direction * speed * delta
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1 | 2 | 4
	query.exclude = _exclude()
	var hit := space.intersect_ray(query)
	if hit:
		_explode(hit.position)
	else:
		global_position = to
		if direction.length_squared() > 0.0001:
			var up := Vector3.UP
			if absf(direction.dot(up)) > 0.99:
				up = Vector3.RIGHT
			look_at(global_position + direction, up)


func _exclude() -> Array[RID]:
	var list: Array[RID] = [get_rid()]
	if shooter != null and is_instance_valid(shooter) and shooter is CollisionObject3D:
		list.append((shooter as CollisionObject3D).get_rid())
	return list


func _on_body(body: Node3D) -> void:
	if not _alive:
		return
	if body == shooter:
		return
	_explode(global_position)


func _explode(at: Vector3) -> void:
	if not _alive:
		return
	_alive = false
	global_position = at
	AudioFx.play_at("explode", at)
	var fx := ExplosionFx.new()
	var host := get_tree().get_first_node_in_group("world_root")
	if host == null:
		host = get_parent()
	host.add_child(fx)
	fx.global_position = at

	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = splash_radius
	query.shape = sphere
	query.transform = Transform3D(Basis(), at)
	query.collision_mask = 2 | 4
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var results := space.intersect_shape(query, 32)
	var seen: Array[Object] = []
	for item in results:
		var collider: Object = item.get("collider")
		if collider == null or collider in seen:
			continue
		seen.append(collider)
		var body := collider as Node3D
		if body == null:
			continue
		var center := body.global_position + Vector3(0.0, 0.45, 0.0)
		var to_body := center - at
		var dist := to_body.length()
		if dist >= splash_radius:
			continue
		var falloff := (splash_radius - dist) / splash_radius
		var dir := Vector3.UP if dist < 0.08 else to_body.normalized()
		var dmg := direct_damage * falloff
		if body == shooter:
			dmg *= self_damage_scale
		if collider.has_method("apply_explosion_knockback"):
			collider.apply_explosion_knockback(dir, blast_force * falloff)
			if collider.has_method("take_damage"):
				collider.take_damage(dmg, dir, 0.0, shooter)
		elif collider.has_method("take_damage"):
			collider.take_damage(dmg, dir, knockback * falloff, shooter)
	queue_free()
