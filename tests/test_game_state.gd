extends SceneTree
## Frag-limit winner for player and bots.
## Run: godot --headless --path . -s res://tests/test_game_state.gd


func _init() -> void:
	var failed := 0
	failed += _test_player_wins()
	failed += _test_bot_wins()
	failed += _test_world_does_not_win()
	if failed > 0:
		push_error("game_state tests failed: %d" % failed)
		quit(1)
	else:
		print("game_state tests passed")
		quit(0)


func _test_player_wins() -> int:
	GameState.reset_match()
	GameState.frag_limit = 3
	GameState.register_bot("Grunt")
	GameState.start_match()
	GameState.add_frag("YOU", "Grunt", true, false)
	GameState.add_frag("YOU", "Grunt", true, false)
	if not GameState.match_running:
		push_error("match ended before frag limit")
		return 1
	GameState.add_frag("YOU", "Grunt", true, false)
	if GameState.match_running:
		push_error("player win did not end match")
		return 1
	if GameState.last_winner != GameState.PLAYER_NAME or GameState.winner_frags() != 3:
		push_error("player winner: %s %d" % [GameState.last_winner, GameState.winner_frags()])
		return 1
	print("ok   player hits frag limit and wins")
	return 0


func _test_bot_wins() -> int:
	GameState.reset_match()
	GameState.frag_limit = 2
	GameState.register_bot("Ranger")
	GameState.start_match()
	GameState.add_frag("Ranger", "YOU", false, true)
	GameState.add_frag("Ranger", "YOU", false, true)
	if GameState.match_running:
		push_error("bot win did not end match")
		return 1
	if GameState.last_winner != "Ranger" or GameState.winner_frags() != 2:
		push_error("bot winner: %s %d" % [GameState.last_winner, GameState.winner_frags()])
		return 1
	print("ok   bot hits frag limit and wins")
	return 0


func _test_world_does_not_win() -> int:
	GameState.reset_match()
	GameState.frag_limit = 1
	GameState.register_bot("Visl")
	GameState.start_match()
	GameState.add_frag("world", "YOU", false, true)
	if not GameState.match_running or GameState.last_winner != "":
		push_error("world kill ended the match")
		return 1
	print("ok   world kills do not award a win")
	return 0
