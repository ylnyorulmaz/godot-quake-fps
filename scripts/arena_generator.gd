class_name ArenaGenerator
extends Node3D
## Procedural CSG deathmatch arena (Quake 3 void / industrial lighting).
##
## Tree:
##   ArenaGenerator (this)
##     NavigationRegion3D
##       CSGCombiner3D
##     JumpPadsContainer
##     MegaHealth, spawn markers, lights, extra pickups

const Layouts := preload("res://scripts/arena_layouts.gd")
const Atmosphere := preload("res://scripts/arena_atmosphere.gd")
const Plate := preload("res://scripts/arena_plate_material.gd")
const PowerUpItem := preload("res://scripts/power_up.gd")
const Neutral := preload("res://scripts/NeutralCreature.gd")
const PickupItem := preload("res://scripts/pickup.gd")
const JumpPadItem := preload("res://scripts/jump_pad.gd")
const TeleporterItem := preload("res://scripts/teleporter.gd")

const FLOOR_SIZE := 100.0
const RAMP_RUN := 18.0
const RAMP_WIDTH := 6.0
const RAMP_ANGLES := [15.0, 30.0, 45.0]
const GAP_WIDTHS := [4.0, 6.0, 8.0, 10.0, 12.0]
const PLATFORM_SIZE := Vector3(8.0, 1.0, 8.0)
const PLATFORM_HEIGHT := 4.0
const HALLWAY_LENGTH := 72.0
const HALLWAY_WIDTH := 4.0
const HALLWAY_HEIGHT := 3.6

var _combiner: CSGCombiner3D
var _pads: Node3D
var _nav_region: NavigationRegion3D
## 0 yard (100m test), 1 tight two-level. Set before add_child / _ready.
@export var layout: int = 0


func floor_size() -> float:
	return Layouts.floor_size(layout)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_build()
	_bake_navigation()


func _build() -> void:
	add_to_group("world_root")
	_environment()
	_ensure_containers()
	_floor_and_hull()
	_ramps()
	if Layouts.is_tight(layout):
		_tight_upper()
	else:
		_gap_course()
	_hallway()
	_cover()
	_jump_pads()
	_teleporters()
	_mega_health()
	_pickups()
	_power_ups()
	_neutrals()
	_spawns()
	_nav_points()
	_lights()
	_labels()


func _bake_navigation() -> void:
	## Bake only the floor plane (not CSG). Parsing CSG at runtime can freeze
	## or crash the renderer, and a 100m BOTH bake is far too heavy for startup.
	await get_tree().physics_frame
	if not is_inside_tree() or _nav_region == null:
		return
	var mesh := NavigationMesh.new()
	mesh.agent_radius = 0.5
	mesh.agent_height = 1.75
	mesh.agent_max_climb = 0.5
	mesh.agent_max_slope = 50.0
	mesh.cell_size = 0.25
	mesh.cell_height = 0.25
	if "border_size" in mesh:
		mesh.border_size = 0.5
	if "geometry_parsed_geometry_type" in mesh:
		mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_MESH_INSTANCES
	elif "parsed_geometry_type" in mesh:
		mesh.parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_MESH_INSTANCES
	_nav_region.navigation_mesh = mesh
	if _nav_region.has_method("bake_navigation_mesh"):
		_nav_region.bake_navigation_mesh(true)
	else:
		var src := NavigationMeshSourceGeometryData3D.new()
		NavigationServer3D.parse_source_geometry_data(mesh, src, _nav_region)
		NavigationServer3D.bake_from_source_geometry_data(mesh, src)
		_nav_region.navigation_mesh = mesh


