class_name Rocket
extends Area3D

const SPEED := 32.0
const RADIUS := 6.0
const MAX_DAMAGE := 100.0
const KNOCKBACK := 18.0

var direction := Vector3.FORWARD
var shooter: Node3D
var _alive := true


func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 8
	collision_mask = 1 | 2 | 4
	body_entered.connect(_on_body)

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.18
	shape.shape = sphere
	add_child(shape)

	var mesh := MeshInstance3D.new()
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
	add_child(mesh)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.45, 0.1)
	light.light_energy = 2.4
	light.omni_range = 6.0
	add_child(light)

	var timer := get_tree().create_timer(4.0)
	timer.timeout.connect(func() -> void:
		if _alive:
			_explode(global_position)
	)


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	var from := global_position
	var motion := direction * SPEED * delta
	var to := from + motion
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1 | 2 | 4
	query.exclude = _exclude()
	var hit := space.intersect_ray(query)
	if hit:
		_explode(hit.position)
	else:
		global_position = to


func _exclude() -> Array[RID]:
	var list: Array[RID] = [get_rid()]
	if shooter != null and is_instance_valid(shooter):
		list.append(shooter.get_rid())
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
	AudioFx.play_at("explode", at)
	var fx := ExplosionFx.new()
	var host := get_tree().get_first_node_in_group("world_root")
	if host == null:
		host = get_parent()
	host.add_child(fx)
	fx.global_position = at

	var space := get_world_3d().direct_space_state
	var params := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = RADIUS
	params.shape = sphere
	params.transform = Transform3D(Basis(), at)
	params.collision_mask = 2 | 4
	params.collide_with_areas = false
	params.collide_with_bodies = true
	var results := space.intersect_shape(params, 32)
	for item in results:
		var collider: Object = item.get("collider")
		if collider == null or not is_instance_valid(collider):
			continue
		if not collider.has_method("take_damage"):
			continue
		var body := collider as Node3D
		var center := body.global_position + Vector3(0.0, 0.9, 0.0)
		var dist := center.distance_to(at)
		var falloff := 1.0 - clampf(dist / RADIUS, 0.0, 1.0)
		if falloff <= 0.0:
			continue
		var dir := (center - at)
		if dir.length_squared() < 0.001:
			dir = Vector3.UP
		else:
			dir = dir.normalized()
		var dmg := MAX_DAMAGE * falloff
		if body == shooter:
			dmg *= 0.55
		collider.take_damage(dmg, dir, KNOCKBACK * falloff, shooter)
	queue_free()
