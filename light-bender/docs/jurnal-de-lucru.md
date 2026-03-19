# Light Bender — Dev Log

## Initial Setup - 02.03.2024

We started from a clean Godot 4 project. We set up `.gitignore`,
`.gitattributes` and `.editorconfig` to keep things tidy from the start, then
laid out the folder structure: `features/player`, `levels/test_room`, `assets`,
`addons`, `docs`, `ui` — each in its place, even if they were empty for now.

---

## Test Scene and First Player - 15.03.2024

The first version of the player came together quickly: a `CharacterBody2D` with
a capsule `CollisionShape2D` and a basic movement script. Along with it came the
test scene — `test_scene.tscn` — a simple sandbox where anything could be
iterated on without breaking anything else.

A few quick rounds of bug fixes and script improvements followed, mostly around
physics and input feel.

---

## Sprite and Assets - 15.03.2024

We create a simple player sprite in **Aseprite** (`Sprite-0001.aseprite`),
exported as PNG and wired up directly in the scene.

---

## Tilemap - 15.03.2024

A base tile was drawn in Aseprite (`Black-tile.aseprite`) alongside a tilemap
template (`Template-tilemap.aseprite`). These produced `tile_map_layer.tscn` —
the first working tilemap dropped into the test scene. The same commit also
tightened up player controls: acceleration, deceleration, and air behaviour.

---

## Player Movement — `player_movement.gd` - 15.03.2024

The movement script grew iteratively. Things that ended up in it:

- **Responsive physics** — separate acceleration and deceleration on the ground
  and in the air, momentum conservation, idle friction
- **Variable jump height** — how high you jump depends on how long you hold the
  button; releasing early cuts the upward velocity
- **Coyote time** and **jump buffering** — small grace windows so jumping always
  feels tight and responsive
- **Apex hang** — reduced gravity and snappier acceleration at the top of the
  jump arc, for a floaty feel at the peak

---

## Squash & Stretch — `player_squash_stretch.gd` - 15.03.2024

A standalone script attached as a child node of the player, handling only the
squash and stretch animation of the sprite. It takes care of:

- Stretching vertically while falling (scales with speed)
- Squashing on landing (scales with impact strength)
- Narrowing on jump
- Smoothly recovering to normal scale

The script reads data directly from the parent `CharacterBody2D` with no
external dependencies.

---

## Abilities — `PlayerAbilities` resource - 16.03.2024

All abilities are driven by a dedicated `Resource` (`player_abilities.gd`) that
can be assigned in the editor or swapped at runtime. This makes unlocking them
later in the game easy to manage from anywhere.

Abilities implemented so far:

| Ability         | Description                                                              |
| --------------- | ------------------------------------------------------------------------ |
| **Dash**        | Quick horizontal burst with cooldown; speed snaps back to normal on exit |
| **Wall slide**  | Slow descent on a wall while holding toward it                           |
| **Wall jump**   | Jump off a wall, requires an explicit jump press                         |
| **Double jump** | One extra jump while airborne                                            |
| **Slow fall**   | Gentle descent activated by pressing jump mid-air and holding it         |

Each ability also exposes a runtime toggle (`set_dash_enabled`,
`set_double_jump_enabled`, etc.) so it can be enabled or disabled from any other
script.

How the game looks like right now:

![alt text](images/game-16.03.26.png)

---

## First Trail Effect and SFX System - 18.03.2026

We added a visible dash trail and a dedicated sound-effects pipeline for the
player.

The trail effect is now part of the player flow: it spawns afterimages during
dash and fades them out smoothly after dash ends.

The SFX setup was introduced as a modular event-based system:

- `SfxClip` resources define sound events as data
- `SfxEmitter2D` handles pooled playback, cooldowns, and looped sounds
- `PlayerSfxController` listens to movement signals and maps gameplay actions to
  sound events
- `player_movement.gd` emits gameplay signals (`jump_performed`,
  `dash_performed`, `wall_slide_state_changed`) and no longer carries SFX
  orchestration

Sounds connected in this first version:

- Jump
- Dash
- Wall Jump (place holder)
- Double Jump (place holder)

Event slots prepared for next additions:

- Wall slide loop

---

## Light Mechanic - 19.03.2026

We added the core light mechanic to the test room, and this features our main
core mechanic: what is in light exists, what is in dark does not. The player
will gain abailities to influence this as well.

The setup is pretty simple, but it unlocked a lot:

- `DarkManager` now drops a full dark overlay over the scene
- `LightZone` was added as a reusable scene, with one polygon driving both the
  visible light cutout and the trigger area
- the player now keeps track of how many light zones it is inside, so floor
  collision only stays active while standing in light
- the test scene got multiple light zones, and some of them are animated with
  `AnimationPlayer` so the safe areas actually move around

![alt text](images/light-19.03.26.png)
