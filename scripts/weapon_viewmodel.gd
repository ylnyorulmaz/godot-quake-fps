class_name WeaponViewmodel
extends RefCounted
## First-person guns from primitives + WeaponSkin. No GLB assets.
## Chunky Quake-style silhouettes: chaingun cluster, super shotgun,
## boxy rocket tubes, coiled rail.

const SkinGen := preload("res://scripts/weapon_skin.gd")
const MG_MUZZLE_LOCAL := Vector3(0.0, 0.04, -0.72)


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


static func barrel_cluster(gun: Node3D) -> Node3D:
	if gun == null:
		return null
	return gun.get_node_or_null("BarrelCluster") as Node3D


static func spin_barrels(gun: Node3D, radians: float) -> void:
	var cluster := barrel_cluster(gun)
	if cluster == null or radians == 0.0:
		return
	cluster.rotate_object_local(Vector3.FORWARD, radians)


static func set_muzzle_flash(gun: Node3D, amount: float) -> void:
	var cluster := barrel_cluster(gun)
	if cluster == null:
		return
	var flash := cluster.get_node_or_null("MuzzleFlash") as Node3D
	var light := cluster.get_node_or_null("MuzzleLight") as OmniLight3D
	var heat := cluster.get_node_or_null("MuzzleHeat") as MeshInstance3D
	var t := clampf(amount, 0.0, 1.0)
	if flash:
		flash.visible = t > 0.04
		flash.scale = Vector3.ONE * (0.65 + t * 1.15)
		if t >= 0.95:
			flash.rotation.z = randf() * TAU
	if light:
		light.light_energy = t * 4.2
		light.visible = t > 0.04
	if heat and heat.material_override is StandardMaterial3D:
		var mat := heat.material_override as StandardMaterial3D
		mat.emission_energy_multiplier = 1.6 + t * 4.5


static func _machinegun(root: Node3D) -> void:
	var steel: StandardMaterial3D = SkinGen.steel(11)
	var blued: StandardMaterial3D = SkinGen.blued(19)
	var brass: StandardMaterial3D = SkinGen.brass(53)
	var rubber: StandardMaterial3D = SkinGen.grip(31)
	var hot: StandardMaterial3D = SkinGen.heat(13)
	var rust: StandardMaterial3D = SkinGen.rust(7)
	var stripe: StandardMaterial3D = SkinGen.caution(17)
	# Stepped gothic receiver
	_box(root, Vector3(0.13, 0.14, 0.38), Vector3(0.0, 0.02, 0.0), steel)
	_box(root, Vector3(0.11, 0.09, 0.16), Vector3(0.0, 0.01, 0.22), blued)
	_box(root, Vector3(0.14, 0.03, 0.2), Vector3(0.0, 0.1, -0.04), rust)
	_box(root, Vector3(0.04, 0.05, 0.1), Vector3(0.06, 0.02, 0.08), stripe)
	# Ejection port + cocking handle
	_box(root, Vector3(0.05, 0.04, 0.1), Vector3(-0.08, 0.05, -0.04), blued)
	_box(root, Vector3(0.08, 0.018, 0.018), Vector3(-0.12, 0.06, 0.02), steel)
	# Rotary cluster (spins while firing)
	var cluster := Node3D.new()
	cluster.name = "BarrelCluster"
	cluster.position = Vector3(0.0, 0.04, -0.30)
	root.add_child(cluster)
	_cyl(cluster, 0.02, 0.02, 0.36, Vector3(0.0, 0.0, -0.08), steel)
	_ring(cluster, 0.058, 0.012, Vector3(0.0, 0.0, 0.06), steel)
	_ring(cluster, 0.056, 0.01, Vector3(0.0, 0.0, -0.12), blued)
	_ring(cluster, 0.05, 0.01, Vector3(0.0, 0.0, -0.28), brass)
	for i in 6:
		var ang := float(i) * TAU / 6.0
		var ox := cos(ang) * 0.032
		var oy := sin(ang) * 0.032
		_cyl(cluster, 0.012, 0.01, 0.44, Vector3(ox, oy, -0.14), blued)
		_cyl(cluster, 0.014, 0.014, 0.04, Vector3(ox, oy, -0.36), brass)
	var heat := _disc(cluster, 0.034, Vector3(0.0, 0.0, -0.42), hot)
	heat.name = "MuzzleHeat"
	var flash := _disc(cluster, 0.055, Vector3(0.0, 0.0, -0.46), hot)
	flash.name = "MuzzleFlash"
	flash.visible = false
	var flare := OmniLight3D.new()
	flare.name = "MuzzleLight"
	flare.light_color = Color(1.0, 0.55, 0.12)
	flare.light_energy = 0.0
	flare.omni_range = 1.4
	flare.shadow_enabled = false
	flare.visible = false
	flare.position = Vector3(0.0, 0.0, -0.48)
	cluster.add_child(flare)
	# Static barrel jacket + front sight (does not spin)
	_cyl(root, 0.062, 0.058, 0.1, Vector3(0.0, 0.04, -0.22), steel)
	_box(root, Vector3(0.016, 0.05, 0.04), Vector3(0.0, 0.12, -0.34), steel)
	_box(root, Vector3(0.01, 0.03, 0.01), Vector3(0.0, 0.16, -0.36), brass)
	# Side ammo drum + feed belt
	_cyl(root, 0.07, 0.07, 0.16, Vector3(0.12, -0.01, 0.02), blued)
	_cyl(root, 0.072, 0.072, 0.03, Vector3(0.12, -0.01, 0.1), rust)
	_box(root, Vector3(0.04, 0.04, 0.14), Vector3(0.08, 0.05, -0.08), brass)
	_box(root, Vector3(0.09, 0.03, 0.1), Vector3(0.12, 0.08, 0.02), stripe)
	for i in 8:
		_box(root, Vector3(0.02, 0.015, 0.024), Vector3(0.09, 0.055, -0.02 - float(i) * 0.026), brass)
	# Grip, trigger, stock
	_box(root, Vector3(0.05, 0.14, 0.055), Vector3(0.0, -0.12, 0.12), rubber)
	_box(root, Vector3(0.035, 0.04, 0.07), Vector3(0.0, -0.08, 0.05), steel)
	_box(root, Vector3(0.045, 0.04, 0.16), Vector3(0.0, -0.04, 0.3), rubber)
	_box(root, Vector3(0.08, 0.1, 0.04), Vector3(0.0, -0.02, 0.4), rust)
	# Carrying handle
	_box(root, Vector3(0.018, 0.02, 0.16), Vector3(0.0, 0.16, 0.04), steel)
	_box(root, Vector3(0.018, 0.05, 0.02), Vector3(0.0, 0.14, -0.04), steel)
	_box(root, Vector3(0.018, 0.05, 0.02), Vector3(0.0, 0.14, 0.12), steel)


