<div align="center">

# Light Bender

**A Godot puzzle platformer where anything outside the light stops existing.**

[![Godot 4.6](https://img.shields.io/badge/Godot-4.6-478cbf?logo=godot-engine&logoColor=white)](https://godotengine.org/)
[![Language: GDScript](https://img.shields.io/badge/Language-GDScript-355570)](https://docs.godotengine.org/)
[![License: Noncommercial](https://img.shields.io/badge/License-PolyForm%20Noncommercial-lightgrey)](LICENSE)

[Watch Gameplay Video](https://youtu.be/lu5tbuory10?si=Ouxw-4WoZDdrRHVM)

[![Light Bender gameplay video](https://img.youtube.com/vi/lu5tbuory10/hqdefault.jpg)](https://youtu.be/lu5tbuory10?si=Ouxw-4WoZDdrRHVM)

</div>

## Overview

Light Bender is a 2D puzzle platformer built in Godot around one rule: if
something is not in the light, it does not really exist.

Platforms, doors, switches, batteries, hazards, and carried objects only become
reliable when light reaches them. To clear a level, the player has to bend,
carry, redirect, and toggle light until the room becomes traversable. A path is
not just found; it is created by shaping where the light goes.

The current build focuses on Chapter 1: a playable chain of levels with a level
selector, pause/menu UI, procedural backgrounds, audio feedback, circular
transitions, and several light-based puzzle objects.

## Highlights

| System | Description |
| --- | --- |
| Movement-first controller | Dash, wall jump, double jump, slow fall, coyote time, jump buffering, and squash/stretch feedback. |
| Light-driven gameplay | Anything outside the light can stop being solid, usable, or dangerous. |
| Absorbable puzzle objects | Batteries and flashlights can be carried while keeping their light behavior, then dropped back into the level. |
| Switch-based light routing | Switches bend the level by turning light sections on and off. |
| Chapter progression | A level selector builds its graph from level data and tracks unlocked/completed rooms. |
| Presentation polish | Pixel UI, procedural shader backgrounds, music/SFX buses, UI sounds, and circular scene transitions. |

> Note: several movement abilities are already implemented in the codebase but
> are intentionally unavailable in Chapter 1. Mechanics such as dash, double
> jump, wall movement, and slow fall are prepared for later chapters, where the
> level design can introduce them properly.

## Screenshots

### Menus

| Level Selector | Pause / Menu |
| --- | --- |
| ![Chapter 1 level selector](light-bender/docs/images/level-selector-chapter-1.png) | ![Main menu audio settings](light-bender/docs/images/main-menu-audio-settings.png) |

### Mechanics

| Battery Light | Flashlight |
| --- | --- |
| ![Battery carried as a light source](light-bender/docs/images/battery-carried-light.png) | ![Flashlight rotation puzzle](light-bender/docs/images/flashlight-rotation-puzzle.png) |

| Switch Puzzle | Transition |
| --- | --- |
| ![Switch and door puzzle](light-bender/docs/images/switch-door-puzzle.png) | ![Door transition ring](light-bender/docs/images/door-transition-ring.png) |

### Levels and Backgrounds

| Chapter 1 Layout | Chapter 2 Shader |
| --- | --- |
| ![Chapter 1 platforming layout](light-bender/docs/images/chapter-1-platforming-layout.png) | ![Chapter 2 background shader](light-bender/docs/images/chapter-2-background-shader.png) |

## Controls

| Action | Keyboard |
| --- | --- |
| Move | `A` / `D` or arrow keys |
| Jump | `Space`, `W`, or `Up` |
| Fast fall | `S` or `Down` |
| Dash | `K` or `Shift` |
| Interact / enter door / toggle switch | `E` |
| Pick up / drop object | `F` |
| Rotate held flashlight | `R` |
| Pause | `Esc` |
| Debug respawn / restart level | `P` / `O` |

Some controls listed above are tied to mechanics that are implemented but not
enabled during Chapter 1 progression. They remain useful for testing and for
future chapter content.

## Tech Stack

| Item | Value |
| --- | --- |
| Engine | Godot 4.6 |
| Language | GDScript |
| Renderer | GL Compatibility |
| Target viewport | 1920x1080 |
| Main scene | `res://ui/level_selector/level_selector.tscn` |

## Running the Project

1. Install Godot 4.6 or a compatible Godot 4 version.
2. Clone this repository.
3. Open `light-bender/project.godot` in the Godot editor.
4. Run the project from the editor.

The game starts in the level selector. No package installation step is required;
the project is self-contained inside the `light-bender/` Godot folder.

## Project Structure

```text
light-bender/
  assets/                 Sprites, audio, fonts, and imports
  docs/                   Development journal and screenshots
  features/               Reusable gameplay systems and puzzle objects
    audio/                SFX emitters, clips, and music manager
    background/           Procedural chapter/menu shaders
    battery_light/        Portable battery light object
    button_box/           Light-reactive trigger box
    darkmanager/          Darkness overlay and edge shader
    door/                 Checkpoint and exit door logic
    flashlight_box/       Carryable rotating flashlight object
    lightzone/            Polygon light zones
    player/               Movement, abilities, pickup, and squash/stretch
    transition/           Circular scene/death transition
  levels/
    base_level/           Shared level lifecycle
    chapter_1/            Chapter 1 rooms
    test_room/            Prototype and sandbox scenes
  ui/
    level_selector/       Chapter graph and level launching
    pause_menu/           Pause/menu overlay and audio sliders
```

## Development Guide

Use the existing systems before adding new one-off logic:

- Put reusable gameplay mechanics under `light-bender/features/`.
- Put playable rooms under `light-bender/levels/chapter_1/` or a future chapter
  folder.
- Add new selectable levels in
  [`LevelManager.LEVELS`](light-bender/features/level_manager/level_manager.gd).
- Reuse [`base_level.gd`](light-bender/levels/base_level/base_level.gd) for
  level setup, completion, menu injection, music, and transitions.
- Use the existing light receiver/reactive flow for light-gated objects.
- Keep documentation screenshots in `light-bender/docs/images/`.

### Useful Entry Points

| System | File |
| --- | --- |
| Player movement | [`player_movement.gd`](light-bender/features/player/player_movement.gd) |
| Player abilities | [`player_abilities.gd`](light-bender/features/player/player_abilities.gd) |
| Pickup and carrying | [`player_pickup_controller.gd`](light-bender/features/player/player_pickup_controller.gd) |
| Light zones | [`light_zone.gd`](light-bender/features/lightzone/light_zone.gd) |
| Light-gated objects | [`light_reactive.gd`](light-bender/features/shared/light_reactive.gd) |
| Battery | [`battery_light.gd`](light-bender/features/battery_light/battery_light.gd) |
| Flashlight | [`flashlight_box.gd`](light-bender/features/flashlight_box/flashlight_box.gd) |
| Switch | [`switch.gd`](light-bender/features/switch/switch.gd) |
| Level selector / progress | [`level_manager.gd`](light-bender/features/level_manager/level_manager.gd) |
| Development journal | [`development-journal.md`](light-bender/docs/development-journal.md) |

## Documentation

- [Development Journal](light-bender/docs/development-journal.md)
- [Gameplay Video](https://youtu.be/lu5tbuory10?si=Ouxw-4WoZDdrRHVM)

## License

This project is source-available for non-commercial use under the
[PolyForm Noncommercial License 1.0.0](LICENSE).

SPDX identifier: `PolyForm-Noncommercial-1.0.0`

You may view, run, study, and modify the project for personal, educational, and
non-commercial purposes. Selling the game, selling modified versions, paid
distribution, commercial redistribution, or using the project inside a paid
product requires written permission from the project owners.

The original project owners keep the right to publish, distribute, or sell
official commercial versions of Light Bender in the future.
