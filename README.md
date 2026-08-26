# Godot Quake FPS

Quake 3 Arena-style movement and a modular weapon manager for **Godot 4.7**.

This is original code. It is not affiliated with id Software and does not include Quake assets.

## Run

1. Install [Godot 4.7](https://godotengine.org/download) (Forward+).
2. Open this folder (`project.godot`). Godot 4.7 should not ask to upgrade the project version.
3. Press **F5**. Input actions are registered at runtime by `scripts/input_bindings.gd`.

## Player node tree

```
Player (CharacterBody3D)          scenes/player.tscn  scripts/player.gd
├─ CollisionShape3D (Capsule)
├─ BodyMesh
└─ Head (Node3D)                  camera pivot / pitch
   └─ Camera3D
      └─ WeaponManager (Node3D)   scripts/weapon_manager.gd
         ├─ Shotgun
         ├─ RocketLauncher
         ├─ Machinegun
         ├─ Railgun
         ├─ Muzzle                projectile spawn
         ├─ FireRay (RayCast3D)   camera-center hitscan
         └─ FireTimer             fire-rate gate
```

## Movement (Quake 3 PMove)

`scripts/quake_movement.gd` — tunables on the Player inspector:

| Variable | Role |
| --- | --- |
| `MOVE_SPEED` | Ground wish-speed cap |
| `FRICTION` / `ACCELERATION` | Ground bleed and snap toward cap |
| `AIR_ACCEL` | Air strafe (wish-speed capped) |
| `JUMP_FORCE` | Vertical impulse |
| `GRAVITY` / `TERMINAL_VELOCITY` | Fall |
| `SPRINT_MULTIPLIER` | Ground speed while holding sprint |

Bunny hop: jump on the landing frame **skips friction**, so horizontal speed is kept. A short jump buffer and optional hold-to-bhop (`AUTO_BHOP`) make the timing usable.

Camera FOV eases from `base_fov` toward `max_fov` as horizontal speed climbs (bhop stretch). Rocket splash calls `apply_explosion_knockback` with extra vertical bias for rocket jumps.

## HUD

`scripts/hud.gd` is a full-rect `CanvasLayer/Root` so it scales with the window.

- **Speedometer** (center-bottom): `Speed: 320 ups` from XZ velocity × 32.
- **Strafe helper** (behind the crosshair): two ticks at ±acos(air-wish-cap / speed) in view space. They turn green when your look yaw is in the optimal window.

## Weapons

`WeaponData` (`scripts/weapon_data.gd`) defines `damage`, `fire_rate`, `range`, `is_hitscan`, `projectile_scene`.

- **Hitscan** (MG / shotgun / rail): `RayCast3D` from the camera, plus spread pellets. Calls `take_damage` on the hit body and spawns a short 3D trail.
- **Projectile** (rocket): `scenes/rocket.tscn` from **Muzzle**, aimed at the camera ray point. Sphere query splash + `apply_explosion_knockback` (self-damage scaled).

Switch with **1–4** or the mouse wheel (`next_weapon` / `prev_weapon`). Fire with **LMB** (`fire`).

## Controls

| Action | Binding |
| --- | --- |
| Move | WASD / arrows |
| Look | Mouse (smoothed, pitch clamped) |
| Jump | Space |
| Sprint | Shift |
| Crouch | Ctrl or C |
| Fire | Left mouse |
| Weapons | 1–4 or wheel |
| Scoreboard | Tab |
| Pause | Esc |

## Optional Project Settings

The autoload `InputBindings` creates these actions if they are missing (device `-1` so they work on Godot 4.7, where device `0` can be a joypad). To bind them in the editor instead:

`move_forward`, `move_back`, `move_left`, `move_right`, `jump`, `sprint`, `crouch`, `fire`, `next_weapon`, `prev_weapon`, `weapon_1`…`weapon_4`.

License: MIT.
