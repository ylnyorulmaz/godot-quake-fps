class_name WeaponViewmodel
extends RefCounted
## First-person guns from primitives + WeaponSkin. No GLB assets.

const SkinGen := preload("res://scripts/weapon_skin.gd")


static func build(weapon_id: String) -> Node3D:
	var root := Node3D.new()
	root.name = weapon_id
	match weapon_id:
		"shotgun":
			_shotgun(root)
		"rocket":
			_rocket(root)
		"railgun":
			_rail(root)
		_:
			_machinegun(root)
	return root


static func _machinegun(root: Node3D) -> void:
	var steel := SkinGen.steel(11)
	var mag := SkinGen.blued(19)
	_box(root, Vector3(0.09, 0.1, 0.28), Vector3(0.0, 0.0, -0.04), steel)
	_cyl(root, 0.02, 0.38, Vector3(0.0, 0.02, -0.32), steel)
	_box(root, Vector3(0.05, 0.14, 0.09), Vector3(0.0, -0.1, 0.02), mag)
	_box(root, Vector3(0.07, 0.07, 0.16), Vector3(0.0, -0.02, 0.18), steel)
	_box(root, Vector3(0.03, 0.04, 0.08), Vector3(0.0, 0.07, -0.02), steel)


static func _shotgun(root: Node3D) -> void:
	var wood := SkinGen.wood(41)
	var metal := SkinGen.blued(5)
	_box(root, Vector3(0.07, 0.08, 0.22), Vector3(0.0, -0.01, 0.16), wood)
	_box(root, Vector3(0.08, 0.09, 0.18), Vector3(0.0, 0.0, -0.02), metal)
	_cyl(root, 0.018, 0.42, Vector3(0.018, 0.02, -0.28), metal)
	_cyl(root, 0.018, 0.42, Vector3(-0.018, 0.02, -0.28), metal)
	_box(root, Vector3(0.05, 0.04, 0.12), Vector3(0.0, -0.05, -0.08), metal)
	_box(root, Vector3(0.04, 0.1, 0.04), Vector3(0.0, -0.08, 0.12), wood)


static func _rocket(root: Node3D) -> void:
	var rust := SkinGen.rust(7)
	var steel := SkinGen.steel(3)
	_cyl(root, 0.07, 0.52, Vector3(0.0, 0.02, -0.12), rust)
	_cyl(root, 0.085, 0.1, Vector3(0.0, 0.02, -0.4), rust)
	_box(root, Vector3(0.06, 0.12, 0.1), Vector3(0.0, -0.08, 0.08), steel)
	_box(root, Vector3(0.04, 0.04, 0.14), Vector3(0.0, -0.04, 0.2), steel)
	_box(root, Vector3(0.12, 0.02, 0.08), Vector3(0.0, 0.08, -0.22), rust)


static func _rail(root: Node3D) -> void:
	var steel := SkinGen.blued(61)
	var glow := SkinGen.energy(99)
	_box(root, Vector3(0.07, 0.08, 0.22), Vector3(0.0, 0.0, 0.08), steel)
	_cyl(root, 0.016, 0.62, Vector3(0.0, 0.02, -0.28), glow)
	_ring(root, 0.04, 0.012, Vector3(0.0, 0.02, -0.18), glow)
	_ring(root, 0.04, 0.012, Vector3(0.0, 0.02, -0.32), glow)
	_ring(root, 0.04, 0.012, Vector3(0.0, 0.02, -0.46), glow)
	_box(root, Vector3(0.05, 0.1, 0.06), Vector3(0.0, -0.08, 0.1), steel)


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


static func _cyl(parent: Node3D, radius: float, length: float, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 8
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees.x = 90.0
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


static func _ring(parent: Node3D, radius: float, thickness: float, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius
	mesh.rings = 8
	mesh.ring_segments = 8
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees.x = 90.0
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
