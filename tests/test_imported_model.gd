extends SceneTree
## Headless checks for Tripo / glTF drop-in fitting.
## Run: godot --headless --path . -s res://tests/test_imported_model.gd

const Imported := preload("res://scripts/imported_model.gd")


func _init() -> void:
	var failed := 0
	failed += _test_missing_path()
	failed += _test_repo_glbs()
	failed += _test_fit_box_height()
	failed += _test_sanitize_collision()
	if failed > 0:
		push_error("imported model tests failed: %d" % failed)
		quit(1)
	else:
		print("imported model tests passed")
		quit(0)


func _test_missing_path() -> int:
	if ResourceLoader.exists("res://assets/models/does_not_exist.glb"):
		push_error("bogus glb path should not exist")
		return 1
	print("ok   missing model path does not exist")
	return 0


func _test_repo_glbs() -> int:
	var warrior: PackedScene = Imported.load_packed(null, "res://assets/warrior.glb")
	var warrior2: PackedScene = Imported.load_packed(null, "res://assets/Warrior2.glb")
	if warrior == null:
		push_error("res://assets/warrior.glb did not load as PackedScene")
		return 1
	if warrior2 == null:
		push_error("res://assets/Warrior2.glb did not load as PackedScene")
		return 1
	print("ok   warrior and Warrior2 load as PackedScene")
	return 0


func _test_fit_box_height() -> int:
	var actor := Node3D.new()
	root.add_child(actor)
	var visual := Node3D.new()
	visual.name = "VisualModel"
	actor.add_child(visual)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 4.0, 2.0)
	mesh.mesh = box
	visual.add_child(mesh)
	Imported.fit_to_capsule(visual, 1.8, 0.0)
	var aabb: AABB = Imported.combined_aabb(visual)
	if absf(aabb.size.y - 1.8) > 0.05:
		push_error("fit height: got %.3f want 1.8" % aabb.size.y)
		return 1
	if absf(aabb.position.y) > 0.05:
		push_error("feet not on floor: min.y=%.3f" % aabb.position.y)
		return 1
	if absf(aabb.get_center().x) > 0.05 or absf(aabb.get_center().z) > 0.05:
		push_error("model not centered on XZ: %s" % str(aabb.get_center()))
		return 1
	print("ok   fit box to 1.8m with feet on floor")
	return 0


func _test_sanitize_collision() -> int:
	var visual := Node3D.new()
	root.add_child(visual)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 1
	visual.add_child(body)
	var col := CollisionShape3D.new()
	col.shape = BoxShape3D.new()
	body.add_child(col)
	Imported.sanitize(visual)
	if body.collision_layer != 0 or body.collision_mask != 0 or not col.disabled:
		push_error("imported colliders were not disabled")
		return 1
	print("ok   imported colliders stripped")
	return 0
