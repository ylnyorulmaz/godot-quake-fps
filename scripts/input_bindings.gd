extends Node

## Runtime InputMap so the project runs without editing Project Settings.
## Actions: move_*, jump, sprint, crouch, fire, alt_fire, next/prev_weapon, weapon_1-4.


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_key("move_forward", KEY_W)
	_key("move_forward", KEY_UP)
	_key("move_back", KEY_S)
	_key("move_back", KEY_DOWN)
	_key("move_left", KEY_A)
	_key("move_left", KEY_LEFT)
	_key("move_right", KEY_D)
	_key("move_right", KEY_RIGHT)
	_key("jump", KEY_SPACE)
	_key("sprint", KEY_SHIFT)
	_key("crouch", KEY_CTRL)
	_key("crouch", KEY_C)
	_mouse("fire", MOUSE_BUTTON_LEFT)
	_mouse("attack", MOUSE_BUTTON_LEFT)
	_mouse("alt_fire", MOUSE_BUTTON_RIGHT)
	_key("weapon_1", KEY_1)
	_key("weapon_2", KEY_2)
	_key("weapon_3", KEY_3)
	_key("weapon_4", KEY_4)
	_mouse("next_weapon", MOUSE_BUTTON_WHEEL_UP)
	_mouse("prev_weapon", MOUSE_BUTTON_WHEEL_DOWN)
	_key("scoreboard", KEY_TAB)
	_key("restart", KEY_R)
	_key("fullscreen", KEY_F11)


func _key(action: String, keycode: Key) -> void:
	_ensure(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	# Match all devices. In Godot 4.7, device 0 can be a joypad.
	event.device = -1
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)


func _mouse(action: String, button: MouseButton) -> void:
	_ensure(action)
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.device = -1
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)


func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
