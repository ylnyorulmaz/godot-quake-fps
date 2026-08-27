# Godot Quake FPS

Quake 3 Arena-style movement and a modular weapon manager for **Godot 4.7.2**.

This is original code. It is not affiliated with id Software and does not include Quake assets.

## Run

1. Install [Godot **4.7.2**](https://godotengine.org/download) (standard build, not an older 4.3/4.4 editor). The project uses the **Compatibility** renderer so it opens on more GPUs.
2. In the Project Manager: **Import** → select this folder’s `project.godot`. Do not convert/upgrade if it already says 4.7.
3. Press **F5**. Input actions are registered at runtime by `scripts/input_bindings.gd`.

If the editor still fails to open, run the **console** build (`Godot_v4.7.2-stable_*_console.exe`) so the error stays on screen. The game starts windowed; press **F11** for fullscreen.

## Player node tree

```
Player (CharacterBody3D)          scenes/player.tscn  scripts/player.gd
├─ HealthComponent                scripts/health_component.gd
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

Camera FOV eases from `base_fov` toward `max_fov` as horizontal speed climbs (bhop stretch). Rocket splash calls `apply_explosion_knockback` with extra vertical bias for rocket jumps. Jump pads call `Player.launch()` so the PMove step treats the body as airborne (`force_air`) and does not apply ground friction.

## Test arena (CSG)

`ArenaGenerator` (`scripts/arena_generator.gd`, `scenes/arena_generator.tscn`) builds the blockout in `_ready()`:

- 100×100 grid floor, ramps at 15° / 30° / 45°, strafe-gap platforms (4–12 units), enclosed speed hallway
- Jump pads (`scenes/jump_pad.tscn`) and a respawning Mega-Health (`scenes/mega_health.tscn`)
- Spawn / nav markers so deathmatch still runs on the same map
- `NavigationRegion3D` wraps the CSG hull; a navmesh is baked at runtime for bots

## Combat bots

`EnemyBot` (`scripts/enemy_bot.gd`, `scenes/enemy_bot.tscn`) is a `CharacterBody3D` with `NavigationAgent3D`, a LOS `RayCast3D`, `ShootTimer`, and `HealthComponent`.

- Chases the player via `get_next_path_position()` with acceleration + gravity
- On line-of-sight, stops following the path and strafes while firing a hitscan (spread from `accuracy_error`)
- Exports: `movement_speed`, `attack_cooldown`, `vision_range`, `accuracy_error`
- Missing or dead players are ignored; the bot wanders nav points instead
- **Custom mesh:** `assets/warrior.glb` and `assets/Warrior2.glb`. Capsules hide; collision stays the 1.8 m capsule.

## Custom 3D model

`assets/warrior.glb` (Grunt, Visl) and `assets/Warrior2.glb` (Ranger) load on match start. Credit: iRahulRajput, [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) — `assets/models/CREDITS.md`.

If a mesh faces the wrong way, set **Model Yaw Degrees** on `EnemyBot` (default **180**). Height scales to `target_height` (1.8 m).

## Health and armor

`HealthComponent` uses classic arena rules: armor absorbs **60%** of a hit, **40%** goes to health; leftover damage after armor depletes hits health at 100%. Values above 100 (mega items) decay at 1 point per second. Signals: `health_changed`, `armor_changed`, `damaged`, `died`.

Mega-Health: +100 HP, clamped to 200, 30s respawn.

## HUD

`scripts/hud.gd` is a full-rect `CanvasLayer/Root` so it scales with the window.

- **Speedometer** (center-bottom): `Speed: 320 ups` from XZ velocity × 32.
- **Strafe helper** (behind the crosshair): two ticks at ±acos(air-wish-cap / speed) in view space. They turn green when your look yaw is in the optimal window.
- **HP / armor**: integer `HP:` / `ARMOR:` from `HealthComponent` signals. Cyan over 100, red at or below 25, crimson flash on damage. `scripts/retro_hud.gd` is the same wiring for a Control-based overlay.

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
