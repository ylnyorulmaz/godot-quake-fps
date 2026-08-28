extends Node

signal match_started
signal match_ended
signal scores_changed
signal event_logged(text: String)

const PLAYER_NAME := "YOU"
const SENS_LOW := 0.0014
const SENS_MED := 0.0024
const SENS_HIGH := 0.0036
const LAYOUT_YARD := 0
const LAYOUT_TIGHT := 1

var match_running := false
var paused := false
var mouse_sensitivity := SENS_MED
var player_kills := 0
var player_deaths := 0
var bot_kills: Dictionary = {}
var bot_deaths: Dictionary = {}
var frag_limit := 20
var time_limit := 0.0
var match_time := 0.0
var ended_by_time := false
var arena_layout := LAYOUT_YARD
var last_winner := ""
var last_event := ""


func reset_match() -> void:
	player_kills = 0
	player_deaths = 0
	bot_kills.clear()
	bot_deaths.clear()
	last_winner = ""
	last_event = ""
	match_running = false
	paused = false
	match_time = 0.0
	ended_by_time = false
	scores_changed.emit()


func register_bot(bot_name: String) -> void:
	bot_kills[bot_name] = 0
	bot_deaths[bot_name] = 0


func add_frag(killer_name: String, victim_name: String, is_player_killer: bool, is_player_victim: bool, verb: String = "fragged") -> void:
	if is_player_killer:
		player_kills += 1
	elif bot_kills.has(killer_name):
		bot_kills[killer_name] = int(bot_kills[killer_name]) + 1
	if is_player_victim:
		player_deaths += 1
	elif bot_deaths.has(victim_name):
		bot_deaths[victim_name] = int(bot_deaths[victim_name]) + 1
	scores_changed.emit()
	push_event(format_frag(killer_name, victim_name, verb))
	_maybe_end_match(killer_name, is_player_killer)


static func format_frag(killer_name: String, victim_name: String, verb: String = "fragged") -> String:
	if killer_name.is_empty() or killer_name == "world" or killer_name == victim_name:
		return "%s bit the dust" % victim_name
	var action := verb if not verb.is_empty() else "fragged"
	return "%s %s %s" % [killer_name, action, victim_name]


static func weapon_verb(killer: Node) -> String:
	if killer == null or not is_instance_valid(killer):
		return "fragged"
	if "weapons" in killer and killer.weapons != null:
		return verb_for_kind(int(killer.weapons.get("current")))
	if "bot_name" in killer:
		return "machine gunned"
	return "fragged"


static func verb_for_kind(kind: int) -> String:
	match kind:
		0:
			return "machine gunned"
		1:
			return "shotgunned"
		2:
			return "rocketed"
		3:
			return "railed"
		_:
			return "fragged"


func push_event(text: String) -> void:
	if text.is_empty():
		return
	last_event = text
	event_logged.emit(text)


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


func tick_clock(delta: float) -> void:
	if not match_running or paused:
		return
	if time_limit <= 0.0:
		return
	match_time += delta
	if match_time >= time_limit:
		_end_by_time()


func _process(delta: float) -> void:
	tick_clock(delta)


func _end_by_time() -> void:
	if not match_running:
		return
	ended_by_time = true
	var rows: Array = standings()
	if rows.is_empty():
		last_winner = PLAYER_NAME
	else:
		last_winner = str(rows[0]["name"])
	match_running = false
	match_ended.emit()


func remaining_time() -> float:
	if time_limit <= 0.0:
		return 0.0
	return maxf(time_limit - match_time, 0.0)


func clock_text() -> String:
	if time_limit <= 0.0:
		return ""
	var left := int(ceili(remaining_time()))
	return "%d:%02d" % [int(left / 60), left % 60]


func winner_frags() -> int:
	if last_winner == PLAYER_NAME or last_winner.is_empty():
		return player_kills
	return int(bot_kills.get(last_winner, 0))


func standings() -> Array:
	var rows: Array = []
	rows.append({"name": PLAYER_NAME, "kills": player_kills, "deaths": player_deaths})
	for bot_name in bot_kills.keys():
		rows.append({
			"name": bot_name,
			"kills": int(bot_kills[bot_name]),
			"deaths": int(bot_deaths.get(bot_name, 0)),
		})
	rows.sort_custom(_sort_standings)
	return rows


func _sort_standings(a, b) -> bool:
	var ak := int(a["kills"])
	var bk := int(b["kills"])
	if ak == bk:
		return int(a["deaths"]) < int(b["deaths"])
	return ak > bk


func scoreboard_text() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("NAME            K     D")
	for row in standings():
		var n := str(row["name"])
		if n == last_winner and not last_winner.is_empty():
			n = "> " + n
		else:
			n = "  " + n
		lines.append("%s %4d  %4d" % [_pad_name(n, 14), int(row["kills"]), int(row["deaths"])])
	return "\n".join(lines)


func _pad_name(n: String, width: int) -> String:
	if n.length() >= width:
		return n.substr(0, width)
	return n + " ".repeat(width - n.length())


func start_match() -> void:
	match_running = true
	paused = false
	match_time = 0.0
	ended_by_time = false
	match_started.emit()
