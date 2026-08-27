extends Node

signal match_started
signal match_ended
signal scores_changed

const PLAYER_NAME := "YOU"

var match_running := false
var paused := false
var mouse_sensitivity := 0.0024
var player_kills := 0
var player_deaths := 0
var bot_kills: Dictionary = {}
var frag_limit := 20
var last_winner := ""


func reset_match() -> void:
	player_kills = 0
	player_deaths = 0
	bot_kills.clear()
	last_winner = ""
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
	_maybe_end_match(killer_name, is_player_killer)


func _maybe_end_match(killer_name: String, is_player_killer: bool) -> void:
	if not match_running:
		return
	var score := player_kills if is_player_killer else int(bot_kills.get(killer_name, 0))
	if score < frag_limit:
		return
	last_winner = PLAYER_NAME if is_player_killer else killer_name
	if last_winner.is_empty():
		last_winner = PLAYER_NAME
	match_running = false
	match_ended.emit()


func winner_frags() -> int:
	if last_winner == PLAYER_NAME or last_winner.is_empty():
		return player_kills
	return int(bot_kills.get(last_winner, 0))


func start_match() -> void:
	match_running = true
	paused = false
	match_started.emit()
