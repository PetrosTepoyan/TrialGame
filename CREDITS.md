# Credits

## Code

- Game design & code: this repository (MIT-licensed unless otherwise noted).

## Art & Audio (recommended drop-in CC0 packs)

The shipped build is **fully programmatic** — there are no third-party assets in
this repo. The following CC0-licensed packs from Kenney.nl are recommended for
upgrading the look-and-feel. Drop them into the matching `assets/` subfolders,
then swap the `_draw()` calls in `scripts/board/piece.gd` and
`scripts/ui/battle_actor.gd` for `Sprite2D` / `AnimatedSprite2D` texture loads.

| Folder              | Recommended pack                | URL                                      |
|---------------------|---------------------------------|------------------------------------------|
| `assets/pieces/`    | Tiny Dungeon (Kenney)           | https://kenney.nl/assets/tiny-dungeon    |
| `assets/characters/`| Medieval RTS (Kenney)           | https://kenney.nl/assets/medieval-rts    |
| `assets/ui/`        | Pixel UI Pack (Kenney)          | https://kenney.nl/assets/pixel-ui-pack   |
| `assets/backgrounds/`| Background Elements Redux      | https://kenney.nl/assets/background-elements-redux |
| `assets/audio/sfx/` | Interface Sounds (Kenney)       | https://kenney.nl/assets/interface-sounds |
| `assets/audio/music/`| RPG Audio (Kenney) — license CC0 | https://kenney.nl/assets/rpg-audio       |

All Kenney assets are released under [Creative Commons Zero (CC0)](https://creativecommons.org/publicdomain/zero/1.0/). Attribution is not required, but is welcome.

## Engine

- [Godot Engine 4](https://godotengine.org/) — MIT.
