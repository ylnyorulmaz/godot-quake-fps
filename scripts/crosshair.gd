class_name Crosshair
extends Control
## Dynamic Q3-style crosshair: weapon shape, movement/fire gap, hit flash.

enum Kind { MG, SHOTGUN, ROCKET, RAIL }

var player: Node
var kind: int = Kind.MG
var ammo: int = 1
var _gap := 5.0
var _punch := 0.0
var _hit := 0.0
var _pulse := 0.0
var _last_kind := -1

const SIZE_PX := 96.0
const PUNCH_DECAY := 9.0
const HIT_DECAY := 8.0
const GAP_LERP := 18.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	name = "Crosshair"
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(SIZE_PX, SIZE_PX)
	offset_left = -SIZE_PX * 0.5
	offset_right = SIZE_PX * 0.5
	offset_top = -SIZE_PX * 0.5
	offset_bottom = SIZE_PX * 0.5
	z_index = 2


func bind_weapons(wm: Node) -> void:
	if wm == null:
		return
	if wm.has_signal("fired") and not wm.fired.is_connected(on_fired):
		wm.fired.connect(on_fired)
	if wm.has_signal("hit_landed") and not wm.hit_landed.is_connected(on_hit):
		wm.hit_landed.connect(on_hit)


func on_fired() -> void:
	_punch = 1.0


func on_hit() -> void:
	_hit = 1.0


func punch_amount() -> float:
	return _punch


func hit_amount() -> float:
	return _hit


func gap_amount() -> float:
	return _gap


func _process(delta: float) -> void:
	_pulse += delta
	_punch = maxf(_punch - delta * PUNCH_DECAY, 0.0)
	_hit = maxf(_hit - delta * HIT_DECAY, 0.0)
	_sync_from_player()
	if kind != _last_kind:
		_gap = rest_gap(kind)
		_last_kind = kind
	var target := dynamic_gap(
		kind,
		_speed_ups(),
		_airborne(),
		_crouching(),
		_punch
	)
	_gap = lerpf(_gap, target, 1.0 - exp(-GAP_LERP * delta))
	queue_redraw()


func _sync_from_player() -> void:
	if player == null or not is_instance_valid(player):
		return
	if not "weapons" in player or player.weapons == null:
		return
	var wm = player.weapons
	kind = int(wm.get("current"))
	if wm.has_method("current_ammo"):
		ammo = int(wm.current_ammo())


func _speed_ups() -> float:
	if player != null and player.has_method("speed_ups"):
		return float(player.call("speed_ups"))
	return 0.0


func _airborne() -> bool:
	if player != null and player.has_method("is_on_floor"):
		return not bool(player.call("is_on_floor"))
	return false


func _crouching() -> bool:
	if player != null and player.has_method("is_crouching"):
		return bool(player.call("is_crouching"))
	return false


static func rest_gap(p_kind: int) -> float:
	match p_kind:
		Kind.SHOTGUN:
			return 11.0
		Kind.ROCKET:
			return 7.0
		Kind.RAIL:
			return 2.5
		_:
			return 4.5


static func low_ammo_limit(p_kind: int) -> int:
	match p_kind:
		Kind.MG:
			return 20
		Kind.RAIL:
			return 3
		_:
			return 3


static func dynamic_gap(p_kind: int, speed_ups: float, airborne: bool, crouching: bool, punch: float) -> float:
	var gap := rest_gap(p_kind)
	gap += clampf(speed_ups / 90.0, 0.0, 1.35) * 7.0
	if airborne:
		gap += 3.5
	if crouching:
		gap *= 0.72
	gap += clampf(punch, 0.0, 1.0) * 9.0
	return clampf(gap, 1.5, 28.0)


static func color_for(p_kind: int, p_ammo: int) -> Color:
	if p_ammo <= 0:
		return Color(1.0, 0.16, 0.1, 0.95)
	var col := _weapon_color(p_kind)
	if p_ammo <= low_ammo_limit(p_kind):
		return col.lerp(Color(1.0, 0.82, 0.12, 0.95), 0.55)
	return col


static func _weapon_color(p_kind: int) -> Color:
	match p_kind:
		Kind.SHOTGUN:
			return Color(1.0, 0.48, 0.12, 0.95)
		Kind.ROCKET:
			return Color(1.0, 0.28, 0.1, 0.95)
		Kind.RAIL:
			return Color(0.25, 0.92, 1.0, 0.95)
		_:
			return Color(1.0, 0.82, 0.22, 0.95)


func _draw() -> void:
	var c := size * 0.5
	var col := color_for(kind, ammo)
	if ammo <= 0:
		col.a = 0.55 + 0.4 * (0.5 + 0.5 * sin(_pulse * 8.0))
	elif ammo <= low_ammo_limit(kind):
		col.a = 0.72 + 0.23 * (0.5 + 0.5 * sin(_pulse * 6.0))
	match kind:
		Kind.ROCKET:
			_draw_rocket(c, col)
		Kind.SHOTGUN:
			_draw_shotgun(c, col)
		Kind.RAIL:
			_draw_rail(c, col)
		_:
			_draw_mg(c, col)
	if _hit > 0.02:
		_draw_hit(c)


