# Three Towers

A medieval-fantasy match-3 battle game for iOS (and later: Android, macOS, Windows, Linux, Steam). Built in **Godot 4** (GDScript).

## Concept

A single day of war. Each castle has three towers. Each tower stands at the end of a chapter of five skirmishes. After all three towers fall, the castle's King takes the field. Beat him and you ride out to the next castle — the cycle continues forever, scaling in difficulty.

Pieces on the 9×9 board represent the four pillars of a medieval army:

| Piece  | Effect on match-3                                                |
|--------|------------------------------------------------------------------|
| Spear  | Direct melee damage to the enemy                                  |
| Archer | Damage that bypasses armor                                        |
| Shield | Heals you + grants temporary armor                                |
| King   | Damage to enemy + fills the **Rally** meter (Royal Command)       |

Matches detected in **all 8 directions**: horizontal, vertical, both diagonals.

- **Match-3**: base effect
- **Match-4**: 2× effect **and** an extra turn
- **Match-5**: 3× effect **and** clears every remaining piece of that type from the board

If you swap and create no match, the swap reverts and your turn ends.

## Project Layout

```
project.godot              Godot project config (autoloads, display, input)
export_presets.cfg         iOS + macOS + Windows + Linux export configs
icon.svg                   App icon (silhouette of three towers)
.gitignore                 Godot-flavoured

scripts/
  autoload/                Singletons (GameState, SceneRouter, AudioBus)
  resources/               Custom Resource scripts (PieceType, LevelResource, ...)
  board/                   Board, Piece, MatchDetector, NoMovesDetector, input
  combat/                  Actor, CombatController, AbilityResolver
  progression/             CastleGenerator, SaveSystem
  scenes/                  Per-scene scripts (battle.gd, chapter_map.gd, ...)
  ui/                      HpBar, BattleActor

scenes/
  main.tscn                Boot scene → main menu
  ui/
    main_menu.tscn
    game_over.tscn
    victory.tscn
  chapter_map.tscn         Three chapters of 5 levels + boss + King button
  battle.tscn              The match-3 battle scene

data/piece_types/          Designer-tunable piece stats (.tres)
assets/                    Sprites/audio/fonts (placeholder — see assets/README.md)
```

## Running on a Mac

1. Install [Godot 4.3+](https://godotengine.org/).
2. Open the editor and **Import** the `project.godot` in this repo. On first import Godot will (re)generate `.import` metadata and `.godot/` — both are gitignored.
3. Hit **F5** (Play). The main menu opens at portrait 540×960 in the editor (1080×1920 base resolution); touch is emulated from mouse.

## Building for iOS

This Godot 4 project ships with an `iOS` export preset (see `export_presets.cfg`). You will need to set the following yourself before exporting:

- **Bundle Identifier** — currently `com.example.threetowers`. Replace with your own.
- **App Store Team ID** — fill in for distribution builds.
- **Provisioning Profile UUIDs** — for code-signing.
- **Icons** — drop `.png` files into the icon slots in `Project ▸ Export ▸ iOS ▸ Options`.

Then:

```
Project ▸ Export ▸ iOS ▸ Export Project...
```

This generates an Xcode project. Open it on your Mac, set your signing identity, plug in your iPhone, and **Run**.

Touch input is wired through `InputEventScreenTouch` / `InputEventScreenDrag` (see `scripts/board/input_handler.gd`). Both **tap-then-tap-adjacent** and **swipe-to-swap** are supported.

## Save Data

Progress is written atomically to `user://savegame.json` (`.tmp` + rename pattern). Save is keyed on `castle.chapter.level` triples; advancing past the King wipes the save and rolls a new (harder) castle.

To wipe progress from inside the app: `Main Menu ▸ Reset Save`.

## Tuning the Game

Most balance lives in two places:

- `scripts/progression/castle_generator.gd` — enemy HP / damage scaling per chapter, level, and castle index.
- `data/piece_types/*.tres` — per-piece base damage and match-4 / match-5 multipliers.

If diagonal-8 matching turns out to feel too easy, set `Board.DIAGONAL_MIN_LENGTH = 4` in `scripts/board/board.gd` to require length-4+ for diagonal matches.

## Visuals

V1 ships with **all visuals drawn programmatically** (pieces, characters, HP bars, backgrounds). This keeps the project asset-free and unblocks playtest immediately. To upgrade visuals:

- Drop **Kenney.nl** CC0 pixel-art packs into `assets/pieces/`, `assets/characters/`, etc. See `assets/README.md` for the directory map.
- Replace `_draw()` in `scripts/board/piece.gd` and `scripts/ui/battle_actor.gd` with `Sprite2D` / `AnimatedSprite2D` texture loads.
- See `CREDITS.md` for the asset packs recommended.

## Testing Checklist

See `TESTING.md`.

## License

Code: MIT. Asset attributions: `CREDITS.md`.
