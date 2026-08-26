class_name StrafeHelper
extends Control

## Two ticks flanking the crosshair at the Q3 optimal air-strafe yaw.
## Angle from velocity: acos(AIR_WISH_SPEED_CAP / speed).

var player: Player
var _theta := 0.0
var _look_error_l := 999.0
var _look_error_r := 999.0
var _active := false
var _px_l := 0.0
var _px_r := 0.0

const TICK_H := 18.0
const WINDOW_DEG := 7.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_right = 0.0
	offset_top = 0.0
	offset_bottom = 0.0


func _process(_delta: float) -> void:
	_refresh()
	queue_redraw()


func _refresh() -> void:
	_active = false
	if player == null or not is_instance_valid(player) or not player.is_alive():
		return
	if player.is_on_floor():
		return
	var horiz := player.horizontal_velocity()
	var speed := horiz.length()
	var cap := player.air_wish_speed_cap()
	if speed <= cap + 0.05:
		return
	_theta = acos(clampf(cap / speed, 0.0, 1.0))
	var vel_yaw := atan2(-horiz.x, -horiz.z)
	var look_yaw := player.look_yaw()
	var ideal_l := vel_yaw - _theta
	var ideal_r := vel_yaw + _theta
	_look_error_l = absf(angle_difference(look_yaw, ideal_l))
	_look_error_r = absf(angle_difference(look_yaw, ideal_r))
	var h_fov := _horizontal_fov()
	if h_fov < 0.001:
		return
	_px_l = angle_difference(look_yaw, ideal_l) / h_fov * size.x
	_px_r = angle_difference(look_yaw, ideal_r) / h_fov * size.x
	_active = true


func _horizontal_fov() -> float:
	var cam := player.camera()
	if cam == null:
		return deg_to_rad(90.0)
	var vfov := deg_to_rad(cam.fov)
	var vp := get_viewport().get_visible_rect().size
	var aspect := vp.x / maxf(vp.y, 1.0)
	return 2.0 * atan(tan(vfov * 0.5) * aspect)


func _draw() -> void:
	if not _active:
		return
	var c := size * 0.5
	_tick(c.x + _px_l, c.y, _look_error_l)
	_tick(c.x + _px_r, c.y, _look_error_r)
	# Faint baseline through the crosshair
	draw_line(Vector2(c.x - 10.0, c.y), Vector2(c.x + 10.0, c.y), Color(1, 0.9, 0.5, 0.12), 1.0)


func _tick(x: float, y: float, error: float) -> void:
	var window := deg_to_rad(WINDOW_DEG)
	var aligned := error < window
	var col := Color(0.35, 0.95, 0.55, 0.95) if aligned else Color(1.0, 0.75, 0.2, 0.7)
	var h := TICK_H if aligned else TICK_H * 0.75
	draw_line(Vector2(x, y - h), Vector2(x, y + h), col, 2.5 if aligned else 2.0)
	draw_line(Vector2(x - 6.0, y - h), Vector2(x + 6.0, y - h), col, 2.0)
	draw_line(Vector2(x - 6.0, y + h), Vector2(x + 6.0, y + h), col, 2.0)
