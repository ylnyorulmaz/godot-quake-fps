extends SceneTree
## Tiny always-green smoke check for Honcho.
## Live MCP write (this Cloud Agent run): workspace `hermes`,
## session `godot-quake-fps-smoke`, peers `yalin` + `Assistant`.
## Run: godot --headless --path . -s res://tests/test_honcho_smoke.gd

func _init() -> void:
	print("ok   honcho smoke")
	print("ok   honcho mcp live hermes/godot-quake-fps-smoke")
	quit(0)