func _ensure_containers() -> void:
	_nav_region = get_node_or_null("NavigationRegion3D") as NavigationRegion3D
	if _nav_region == null:
		_nav_region = NavigationRegion3D.new()
		_nav_region.name = "NavigationRegion3D"
		add_child(_nav_region)

	_combiner = get_node_or_null("CSGCombiner3D") as CSGCombiner3D
	if _combiner == null:
		_combiner = get_node_or_null("NavigationRegion3D/CSGCombiner3D") as CSGCombiner3D
	if _combiner == null:
		_combiner = CSGCombiner3D.new()
		_combiner.name = "CSGCombiner3D"
		add_child(_combiner)
	elif _combiner.get_parent() != self:
		_combiner.reparent(self)
	_combiner.use_collision = true
	_combiner.collision_layer = 1
	_combiner.collision_mask = 0
	# 4.7 CSG autosmooth/tangents are expensive on a 100m hull and can hitch the first frame.
	if "autosmooth" in _combiner:
		_combiner.autosmooth = false
	if "calculate_tangents" in _combiner:
		_combiner.calculate_tangents = false

	# Invisible parse source so the floor stays walkable even if CSG bake is thin.
	if _nav_region.get_node_or_null("NavFloor") == null:
		var floor_mesh := MeshInstance3D.new()
		floor_mesh.name = "NavFloor"
		var plane := PlaneMesh.new()
		plane.size = Vector2(floor_size() - 2.0, floor_size() - 2.0)
		floor_mesh.mesh = plane
		floor_mesh.position.y = 0.02
		floor_mesh.visible = false
		_nav_region.add_child(floor_mesh)

	_pads = get_node_or_null("JumpPadsContainer") as Node3D
	if _pads == null:
		_pads = Node3D.new()
		_pads.name = "JumpPadsContainer"
		add_child(_pads)


func _environment() -> void:
	if get_node_or_null("WorldEnvironment") != null:
		return
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = Atmosphere.make_environment()
	add_child(we)
	add_child(Atmosphere.make_sun())
	add_child(Atmosphere.make_starfield())


func _floor_and_hull() -> void:
	var size := floor_size()
	# Massive test floor: top face sits on y = 0.
	_csg_box(Vector3(0, -0.5, 0), Vector3(size, 1.0, size), _mat_floor())
	# Perimeter walls keep rocket-jumps and overshoots inside the volume.
	var wall: StandardMaterial3D = _mat_wall()
	var h := 16.0
	var half := size * 0.5 + 0.5
	_csg_box(Vector3(0, h * 0.5, -half), Vector3(size + 1.0, h, 1.0), wall)
	_csg_box(Vector3(0, h * 0.5, half), Vector3(size + 1.0, h, 1.0), wall)
	_csg_box(Vector3(-half, h * 0.5, 0), Vector3(1.0, h, size + 1.0), wall)
	_csg_box(Vector3(half, h * 0.5, 0), Vector3(1.0, h, size + 1.0), wall)
	if not Layouts.is_tight(layout):
		_ceiling_ring(h, wall, size)
		_center_pit(wall)
		_corner_pillars(wall)


func _ceiling_ring(wall_h: float, wall: Material, size: float) -> void:
	var thick := 11.0
	var y := wall_h + 0.25
	var half := size * 0.5
	var ceil_mat: StandardMaterial3D = _mat_ceiling()
	_csg_box(Vector3(0, y, -half + thick * 0.5), Vector3(size, 0.5, thick), ceil_mat)
	_csg_box(Vector3(0, y, half - thick * 0.5), Vector3(size, 0.5, thick), ceil_mat)
	var mid := size - thick * 2.0
	_csg_box(Vector3(-half + thick * 0.5, y, 0), Vector3(thick, 0.5, mid), ceil_mat)
	_csg_box(Vector3(half - thick * 0.5, y, 0), Vector3(thick, 0.5, mid), ceil_mat)
	_csg_box(Vector3(0, wall_h - 0.4, -half + 1.2), Vector3(size - 4.0, 0.12, 0.35), wall)
	_csg_box(Vector3(0, wall_h - 0.4, half - 1.2), Vector3(size - 4.0, 0.12, 0.35), wall)


func _center_pit(wall: Material) -> void:
	const PIT := 16.0
	_csg_box(Vector3(0, -0.5, 0), Vector3(PIT, 2.2, PIT), _mat_floor(), CSGShape3D.OPERATION_SUBTRACTION)
	_csg_box(Vector3(0, -3.5, 0), Vector3(PIT, 1.0, PIT), Atmosphere.lava_material())
	_csg_box(Vector3(-(PIT * 0.5 + 0.4), -1.75, 0), Vector3(0.8, 3.5, PIT + 1.6), wall)
	_csg_box(Vector3(PIT * 0.5 + 0.4, -1.75, 0), Vector3(0.8, 3.5, PIT + 1.6), wall)
	var rust := Color(0.42, 0.22, 0.1)
	var angle := rad_to_deg(atan(3.0 / 5.6))
	_ramp_polygon(Vector3(0.0, -3.0, 2.5), 5.6, angle, 3.0, -90.0, rust)
	_ramp_polygon(Vector3(0.0, -3.0, -2.5), 5.6, angle, 3.0, 90.0, rust)


