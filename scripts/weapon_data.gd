class_name WeaponData
extends Resource

## Data-only definition for one weapon. Fire logic lives in WeaponManager.

@export var id: String = "shotgun"
@export var display_name: String = "SHOTGUN"
@export var damage: float = 8.0
@export var fire_rate: float = 0.85
@export var range: float = 80.0
@export var is_hitscan: bool = true
@export var projectile_scene: PackedScene
@export var pellet_count: int = 1
@export var spread_deg: float = 0.0
@export var knockback: float = 4.0
@export var pierce: bool = false
@export var trail_color: Color = Color(1.0, 0.85, 0.3)
@export var trail_thickness: float = 0.03
@export var viewmodel_size: Vector3 = Vector3(0.1, 0.1, 0.55)
@export var viewmodel_color: Color = Color(0.4, 0.4, 0.42)
@export var sound_key: String = "shotgun"
@export var max_ammo: int = 50
@export var splash_radius: float = 6.0
@export var splash_knockback: float = 18.0
@export var projectile_speed: float = 32.0
@export var self_damage_scale: float = 0.55
@export var automatic: bool = false


static func machinegun() -> WeaponData:
	var d := WeaponData.new()
	d.id = "machinegun"
	d.display_name = "MACHINEGUN"
	d.damage = 9.0
	d.fire_rate = 0.09
	d.range = 180.0
	d.is_hitscan = true
	d.pellet_count = 1
	d.spread_deg = 1.0
	d.knockback = 3.5
	d.trail_color = Color(1.0, 0.85, 0.3)
	d.trail_thickness = 0.025
	d.viewmodel_size = Vector3(0.08, 0.08, 0.55)
	d.viewmodel_color = Color(0.25, 0.25, 0.28)
	d.sound_key = "mg"
	d.max_ammo = 200
	d.automatic = true
	return d


static func shotgun() -> WeaponData:
	var d := WeaponData.new()
	d.id = "shotgun"
	d.display_name = "SHOTGUN"
	d.damage = 8.0
	d.fire_rate = 0.85
	d.range = 60.0
	d.is_hitscan = true
	d.pellet_count = 8
	d.spread_deg = 5.2
	d.knockback = 1.8
	d.trail_color = Color(1.0, 0.7, 0.25)
	d.trail_thickness = 0.016
	d.viewmodel_size = Vector3(0.1, 0.1, 0.62)
	d.viewmodel_color = Color(0.45, 0.28, 0.12)
	d.sound_key = "shotgun"
	d.max_ammo = 50
	return d


static func rocket_launcher() -> WeaponData:
	var d := WeaponData.new()
	d.id = "rocket"
	d.display_name = "ROCKET"
	d.damage = 100.0
	d.fire_rate = 0.8
	d.range = 250.0
	d.is_hitscan = false
	d.projectile_scene = load("res://scenes/rocket.tscn") as PackedScene
	d.pellet_count = 1
	d.knockback = 28.0
	d.viewmodel_size = Vector3(0.16, 0.16, 0.7)
	d.viewmodel_color = Color(0.35, 0.12, 0.08)
	d.sound_key = "rocket"
	d.max_ammo = 50
	d.splash_radius = 6.0
	d.splash_knockback = 28.0
	d.projectile_speed = 40.0
	return d


static func railgun() -> WeaponData:
	var d := WeaponData.new()
	d.id = "railgun"
	d.display_name = "RAILGUN"
	d.damage = 80.0
	d.fire_rate = 1.35
	d.range = 250.0
	d.is_hitscan = true
	d.pellet_count = 1
	d.spread_deg = 0.0
	d.knockback = 8.0
	d.pierce = true
	d.trail_color = Color(0.25, 0.95, 1.0)
	d.trail_thickness = 0.07
	d.viewmodel_size = Vector3(0.07, 0.07, 0.8)
	d.viewmodel_color = Color(0.1, 0.45, 0.55)
	d.sound_key = "rail"
	d.max_ammo = 25
	return d
