extends Node

signal match_started
signal match_ended
signal scores_changed

var match_running := false
var paused := false
var mouse_sensitivity := 0.0024
var player_kills := 0
var player_deaths := 0
var bot_kills: Dictionary = {}
var frag_limit := 20


func reset_match() -> void:
	player_kills = 0
	player_deaths = 0
	bot_kills.clear()
	match_running = false
	paused = false
	scores_changed.emit()


func register_bot(bot_name: String) -> void:
	bot_kills[bot_name] = 0


func add_frag(killer_name: String, victim_name: String, is_player_killer: bool, is_player_victim: bool) -> void:
	if is_player_killer:
		player_kills += 1
	elif bot_kills.has(killer_name):
		bot_kills[killer_name] = int(bot_kills[killer_name]) + 1
	if is_player_victim:
		player_deaths += 1
	scores_changed.emit()
	if player_kills >= frag_limit:
		match_running = false
		match_ended.emit()


func start_match() -> void:
	match_running = true
	paused = false
	match_started.emit()
