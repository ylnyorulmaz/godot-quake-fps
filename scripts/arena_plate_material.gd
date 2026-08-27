class_name ArenaPlateMaterial
extends Node
## Procedural Quake 3 / retro-arena plate material for MeshInstance3D.
##
## FastNoiseLite cellular cells + a rust/metal Gradient produce a 256×256
## nearest-filtered albedo (and optional normal) that reads as industrial
## deck plates rather than organic terrain. Drop this node under a
## MeshInstance3D, or call `apply_to()` / `make_material()` from code.
##
## Palette defaults: #1a1a1a, #3a2a20, #5a5a5a.

enum Kind { FLOOR, WALL, CEILING, TRIM }

const SIZE := 256
const RUST_BLACK := Color("#1a1a1a")
const RUST_BROWN := Color("#3a2a20")
const METAL_GREY := Color("#5a5a5a")

@export var kind: Kind = Kind.FLOOR
@export var noise_seed: int = 1337
@export var metallic: float = 0.6
@export var roughness: float = 0.4
@export var use_normal_map: bool = true
@export var normal_scale: float = 0.85
@export var uv_scale: float = 0.22
@export var tint: Color = Color.WHITE
@export var apply_on_ready: bool = true

static var _cache: Dictionary = {}


func _ready() -> void:
	if not apply_on_ready:
		return
	var parent_mesh := get_parent() as MeshInstance3D
	if parent_mesh:
		apply_to(parent_mesh, kind, {
			"seed": noise_seed,
			"metallic": metallic,
			"roughness": roughness,
			"use_normal_map": use_normal_map,
			"normal_scale": normal_scale,
			"uv_scale": uv_scale,
			"tint": tint,
		})


static func apply_to(mesh: MeshInstance3D, plate_kind: Kind = Kind.FLOOR, opts: Dictionary = {}) -> StandardMaterial3D:
	if mesh == null:
		return null
	var mat := make_material(plate_kind, opts)
	mesh.material_override = mat
	return mat


static func make_material(plate_kind: Kind = Kind.FLOOR, opts: Dictionary = {}) -> StandardMaterial3D:
	var noise_seed: int = int(opts.get("seed", _default_seed(plate_kind)))
	var use_n := bool(opts.get("use_normal_map", true))
	var uv := float(opts.get("uv_scale", 0.22))
	var tint: Color = opts.get("tint", Color.WHITE)
	var key := "%s|%s|%s|%s|%s" % [plate_kind, noise_seed, use_n, uv, tint]
	if _cache.has(key):
		return (_cache[key] as StandardMaterial3D).duplicate() as StandardMaterial3D

	var baked := _bake_maps(plate_kind, noise_seed, tint)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = baked.albedo
	mat.albedo_color = Color.WHITE
	mat.metallic = float(opts.get("metallic", 0.6))
	mat.roughness = float(opts.get("roughness", 0.4))
	mat.metallic_specular = 0.55
	mat.texture_filter = StandardMaterial3D.TEXTURE_FILTER_NEAREST
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_triplanar_sharpness = 4.0
	mat.uv1_scale = Vector3(uv, uv, uv)
	if use_n:
		mat.normal_enabled = true
		mat.normal_texture = baked.normal
		mat.normal_scale = float(opts.get("normal_scale", 0.85))
	_cache[key] = mat
	return mat.duplicate() as StandardMaterial3D


static func make_gradient(plate_kind: Kind = Kind.FLOOR) -> Gradient:
	var g := Gradient.new()
	match plate_kind:
		Kind.WALL:
			g.offsets = PackedFloat32Array([0.0, 0.42, 0.78, 1.0])
			g.colors = PackedColorArray([
				RUST_BLACK,
				Color("#2a2420"),
				METAL_GREY,
				Color("#6e6a64"),
			])
		Kind.CEILING:
			g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
			g.colors = PackedColorArray([
				Color("#101010"),
				RUST_BLACK,
				Color("#3a3836"),
			])
		Kind.TRIM:
			g.offsets = PackedFloat32Array([0.0, 0.28, 0.62, 1.0])
			g.colors = PackedColorArray([
				RUST_BLACK,
				RUST_BROWN,
				Color("#4a3828"),
				METAL_GREY,
			])
		_:
			g.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
			g.colors = PackedColorArray([
				RUST_BLACK,
				RUST_BROWN,
				Color("#4a4038"),
				METAL_GREY,
			])
	return g


static func _bake_maps(plate_kind: Kind, noise_seed: int, tint: Color) -> Dictionary:
	var cells := FastNoiseLite.new()
	cells.noise_type = FastNoiseLite.TYPE_CELLULAR
	cells.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	cells.cellular_distance_function = FastNoiseLite.DISTANCE_MANHATTAN
	cells.cellular_jitter = 0.28
	cells.frequency = 0.055
	cells.fractal_type = FastNoiseLite.FRACTAL_NONE
	cells.seed = noise_seed

	var edges := FastNoiseLite.new()
	edges.noise_type = FastNoiseLite.TYPE_CELLULAR
	edges.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	edges.cellular_distance_function = FastNoiseLite.DISTANCE_MANHATTAN
	edges.cellular_jitter = 0.28
	edges.frequency = 0.055
	edges.fractal_type = FastNoiseLite.FRACTAL_NONE
	edges.seed = noise_seed

	var gradient := make_gradient(plate_kind)
	var albedo_img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var height_img := Image.create(SIZE, SIZE, false, Image.FORMAT_L8)

	for y in SIZE:
		for x in SIZE:
			var cell := cells.get_noise_2d(float(x), float(y))
			var dist := edges.get_noise_2d(float(x), float(y))
			var plate := clampf((cell + 1.0) * 0.5, 0.0, 1.0)
			var dist01 := clampf(dist, 0.0, 1.0)
			var groove := smoothstep(0.42, 0.82, dist01)
			var color := gradient.sample(plate)
			color = color.lerp(RUST_BLACK, groove * 0.72)
			if tint != Color.WHITE:
				color = color.lerp(tint, 0.42)
			albedo_img.set_pixel(x, y, color)
			var h := clampf(1.0 - groove, 0.0, 1.0)
			height_img.set_pixel(x, y, Color(h, h, h))

	var normal_img := _height_to_normal(height_img, 6.5)
	return {
		"albedo": ImageTexture.create_from_image(albedo_img),
		"normal": ImageTexture.create_from_image(normal_img),
		"height": ImageTexture.create_from_image(height_img),
	}


static func _height_to_normal(height: Image, strength: float) -> Image:
	var w := height.get_width()
	var h := height.get_height()
	var nrm := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var left := _sample_h(height, x - 1, y)
			var right := _sample_h(height, x + 1, y)
			var up := _sample_h(height, x, y - 1)
			var down := _sample_h(height, x, y + 1)
			var n := Vector3((left - right) * strength, (up - down) * strength, 1.0).normalized()
			nrm.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5, 1.0))
	return nrm


static func _sample_h(img: Image, x: int, y: int) -> float:
	var w := img.get_width()
	var h := img.get_height()
	x = posmod(x, w)
	y = posmod(y, h)
	return img.get_pixel(x, y).r


static func _default_seed(plate_kind: Kind) -> int:
	match plate_kind:
		Kind.WALL:
			return 2048
		Kind.CEILING:
			return 4096
		Kind.TRIM:
			return 777
		_:
			return 1337
