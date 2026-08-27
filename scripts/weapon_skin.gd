class_name WeaponSkin
extends RefCounted
## Procedural first-person weapon skins. No image assets.
## 128×128 nearest-filtered plates: steel, wood grain, rust, energy lattice.

const SIZE := 128

static var _cache: Dictionary = {}


static func steel(seed: int = 11) -> StandardMaterial3D:
	return _cached("steel|%s" % seed, func() -> Image:
		return _noise_tex(seed, 0.11, [
			Color("#1c1c1e"),
			Color("#3a3a40"),
			Color("#6a6a72"),
		], true)
	, 0.72, 0.38)


static func blued(seed: int = 23) -> StandardMaterial3D:
	return _cached("blued|%s" % seed, func() -> Image:
		return _noise_tex(seed, 0.09, [
			Color("#121820"),
			Color("#243044"),
			Color("#4a5a70"),
		], true)
	, 0.78, 0.32)


static func wood(seed: int = 41) -> StandardMaterial3D:
	return _cached("wood|%s" % seed, func() -> Image:
		return _wood_tex(seed)
	, 0.02, 0.78)


static func rust(seed: int = 7) -> StandardMaterial3D:
	return _cached("rust|%s" % seed, func() -> Image:
		return _noise_tex(seed, 0.08, [
			Color("#2a120c"),
			Color("#6a2818"),
			Color("#a84820"),
		], true)
	, 0.55, 0.48)


static func brass(seed: int = 53) -> StandardMaterial3D:
	return _cached("brass|%s" % seed, func() -> Image:
		return _noise_tex(seed, 0.1, [
			Color("#3a2810"),
			Color("#8a6a24"),
			Color("#d4b050"),
		], true)
	, 0.82, 0.28)


static func grip(seed: int = 31) -> StandardMaterial3D:
	return _cached("grip|%s" % seed, func() -> Image:
		return _noise_tex(seed, 0.16, [
			Color("#121214"),
			Color("#1c1c20"),
			Color("#323238"),
		], false)
	, 0.04, 0.86)


static func caution(seed: int = 17) -> StandardMaterial3D:
	return _cached("caution|%s" % seed, func() -> Image:
		return _stripe_tex(Color("#1a1408"), Color("#e8b014"))
	, 0.12, 0.55)


static func energy(seed: int = 99) -> StandardMaterial3D:
	var mat := _cached("energy|%s" % seed, func() -> Image:
		return _grid_tex(seed, Color("#062028"), Color("#1ae0ff"))
	, 0.35, 0.22)
	mat.emission_enabled = true
	mat.emission = Color(0.12, 0.75, 0.95)
	mat.emission_energy_multiplier = 2.4
	mat.emission_texture = mat.albedo_texture
	return mat


static func heat(seed: int = 13) -> StandardMaterial3D:
	var mat := _cached("heat|%s" % seed, func() -> Image:
		return _noise_tex(seed, 0.14, [
			Color("#2a0800"),
			Color("#c04008"),
			Color("#ffb030"),
		], false)
	, 0.2, 0.35)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.08)
	mat.emission_energy_multiplier = 2.8
	mat.emission_texture = mat.albedo_texture
	return mat


static func _cached(key: String, bake: Callable, metallic: float, roughness: float) -> StandardMaterial3D:
	if _cache.has(key):
		return (_cache[key] as StandardMaterial3D).duplicate() as StandardMaterial3D
	var img: Image = bake.call()
	var tex := ImageTexture.create_from_image(img)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.albedo_color = Color.WHITE
	mat.metallic = metallic
	mat.roughness = roughness
	mat.texture_filter = StandardMaterial3D.TEXTURE_FILTER_NEAREST
	mat.uv1_scale = Vector3(2.0, 2.0, 2.0)
	_cache[key] = mat
	return mat.duplicate() as StandardMaterial3D


static func _noise_tex(seed: int, freq: float, ramp: Array, cellular: bool) -> Image:
	var n := FastNoiseLite.new()
	n.seed = seed
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_NONE
	n.noise_type = FastNoiseLite.TYPE_CELLULAR if cellular else FastNoiseLite.TYPE_VALUE
	if cellular:
		n.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
		n.cellular_distance_function = FastNoiseLite.DISTANCE_MANHATTAN
		n.cellular_jitter = 0.35
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([ramp[0], ramp[1], ramp[2]])
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var t := clampf((n.get_noise_2d(float(x), float(y)) + 1.0) * 0.5, 0.0, 1.0)
			var rivet := 0.0
			if x % 16 < 2 or y % 16 < 2:
				rivet = 0.18
			img.set_pixel(x, y, g.sample(t).darkened(rivet))
	return img


static func _wood_tex(seed: int) -> Image:
	var n := FastNoiseLite.new()
	n.seed = seed
	n.frequency = 0.035
	n.noise_type = FastNoiseLite.TYPE_VALUE
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 3
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var dark := Color("#3a2414")
	var light := Color("#8a5a30")
	for y in SIZE:
		for x in SIZE:
			var grain := sin((float(x) * 0.35) + n.get_noise_2d(float(x) * 0.2, float(y)) * 4.0)
			var t := clampf(grain * 0.5 + 0.5, 0.0, 1.0)
			img.set_pixel(x, y, dark.lerp(light, t))
	return img


static func _grid_tex(seed: int, bg: Color, line: Color) -> Image:
	var n := FastNoiseLite.new()
	n.seed = seed
	n.frequency = 0.07
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var d := clampf(n.get_noise_2d(float(x), float(y)), 0.0, 1.0)
			var c := bg
			if x % 8 == 0 or y % 8 == 0:
				c = line.darkened(0.35)
			if d > 0.72:
				c = line
			img.set_pixel(x, y, c)
	return img


static func _stripe_tex(a: Color, b: Color) -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var band := posmod(x + y, 16) < 8
			img.set_pixel(x, y, b if band else a)
	return img
