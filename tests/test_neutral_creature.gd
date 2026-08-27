extends SceneTree
## NeutralCreature: hunts player/enemy, melee, ignores pickups, 100 HP.
## Run: godot --headless --path . -s res://tests/test_neutral_creature.gd

const Creature := preload("res://scripts/NeutralCreature.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed := 0
	failed += _test_hp_and_layer()
	failed += _test_ignores_pickups()
	failed += _test_nearest_and_melee()
	failed += _test_dies()
	failed += _test_has_nav_agent()
	if failed > 0:
		push_error("neutral creature tests failed: %d" % failed)
		quit(1)
	else:
		print("neutral creature tests passed")
		quit(0)


func _make_creature(pos: Vector3):
	var c = Creature.new()
	c.name = "Critter"
	root.add_child(c)
	c.global_position = pos
	return c


func _dummy(group: String, name: String, pos: Vector3) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.name = name
	body.add_to_group(group)
	root.add_child(body)
	body.global_position = pos
	return body


func _test_hp_and_layer() -> int:
	var c = _make_creature(Vector3.ZERO)
	if c.collision_layer != Creature.LAYER:
		push_error("neutral layer should be 32, got %s" % c.collision_layer)
		return 1
	if c.collision_layer & 2 or c.collision_layer & 4:
		push_error("neutral must not sit on player/enemy pickup layers")
		return 1
	if c.collision_mask & 16:
		push_error("neutral must not collide with pickup layer 16")
		return 1
	if c.health_comp == null or absf(c.health_comp.max_health - 100.0) > 0.01:
		push_error("neutral should have 100 HP")
		return 1
	if absf(c.health_comp.current_health - 100.0) > 0.01:
		push_error("neutral spawn HP should be 100")
		return 1
	print("ok   100 HP and pickup-safe physics layers")
	c.queue_free()
	return 0


func _test_ignores_pickups() -> int:
	var c = _make_creature(Vector3.ZERO)
	if c.has_method("apply_pickup") or c.has_method("apply_power_up"):
		push_error("neutral must not implement pickup methods")
		return 1
	print("ok   no pickup / power-up hooks")
	c.queue_free()
	return 0


func _test_nearest_and_melee() -> int:
	var c = _make_creature(Vector3.ZERO)
	c.activation_radius = 30.0
	c.melee_range = 2.0
	c.melee_damage = 15.0
	c._swing = 0.0
	var far := _dummy("player", "FarPlayer", Vector3(40, 0, 0))
	var near := _dummy("bots", "NearEnemy", Vector3(4, 0, 0))
	var picked: Node3D = c._nearest_entity()
	if picked != near:
		push_error("should chase nearest in radius, got %s" % picked)
		return 1
	var victim := _HurtDummy.new()
	victim.name = "Hurt"
	root.add_child(victim)
	victim.global_position = Vector3(1.0, 0, 0)
	c.attack_target = victim
	c._try_melee()
	if absf(victim.last_amount - 15.0) > 0.01:
		push_error("melee should deal melee_damage, got %s" % victim.last_amount)
		return 1
	print("ok   nearest in radius and melee damage")
	c.queue_free()
	far.queue_free()
	near.queue_free()
	victim.queue_free()
	return 0


func _test_dies() -> int:
	var c = _make_creature(Vector3.ZERO)
	c.take_damage(100.0, Vector3.FORWARD, 0.0, null)
	if c.is_alive():
		push_error("100 damage should kill a 100 HP creature")
		return 1
	print("ok   dies at 0 HP")
	return 0


func _test_has_nav_agent() -> int:
	var c = _make_creature(Vector3.ZERO)
	var agent = c.get_node_or_null("NavigationAgent3D")
	if agent == null:
		push_error("NeutralCreature should own a NavigationAgent3D")
		return 1
	if not c.has_method("_chase_velocity"):
		push_error("expected _chase_velocity for nav fallback")
		return 1
	var dummy := _dummy("player", "NavPlayer", Vector3(8, 0, 0))
	var wish: Vector3 = c._chase_velocity(dummy, 8.0, 0.2)
	if wish.length() < 0.5:
		push_error("straight-line fallback should still chase, got %s" % wish)
		return 1
	print("ok   NavigationAgent3D + chase fallback")
	c.queue_free()
	dummy.queue_free()
	return 0


class _HurtDummy extends Node3D:
	var last_amount := 0.0

	func take_damage(amount: float, _dir: Vector3, _kb: float, _atk: Node = null) -> void:
		last_amount = amount
