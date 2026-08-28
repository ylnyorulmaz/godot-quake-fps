extends SceneTree
## Top-left combat log lines fade out; frags format as "X machine gunned Y".
## Run: godot --headless --path . -s res://tests/test_combat_log.gd

const LogScript := preload("res://scripts/combat_log.gd")
const GameStateScript := preload("res://scripts/game_state.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed := 0
	failed += _test_format()
	failed += _test_weapon_verb()
	failed += _test_add_frag_logs()
	failed += _test_lines_expire()
	if failed > 0:
		push_error("combat log tests failed: %d" % failed)
		quit(1)
	else:
		print("combat log tests passed")
		quit(0)


func _test_format() -> int:
	var line: String = GameStateScript.format_frag("YOU", "Grunt", "machine gunned")
	if line != "YOU machine gunned Grunt":
		push_error("expected YOU machine gunned Grunt, got %s" % line)
		return 1
	var dust: String = GameStateScript.format_frag("world", "YOU", "fragged")
	if dust != "YOU bit the dust":
		push_error("world kill should be bit the dust, got %s" % dust)
		return 1
	print("ok   frag lines use weapon verbs")
	return 0


func _test_weapon_verb() -> int:
	if GameStateScript.weapon_verb(null) != "fragged":
		push_error("null killer should frag")
		return 1
	if GameStateScript.verb_for_kind(0) != "machine gunned":
		push_error("kind 0 should be machine gunned")
		return 1
	if GameStateScript.verb_for_kind(1) != "shotgunned":
		push_error("kind 1 should be shotgunned")
		return 1
	if GameStateScript.verb_for_kind(2) != "rocketed":
		push_error("kind 2 should be rocketed")
		return 1
	if GameStateScript.verb_for_kind(3) != "railed":
		push_error("kind 3 should be railed")
		return 1
	print("ok   weapon verb follows current gun")
	return 0


func _test_add_frag_logs() -> int:
	var gs = GameStateScript.new()
	root.add_child(gs)
	gs.register_bot("Grunt")
	gs.start_match()
	var got := [""]
	gs.event_logged.connect(func(text: String) -> void:
		got[0] = text
	)
	gs.add_frag("YOU", "Grunt", true, false, "machine gunned")
	if got[0] != "YOU machine gunned Grunt" or gs.last_event != got[0]:
		push_error("add_frag should log the line, got %s" % gs.last_event)
		return 1
	print("ok   add_frag emits combat log line")
	gs.queue_free()
	return 0


func _test_lines_expire() -> int:
	var log = LogScript.new()
	root.add_child(log)
	log.push("YOU machine gunned Grunt")
	log.push("Ranger shotgunned YOU")
	if log.line_count() != 2:
		push_error("log should keep both fresh lines, got %d" % log.line_count())
		return 1
	var first := log.get_child(0) as Label
	if first == null or first.text != "Ranger shotgunned YOU":
		push_error("newest line should sit on top")
		return 1
	log._process(3.5)
	if first.modulate.a >= 0.99:
		push_error("line should start fading before it expires")
		return 1
	log._process(2.0)
	var leftover := 0
	for child in log.get_children():
		if not child.is_queued_for_deletion():
			leftover += 1
	if leftover != 0:
		push_error("expired lines should disappear, leftover %d" % leftover)
		return 1
	print("ok   combat log lines fade and disappear")
	log.queue_free()
	return 0
