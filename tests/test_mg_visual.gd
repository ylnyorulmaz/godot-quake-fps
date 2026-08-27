extends SceneTree
## Chaingun viewmodel: spinning barrels, muzzle flash, hotter tracers.
## Run: godot --headless --path . -s res://tests/test_mg_visual.gd

const WView := preload("res://scripts/weapon_viewmodel.gd")
const Weapons := preload("res://scripts/weapon_manager.gd")
const Data := preload("res://scripts/weapon_data.gd")
const Fx := preload("res://scripts/hitscan_fx.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed := 0
	failed += _test_cluster_and_flash()
	failed += _test_chunkier()
	failed += _test_tracer()
	failed += _test_fire_pulses()
	if failed > 0:
		push_error("mg visual tests failed: %d" % failed)
		quit(1)
	else:
		print("mg visual tests passed")
		quit(0)


func _count_meshes(n: Node) -> int:
	var total := 0
	if n is MeshInstance3D:
		total += 1
	for child in n.get_children():
		total += _count_meshes(child)
	return total


func _test_cluster_and_flash() -> int:
	var gun: Node3D = WView.build("machinegun")
	root.add_child(gun)
	var cluster := WView.barrel_cluster(gun)
	if cluster == null:
		push_error("machinegun needs a BarrelCluster")
		return 1
	var z0 := cluster.rotation.z
	WView.spin_barrels(gun, 0.4)
	if is_equal_approx(cluster.rotation.z, z0):
		push_error("spin_barrels should rotate the cluster")
		return 1
	var flash := cluster.get_node_or_null("MuzzleFlash") as Node3D
	var light := cluster.get_node_or_null("MuzzleLight") as OmniLight3D
	if flash == null or light == null:
		push_error("machinegun needs MuzzleFlash and MuzzleLight")
		return 1
	WView.set_muzzle_flash(gun, 1.0)
	if not flash.visible:
		push_error("full flash should show the muzzle disc")
		return 1
	if light.light_energy < 1.0:
		push_error("full flash should light the muzzle")
		return 1
	WView.set_muzzle_flash(gun, 0.0)
	if flash.visible:
		push_error("zero flash should hide the muzzle disc")
		return 1
	print("ok   barrel cluster spins and muzzle flash toggles")
	gun.queue_free()
	return 0


func _test_chunkier() -> int:
	var mg: Node3D = WView.build("machinegun")
	var sg: Node3D = WView.build("shotgun")
	var mg_n := _count_meshes(mg)
	var sg_n := _count_meshes(sg)
	if mg_n < 28:
		push_error("chaingun viewmodel too simple (%d parts)" % mg_n)
		return 1
	if mg_n <= sg_n:
		push_error("chaingun should out-chunk shotgun (%d vs %d)" % [mg_n, sg_n])
		return 1
	print("ok   chaingun is the chunkiest gun (%d parts)" % mg_n)
	mg.queue_free()
	sg.queue_free()
	return 0


func _test_tracer() -> int:
	var data: WeaponData = Data.machinegun()
	if data.trail_thickness >= 0.025:
		push_error("MG tracer should be a thin streak, got %s" % data.trail_thickness)
		return 1
	if data.trail_color.g >= 0.82:
		push_error("MG tracer should read brass-orange, got %s" % data.trail_color)
		return 1
	var fx = Fx.new()
	root.add_child(fx)
	fx.configure(Vector3.ZERO, Vector3(0, 0, -4), data.trail_color, data.trail_thickness, true)
	if fx.get_child_count() < 1:
		push_error("MG tracer should spawn a muzzle spark")
		return 1
	print("ok   MG tracer is a brass streak with a muzzle spark")
	fx.queue_free()
	return 0


func _make_player_wm():
	var body := CharacterBody3D.new()
	body.name = "Owner"
	root.add_child(body)
	var wm = Weapons.new()
	wm.name = "Weapons"
	root.add_child(wm)
	wm.setup(body, true)
	return wm


func _test_fire_pulses() -> int:
	var wm = _make_player_wm()
	wm.state = Weapons.State.IDLE
	if wm._fire_timer:
		wm._fire_timer.stop()
	var gun: Node3D = wm.viewmodel.get_node_or_null("MACHINEGUN")
	if gun == null:
		push_error("player viewmodel missing MACHINEGUN")
		return 1
	var cluster := WView.barrel_cluster(gun)
	var z0 := cluster.rotation.z
	if not wm.try_fire():
		push_error("MG try_fire should succeed")
		return 1
	if wm._mg_flash < 0.99:
		push_error("firing should pulse muzzle flash, got %s" % wm._mg_flash)
		return 1
	if wm._mg_spin_vel < 20.0:
		push_error("firing should spin up the barrels, got %s" % wm._mg_spin_vel)
		return 1
	wm._tick_mg(0.05)
	if is_equal_approx(cluster.rotation.z, z0):
		push_error("tick should rotate the barrel cluster")
		return 1
	print("ok   fire pulses flash and spins the barrels")
	var body := wm.owner_body
	wm.queue_free()
	if body:
		body.queue_free()
	return 0