static func _shotgun(root: Node3D) -> void:
	var wood: StandardMaterial3D = SkinGen.wood(41)
	var metal: StandardMaterial3D = SkinGen.blued(5)
	var brass: StandardMaterial3D = SkinGen.brass(8)
	var rubber: StandardMaterial3D = SkinGen.grip(31)
	# Dual barrels
	_cyl(root, 0.02, 0.02, 0.52, Vector3(0.022, 0.03, -0.3), metal)
	_cyl(root, 0.02, 0.02, 0.52, Vector3(-0.022, 0.03, -0.3), metal)
	_cyl(root, 0.024, 0.024, 0.04, Vector3(0.022, 0.03, -0.56), brass)
	_cyl(root, 0.024, 0.024, 0.04, Vector3(-0.022, 0.03, -0.56), brass)
	# Receiver + pump
	_box(root, Vector3(0.09, 0.1, 0.2), Vector3(0.0, 0.01, -0.02), metal)
	_box(root, Vector3(0.07, 0.06, 0.16), Vector3(0.0, -0.02, -0.2), wood)
	_box(root, Vector3(0.055, 0.045, 0.1), Vector3(0.0, -0.05, -0.18), rubber)
	# Stock
	_box(root, Vector3(0.07, 0.08, 0.18), Vector3(0.0, -0.01, 0.18), wood)
	_box(root, Vector3(0.08, 0.11, 0.06), Vector3(0.0, -0.02, 0.3), wood)
	_box(root, Vector3(0.09, 0.12, 0.03), Vector3(0.0, -0.01, 0.35), rubber)
	# Trigger, rib, bead
	_box(root, Vector3(0.04, 0.05, 0.08), Vector3(0.0, -0.07, 0.06), metal)
	_box(root, Vector3(0.012, 0.012, 0.36), Vector3(0.0, 0.07, -0.18), brass)
	_cyl(root, 0.008, 0.008, 0.02, Vector3(0.0, 0.08, -0.54), brass)


