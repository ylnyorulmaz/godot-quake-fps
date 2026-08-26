class_name HUD
extends CanvasLayer

## Full-screen HUD. Root Control uses full-rect anchors so it survives resize.

var player: Player
var _root: Control
var _health: Label
var _armor: Label
var _ammo: Label
var _weapon: Label
var _speedo: Label
var _score: Label
var _cross: Control
var _strafe: StrafeHelper
var _hurt: ColorRect
var _scoreboard: Label
var _hint: Label
var _shown_ups := 0.0


func _ready() -> void:
	layer = 20
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_hurt = ColorRect.new()
	_hurt.color = Color(0.7, 0.05, 0.0, 0.0)
	_hurt.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hurt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hurt)

	_strafe = StrafeHelper.new()
	_strafe.name = "StrafeHelper"
	_root.add_child(_strafe)

	_cross = Control.new()
	_cross.name = "Crosshair"
	_cross.set_anchors_preset(Control.PRESET_CENTER)
	_cross.offset_left = -12.0
	_cross.offset_right = 12.0
	_cross.offset_top = -12.0
	_cross.offset_bottom = 12.0
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_cross)
	_cross.draw.connect(_draw_cross)

	_speedo = _label(28, Color(1.0, 0.82, 0.28), HORIZONTAL_ALIGNMENT_CENTER)
	_speedo.name = "Speedometer"
	_speedo.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_speedo.offset_left = -220.0
	_speedo.offset_right = 220.0
	_speedo.offset_top = -92.0
	_speedo.offset_bottom = -52.0
	_speedo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_health = _label(42, Color(0.95, 0.25, 0.15), HORIZONTAL_ALIGNMENT_LEFT)
	_health.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_health.offset_left = 40.0
	_health.offset_right = 280.0
	_health.offset_top = -110.0
	_health.offset_bottom = -62.0

	_armor = _label(28, Color(0.95, 0.8, 0.2), HORIZONTAL_ALIGNMENT_LEFT)
	_armor.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_armor.offset_left = 40.0
	_armor.offset_right = 280.0
	_armor.offset_top = -62.0
	_armor.offset_bottom = -28.0

	_ammo = _label(42, Color(0.95, 0.85, 0.4), HORIZONTAL_ALIGNMENT_RIGHT)
	_ammo.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_ammo.offset_left = -280.0
	_ammo.offset_right = -40.0
	_ammo.offset_top = -110.0
	_ammo.offset_bottom = -62.0

	_weapon = _label(22, Color(0.75, 0.75, 0.7), HORIZONTAL_ALIGNMENT_RIGHT)
	_weapon.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_weapon.offset_left = -320.0
	_weapon.offset_right = -40.0
	_weapon.offset_top = -62.0
	_weapon.offset_bottom = -28.0

	_score = _label(22, Color(0.95, 0.9, 0.75), HORIZONTAL_ALIGNMENT_LEFT)
	_score.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_score.offset_left = 16.0
	_score.offset_right = 420.0
	_score.offset_top = 16.0
	_score.offset_bottom = 48.0

	_hint = _label(16, Color(0.6, 0.6, 0.55), HORIZONTAL_ALIGNMENT_LEFT)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.offset_left = 16.0
	_hint.offset_right = 720.0
	_hint.offset_top = -28.0
	_hint.offset_bottom = -8.0
	_hint.text = "WASD  mouse  SPACE jump  SHIFT sprint  CTRL crouch  LMB fire  1-4 / wheel  ESC"

	_scoreboard = Label.new()
	_scoreboard.visible = false
	_scoreboard.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scoreboard.add_theme_font_size_override("font_size", 28)
	_scoreboard.add_theme_color_override("font_color", Color(1, 0.92, 0.75))
	_scoreboard.set_anchors_preset(Control.PRESET_CENTER)
	_scoreboard.offset_left = -220.0
	_scoreboard.offset_right = 220.0
	_scoreboard.offset_top = -140.0
	_scoreboard.offset_bottom = 140.0
	_root.add_child(_scoreboard)

	GameState.scores_changed.connect(_refresh_score)


func setup(p: Player) -> void:
	player = p
	_strafe.player = p


func _label(size: int, color: Color, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(l)
	return l


func _draw_cross() -> void:
	var c := Color(1, 0.92, 0.4, 0.85)
	_cross.draw_rect(Rect2(10, 0, 4, 24), c)
	_cross.draw_rect(Rect2(0, 10, 24, 4), c)
	_cross.draw_rect(Rect2(11, 11, 2, 2), Color(0, 0, 0))


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_health.text = "%d" % int(player.health)
	_armor.text = "ARMOR %d" % int(player.armor)
	_ammo.text = "%d" % player.weapons.current_ammo()
	_weapon.text = player.weapons.current_name()
	var target_ups := player.speed_ups()
	_shown_ups = lerpf(_shown_ups, target_ups, 1.0 - exp(-14.0 * delta))
	_speedo.text = "Speed: %d ups" % int(round(_shown_ups))
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