func _corner_pillars(wall: Material) -> void:
	for xz in [Vector3(42, 8, 42), Vector3(-42, 8, 42), Vector3(42, 8, -42), Vector3(-42, 8, -42)]:
		_csg_box(xz, Vector3(3.2, 16.0, 3.2), wall)


func _ramps() -> void:
	## Three side-by-side ramps: 15°, 30°, 45°. Walk up and down to feel
	## ground friction, air-control, and slope-launch differences.
	var origin_x := 8.0
	var z0 := -18.0 if Layouts.is_tight(layout) else -32.0
	var spacing := RAMP_WIDTH + 2.0
	var colors := [
		Color(0.22, 0.55, 0.28),
		Color(0.75, 0.55, 0.12),
		Color(0.78, 0.22, 0.14),
	]
	for i in RAMP_ANGLES.size():
		var angle: float = RAMP_ANGLES[i]
		var z := z0 + float(i) * spacing
		_ramp_polygon(Vector3(origin_x, 0.0, z), RAMP_RUN, angle, RAMP_WIDTH, 0.0, colors[i])
		# Landing shelf at the top so you can stand, turn around, and run down.
		var rise := RAMP_RUN * tan(deg_to_rad(angle))
		_csg_box(
			Vector3(origin_x + RAMP_RUN + 3.0, rise * 0.5, z),
			Vector3(6.0, rise, RAMP_WIDTH),
			_grid_mat(colors[i], colors[i].lightened(0.18))
		)


func _gap_course() -> void:
	## Elevated platforms with growing gaps (4 → 12). Strafe-jump across;
	## falling lands on the main floor so the test can be repeated quickly.
	var x := -30.0
	var z := 6.0
	var plat_len := PLATFORM_SIZE.z
	var mat := _grid_mat(Color(0.18, 0.32, 0.62), Color(0.28, 0.48, 0.85))
	_csg_box(Vector3(x, PLATFORM_HEIGHT - PLATFORM_SIZE.y * 0.5, z), PLATFORM_SIZE, mat)
	for gap in GAP_WIDTHS:
		z += plat_len * 0.5 + gap + plat_len * 0.5
		_csg_box(Vector3(x, PLATFORM_HEIGHT - PLATFORM_SIZE.y * 0.5, z), PLATFORM_SIZE, mat)
	# Staircase onto the first platform so you do not need a pad to start.
	_ramp_polygon(Vector3(x - PLATFORM_SIZE.x * 0.5 - 10.0, 0.0, 6.0), 10.0, rad_to_deg(atan(PLATFORM_HEIGHT / 10.0)), PLATFORM_SIZE.x, 0.0, Color(0.2, 0.36, 0.7))


func _tight_upper() -> void:
	## Two-level catwalk ring for the compact map.
	var plat := _grid_mat(Color(0.28, 0.24, 0.2), Color(0.4, 0.34, 0.28))
	_csg_box(Vector3(0, 6.0, 18), Vector3(24, 0.4, 5), plat)
	_csg_box(Vector3(0, 6.0, -18), Vector3(24, 0.4, 5), plat)
	_csg_box(Vector3(18, 6.0, 0), Vector3(5, 0.4, 24), plat)
	_csg_box(Vector3(-18, 6.0, 0), Vector3(5, 0.4, 24), plat)
	for xz in [Vector3(18, 6.0, 18), Vector3(-18, 6.0, 18), Vector3(18, 6.0, -18), Vector3(-18, 6.0, -18)]:
		_csg_box(xz, Vector3(6, 0.4, 6), plat)
	_ramp_polygon(Vector3(4.0, 0.0, 18.0), 12.0, rad_to_deg(atan(6.0 / 12.0)), 3.2, 90.0, Color(0.36, 0.22, 0.1))
	_ramp_polygon(Vector3(-4.0, 0.0, -18.0), 12.0, rad_to_deg(atan(6.0 / 12.0)), 3.2, -90.0, Color(0.36, 0.22, 0.1))
	_item(Vector3(18, 7.3, 18), Pickup.Kind.RAIL, 25.0)
	_item(Vector3(-18, 7.3, -18), Pickup.Kind.ARMOR, 20.0)


