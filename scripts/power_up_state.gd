class_name PowerUpState
extends Node
## Timed Quad / Haste / Invis. Int kinds so -s tests never need the pickup script.

const QUAD := 0
const HASTE := 1
const INVIS := 2

const DEFAULT_DURATION := 15.0

var duration: float = DEFAULT_DURATION
var quad_left := 0.0
var haste_left := 0.0
var invis_left := 0.0


func apply(kind: int, seconds: float = -1.0) -> bool:
	var t := duration if seconds < 0.0 else seconds
	if t <= 0.0:
		return false
	match kind:
		QUAD:
			quad_left = t
		HASTE:
			haste_left = t
		INVIS:
			invis_left = t
		_:
			return false
	return true


func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	quad_left = maxf(quad_left - delta, 0.0)
	haste_left = maxf(haste_left - delta, 0.0)
	invis_left = maxf(invis_left - delta, 0.0)


func clear() -> void:
	quad_left = 0.0
	haste_left = 0.0
	invis_left = 0.0


func has_quad() -> bool:
	return quad_left > 0.0


func has_haste() -> bool:
	return haste_left > 0.0


func is_invisible() -> bool:
	return invis_left > 0.0


func is_active() -> bool:
	return has_quad() or has_haste() or is_invisible()


func damage_scale() -> float:
	return 4.0 if has_quad() else 1.0


func speed_scale() -> float:
	return 2.0 if has_haste() else 1.0


func overlay_color() -> Color:
	if has_quad() and has_haste():
		return Color(1.0, 0.4, 0.05, 0.72)
	if has_quad():
		return Color(1.0, 0.16, 0.05, 0.78)
	if has_haste():
		return Color(1.0, 0.88, 0.12, 0.68)
	if is_invisible():
		return Color(0.55, 0.88, 1.0, 0.28)
	return Color(1.0, 1.0, 1.0, 0.0)


func screen_tint() -> Color:
	var c := overlay_color()
	if c.a <= 0.001:
		return Color(0.0, 0.0, 0.0, 0.0)
	c.a = minf(c.a * 0.35, 0.28)
	return c


func status_text() -> String:
	var parts: PackedStringArray = PackedStringArray()
	if has_quad():
		parts.append("QUAD %d" % ceili(quad_left))
	if has_haste():
		parts.append("HASTE %d" % ceili(haste_left))
	if is_invisible():
		parts.append("INVIS %d" % ceili(invis_left))
	return "   ".join(parts)
