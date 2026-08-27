extends Object
## Gothic-industrial Play-time atmosphere: dark iron, rust fog, punchy bloom.
## Applied from Main._ready() so Play needs no editor setup.

static func make_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.035, 0.02, 0.016)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.1, 0.07)
	env.ambient_light_energy = 0.26
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	if "tonemap_exposure" in env:
		env.tonemap_exposure = 1.08
	env.glow_enabled = true
	env.glow_intensity = 0.55
	if "glow_bloom" in env:
		env.glow_bloom = 0.22
	if "glow_map" in env:
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color(1.0, 0.42, 0.12))
		env.glow_map = ImageTexture.create_from_image(img)
		if "glow_map_strength" in env:
			env.glow_map_strength = 0.4
	if "ssao_enabled" in env:
		env.ssao_enabled = true
		env.ssao_intensity = 1.5
	env.fog_enabled = true
	env.fog_light_color = Color(0.16, 0.06, 0.035)
	env.fog_density = 0.012
	return env


static func style_directional_light(light: DirectionalLight3D) -> void:
	# Low molten sun: long shadows, local colored lights still read.
	light.light_color = Color(1.0, 0.48, 0.22)
	light.light_energy = 0.72
	light.rotation_degrees = Vector3(-20.0, 48.0, 0.0)
	light.shadow_enabled = true
	if "shadow_blur" in light:
		light.shadow_blur = 1.2
	if "shadow_opacity" in light:
		light.shadow_opacity = 0.58


static func apply_to(host: Node) -> WorldEnvironment:
	var we := host.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we == null:
		we = WorldEnvironment.new()
		we.name = "WorldEnvironment"
		host.add_child(we)
	we.environment = make_environment()
	style_lights(host)
	return we


static func style_lights(node: Node) -> void:
	if node is DirectionalLight3D:
		style_directional_light(node)
	for child in node.get_children():
		style_lights(child)


static func keep_single_environment(host: Node, keep: WorldEnvironment) -> void:
	_strip(host, keep)


static func _strip(node: Node, keep: WorldEnvironment) -> void:
	if node is WorldEnvironment and node != keep:
		node.queue_free()
		return
	for child in node.get_children():
		_strip(child, keep)