func _hallway() -> void:
	## Narrow enclosed corridor along +X. Sprint / bhop through it to judge
	## speed perception and the player's dynamic FOV ceiling.
	var wall_mat := _grid_mat(Color(0.45, 0.16, 0.12), Color(0.62, 0.22, 0.16))
	var ceil_mat := _grid_mat(Color(0.12, 0.12, 0.14), Color(0.2, 0.2, 0.22))
	var floor_mat := _grid_mat(Color(0.55, 0.5, 0.18), Color(0.75, 0.68, 0.22))
	var z := 18.0 if Layouts.is_tight(layout) else 36.0
	var x_mid := 0.0
	var half_w := HALLWAY_WIDTH * 0.5
	var hall_len := 36.0 if Layouts.is_tight(layout) else HALLWAY_LENGTH
	# Distinct floor stripe so the corridor reads as a speed trap.
	_csg_box(Vector3(x_mid, 0.06, z), Vector3(hall_len, 0.12, HALLWAY_WIDTH), floor_mat)
	# Walls
	_csg_box(
		Vector3(x_mid, HALLWAY_HEIGHT * 0.5, z - half_w - 0.25),
		Vector3(hall_len, HALLWAY_HEIGHT, 0.5),
		wall_mat
	)
	_csg_box(
		Vector3(x_mid, HALLWAY_HEIGHT * 0.5, z + half_w + 0.25),
		Vector3(hall_len, HALLWAY_HEIGHT, 0.5),
		wall_mat
	)
	# Ceiling
	_csg_box(
		Vector3(x_mid, HALLWAY_HEIGHT + 0.15, z),
		Vector3(hall_len, 0.3, HALLWAY_WIDTH + 1.0),
		ceil_mat
	)
	# Far cap
	_csg_box(
		Vector3(hall_len * 0.5 - 0.25, HALLWAY_HEIGHT * 0.5, z),
		Vector3(0.5, HALLWAY_HEIGHT, HALLWAY_WIDTH + 1.0),
		wall_mat
	)


func _cover() -> void:
	var crate := _grid_mat(Color(0.4, 0.28, 0.12), Color(0.55, 0.38, 0.16))
	for p in [Vector3(18, 1.0, 12), Vector3(-12, 1.0, -8), Vector3(22, 1.0, -18), Vector3(-22, 1.0, 18)]:
		_csg_box(p, Vector3(2.4, 2.0, 2.4), crate)


func _jump_pads() -> void:
	if Layouts.is_tight(layout):
		_add_pad(Vector3(0.0, 0.08, 0.0), Vector3(0, 22, 0), 0.0)
		_add_pad(Vector3(-12.0, 0.08, -4.0), Vector3(-4, 14, 8), 0.0)
		_add_pad(Vector3(-16.0, 0.08, 18.0), Vector3(14, 8, 0), 0.0)
		_add_pad(Vector3(16.0, 6.2, 16.0), Vector3(0, 14, 0), 0.0)
		return
	# Vertical pop from the lava pit (Q3 center pad).
	_add_pad(Vector3(0.0, -2.88, 0.0), Vector3(0, 24, 0), 0.0)
	# Aimed at the gap course start.
	_add_pad(Vector3(-18.0, 0.08, -4.0), Vector3(-8, 14, 10), 0.0)
	# Hallway injector: long, low launch so you enter already at speed.
	_add_pad(Vector3(-40.0, 0.08, 36.0), Vector3(28, 6, 0), 0.0)
	# Top of the 45° ramp — extra height for air-control practice.
	var rise45 := RAMP_RUN * tan(deg_to_rad(45.0))
	_add_pad(Vector3(8.0 + RAMP_RUN + 3.0, rise45 + 0.08, -32.0 + 2.0 * (RAMP_WIDTH + 2.0)), Vector3(-4, 16, 0), 0.0)


func _add_pad(pos: Vector3, boost: Vector3, yaw_deg: float) -> void:
	var packed := load("res://scenes/jump_pad.tscn") as PackedScene
	var pad: JumpPadItem
	if packed != null:
		pad = packed.instantiate() as JumpPadItem
	else:
		pad = JumpPadItem.new()
	pad.boost = boost
	pad.position = pos
	pad.rotation_degrees.y = yaw_deg
	_pads.add_child(pad)


func _teleporters() -> void:
	var a := TeleporterItem.new()
	a.name = "TeleporterA"
	a.position = Vector3(34.0, 1.0, 36.0)
	a.target = Vector3(-38.0, 1.2, -38.0)
	add_child(a)
	var b := TeleporterItem.new()
	b.name = "TeleporterB"
	b.position = Vector3(-34.0, 1.0, -36.0)
	b.target = Vector3(38.0, 1.2, 38.0)
	add_child(b)


