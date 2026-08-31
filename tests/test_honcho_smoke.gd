extends SceneTree
## Tiny always-green smoke check for Honcho.
## Run: godot --headless --path . -s res://tests/test_honcho_smoke.gd

func _init() -> void:
	print("ok   honcho smoke")
	quit(0)
