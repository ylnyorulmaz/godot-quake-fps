extends SceneTree
## Frag-limit winner for player and bots.
## Run: godot --headless --path . -s res://tests/test_game_state.gd

const GameStateScript := preload("res://scripts/game_state.gd")


func _init() -> void:
	var failed := 0
	failed += _test_player_wins()
	failed += _test_bot_wins()
	failed += _test_world_does_not_win()
	failed += _test_scoreboard_kd()
	if failed > 0:
		push_error("game_state tests failed: %d" % failed)
		quit(1)
	else:
		print("game_state tests passed")
		quit(0)


func _fresh():
	var gs = GameStateScript.new()
	root.add_child(gs)
	gs.frag_limit = 3
	return gs


func _test_player_wins() -> int:
	var gs = _fresh()
	gs.frag_limit = 3
	gs.register_bot("Grunt")
	gs.start_match()
	gs.add_frag("YOU", "Grunt", true, false)
	gs.add_frag("YOU", "Grunt", true, false)
	if not gs.match_running:
		push_error("match ended before frag limit")
		return 1
	gs.add_frag("YOU", "Grunt", true, false)
	if gs.match_running:
		push_error("player win did not end match")
		return 1
	if gs.last_winner != gs.PLAYER_NAME or gs.winner_frags() != 3:
		push_error("player winner: %s %d" % [gs.last_winner, gs.winner_frags()])
		return 1
	print("ok   player hits frag limit and wins")
	gs.queue_free()
	return 0


func _test_bot_wins() -> int:
	var gs = _fresh()
	gs.frag_limit = 2
	gs.register_bot("Ranger")
	gs.start_match()
	gs.add_frag("Ranger", "YOU", false, true)
	gs.add_frag("Ranger", "YOU", false, true)
	if gs.match_running:
		push_error("bot win did not end match")
		return 1
	if gs.last_winner != "Ranger" or gs.winner_frags() != 2:
		push_error("bot winner: %s %d" % [gs.last_winner, gs.winner_frags()])
		return 1
	print("ok   bot hits frag limit and wins")
	gs.queue_free()
	return 0


func _test_world_does_not_win() -> int:
	var gs = _fresh()
	gs.frag_limit = 1
	gs.register_bot("Visl")
	gs.start_match()
	gs.add_frag("world", "YOU", false, true)
	if not gs.match_running or gs.last_winner != "":
		push_error("world kill ended the match")
		return 1
	print("ok   world kills do not award a win")
	gs.queue_free()
	return 0


func _test_scoreboard_kd() -> int:
	var gs = _fresh()
	gs.frag_limit = 3
	gs.register_bot("Grunt")
	gs.register_bot("Ranger")
	gs.start_match()
	gs.add_frag("YOU", "Grunt", true, false)
	gs.add_frag("Ranger", "YOU", false, true)
	gs.add_frag("YOU", "Ranger", true, false)
	gs.add_frag("YOU", "Grunt", true, false)
	if gs.match_running:
		push_error("match should end at 3 frags")
		return 1
	if int(gs.bot_deaths.get("Grunt", -1)) != 2:
		push_error("Grunt deaths should be 2, got %s" % gs.bot_deaths.get("Grunt", -1))
		return 1
	if gs.player_deaths != 1:
		push_error("player deaths should be 1, got %s" % gs.player_deaths)
		return 1
	var rows: Array = gs.standings()
	if rows.is_empty() or str(rows[0]["name"]) != gs.PLAYER_NAME or int(rows[0]["kills"]) != 3:
		push_error("standings should lead with YOU at 3 kills")
		return 1
	var text: String = gs.scoreboard_text()
	if text.find("K") < 0 or text.find("D") < 0 or text.find("Grunt") < 0:
		push_error("scoreboard text missing columns: %s" % text)
		return 1
	if gs.last_winner != gs.PLAYER_NAME:
		push_error("winner should be YOU")
		return 1
	print("ok   scoreboard lists names, kills, deaths")
	gs.queue_free()
	return 0
