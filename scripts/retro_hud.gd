class_name RetroHUD
extends Control
## Classic 90s arena HUD: integer HP/armor, mega cyan, critical red, damage flash.
##
## Attach to a Control that contains:
##   MarginContainer / HBoxContainer / HealthLabel
##   MarginContainer / HBoxContainer / ArmorLabel
## If those nodes are missing, labels are created automatically.

@onready var health_label: Label = $MarginContainer/HBoxContainer/HealthLabel
@onready var armor_label: Label = $MarginContainer/HBoxContainer/ArmorLabel

@export var critical_health_color: Color = Color.RED
@export var normal_health_color: Color = Color.WHITE
@export var mega_health_color: Color = Color.CYAN
@export var damage_flash_color: Color = Color.CRIMSON
@export var health_path: NodePath = NodePath("/root/Main/Player/HealthComponent")

var flash_tween: Tween
var _last_health: float = -1.0


func _ready() -> void:
	_ensure_labels()
	var player_health := _find_health()
	if player_health:
		bind_health(player_health)


func bind_health(player_health: HealthComponent) -> void:
	if player_health == null:
		return
	if not player_health.health_changed.is_connected(_on_health_changed):
		player_health.health_changed.connect(_on_health_changed)
	if not player_health.armor_changed.is_connected(_on_armor_changed):
		player_health.armor_changed.connect(_on_armor_changed)
	if not player_health.damaged.is_connected(_on_damaged):
		player_health.damaged.connect(_on_damaged)
	_on_health_changed(player_health.current_health)
	_on_armor_changed(player_health.current_armor)


func _find_health() -> HealthComponent:
	var from_path := get_node_or_null(health_path)
	if from_path is HealthComponent:
		return from_path
	var players := get_tree().get_nodes_in_group("player")
	for n in players:
		var hc := n.get_node_or_null("HealthComponent")
		if hc is HealthComponent:
			return hc
	return null


func _ensure_labels() -> void:
	if health_label != null and armor_label != null:
		return
	var margin := get_node_or_null("MarginContainer") as MarginContainer
	if margin == null:
		margin = MarginContainer.new()
		margin.name = "MarginContainer"
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 40)
		margin.add_theme_constant_override("margin_bottom", 28)
		add_child(margin)
	var row := margin.get_node_or_null("HBoxContainer") as HBoxContainer
	if row == null:
		row = HBoxContainer.new()
		row.name = "HBoxContainer"
		row.add_theme_constant_override("separation", 32)
		margin.add_child(row)
	health_label = row.get_node_or_null("HealthLabel") as Label
	if health_label == null:
		health_label = Label.new()
		health_label.name = "HealthLabel"
		health_label.add_theme_font_size_override("font_size", 42)
		row.add_child(health_label)
	armor_label = row.get_node_or_null("ArmorLabel") as Label
	if armor_label == null:
		armor_label = Label.new()
		armor_label.name = "ArmorLabel"
		armor_label.add_theme_font_size_override("font_size", 42)
		row.add_child(armor_label)


func _on_health_changed(new_health: float) -> void:
	health_label.text = "HP: " + str(ceili(new_health))
	_apply_health_color(new_health)
	_last_health = new_health


func _on_armor_changed(new_armor: float) -> void:
	armor_label.text = "ARMOR: " + str(ceili(new_armor))
	if new_armor > 100.0:
		armor_label.add_theme_color_override("font_color", mega_health_color)
	else:
		armor_label.add_theme_color_override("font_color", normal_health_color)


func _on_damaged(_amount: float, _new_health: float) -> void:
	_trigger_damage_flash()


func _apply_health_color(new_health: float) -> void:
	if new_health > 100.0:
		health_label.add_theme_color_override("font_color", mega_health_color)
	elif new_health <= 25.0:
		health_label.add_theme_color_override("font_color", critical_health_color)
	else:
		health_label.add_theme_color_override("font_color", normal_health_color)


func _trigger_damage_flash() -> void:
	if flash_tween:
		flash_tween.kill()
	flash_tween = create_tween()
	health_label.add_theme_color_override("font_color", damage_flash_color)
	flash_tween.tween_interval(0.1)
	flash_tween.tween_callback(func() -> void:
		_apply_health_color(_last_health)
	)
