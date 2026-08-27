extends SceneTree
## Procedural weapon skins / viewmodels.
## Run: godot --headless --path . -s res://tests/test_weapon_skin.gd

const WSkin := preload("res://scripts/weapon_skin.gd")
const WView := preload("res://scripts/weapon_viewmodel.gd")


func _init() -> void:
	var failed := 0
	failed += _test_steel_nearest()
	failed += _test_wood_differs()
	failed += _test_energy_emits()
	failed += _test_brass_and_caution()
	failed += _test_viewmodels_are_compound()
	failed += _test_guns_are_distinct()
	if failed > 0:
		push_error("weapon skin tests failed: %d" % failed)
		quit(1)
	else:
		print("weapon skin tests passed")
		quit(0)


func _test_steel_nearest() -> int:
	var mat: StandardMaterial3D = WSkin.steel()
	var tex := mat.albedo_texture as ImageTexture
	if tex == null or tex.get_width() != 128 or tex.get_height() != 128:
		push_error("steel albedo should be 128x128")
		return 1
	if mat.texture_filter != StandardMaterial3D.TEXTURE_FILTER_NEAREST:
		push_error("weapon skins must be nearest-filtered")
		return 1
	if mat.metallic < 0.5:
		push_error("steel should read metallic")
		return 1
	print("ok   steel 128 nearest")
	return 0


func _test_wood_differs() -> int:
	var steel_img := (WSkin.steel().albedo_texture as ImageTexture).get_image()
	var wood_img := (WSkin.wood().albedo_texture as ImageTexture).get_image()
	if steel_img.get_pixel(20, 20).is_equal_approx(wood_img.get_pixel(20, 20)):
		push_error("wood and steel skins look identical")
		return 1
	var wood: StandardMaterial3D = WSkin.wood()
	if wood.metallic > 0.1:
		push_error("wood should not be metallic")
		return 1
	print("ok   wood grain distinct from steel")
	return 0


func _test_energy_emits() -> int:
	var mat: StandardMaterial3D = WSkin.energy()
	if not mat.emission_enabled or mat.emission_texture == null:
		push_error("rail energy skin should emit")
		return 1
	print("ok   energy lattice emits")
	return 0


func _test_brass_and_caution() -> int:
	var brass: StandardMaterial3D = WSkin.brass()
	if brass.metallic < 0.6:
		push_error("brass should read metallic")
		return 1
	var caution: StandardMaterial3D = WSkin.caution()
	var img := (caution.albedo_texture as ImageTexture).get_image()
	if img.get_pixel(0, 0).is_equal_approx(img.get_pixel(10, 0)):
		push_error("caution stripes should alternate")
		return 1
	var heat: StandardMaterial3D = WSkin.heat()
	if not heat.emission_enabled:
		push_error("heat skin should emit")
		return 1
	print("ok   brass / caution / heat skins")
	return 0


func _count_meshes(n: Node) -> int:
	var total := 0
	if n is MeshInstance3D:
		total += 1
	for child in n.get_children():
		total += _count_meshes(child)
	return total


func _count_textured(n: Node) -> int:
	var total := 0
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.material_override is StandardMaterial3D:
			var mat := mi.material_override as StandardMaterial3D
			if mat.albedo_texture != null:
				total += 1
	for child in n.get_children():
		total += _count_textured(child)
	return total


func _has_emission(n: Node) -> bool:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.material_override is StandardMaterial3D:
			var mat := mi.material_override as StandardMaterial3D
			if mat.emission_enabled:
				return true
	for child in n.get_children():
		if _has_emission(child):
			return true
	return false


func _test_viewmodels_are_compound() -> int:
	for id in ["machinegun", "shotgun", "rocket", "railgun"]:
		var gun: Node3D = WView.build(id)
		root.add_child(gun)
		var meshes := _count_meshes(gun)
		var textured := _count_textured(gun)
		if meshes < 10:
			push_error("%s viewmodel too simple (%d parts)" % [id, meshes])
			return 1
		if textured < 8:
			push_error("%s missing skins on parts (%d)" % [id, textured])
			return 1
		gun.queue_free()
	print("ok   four guns are compound textured meshes")
	return 0


func _test_guns_are_distinct() -> int:
	var counts: Dictionary = {}
	for id in ["machinegun", "shotgun", "rocket", "railgun"]:
		var gun: Node3D = WView.build(id)
		counts[id] = _count_meshes(gun)
		var has_glow := _has_emission(gun)
		if id == "railgun" and not has_glow:
			push_error("railgun should have an emitting coil")
			return 1
		if id == "rocket" and not has_glow:
			push_error("rocket should have a hot nozzle")
			return 1
		if id == "machinegun" and not has_glow:
			push_error("machinegun should have a hot muzzle")
			return 1
		gun.queue_free()
	if int(counts["machinegun"]) <= int(counts["shotgun"]):
		push_error("chaingun should be chunkier than shotgun")
		return 1
	if int(counts["machinegun"]) == int(counts["shotgun"]) and int(counts["shotgun"]) == int(counts["railgun"]):
		push_error("guns should not all share the same part count")
		return 1
	print("ok   guns have distinct silhouettes")
	return 0
