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
	failed += _test_viewmodels_are_compound()
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


func _test_viewmodels_are_compound() -> int:
	for id in ["machinegun", "shotgun", "rocket", "railgun"]:
		var gun: Node3D = WView.build(id)
		root.add_child(gun)
		var meshes := 0
		var textured := 0
		for child in gun.get_children():
			if child is MeshInstance3D:
				meshes += 1
				var mi := child as MeshInstance3D
				if mi.material_override is StandardMaterial3D:
					var mat := mi.material_override as StandardMaterial3D
					if mat.albedo_texture != null:
						textured += 1
		if meshes < 4:
			push_error("%s viewmodel too simple (%d parts)" % [id, meshes])
			return 1
		if textured < 4:
			push_error("%s missing skins on parts" % id)
			return 1
		gun.queue_free()
	print("ok   four guns are compound textured meshes")
	return 0
