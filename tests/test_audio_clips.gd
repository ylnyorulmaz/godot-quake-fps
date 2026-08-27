extends SceneTree
## Clip mapping for assets/audio. Procedural fallback stays for other keys.
## Run: godot --headless --path . -s res://tests/test_audio_clips.gd

const Sfx := preload("res://scripts/audio_fx.gd")
const Weapons := preload("res://scripts/weapon_manager.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed := 0
	failed += _test_files_present()
	failed += _test_mapping()
	failed += _test_streams()
	failed += _test_dry_click()
	if failed > 0:
		push_error("audio clip tests failed: %d" % failed)
		quit(1)
	else:
		print("audio clip tests passed")
		quit(0)


func _test_files_present() -> int:
	for kind in Sfx.FILES.keys():
		var path := str(Sfx.FILES[kind])
		if not FileAccess.file_exists(path):
			push_error("missing audio clip for %s at %s" % [kind, path])
			return 1
	print("ok   five clips exist under assets/audio")
	return 0


func _test_mapping() -> int:
	var fx = Sfx.new()
	root.add_child(fx)
	if not fx.has_clip("mg") or not fx.has_clip("mg_loop"):
		push_error("machinegun should map to ogg single-shot and loop")
		return 1
	if not fx.has_clip("shotgun"):
		push_error("shotgun should map to the pgi ogg")
		return 1
	if not fx.has_clip("dry"):
		push_error("empty click should map to the dry-fire wav")
		return 1
	if not fx.has_clip("hurt"):
		push_error("hurt should map to the orc grunt")
		return 1
	if fx.has_clip("jump") or fx.has_clip("rail"):
		push_error("unmapped keys should stay procedural")
		return 1
	print("ok   clip keys map, others stay procedural")
	fx.queue_free()
	return 0


func _test_streams() -> int:
	var fx = Sfx.new()
	root.add_child(fx)
	var mg: AudioStream = fx._stream("mg")
	var loop: AudioStream = fx._stream("mg_loop")
	var shot: AudioStream = fx._stream("shotgun")
	var dry: AudioStream = fx._stream("dry")
	var hurt: AudioStream = fx._stream("hurt")
	var jump: AudioStream = fx._stream("jump")
	if mg == null or shot == null or dry == null or hurt == null or loop == null:
		push_error("mapped clips failed to load")
		return 1
	if mg == loop:
		push_error("MG single shot and loop should be different streams")
		return 1
	if jump is AudioStreamWAV:
		pass
	else:
		push_error("jump should stay a procedural WAV")
		return 1
	if mg is AudioStreamWAV and fx.has_clip("mg"):
		push_error("MG clip exists on disk but loaded as procedural WAV (import?)")
		return 1
	if loop is AudioStreamOggVorbis:
		var ogg := loop as AudioStreamOggVorbis
		if not ogg.loop:
			push_error("mg_loop ogg should have loop enabled")
			return 1
	fx.start_loop("mg")
	if not fx.is_looping():
		push_error("start_loop should play the MG loop")
		return 1
	fx.stop_loop()
	if fx.is_looping():
		push_error("stop_loop should silence the MG loop")
		return 1
	print("ok   clips load, loop toggles, jump stays procedural")
	fx.queue_free()
	return 0


func _test_dry_click() -> int:
	var sfx = root.get_node_or_null("AudioFx")
	if sfx == null:
		push_error("AudioFx autoload missing")
		return 1
	var body := CharacterBody3D.new()
	root.add_child(body)
	var wm = Weapons.new()
	root.add_child(wm)
	wm.setup(body, false)
	wm.ammo[Weapons.Kind.MG] = 0
	wm.state = Weapons.State.IDLE
	if wm._fire_timer:
		wm._fire_timer.stop()
	sfx.last_played = ""
	if wm.try_fire():
		push_error("empty MG should not fire")
		return 1
	if str(sfx.last_played) != "dry":
		push_error("empty MG should dry-click, got '%s'" % sfx.last_played)
		return 1
	print("ok   empty MG dry-clicks")
	wm.queue_free()
	body.queue_free()
	return 0
