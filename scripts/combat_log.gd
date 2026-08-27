class_name CombatLog
extends VBoxContainer
## Top-left frag lines. Newest on top; each row fades out and frees itself.

const LIFE := 4.2
const FADE := 0.9
const MAX_LINES := 6


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	name = "CombatLog"
	add_theme_constant_override("separation", 2)


func push(text: String) -> void:
	if text.is_empty():
		return
	var row := Label.new()
	row.text = text
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_font_size_override("font_size", 18)
	row.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55, 0.95))
	row.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	row.add_theme_constant_override("outline_size", 6)
	row.set_meta("life", LIFE)
	add_child(row)
	move_child(row, 0)
	while get_child_count() > MAX_LINES:
		var old := get_child(get_child_count() - 1)
		remove_child(old)
		old.free()


func line_count() -> int:
	return get_child_count()


func _process(delta: float) -> void:
	var dead: Array[Node] = []
	for child in get_children():
		var life := float(child.get_meta("life", LIFE)) - delta
		child.set_meta("life", life)
		var alpha := 1.0 if life > FADE else clampf(life / FADE, 0.0, 1.0)
		child.modulate = Color(1, 1, 1, alpha)
		if life <= 0.0:
			dead.append(child)
	for row in dead:
		row.queue_free()
