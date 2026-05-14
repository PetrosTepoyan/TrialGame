# Credits

## Code

- Game design & code: this repository (MIT-licensed unless otherwise noted).

## Art

All art assets in `assets/pieces/`, `assets/characters/` (including `assets/characters/bosses/`), and `assets/ui/` are by **[Kenney](https://kenney.nl)** under [Creative Commons Zero (CC0 1.0)](https://creativecommons.org/publicdomain/zero/1.0/). CC0 = free to use, modify, and sell with no attribution required — Kenney is credited here anyway.

| Pack                                                  | Used for                                              | Files                                                  |
|-------------------------------------------------------|-------------------------------------------------------|--------------------------------------------------------|
| [Tiny Dungeon](https://kenney.nl/assets/tiny-dungeon)  | Board pieces + battle-scene + boss-specific portraits | `assets/pieces/*.png`, `assets/characters/*.png`, `assets/characters/bosses/*.png` |
| [Pixel UI Pack](https://kenney.nl/assets/pixel-ui-pack) | 9-slice popup frames                                 | `assets/ui/panel_*.png`                                |
| [Interface Sounds](https://kenney.nl/assets/interface-sounds) | UI / combat SFX                                  | `assets/audio/sfx/*.ogg`                                |

Per-folder `LICENSE.txt` files preserve Kenney's CC0 declaration.

### Tile picks (Tiny Dungeon → role)

The pack ships as a 12 × 11 grid of named tiles. Roles used:

| Tile | Role                                       |
|------|--------------------------------------------|
| 0084 | Staff piece (purple wizard)                |
| 0085 | Shield piece (armored guard with shield)   |
| 0086 | Default enemy / non-boss footsoldier       |
| 0087 | (alt enemy sprite)                         |
| 0096 | Sword piece + Hero (silver knight)         |
| 0097 | Watchtower Warden — chapter 1 tower boss   |
| 0099 | Bow piece (hooded ranger)                  |
| 0100 | King — castle final boss                   |
| 0109 | Drum Tower Warden — chapter 2 tower boss   |
| 0087 | Keep Warden — chapter 3 tower boss         |

These are wired in `scripts/board/piece.gd`, `scripts/ui/battle_actor.gd`, and `scripts/progression/castle_generator.gd::_boss_sprite_path()` — swap any file (keep the filename) to swap visuals.

## Music

Music tracks in `assets/audio/music/` are by **[Kevin MacLeod](https://incompetech.com)** under [Creative Commons Attribution 4.0 (CC-BY 4.0)](https://creativecommons.org/licenses/by/4.0/). CC-BY requires a credit line, which appears on the main menu of the game.

| File          | Track            | Composer       | License |
|---------------|------------------|----------------|---------|
| `menu.mp3`    | "Achilles"       | Kevin MacLeod  | CC-BY 4.0 |
| `battle.mp3`  | "Achaidh Cheide" | Kevin MacLeod  | CC-BY 4.0 |

In-game credit line (shown on the main menu's bottom strip):

> Art: Kenney.nl (CC0) • Music: Kevin MacLeod / incompetech.com (CC-BY)

## Recommended further assets (V2 art swap)

- [Kenney Roguelike Characters](https://kenney.nl/assets/roguelike-characters) — modular character builder for boss variety.
- [Kenney Medieval RTS](https://kenney.nl/assets/medieval-rts) — top-down medieval units, structures, tiles for world map.
- [0x72 Dungeon Tileset II](https://0x72.itch.io/dungeontileset-ii) — darker pixel-fantasy alternative.
- [Kevin MacLeod / incompetech.com](https://incompetech.com) — many more medieval tracks ("Heart of the Beast", "Volatile Reaction", "Heroic Age").
- [OpenGameArt LPC](https://opengameart.org/content/lpc-collection) — LPC characters (CC-BY-SA — verify per asset).

## Engine

- [Godot Engine 4](https://godotengine.org/) — MIT.
