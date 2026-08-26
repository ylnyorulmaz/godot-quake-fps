class_name HealthComponent
extends Node
## Arena-shooter vitals: 60/40 armor split, mega-item overflow, and 1 HP/s decay.

signal health_changed(new_health: float)
signal armor_changed(new_armor: float)
signal died
signal damaged(amount: float, new_health: float)

const ARMOR_ABSORB := 0.6

@export var max_health: float = 100.0
@export var max_armor: float = 100.0
@export var mega_health_limit: float = 200.0
@export var mega_armor_limit: float = 200.0
@export var decay_per_second: float = 1.0

var current_health: float = 100.0
var current_armor: float = 0.0

var _last_emitted_health: int = -1
var _last_emitted_armor: int = -1


func _ready() -> void:
	current_health = max_health
	current_armor = 0.0
	_emit_health(true)
	_emit_armor(true)


func _process(delta: float) -> void:
	if current_health <= 0.0:
		return
	var dirty_h := false
	var dirty_a := false
	if current_health > max_health:
		current_health = maxf(current_health - decay_per_second * delta, max_health)
		dirty_h = true
	if current_armor > max_armor:
		current_armor = maxf(current_armor - decay_per_second * delta, max_armor)
		dirty_a = true
	if dirty_h:
		_emit_health(false)
	if dirty_a:
		_emit_armor(false)


func take_damage(amount: float) -> void:
	if amount <= 0.0 or current_health <= 0.0:
		return
	var remaining := amount
	if current_armor > 0.0:
		var armor_share := remaining * ARMOR_ABSORB
		var health_share := remaining * (1.0 - ARMOR_ABSORB)
		if armor_share > current_armor:
			# Armor depleted mid-hit: leftover armor-share plus the 40% all hit health.
			remaining = health_share + (armor_share - current_armor)
			current_armor = 0.0
		else:
			current_armor -= armor_share
			remaining = health_share
	current_health = maxf(current_health - remaining, 0.0)
	_emit_armor(true)
	_emit_health(true)
	damaged.emit(amount, current_health)
	if current_health <= 0.0:
		died.emit()


func add_health(amount: float, cap: float = -1.0) -> bool:
	if amount <= 0.0 or current_health <= 0.0:
		return false
	var limit := mega_health_limit if cap < 0.0 else cap
	if current_health >= limit:
		return false
	current_health = minf(current_health + amount, limit)
	_emit_health(true)
	return true


func add_armor(amount: float, cap: float = -1.0) -> bool:
	if amount <= 0.0 or current_health <= 0.0:
		return false
	var limit := mega_armor_limit if cap < 0.0 else cap
	if current_armor >= limit:
		return false
	current_armor = minf(current_armor + amount, limit)
	_emit_armor(true)
	return true


func apply_mega_health(amount: float = 100.0) -> bool:
	return add_health(amount, mega_health_limit)


func can_pickup_mega_health() -> bool:
	return current_health > 0.0 and current_health < mega_health_limit


func reset_to_spawn() -> void:
	current_health = max_health
	current_armor = 0.0
	_emit_health(true)
	_emit_armor(true)


func _emit_health(force: bool) -> void:
	var rounded := int(ceil(current_health))
	if force or rounded != _last_emitted_health:
		_last_emitted_health = rounded
		health_changed.emit(current_health)


func _emit_armor(force: bool) -> void:
	var rounded := int(ceil(current_armor))
	if force or rounded != _last_emitted_armor:
		_last_emitted_armor = rounded
		armor_changed.emit(current_armor)
