class_name QuakeMoveParams
extends RefCounted

## Tunable Quake 3 PMove-style parameters (Godot units, ~1 unit = 1 m).

var MOVE_SPEED := 10.0
var SPRINT_MULTIPLIER := 1.3
var CROUCH_MULTIPLIER := 0.45
var FRICTION := 6.0
var STOP_SPEED := 1.6
var ACCELERATION := 10.0
var AIR_ACCEL := 1.0
## Q3 caps the *wish* speed used for air accel (~30ups). Scaled to meters.
var AIR_WISH_SPEED_CAP := 2.4
var JUMP_FORCE := 8.6
var GRAVITY := 20.0
var TERMINAL_VELOCITY := 48.0
