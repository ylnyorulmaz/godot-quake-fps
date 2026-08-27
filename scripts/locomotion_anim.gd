class_name LocomotionAnim
extends Node
## Godot 4 AnimationTree locomotion: idle / walk / run (BlendSpace1D)
## plus jump/air (state machine) with xfade.
##
## Attach next to a CharacterBody3D, then `bind(body, visual_root)`.
## Clip names are matched loosely (Idle, Walk, Run, Jump, Mixamo, etc.).
## Returns false from bind() if there is not at least Idle + Walk — caller
## can fall back to a bob or a single looping clip.

const IDLE_KEYS: PackedStringArray = ["idle", "stand", "wait"]
const WALK_KEYS: PackedStringArray = ["walk", "walking"]
const RUN_KEYS: PackedStringArray = ["run", "running", "sprint"]
const JUMP_KEYS: PackedStringArray = ["jump", "jumping", "fall", "air"]

@export var walk_speed: float = 4.0
@export var run_speed: float = 8.0
@export var blend_sharpness: float = 8.0
@export var jump_xfade: float = 0.12
@export var land_xfade: float = 0.18

var tree: AnimationTree
var playback: AnimationNodeStateMachinePlayback

var _body: CharacterBody3D
var _player: AnimationPlayer
var _blend := 0.0
var _clips: Dictionary = {}
var _has_jump := false
var _bound := false


func bind(body: CharacterBody3D, visual_root: Node) -> bool:
	_body = body
	_player = _find_animation_player(visual_root)
	if _body == null or _player == null:
		return false
	_clips = _resolve_clips(_player)
	if not _clips.has("idle") or not _clips.has("walk"):
		return false
	_loop_clip(_clips["idle"])
	_loop_clip(_clips["walk"])
	if _clips.has("run"):
		_loop_clip(_clips["run"])
	_has_jump = _clips.has("jump")
	if _has_jump:
		_one_shot_clip(_clips["jump"])
	_build_tree()
	_bound = tree != null and playback != null
	set_physics_process(_bound)
	return _bound


func is_bound() -> bool:
	return _bound


func apply(speed: float, airborne: bool, delta: float) -> void:
	if not _bound or tree == null or playback == null:
		return
	var dt := delta if delta > 0.0 else 0.016
	var speed_target := clampf(speed, 0.0, run_speed)
	_blend = lerpf(_blend, speed_target, 1.0 - exp(-blend_sharpness * dt))
	tree.set("parameters/Grounded/blend_position", _blend)
	var current := String(playback.get_current_node())
	var state_target := "Air" if _has_jump and airborne else "Grounded"
	if current != state_target:
		playback.travel(state_target)
	tree.advance(dt)


func current_state() -> String:
	if playback == null:
		return ""
	return String(playback.get_current_node())


func blend_position() -> float:
	return _blend


func _physics_process(delta: float) -> void:
	if not _bound or _body == null or not is_instance_valid(_body):
		return
	var gs := get_node_or_null("/root/GameState")
	if gs != null and bool(gs.get("paused")):
		return
	var horiz := Vector2(_body.velocity.x, _body.velocity.z).length()
	var airborne := not _body.is_on_floor()
	apply(horiz, airborne, delta)


func _build_tree() -> void:
	var sm := AnimationNodeStateMachine.new()
	var grounded := _make_blend_space()
	sm.add_node("Grounded", grounded, Vector2(0, 80))
	var start_to_ground := _transition(0.0)
	start_to_ground.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	sm.add_transition("Start", "Grounded", start_to_ground)
	if _has_jump:
		var air := AnimationNodeAnimation.new()
		air.animation = StringName(_clips["jump"])
		sm.add_node("Air", air, Vector2(240, 80))
		var to_air := _transition(jump_xfade)
		var to_land := _transition(land_xfade)
		sm.add_transition("Grounded", "Air", to_air)
		sm.add_transition("Air", "Grounded", to_land)
		sm.add_transition("Start", "Air", _transition(0.0))

	if tree != null and is_instance_valid(tree):
		tree.queue_free()
	tree = AnimationTree.new()
	tree.name = "AnimationTree"
	add_child(tree)
	tree.tree_root = sm
	tree.anim_player = tree.get_path_to(_player)
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	tree.active = true
	playback = tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	if playback:
		playback.start("Grounded")
	tree.advance(0.016)


func _make_blend_space() -> AnimationNodeBlendSpace1D:
	var blend := AnimationNodeBlendSpace1D.new()
	blend.min_space = 0.0
	blend.max_space = run_speed
	var idle := AnimationNodeAnimation.new()
	idle.animation = StringName(_clips["idle"])
	blend.add_blend_point(idle, 0.0, -1, StringName("idle"))
	var walk := AnimationNodeAnimation.new()
	walk.animation = StringName(_clips["walk"])
	blend.add_blend_point(walk, walk_speed, -1, StringName("walk"))
	if _clips.has("run"):
		var run := AnimationNodeAnimation.new()
		run.animation = StringName(_clips["run"])
		blend.add_blend_point(run, run_speed, -1, StringName("run"))
	else:
		var walk_fast := AnimationNodeAnimation.new()
		walk_fast.animation = StringName(_clips["walk"])
		blend.add_blend_point(walk_fast, run_speed, -1, StringName("walk_fast"))
	return blend


func _transition(xfade: float) -> AnimationNodeStateMachineTransition:
	var t := AnimationNodeStateMachineTransition.new()
	t.xfade_time = xfade
	t.reset = true
	t.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED
	return t


static func _resolve_clips(player: AnimationPlayer) -> Dictionary:
	var found: Dictionary = {}
	var names := player.get_animation_list()
	found["idle"] = _match_clip(names, IDLE_KEYS)
	found["walk"] = _match_clip(names, WALK_KEYS)
	found["run"] = _match_clip(names, RUN_KEYS)
	found["jump"] = _match_clip(names, JUMP_KEYS)
	var cleaned: Dictionary = {}
	for key in found.keys():
		if str(found[key]) != "":
			cleaned[key] = found[key]
	return cleaned


static func _match_clip(names: PackedStringArray, keys: PackedStringArray) -> String:
	for n in names:
		var lower := n.to_lower()
		for key in keys:
			if lower == key or key in lower:
				return n
	return ""


func _loop_clip(anim_name: String) -> void:
	if _player == null or anim_name.is_empty():
		return
	var anim := _player.get_animation(anim_name)
	if anim:
		anim.loop_mode = Animation.LOOP_LINEAR


func _one_shot_clip(anim_name: String) -> void:
	if _player == null or anim_name.is_empty():
		return
	var anim := _player.get_animation(anim_name)
	if anim:
		anim.loop_mode = Animation.LOOP_NONE


static func _find_animation_player(root: Node) -> AnimationPlayer:
	if root == null:
		return null
	if root is AnimationPlayer:
		return root
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			if child is AnimationPlayer:
				return child
			stack.append(child)
	return null