func _mega_health() -> void:
	var packed := load("res://scenes/mega_health.tscn") as PackedScene
	var item: Node3D
	if packed != null:
		item = packed.instantiate() as Node3D
	else:
		item = (load("res://scripts/mega_health.gd") as GDScript).new() as Node3D
	item.position = Vector3(18.0, 1.1, -14.0)
	add_child(item)


func _pickups() -> void:
	# Keep deathmatch usable while this arena is the active map.
	_item(Vector3(16, 1.2, 16), PickupItem.Kind.ROCKET, 20.0)
	_item(Vector3(-16, 1.2, 16), PickupItem.Kind.SHOTGUN, 15.0)
	_item(Vector3(16, 1.2, -16), PickupItem.Kind.RAIL, 25.0)
	_item(Vector3(-16, 1.2, -16), PickupItem.Kind.ARMOR, 20.0)
	var hall_z := 18.0 if Layouts.is_tight(layout) else 36.0
	_item(Vector3(10, 1.2, hall_z), PickupItem.Kind.RL_AMMO, 15.0)
	_item(Vector3(-10, 1.2, hall_z), PickupItem.Kind.HEALTH, 10.0)
	_item(Vector3(-16, 1.2, 8), PickupItem.Kind.SG_AMMO, 12.0)
	_item(Vector3(16, 1.2, -8), PickupItem.Kind.RAIL_AMMO, 15.0)
	if not Layouts.is_tight(layout):
		_item(Vector3(-30, PLATFORM_HEIGHT + 1.2, 6), PickupItem.Kind.MG_AMMO, 10.0)
		_item(Vector3(30, 1.2, -6), PickupItem.Kind.MG_AMMO, 10.0)
		_item(Vector3(-8, 1.2, -28), PickupItem.Kind.SG_AMMO, 12.0)
		_item(Vector3(8, 1.2, 28), PickupItem.Kind.RAIL_AMMO, 15.0)


func _item(pos: Vector3, kind: int, respawn: float) -> void:
	var p := PickupItem.new()
	p.configure(kind, respawn)
	p.position = pos
	add_child(p)


func _power_ups() -> void:
	_power_item(Vector3(0.0, 1.25, 12.0), PowerUpItem.Kind.QUAD, false)
	_power_item(Vector3(22.0, 1.25, 0.0), PowerUpItem.Kind.HASTE, false)
	_power_item(Vector3(-22.0, 1.25, 0.0), PowerUpItem.Kind.INVIS, false)
	_power_item(Vector3(0.0, 1.25, -12.0), PowerUpItem.Kind.QUAD, true)


func _power_item(pos: Vector3, kind: int, wild: bool) -> void:
	var item := PowerUpItem.new()
	item.configure(kind, 30.0, 15.0)
	item.position = pos
	item.relocate_on_respawn = wild
	item.randomize_kind_on_respawn = wild
	add_child(item)


func _neutrals() -> void:
	for pos in [Vector3(8.0, 1.2, -28.0), Vector3(-12.0, 1.2, 28.0)]:
		var critter := Neutral.new()
		critter.position = pos
		add_child(critter)


func _spawns() -> void:
	var pts: Array
	if Layouts.is_tight(layout):
		pts = [
			Vector3(22, 1.2, 22), Vector3(-22, 1.2, 22), Vector3(22, 1.2, -22),
			Vector3(-22, 1.2, -22), Vector3(0, 1.2, 14), Vector3(0, 1.2, -14),
			Vector3(18, 7.4, 0), Vector3(-18, 7.4, 0),
		]
	else:
		pts = [
			Vector3(40, 1.2, 40), Vector3(-40, 1.2, 40), Vector3(40, 1.2, -40),
			Vector3(-40, 1.2, -40), Vector3(0, 1.2, 20), Vector3(0, 1.2, -20),
			Vector3(24, 1.2, 0), Vector3(-24, 1.2, 0),
		]
	for p in pts:
		var m := Marker3D.new()
		m.position = p
		m.add_to_group("spawn_points")
		add_child(m)


