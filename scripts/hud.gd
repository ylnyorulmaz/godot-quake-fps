class_name HUD
extends CanvasLayer

var player: Player
var _health: Label
var _armor: Label
var _ammo: Label
var _weapon: Label
var _speed: Label
var _score: Label
var _cross: Control
var _hurt: ColorRect
var _scoreboard: Label
var _hint: Label


func _ready() -> void:
	layer = 20
	_hurt = ColorRect.new()
	_hurt.color = Color(0.7, 0.05, 0.0, 0.0)
	_hurt.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hurt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hurt)

	_cross = Control.new()
	_cross.set_anchors_preset(Control.PRESET_CENTER)
	_cross.custom_minimum_size = Vector2(24, 24)
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cross)
	_cross.draw.connect(_draw_cross)

	_health = _label(Vector2(40, -90), 42, Color(0.95, 0.25, 0.15), HORIZONTAL_ALIGNMENT_LEFT)
	_health.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_health.position = Vector2(40, -90)

	_armor = _label(Vector2(40, -48), 28, Color(0.95, 0.8, 0.2), HORIZONTAL_ALIGNMENT_LEFT)
	_armor.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_armor.position = Vector2(40, -48)

	_ammo = _label(Vector2(-220, -90), 42, Color(0.95, 0.85, 0.4), HORIZONTAL_ALIGNMENT_RIGHT)
	_ammo.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_ammo.position = Vector2(-220, -90)

	_weapon = _label(Vector2(-280, -48), 22, Color(0.75, 0.75, 0.7), HORIZONTAL_ALIGNMENT_RIGHT)
	_weapon.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_weapon.position = Vector2(-280, -48)

	_speed = _label(Vector2(-140, 16), 18, Color(0.7, 0.7, 0.65), HORIZONTAL_ALIGNMENT_RIGHT)
	_speed.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_speed.position = Vector2(-140, 16)

	_score = _label(Vector2(16, 16), 22, Color(0.95, 0.9, 0.75), HORIZONTAL_ALIGNMENT_LEFT)
	_score.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_score.position = Vector2(16, 16)

	_hint = _label(Vector2(16, -28), 16, Color(0.6, 0.6, 0.55), HORIZONTAL_ALIGNMENT_LEFT)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.position = Vector2(16, -28)
	_hint.text = "WASD  mouse  SPACE jump  SHIFT sprint  CTRL crouch  LMB fire  1-4 / wheel  ESC"

	_scoreboard = Label.new()
	_scoreboard.visible = false
	_scoreboard.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scoreboard.add_theme_font_size_override("font_size", 28)
	_scoreboard.add_theme_color_override("font_color", Color(1, 0.92, 0.75))
	_scoreboard.set_anchors_preset(Control.PRESET_CENTER)
	_scoreboard.position = Vector2(-220, -140)
	_scoreboard.size = Vector2(440, 280)
	add_child(_scoreboard)

	GameState.scores_changed.connect(_refresh_score)


func _label(pos: Vector2, size: int, color: Color, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.position = pos
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)
	return l


func _draw_cross() -> void:
	var c := Color(1, 0.92, 0.4, 0.85)
	_cross.draw_rect(Rect2(10, 0, 4, 24), c)
	_cross.draw_rect(Rect2(0, 10, 24, 4), c)
	_cross.draw_rect(Rect2(11, 11, 2, 2), Color(0, 0, 0))


func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_health.text = "%d" % int(player.health)
	_armor.text = "ARMOR %d" % int(player.armor)
	_ammo.text = "%d" % player.weapons.current_ammo()
	_weapon.text = player.weapons.current_name()
	var spd := Vector3(player.velocity.x, 0, player.velocity.z).length()
	_speed.text = "%.0f u/s" % (spd * 32.0)
	_hurt.color.a = player.hurt_alpha() * 0.45
	_cross.queue_redraw()
	_scoreboard.visible = Input.is_action_pressed("scoreboard")
	if _scoreboard.visible:
		_scoreboard.text = _board_text()


func _refresh_score() -> void:
	_score.text = "FRAGS %d   DEATHS %d" % [GameState.player_kills, GameState.player_deaths]


func _board_text() -> String:
	var lines := ["SCOREBOARD", ""]
	lines.append("YOU    %d" % GameState.player_kills)
	for k in GameState.bot_kills.keys():
		lines.append("%s    %d" % [k, GameState.bot_kills[k]])
	return "\n".join(lines)