func _draw_mg(c: Vector2, col: Color) -> void:
	_draw_plus(c, col, 9.0, 2.05, true)
	_draw_rest_ticks(c, col)


func _draw_plus(c: Vector2, col: Color, arm: float, thick: float, center_dot: bool) -> void:
	var g := _gap
	_bar(Vector2(c.x, c.y - g - arm), Vector2(c.x, c.y - g), col, thick)
	_bar(Vector2(c.x, c.y + g), Vector2(c.x, c.y + g + arm), col, thick)
	_bar(Vector2(c.x - g - arm, c.y), Vector2(c.x - g, c.y), col, thick)
	_bar(Vector2(c.x + g, c.y), Vector2(c.x + g + arm, c.y), col, thick)
	if center_dot and g < 10.0:
		_dot(c, 1.55, col)


func _draw_rest_ticks(c: Vector2, col: Color) -> void:
	var rest := rest_gap(kind)
	if _gap <= rest + 1.2:
		return
	var tick := Color(col.r, col.g, col.b, col.a * 0.38)
	var t := 3.2
	_bar(Vector2(c.x, c.y - rest - t), Vector2(c.x, c.y - rest), tick, 1.2)
	_bar(Vector2(c.x, c.y + rest), Vector2(c.x, c.y + rest + t), tick, 1.2)
	_bar(Vector2(c.x - rest - t, c.y), Vector2(c.x - rest, c.y), tick, 1.2)
	_bar(Vector2(c.x + rest, c.y), Vector2(c.x + rest + t, c.y), tick, 1.2)


func _draw_shotgun(c: Vector2, col: Color) -> void:
	_draw_plus(c, col, 7.0, 2.2, false)
	var r := _gap + 6.0
	for i in 8:
		var a := TAU * float(i) / 8.0 + PI * 0.125
		var p := c + Vector2(cos(a), sin(a)) * r
		_dot(p, 1.4, col)


func _draw_rocket(c: Vector2, col: Color) -> void:
	var r := _gap + 5.5
	_ring(c, r + 3.5, Color(col.r, col.g, col.b, col.a * 0.4), 1.2)
	_ring(c, r, col, 2.05)
	_draw_plus(c, col, 5.5, 1.8, true)


func _draw_rail(c: Vector2, col: Color) -> void:
	var glow := Color(col.r, col.g, col.b, col.a * 0.28)
	var g := _gap
	var arm := 14.0
	draw_line(Vector2(c.x, c.y - g - arm), Vector2(c.x, c.y + g + arm), glow, 5.5, false)
	draw_line(Vector2(c.x - g - arm, c.y), Vector2(c.x + g + arm, c.y), glow, 5.5, false)
	_draw_plus(c, col, 13.0, 1.55, true)
	var inner := Color(col.r, col.g, col.b, col.a * 0.55)
	_ring(c, _gap + 3.0, inner, 1.15)


func _draw_hit(c: Vector2) -> void:
	var a := clampf(_hit, 0.0, 1.0)
	var col := Color(1.0, 0.95, 0.35, 0.22 + 0.78 * a)
	var d := 5.0 + (1.0 - a) * 8.0
	var s := 5.4
	_bar(c + Vector2(-d, -d), c + Vector2(-d + s, -d + s), col, 2.15)
	_bar(c + Vector2(d, -d), c + Vector2(d - s, -d + s), col, 2.15)
	_bar(c + Vector2(-d, d), c + Vector2(-d + s, d - s), col, 2.15)
	_bar(c + Vector2(d, d), c + Vector2(d - s, d - s), col, 2.15)


func _bar(from: Vector2, to: Vector2, col: Color, thick: float) -> void:
	draw_line(from + Vector2(0.0, 1.0), to + Vector2(0.0, 1.0), Color(0.0, 0.0, 0.0, col.a * 0.65), thick + 3.0, false)
	draw_line(from, to, Color(0.0, 0.0, 0.0, col.a), thick + 2.3, false)
	draw_line(from, to, col, thick, false)
	var hi := Color(minf(col.r + 0.28, 1.0), minf(col.g + 0.22, 1.0), minf(col.b + 0.16, 1.0), col.a * 0.8)
	draw_line(from, to, hi, maxf(thick - 1.05, 0.7), false)


func _dot(at: Vector2, radius: float, col: Color) -> void:
	draw_circle(at + Vector2(0.0, 1.0), radius + 1.4, Color(0.0, 0.0, 0.0, col.a * 0.55))
	draw_circle(at, radius + 1.25, Color(0.0, 0.0, 0.0, col.a))
	draw_circle(at, radius, col)


func _ring(at: Vector2, radius: float, col: Color, thick: float) -> void:
	draw_arc(at, radius, 0.0, TAU, 40, Color(0.0, 0.0, 0.0, col.a), thick + 2.1, false)
	draw_arc(at, radius, 0.0, TAU, 40, col, thick, false)