static func _rocket(root: Node3D) -> void:
	var rust: StandardMaterial3D = SkinGen.rust(7)
	var steel: StandardMaterial3D = SkinGen.steel(3)
	var stripe: StandardMaterial3D = SkinGen.caution(17)
	var rubber: StandardMaterial3D = SkinGen.grip(31)
	var hot: StandardMaterial3D = SkinGen.heat(13)
	# Twin tubes
	_cyl(root, 0.055, 0.055, 0.48, Vector3(0.0, 0.05, -0.16), rust)
	_cyl(root, 0.038, 0.038, 0.4, Vector3(0.0, 0.12, -0.12), steel)
	_cyl(root, 0.07, 0.05, 0.1, Vector3(0.0, 0.05, -0.42), rust)
	_cyl(root, 0.048, 0.03, 0.08, Vector3(0.0, 0.05, -0.5), hot)
	_box(root, Vector3(0.12, 0.04, 0.08), Vector3(0.0, 0.05, -0.22), stripe)
	# Body, grip, shoulder
	_box(root, Vector3(0.12, 0.14, 0.22), Vector3(0.0, -0.02, 0.1), steel)
	_box(root, Vector3(0.05, 0.12, 0.05), Vector3(0.0, -0.12, 0.08), rubber)
	_box(root, Vector3(0.04, 0.04, 0.16), Vector3(0.0, -0.06, 0.24), rubber)
	_box(root, Vector3(0.1, 0.08, 0.04), Vector3(0.0, 0.02, 0.24), rust)
	# Sights + side vents
	_box(root, Vector3(0.03, 0.04, 0.1), Vector3(0.0, 0.16, 0.02), steel)
	_box(root, Vector3(0.016, 0.03, 0.016), Vector3(0.0, 0.19, -0.02), rust)
	_box(root, Vector3(0.02, 0.06, 0.08), Vector3(0.08, 0.02, 0.04), stripe)
	_box(root, Vector3(0.02, 0.06, 0.08), Vector3(-0.08, 0.02, 0.04), stripe)
	_light(root, Color(1.0, 0.35, 0.08), 0.9, Vector3(0.0, 0.05, -0.48))


static func _rail(root: Node3D) -> void:
	var steel: StandardMaterial3D = SkinGen.blued(61)
	var glow: StandardMaterial3D = SkinGen.energy(99)
	var rubber: StandardMaterial3D = SkinGen.grip(31)
	var brass: StandardMaterial3D = SkinGen.brass(21)
	# Receiver + stock
	_box(root, Vector3(0.08, 0.09, 0.24), Vector3(0.0, 0.01, 0.1), steel)
	_box(root, Vector3(0.06, 0.08, 0.16), Vector3(0.0, -0.01, 0.26), rubber)
	_box(root, Vector3(0.045, 0.11, 0.05), Vector3(0.0, -0.1, 0.12), rubber)
	# Glowing core and coils
	_cyl(root, 0.014, 0.014, 0.72, Vector3(0.0, 0.03, -0.28), glow)
	for i in 5:
		var z := -0.08 - float(i) * 0.1
		_ring(root, 0.042, 0.01, Vector3(0.0, 0.03, z), glow)
	# Muzzle prongs
	_box(root, Vector3(0.012, 0.07, 0.08), Vector3(0.03, 0.03, -0.62), steel)
	_box(root, Vector3(0.012, 0.07, 0.08), Vector3(-0.03, 0.03, -0.62), steel)
	_disc(root, 0.022, Vector3(0.0, 0.03, -0.66), glow)
	# Energy cell + rails
	_box(root, Vector3(0.05, 0.07, 0.09), Vector3(0.07, 0.0, 0.06), glow)
	_box(root, Vector3(0.02, 0.02, 0.28), Vector3(0.0, 0.08, -0.06), brass)
	_box(root, Vector3(0.03, 0.03, 0.06), Vector3(0.0, 0.1, 0.08), steel)
	_light(root, Color(0.2, 0.85, 1.0), 1.2, Vector3(0.0, 0.03, -0.4))


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _cyl(parent: Node3D, r_top: float, r_bot: float, length: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = r_top
	mesh.bottom_radius = r_bot
	mesh.height = length
	mesh.radial_segments = 12
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees.x = 90.0
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _ring(parent: Node3D, radius: float, thickness: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = maxf(radius - thickness, 0.004)
	mesh.outer_radius = radius
	mesh.rings = 10
	mesh.ring_segments = 10
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees.x = 90.0
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _disc(parent: Node3D, radius: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 0.55
	mesh.radial_segments = 10
	mesh.rings = 6
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _light(parent: Node3D, color: Color, energy: float, pos: Vector3) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 0.55
	light.shadow_enabled = false
	light.position = pos
	parent.add_child(light)
