class_name ExplosionFx
extends Node3D

var _age := 0.0
const LIFE := 0.45
var _sphere: MeshInstance3D
var _light: OmniLight3D


func _ready() -> void:
	_sphere = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.4
	mesh.height = 0.8
	_sphere.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.55, 0.15, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.05)
	mat.emission_energy_multiplier = 6.0
	_sphere.material_override = mat
	add_child(_sphere)

	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.55, 0.15)
	_light.light_energy = 8.0
	_light.omni_range = 12.0
	add_child(_light)


func _process(delta: float) -> void:
	_age += delta
	var t := _age / LIFE
	var s := lerpf(0.5, 7.0, t)
	_sphere.scale = Vector3.ONE * s
	if _sphere.material_override is StandardMaterial3D:
		var mat := _sphere.material_override as StandardMaterial3D
		mat.albedo_color.a = 1.0 - t
	_light.light_energy = lerpf(8.0, 0.0, t)
	if _age >= LIFE:
		queue_free()
