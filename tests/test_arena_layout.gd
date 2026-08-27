extends SceneTree
## Yard vs tight arena layout sizes.
## Run: godot --headless --path . -s res://tests/test_arena_layout.gd

const Layouts := preload("res://scripts/arena_layouts.gd")


func _init() -> void:
	var failed := 0
	failed += _test_sizes()
	failed += _test_tight_flag()
	if failed > 0:
		push_error("arena layout tests failed: %d" % failed)
		quit(1)
	else:
		print("arena layout tests passed")
		quit(0)


func _test_sizes() -> int:
	if absf(Layouts.floor_size(Layouts.YARD) - 100.0) > 0.01:
		push_error("yard floor should be 100")
		return 1
	if absf(Layouts.floor_size(Layouts.TIGHT) - 64.0) > 0.01:
		push_error("tight floor should be 64")
		return 1
	print("ok   yard 100, tight 64")
	return 0


func _test_tight_flag() -> int:
	if Layouts.is_tight(Layouts.YARD):
		push_error("yard is not tight")
		return 1
	if not Layouts.is_tight(Layouts.TIGHT):
		push_error("tight layout flag")
		return 1
	print("ok   layout flags")
	return 0