func _nav_points() -> void:
	var pts: Array
	if Layouts.is_tight(layout):
		pts = [
			Vector3(16, 1, 16), Vector3(-16, 1, 16), Vector3(16, 1, -16), Vector3(-16, 1, -16),
			Vector3(0, 1, 0), Vector3(18, 7, 0), Vector3(-18, 7, 0), Vector3(0, 7, 18),
		]
	else:
		pts = [
			Vector3(20, 1, 20), Vector3(-20, 1, 20), Vector3(20, 1, -20), Vector3(-20, 1, -20),
			Vector3(0, -2, 0), Vector3(-30, 5, 20), Vector3(20, 4, -20), Vector3(0, 1, 36),
		]
	for p in pts:
		var m := Marker3D.new()
		m.position = p
		m.add_to_group("nav_points")
		add_child(m)


func _lights() -> void:
	for entry in Atmosphere.light_rig():
		var pos: Vector3 = entry["pos"]
		var color: Color = entry["color"]
		var energy: float = float(entry["energy"])
		var omni_range: float = float(entry["range"])
		add_child(Atmosphere.make_fill_light(pos, color, energy, omni_range))


func _labels() -> void:
	if Layouts.is_tight(layout):
		_billboard(Vector3(0.0, 8.5, 18.0), "UPPER")
		return
	_billboard(Vector3(8.0 + RAMP_RUN * 0.5, 2.4, -32.0), "15° RAMP")
	_billboard(Vector3(8.0 + RAMP_RUN * 0.5, 4.0, -24.0), "30° RAMP")
	_billboard(Vector3(8.0 + RAMP_RUN * 0.5, 6.0, -16.0), "45° RAMP")
	_billboard(Vector3(-30.0, PLATFORM_HEIGHT + 2.5, 6.0), "STRAFE GAPS  4–12")
	_billboard(Vector3(-20.0, 2.8, 36.0), "SPEED HALLWAY")


func _billboard(pos: Vector3, text: String) -> void:
	var lab := Label3D.new()
	lab.text = text
	lab.position = pos
	lab.font_size = 64
	lab.modulate = Color(1.0, 0.92, 0.45)
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.outline_size = 8
	lab.outline_modulate = Color(0, 0, 0, 0.85)
	add_child(lab)


func _ramp_polygon(origin: Vector3, run: float, angle_deg: float, width: float, yaw_deg: float, color: Color) -> void:
	## Walkable slope as a CSGBox3D slab rotated to `angle_deg`.
	## (CSGPolygon3D wedges are valid visually in-editor but Godot's CSG brush
	## pass often drops the extruded triangle, so the box is the collision source.)
	var rise := run * tan(deg_to_rad(angle_deg))
	var angle := deg_to_rad(angle_deg)
	var thickness := 0.4
	var slab := CSGBox3D.new()
	slab.size = Vector3(run, thickness, width)
	slab.material = _grid_mat(color, color.lightened(0.2))
	# Rotated brushes cannot live inside CSGCombiner3D (Godot drops faces).
	slab.use_collision = true
	slab.collision_layer = 1
	slab.collision_mask = 0
	add_child(slab)
	slab.rotation_degrees.y = yaw_deg
	var local_mid := Vector3(run * 0.5, (rise * 0.5) + thickness * 0.5, 0.0)
	slab.position = origin + Basis(Vector3.UP, deg_to_rad(yaw_deg)) * local_mid
	slab.rotate_object_local(Vector3.RIGHT, -angle)


func _csg_box(center: Vector3, size: Vector3, mat: Material, operation: int = CSGShape3D.OPERATION_UNION) -> CSGBox3D:
	var b := CSGBox3D.new()
	b.size = size
	b.position = center
	b.material = mat
	b.operation = operation
	_combiner.add_child(b)
	return b


func _mat_floor() -> StandardMaterial3D:
	return _lit_plate(Plate.Kind.FLOOR, Color(0.92, 0.84, 0.74))


func _mat_wall() -> StandardMaterial3D:
	return _lit_plate(Plate.Kind.WALL, Color(0.78, 0.7, 0.62))


func _mat_ceiling() -> StandardMaterial3D:
	return _lit_plate(Plate.Kind.CEILING, Color(0.55, 0.52, 0.5))


func _grid_mat(a: Color, b: Color) -> StandardMaterial3D:
	var mat := Plate.make_material(Plate.Kind.TRIM)
	mat.albedo_color = a.lerp(b, 0.45).lightened(0.08)
	mat.metallic = 0.18
	mat.roughness = 0.62
	return mat


func _lit_plate(kind: int, albedo: Color) -> StandardMaterial3D:
	var mat := Plate.make_material(kind)
	mat.albedo_color = albedo
	mat.metallic = 0.18
	mat.roughness = 0.62
	return mat
