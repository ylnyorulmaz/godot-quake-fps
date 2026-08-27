extends SceneTree
## Quake 3 void lighting helpers.
## Run: godot --headless --path . -s res://tests/test_arena_atmosphere.gd

const Atmosphere := preload("res://scripts/arena_atmosphere.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed := 0
	failed += _test_void_environment()
	failed += _test_not_gym_sky()
	failed += _test_sun_has_no_shadows()
	failed += _test_starfield()
	failed += _test_light_rig_is_colored()
	failed += _test_lava_emits()
	if failed > 0:
		push_error("arena atmosphere tests failed: %d" % failed)
		quit(1)
	else:
		print("arena atmosphere tests passed")
		quit(0)


func _test_void_environment() -> int:
	var env: Environment = Atmosphere.make_environment()
	if not Atmosphere.is_void_sky(env):
		push_error("environment should be a dark foggy void")
		return 1
	if env.background_color.get_luminance() > 0.08:
		push_error("void background too bright %s" % env.background_color)
		return 1
	print("ok   dark foggy void environment")
	return 0


func _test_not_gym_sky() -> int:
	var env: Environment = Atmosphere.make_environment()
	var old := Color(0.42, 0.48, 0.55)
	if env.background_color.is_equal_approx(old):
		push_error("still using the bright gymnasium sky")
		return 1
	if env.ambient_light_energy >= 1.0:
		push_error("ambient still washed out at %s" % env.ambient_light_energy)
		return 1
	print("ok   not the old open-sky gym look")
	return 0


func _test_sun_has_no_shadows() -> int:
	var sun: DirectionalLight3D = Atmosphere.make_sun()
	if sun.shadow_enabled:
		push_error("sun shadows black out Compatibility floors")
		return 1
	if sun.light_energy > 0.8:
		push_error("sun too strong for void arena %s" % sun.light_energy)
		return 1
	sun.free()
	print("ok   dim sun, no shadows")
	return 0


func _test_starfield() -> int:
	var stars: MeshInstance3D = Atmosphere.make_starfield()
	if stars.mesh == null:
		push_error("starfield missing mesh")
		return 1
	if not (stars.material_override is ShaderMaterial):
		push_error("starfield should use a shader")
		return 1
	stars.free()
	print("ok   starfield sphere + shader")
	return 0


func _test_light_rig_is_colored() -> int:
	var rig: Array = Atmosphere.light_rig()
	if rig.size() < 6:
		push_error("expected a colored omni rig")
		return 1
	var hues := PackedFloat32Array()
	for entry in rig:
		var color: Color = entry["color"]
		var energy: float = float(entry["energy"])
		if energy < 1.0:
			push_error("fill light too dim")
			return 1
		hues.append(color.h)
	var spread := 0.0
	for i in hues.size():
		spread += absf(hues[i] - hues[0])
	if spread < 0.4:
		push_error("lights are not Q3-colored (hue spread %s)" % spread)
		return 1
	print("ok   colored fill lights")
	return 0


func _test_lava_emits() -> int:
	var mat: StandardMaterial3D = Atmosphere.lava_material()
	if not mat.emission_enabled:
		push_error("lava should emit")
		return 1
	if mat.emission.get_luminance() < 0.2:
		push_error("lava emission too dark")
		return 1
	print("ok   pit lava emits")
	return 0
