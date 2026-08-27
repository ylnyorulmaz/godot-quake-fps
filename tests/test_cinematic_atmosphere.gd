extends SceneTree
## Cinematic WorldEnvironment from Main._ready().
## Run: godot --headless --path . -s res://tests/test_cinematic_atmosphere.gd

const Atmosphere := preload("res://scripts/cinematic_atmosphere.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed := 0
	failed += _test_environment_look()
	failed += _test_sun_style()
	failed += _test_applies_to_host()
	failed += _test_main_ready_creates_it()
	if failed > 0:
		push_error("cinematic atmosphere tests failed: %d" % failed)
		quit(1)
	else:
		print("cinematic atmosphere tests passed")
		quit(0)


func _test_environment_look() -> int:
	var env: Environment = Atmosphere.make_environment()
	if env.background_mode != Environment.BG_COLOR:
		push_error("background should be a solid color")
		return 1
	if not env.background_color.is_equal_approx(Color(0.05, 0.05, 0.05)):
		push_error("background should be dark gray, got %s" % env.background_color)
		return 1
	if not env.ambient_light_color.is_equal_approx(Color(0.1, 0.12, 0.15)):
		push_error("ambient should be cold blue, got %s" % env.ambient_light_color)
		return 1
	if env.ambient_light_energy > 0.5:
		push_error("ambient energy should stay low, got %s" % env.ambient_light_energy)
		return 1
	if env.tonemap_mode != Environment.TONE_MAPPER_ACES:
		push_error("tonemap should be ACES, got %s" % env.tonemap_mode)
		return 1
	if not env.glow_enabled or absf(env.glow_intensity - 0.3) > 0.001:
		push_error("glow should be on at 0.3 intensity")
		return 1
	if "ssao_enabled" in env and (not env.ssao_enabled or absf(env.ssao_intensity - 1.5) > 0.001):
		push_error("SSAO should be on at 1.5 intensity")
		return 1
	if not env.fog_enabled or absf(env.fog_density - 0.015) > 0.0001:
		push_error("fog should be on at density 0.015")
		return 1
	var fog: Color = env.fog_light_color
	if fog.b <= fog.r:
		push_error("fog should read teal/cold, got %s" % fog)
		return 1
	print("ok   environment is dark, ACES, bloom, SSAO, teal fog")
	return 0


func _test_sun_style() -> int:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_color = Color(1, 1, 1)
	Atmosphere.style_directional_light(sun)
	if sun.light_color.b <= sun.light_color.r:
		push_error("sun should be cold, got %s" % sun.light_color)
		sun.free()
		return 1
	if sun.rotation_degrees.x > -12.0 or sun.rotation_degrees.x < -30.0:
		push_error("sun should sit low for long shadows, got %s" % sun.rotation_degrees)
		sun.free()
		return 1
	if not sun.shadow_enabled:
		push_error("sun should cast shadows")
		sun.free()
		return 1
	print("ok   directional light is cold and low-angle")
	sun.free()
	return 0


func _test_applies_to_host() -> int:
	var host := Node.new()
	root.add_child(host)
	var we: WorldEnvironment = Atmosphere.apply_to(host)
	if we == null or we.get_parent() != host:
		push_error("atmosphere should add a WorldEnvironment child")
		host.queue_free()
		return 1
	if we.environment == null or we.environment.tonemap_mode != Environment.TONE_MAPPER_ACES:
		push_error("applied environment missing ACES")
		host.queue_free()
		return 1
	print("ok   apply_to attaches WorldEnvironment to the host")
	host.queue_free()
	return 0


func _test_main_ready_creates_it() -> int:
	var src := FileAccess.get_file_as_string("res://scripts/main.gd")
	if src.find("WorldEnvironment.new()") < 0:
		push_error("main.gd _ready should create a WorldEnvironment node")
		return 1
	if src.find("Atmosphere.make_environment") < 0:
		push_error("main.gd should assign the cinematic Environment in code")
		return 1
	print("ok   main script applies atmosphere on ready")
	return 0
