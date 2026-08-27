extends RefCounted
## Quake 3 Arena-style look: void sky, fog, colored fill lights, no shadows.
## Compatibility renderer stays readable without a washed-out gymnasium sky.

const VOID_COLOR := Color(0.018, 0.022, 0.045)
const FOG_COLOR := Color(0.04, 0.045, 0.07)
const AMBIENT_COLOR := Color(0.28, 0.30, 0.36)
const AMBIENT_ENERGY := 0.48
const SUN_ENERGY := 0.32
const FOG_DENSITY := 0.009


static func make_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = VOID_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = AMBIENT_COLOR
	env.ambient_light_energy = AMBIENT_ENERGY
	env.fog_enabled = true
	env.fog_light_color = FOG_COLOR
	env.fog_density = FOG_DENSITY
	if "fog_aerial_perspective" in env:
		env.fog_aerial_perspective = 0.35
	env.glow_enabled = false
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	if "tonemap_exposure" in env:
		env.tonemap_exposure = 0.92
	return env


static func make_sun() -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-48, 28, 0)
	sun.light_color = Color(0.95, 0.82, 0.68)
	sun.light_energy = SUN_ENERGY
	sun.shadow_enabled = false
	return sun


static func make_starfield() -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = "Starfield"
	var sphere := SphereMesh.new()
	sphere.radius = 280.0
	sphere.height = 560.0
	sphere.radial_segments = 16
	sphere.rings = 12
	if "flip_faces" in sphere:
		sphere.flip_faces = true
	node.mesh = sphere
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = _star_shader()
	node.material_override = mat
	return node


static func make_fill_light(pos: Vector3, color: Color, energy: float, omni_range: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = omni_range
	light.shadow_enabled = false
	return light


## Warm jumppad / rocket / rail / health colors, Q3 vertex-light language.
static func light_rig() -> Array:
	return [
		{"pos": Vector3(0, 9, 0), "color": Color(1.0, 0.55, 0.18), "energy": 5.2, "range": 28.0},
		{"pos": Vector3(24, 7, 24), "color": Color(1.0, 0.32, 0.12), "energy": 3.6, "range": 26.0},
		{"pos": Vector3(-24, 7, 24), "color": Color(0.2, 0.85, 1.0), "energy": 3.6, "range": 26.0},
		{"pos": Vector3(24, 7, -24), "color": Color(0.35, 1.0, 0.28), "energy": 3.4, "range": 26.0},
		{"pos": Vector3(-24, 7, -24), "color": Color(1.0, 0.72, 0.2), "energy": 3.4, "range": 26.0},
		{"pos": Vector3(0, 5, 36), "color": Color(1.0, 0.22, 0.1), "energy": 3.8, "range": 22.0},
		{"pos": Vector3(16, 8, -20), "color": Color(1.0, 0.45, 0.12), "energy": 3.2, "range": 20.0},
		{"pos": Vector3(-30, 8, 16), "color": Color(0.25, 0.7, 1.0), "energy": 3.2, "range": 20.0},
		{"pos": Vector3(0, -1.2, 0), "color": Color(1.0, 0.28, 0.05), "energy": 4.0, "range": 14.0},
	]


static func lava_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.16, 0.04)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.28, 0.04)
	mat.emission_energy_multiplier = 2.8
	mat.roughness = 0.85
	mat.metallic = 0.0
	return mat


static func is_void_sky(env: Environment) -> bool:
	if env == null:
		return false
	if env.background_color.get_luminance() > 0.12:
		return false
	if env.ambient_light_energy > 0.7:
		return false
	if not env.fog_enabled:
		return false
	return true


static func _star_shader() -> Shader:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

void fragment() {
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 dir = normalize(world);
	vec3 cell = floor(dir * 72.0);
	float n = fract(sin(dot(cell, vec3(12.9898, 78.233, 45.164))) * 43758.5453);
	float star = step(0.9965, n);
	float twinkle = 0.55 + 0.45 * sin(TIME * 1.6 + n * 50.0);
	vec3 void_col = vec3(0.012, 0.016, 0.038);
	ALBEDO = void_col + vec3(0.82, 0.88, 1.0) * star * twinkle;
}
"""
	return sh
