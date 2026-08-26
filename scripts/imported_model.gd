class_name ImportedModel
extends RefCounted
## Drop-in helper for Tripo / glTF meshes on CharacterBody3D actors.
##
## Godot imports `.glb` / `.gltf` as a PackedScene. This fits the instance to a
## target height, plants the feet on y=0, and strips imported colliders/lights
## so the actor keeps its own capsule.

const DEFAULT_CANDIDATES: PackedStringArray = [
	"res://assets/models/orc.glb",
	"res://assets/models/orc.gltf",
	"res://assets/models/orc.tscn",
	"res://assets/models/Orc.glb",
	"res://assets/models/Orc.gltf",
]


static func load_packed(explicit: PackedScene = null, path: String = "") -> PackedScene:
	if explicit != null:
		return explicit
	if not path.is_empty() and ResourceLoader.exists(path):
		var from_path := ResourceLoader.load(path)
		if from_path is PackedScene:
			return from_path
	for candidate in DEFAULT_CANDIDATES:
		if ResourceLoader.exists(candidate):
			var loaded := ResourceLoader.load(candidate)
			if loaded is PackedScene:
				return loaded
	return null


static func instantiate_under(
		parent: Node3D,
		packed: PackedScene,
		target_height: float = 1.8,
		yaw_degrees: float = 180.0
) -> Node3D:
	if parent == null or packed == null:
		return null
	var inst := packed.instantiate()
	if inst == null:
		return null
	if not (inst is Node3D):
		var wrap := Node3D.new()
		wrap.name = "VisualModel"
		wrap.add_child(inst)
		inst = wrap
	else:
		inst.name = "VisualModel"
	parent.add_child(inst)
	sanitize(inst)
	fit_to_capsule(inst, target_height, yaw_degrees)
	play_first_animation(inst)
	return inst as Node3D


static func sanitize(root: Node) -> void:
	if root == null:
		return
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node is CollisionObject3D:
			(node as CollisionObject3D).collision_layer = 0
			(node as CollisionObject3D).collision_mask = 0
		if node is CollisionShape3D:
			(node as CollisionShape3D).disabled = true
		if node is Light3D or node is Camera3D:
			(node as Node3D).visible = false


static func fit_to_capsule(root: Node3D, target_height: float, yaw_degrees: float) -> void:
	if root == null:
		return
	root.rotation.y = deg_to_rad(yaw_degrees)
	var aabb := combined_aabb(root)
	if aabb.size.y > 0.001 and target_height > 0.001:
		root.scale *= target_height / aabb.size.y
		aabb = combined_aabb(root)
	if aabb.size == Vector3.ZERO:
		return
	var center := aabb.get_center()
	root.position.x -= center.x
	root.position.z -= center.z
	root.position.y -= aabb.position.y


static func combined_aabb(root: Node3D) -> AABB:
	var acc := AABB()
	var has := false
	if root == null or not root.is_inside_tree():
		return acc
	var parent_inv := root.get_parent() as Node3D
	var to_parent: Transform3D
	if parent_inv != null:
		to_parent = parent_inv.global_transform.affine_inverse()
	else:
		to_parent = Transform3D.IDENTITY
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if not (node is VisualInstance3D) or not (node is Node3D):
			continue
		var vis := node as VisualInstance3D
		var local_aabb: AABB = vis.get_aabb()
		if local_aabb.size.x <= 0.0 and local_aabb.size.y <= 0.0 and local_aabb.size.z <= 0.0:
			continue
		var xf := to_parent * (node as Node3D).global_transform
		var world_aabb := xf.xform(local_aabb)
		if not has:
			acc = world_aabb
			has = true
		else:
			acc = acc.merge(world_aabb)
	return acc if has else AABB()


static func play_first_animation(root: Node) -> void:
	var player := _find_animation_player(root)
	if player == null:
		return
	var names := player.get_animation_list()
	if names.is_empty():
		return
	player.play(names[0])


static func _find_animation_player(root: Node) -> AnimationPlayer:
	if root == null:
		return null
	if root is AnimationPlayer:
		return root
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			if child is AnimationPlayer:
				return child
			stack.append(child)
	return null
