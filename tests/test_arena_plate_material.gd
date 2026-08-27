extends SceneTree
## Procedural Quake plate material.
## Run: godot --headless --path . -s res://tests/test_arena_plate_material.gd

const Plate := preload("res://scripts/arena_plate_material.gd")


func _init() -> void:
	var failed := 0
	failed += _test_albedo_size_and_filter()
	failed += _test_metal_rough()
	failed += _test_cellular_not_flat()
	failed += _test_palette_is_dark_metal()
	failed += _test_palette_is_warm_rust()
	failed += _test_normal_map()
	failed += _test_apply_to_mesh()
	failed += _test_node_on_meshinstance()
	if failed > 0:
		push_error("arena plate tests failed: %d" % failed)
		quit(1)
	else:
		print("arena plate tests passed")
		quit(0)


func _test_albedo_size_and_filter() -> int:
	var mat: StandardMaterial3D = Plate.make_material(Plate.Kind.FLOOR)
	if mat == null:
		push_error("make_material returned null")
		return 1
	var tex := mat.albedo_texture as ImageTexture
	if tex == null:
		push_error("albedo_texture missing")
		return 1
	if tex.get_width() != 256 or tex.get_height() != 256:
		push_error("expected 256x256, got %sx%s" % [tex.get_width(), tex.get_height()])
		return 1
	if mat.texture_filter != StandardMaterial3D.TEXTURE_FILTER_NEAREST:
		push_error("texture_filter should be NEAREST")
		return 1
	print("ok   256x256 nearest albedo")
	return 0


func _test_metal_rough() -> int:
	var mat: StandardMaterial3D = Plate.make_material(Plate.Kind.WALL)
	if absf(mat.metallic - 0.6) > 0.001:
		push_error("metallic want 0.6 got %s" % mat.metallic)
		return 1
	if absf(mat.roughness - 0.4) > 0.001:
		push_error("roughness want 0.4 got %s" % mat.roughness)
		return 1
	print("ok   metallic 0.6 roughness 0.4")
	return 0


func _test_cellular_not_flat() -> int:
	var mat: StandardMaterial3D = Plate.make_material(Plate.Kind.FLOOR, {"seed": 42})
	var img := (mat.albedo_texture as ImageTexture).get_image()
	var first := img.get_pixel(0, 0)
	var distinct := 0
	for i in 32:
		var p := img.get_pixel(i * 7, i * 5)
		if not p.is_equal_approx(first):
			distinct += 1
	if distinct < 4:
		push_error("cellular albedo looks flat (%d distinct of 32)" % distinct)
		return 1
	print("ok   cellular albedo has plate variation")
	return 0


func _test_palette_is_dark_metal() -> int:
	var mat: StandardMaterial3D = Plate.make_material(Plate.Kind.FLOOR)
	var img := (mat.albedo_texture as ImageTexture).get_image()
	var acc := 0.0
	var n := 0
	for y in range(0, 256, 16):
		for x in range(0, 256, 16):
			acc += img.get_pixel(x, y).get_luminance()
			n += 1
	var avg := acc / float(n)
	if avg > 0.45:
		push_error("palette too bright for rust/metal, avg lum %s" % avg)
		return 1
	if avg < 0.04:
		push_error("palette too black, avg lum %s" % avg)
		return 1
	print("ok   rust/metal luminance %.2f" % avg)
	return 0


func _test_palette_is_warm_rust() -> int:
	var mat: StandardMaterial3D = Plate.make_material(Plate.Kind.FLOOR)
	var img := (mat.albedo_texture as ImageTexture).get_image()
	var r_acc := 0.0
	var b_acc := 0.0
	var n := 0
	for y in range(0, 256, 16):
		for x in range(0, 256, 16):
			var p := img.get_pixel(x, y)
			r_acc += p.r
			b_acc += p.b
			n += 1
	if r_acc / float(n) <= b_acc / float(n):
		push_error("floor plates should read rust-warm, r %s b %s" % [r_acc / float(n), b_acc / float(n)])
		return 1
	print("ok   floor plates are rust-warm")
	return 0


func _test_normal_map() -> int:
	var mat: StandardMaterial3D = Plate.make_material(Plate.Kind.TRIM, {"use_normal_map": true})
	if not mat.normal_enabled or mat.normal_texture == null:
		push_error("normal map not bound")
		return 1
	var off: StandardMaterial3D = Plate.make_material(Plate.Kind.TRIM, {"use_normal_map": false, "seed": 99})
	if off.normal_enabled:
		push_error("use_normal_map false should skip normals")
		return 1
	print("ok   normal_texture from plate grooves")
	return 0


func _test_apply_to_mesh() -> int:
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	root.add_child(mi)
	var mat := Plate.apply_to(mi, Plate.Kind.WALL)
	if mi.material_override != mat:
		push_error("apply_to did not set material_override")
		return 1
	mi.queue_free()
	print("ok   apply_to MeshInstance3D")
	return 0


func _test_node_on_meshinstance() -> int:
	var mi := MeshInstance3D.new()
	mi.mesh = PlaneMesh.new()
	root.add_child(mi)
	var node = Plate.new()
	node.kind = Plate.Kind.CEILING
	mi.add_child(node)
	if mi.material_override == null:
		push_error("child ArenaPlateMaterial did not apply when parented")
		return 1
	if mi.material_override.texture_filter != StandardMaterial3D.TEXTURE_FILTER_NEAREST:
		push_error("applied material is not nearest-filtered")
		return 1
	mi.queue_free()
	print("ok   node under MeshInstance3D applies when parented")
	return 0
