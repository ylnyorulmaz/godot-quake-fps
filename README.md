# Godot Quake FPS

Quake-inspired arena FPS built for **Godot 4.3+** (Forward Plus). Fast CPM-style movement, splash knockback / rocket jumps, hitscan + projectile weapons, and a small deathmatch versus bots.

This is original code and geometry. It is **not** affiliated with id Software and does not include Quake assets.

## Run

1. Install [Godot 4.3 or newer](https://godotengine.org/download).
2. Import this folder (`project.godot`).
3. Press **F5**.

## Controls

| Action | Binding |
| --- | --- |
| Move | WASD / arrows |
| Look | Mouse |
| Jump | Space |
| Crouch | Ctrl or C |
| Fire | Left mouse |
| Weapons | 1–4 or mouse wheel |
| Scoreboard | Tab |
| Pause / menu | Esc |
| Fullscreen | F11 |

## Weapons

1. **Machinegun** — starting hitscan
2. **Shotgun** — pellet spread (pickup)
3. **Rocket launcher** — splash + self knockback (pit pickup)
4. **Railgun** — piercing hitscan (upper platform)

Health, armor, and ammo pads respawn. Green pads are jump pads; purple cylinders are teleporters.

## Movement

Ground accel / friction skip on jump, Q3-style air-speed cap, extra air control for strafe jumping. Rocket-jump off walls or the pit floor.

Frag limit is 20. Three bots (Grunt, Ranger, Visl) roam the arena.

## Layout

```
project.godot
scenes/main.tscn
scripts/
  main.gd              match flow + menu
  quake_movement.gd    player/bot physics
  player.gd / bot.gd
  weapon_manager.gd    mg / shotgun / rocket / rail
  arena_builder.gd     CSG arena
  pickup.gd, jump_pad.gd, teleporter.gd
  hud.gd, audio_fx.gd
```

License: MIT.
