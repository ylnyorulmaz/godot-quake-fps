extends SceneTree
## AnimationTree idle/walk/run blend + jump state.
## Run: godot --headless --path . -s res://tests/test_locomotion_anim.gd

const Loco := preload("res://scripts/locomotion_anim.gd")


func _init() -> void:
	var failed := 0
	failed += _test_bind_requires_walk()
	failed += _test_blend_and_jump()
	if failed > 0:
		push_error("locomotion tests failed: %d" % failed)
		quit(1)
	else:
		print("locomotion tests passed")
		quit(0)


func _clip(length: float) -> Animation:
	var a := Animation.new()
	a.length = length
	a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(0, NodePath(".:position:y"))
	a.track_insert_key(0, 0.0, 0.0)
	a.track_insert_key(0, length, 0.0)
	return a


func _rig(with_jump: bool) -> Dictionary:
	var body := CharacterBody3D.new()
	root.add_child(body)
	var vis := Node3D.new()
	vis.name = "Visual"
	body.add_child(vis)
	var ap := AnimationPlayer.new()
	vis.add_child(ap)
	var lib := AnimationLibrary.new()
	lib.add_animation("Idle", _clip(1.0))
	lib.add_animation("Walk", _clip(0.8))
	lib.add_animation("Run", _clip(0.6))
	if with_jump:
		lib.add_animation("Jump", _clip(0.4))
	ap.add_animation_library("", lib)
	var loco = Loco.new()
	body.add_child(loco)
	return {"body": body, "vis": vis, "loco": loco}


func _test_bind_requires_walk() -> int:
	var body := CharacterBody3D.new()
	root.add_child(body)
	var vis := Node3D.new()
	body.add_child(vis)
	var ap := AnimationPlayer.new()
	vis.add_child(ap)
	var lib := AnimationLibrary.new()
	lib.add_animation("Idle", _clip(1.0))
	ap.add_animation_library("", lib)
	var loco = Loco.new()
	body.add_child(loco)
	if loco.bind(body, vis):
		push_error("bind should fail without Walk")
		return 1
	print("ok   bind needs Idle + Walk")
	return 0


func _test_blend_and_jump() -> int:
	var rig: Dictionary = _rig(true)
	var loco = rig["loco"]
	if not loco.bind(rig["body"], rig["vis"]):
		push_error("bind failed with Idle/Walk/Run/Jump")
		return 1
	loco.set_physics_process(false)
	loco.apply(0.0, false, 0.5)
	if loco.current_state() != "Grounded":
		push_error("expected Grounded, got %s" % loco.current_state())
		return 1
	loco.apply(8.0, false, 0.5)
	if loco.blend_position() < 6.0:
		push_error("run blend did not ease toward 8, got %.2f" % loco.blend_position())
		return 1
	loco.apply(1.0, true, 0.2)
	if loco.current_state() != "Air":
		push_error("expected Air after jump, got %s" % loco.current_state())
		return 1
	loco.apply(1.0, false, 0.25)
	if loco.current_state() != "Grounded":
		push_error("expected Grounded after land, got %s" % loco.current_state())
		return 1
	print("ok   BlendSpace speed + Air xfade")
	return 0
