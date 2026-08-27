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
var _clock: Label
var _cross: Control
var _strafe: StrafeHelper
var _hurt: ColorRect
var _scoreboard: Label
var _hint: Label
var _power: Label
var _power_tint: ColorRect
var _shown_ups := 0.0
var _flash_tween: Tween
var _last_health: float = -1.0
var _health_comp: HealthComponent

@export var critical_health_color: Color = Color(1.0, 0.12, 0.08)
@export var normal_health_color: Color = Color(1.0, 0.2, 0.1)
@export var mega_health_color: Color = Color(0.25, 0.95, 1.0)
@export var armor_color: Color = Color(0.95, 0.82, 0.18)
@export var damage_flash_color: Color = Color(1.0, 0.95, 0.85)


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

	_power_tint = ColorRect.new()
	_power_tint.name = "PowerTint"
	_power_tint.color = Color(1.0, 0.2, 0.05, 0.0)
	_power_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_power_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_power_tint)

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

	_speedo = _label(22, Color(1.0, 0.72, 0.18, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	_speedo.name = "Speedometer"
	_speedo.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_speedo.offset_left = -220.0
	_speedo.offset_right = 220.0
	_speedo.offset_top = -92.0
	_speedo.offset_bottom = -52.0
	_speedo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_health = _label(64, Color(0.95, 0.18, 0.1), HORIZONTAL_ALIGNMENT_LEFT)
	_health.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_health.offset_left = 36.0
	_health.offset_right = 280.0
	_health.offset_top = -128.0
	_health.offset_bottom = -56.0

	_armor = _label(36, Color(0.95, 0.72, 0.18), HORIZONTAL_ALIGNMENT_LEFT)
	_armor.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_armor.offset_left = 40.0
	_armor.offset_right = 280.0
	_armor.offset_top = -58.0
	_armor.offset_bottom = -22.0

	_ammo = _label(64, Color(1.0, 0.48, 0.12), HORIZONTAL_ALIGNMENT_RIGHT)
	_ammo.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_ammo.offset_left = -280.0
	_ammo.offset_right = -40.0
	_ammo.offset_top = -128.0
	_ammo.offset_bottom = -56.0

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

	_clock = _label(22, Color(0.95, 0.85, 0.4), HORIZONTAL_ALIGNMENT_RIGHT)
	_clock.name = "Clock"
	_clock.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_clock.offset_left = -220.0
	_clock.offset_right = -16.0
	_clock.offset_top = 16.0
	_clock.offset_bottom = 48.0

	_hint = _label(16, Color(0.6, 0.6, 0.55), HORIZONTAL_ALIGNMENT_LEFT)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.offset_left = 16.0
	_hint.offset_right = 720.0
	_hint.offset_top = -28.0
	_hint.offset_bottom = -8.0
	_hint.text = ""
	_hint.visible = false

	_power = _label(26, Color(1.0, 0.45, 0.2), HORIZONTAL_ALIGNMENT_CENTER)
	_power.name = "PowerUpStatus"
	_power.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_power.offset_left = -280.0
	_power.offset_right = 280.0
	_power.offset_top = 18.0
	_power.offset_bottom = 56.0

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
	_bind_health(p)


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
	var c := Color(1.0, 0.42, 0.1, 0.92)
	_cross.draw_rect(Rect2(11, 0, 2, 7), c)
	_cross.draw_rect(Rect2(11, 17, 2, 7), c)
	_cross.draw_rect(Rect2(0, 11, 7, 2), c)
	_cross.draw_rect(Rect2(17, 11, 7, 2), c)


func _bind_health(p: Player) -> void:
	_health_comp = p.get_node_or_null("HealthComponent") as HealthComponent
	if _health_comp == null:
		_health_comp = get_node_or_null("/root/Main/Player/HealthComponent") as HealthComponent
	if _health_comp == null:
		return
	if not _health_comp.health_changed.is_connected(_on_health_changed):
		_health_comp.health_changed.connect(_on_health_changed)
	if not _health_comp.armor_changed.is_connected(_on_armor_changed):
		_health_comp.armor_changed.connect(_on_armor_changed)
	if not _health_comp.damaged.is_connected(_on_damaged):
		_health_comp.damaged.connect(_on_damaged)
	_on_health_changed(_health_comp.current_health)
	_on_armor_changed(_health_comp.current_armor)


func _on_health_changed(new_health: float) -> void:
	if _health == null:
		return
	_health.text = "%d" % ceili(new_health)
	_apply_health_color(new_health)
	_last_health = new_health


func _on_armor_changed(new_armor: float) -> void:
	if _armor == null:
		return
	_armor.text = "%d" % ceili(new_armor)
	if new_armor > 100.0:
		_armor.add_theme_color_override("font_color", mega_health_color)
	else:
		_armor.add_theme_color_override("font_color", armor_color)


func _on_damaged(_amount: float, _new_health: float) -> void:
	_trigger_damage_flash()


func _apply_health_color(new_health: float) -> void:
	if new_health > 100.0:
		_health.add_theme_color_override("font_color", mega_health_color)
	elif new_health <= 25.0:
		_health.add_theme_color_override("font_color", critical_health_color)
	else:
		_health.add_theme_color_override("font_color", normal_health_color)


func _trigger_damage_flash() -> void:
	if _health == null:
		return
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_health.add_theme_color_override("font_color", damage_flash_color)
	_flash_tween.tween_interval(0.1)
	_flash_tween.tween_callback(func() -> void:
		_apply_health_color(_last_health)
	)


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_ammo.text = "%d" % player.weapons.current_ammo()
	_ammo.add_theme_color_override("font_color", player.weapons.ammo_hud_color())
	_weapon.text = player.weapons.current_name()
	var target_ups := player.speed_ups()
	_shown_ups = lerpf(_shown_ups, target_ups, 1.0 - exp(-14.0 * delta))
	_speedo.text = "%d" % int(round(_shown_ups))
	_hurt.color.a = player.hurt_alpha() * 0.45
	if _power_tint:
		_power_tint.color = player.power_screen_tint()
	if _power:
		_power.text = player.power_status_text()
		_power.visible = not _power.text.is_empty()
	_cross.queue_redraw()
	if _clock:
		var gs := get_node_or_null("/root/GameState")
		var clock := ""
		if gs != null and gs.has_method("clock_text"):
			clock = str(gs.call("clock_text"))
		_clock.text = clock
		_clock.visible = not clock.is_empty()
	_scoreboard.visible = Input.is_action_pressed("scoreboard")
	if _scoreboard.visible:
		_scoreboard.text = _board_text()


func _refresh_score() -> void:
	_score.text = "%d" % GameState.player_kills


func _board_text() -> String:
	var gs := get_node_or_null("/root/GameState")
	if gs != null and gs.has_method("scoreboard_text"):
		var head := "SCOREBOARD  ·  first to %d" % int(gs.get("frag_limit"))
		if float(gs.get("time_limit")) > 0.0 and gs.has_method("clock_text"):
			head += "  ·  %s" % str(gs.call("clock_text"))
		head += "\n\n"
		return head + str(gs.call("scoreboard_text"))
	var lines := ["SCOREBOARD  ·  first to %d" % GameState.frag_limit, ""]
	lines.append("YOU    %d" % GameState.player_kills)
	for k in GameState.bot_kills.keys():
		lines.append("%s    %d" % [k, GameState.bot_kills[k]])
	return "\n".join(lines)
