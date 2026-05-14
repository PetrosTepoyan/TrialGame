# Three Towers

A medieval-fantasy match-3 battle game for iOS (and later: Android, macOS, Windows, Linux, Steam). Built in **Godot 4** (GDScript).

## Concept

A single day of war. Each castle has three towers. Each tower stands at the end of a chapter of five skirmishes. After all three towers fall, the castle's King takes the field. Beat him and you ride out to the next castle — the cycle continues forever, scaling in difficulty.

The 9×9 board is stocked with four "army" pieces:

| Piece  | Role on the action scale                                          |
|--------|-------------------------------------------------------------------|
| Sword  | Direct damage to the enemy                                        |
| Shield | Armor for you — or, on combo, stun for the enemy                  |
| Staff  | DoT effects on the enemy (Burn / Swarm / Cold by emblem level)    |
| Bow    | Armor-pierce + flat HP damage; combo of L3 emblems also bleeds    |

Matches detected in **all 8 directions**: horizontal, vertical, both diagonals.

## Combat loop — the action scale

Combat is **round-based**, not match-by-match. Each successful match drops an **Emblem** onto your **action scale** (capacity 5). When the scale fills, your hero acts and:

1. The 5 emblems are resolved together — damage / armor / heal / status effects all batched into one beat.
2. Existing DoTs on both sides tick (Burn ticks for its dps, Bleed ticks for its dps, etc.).
3. The enemy attacks once for its base damage — **unless it's stunned**, in which case the attack is skipped (stun rounds decrement at end-of-round).
4. The scale clears, ready for your next 5 matches. Emblems collected while the round was animating queue for the new round.

### Emblem levels

The length of your match determines the emblem level:

| Match length | Emblem level |
|--------------|--------------|
| 3 in a row   | Level 1      |
| 4 in a row   | Level 2      |
| 5+ in a row  | Level 3      |

### Per-kind effects at each level

| Kind   | L1                       | L2                       | L3                       |
|--------|--------------------------|--------------------------|--------------------------|
| Sword  | 10 dmg                   | 12 dmg                   | 15 dmg                   |
| Shield | +1 armor                 | +3 armor                 | +5 armor                 |
| Staff  | Burn (3 rounds, 5 dps)   | Swarm (5 rounds, 5 dps)  | Cold (7 rounds, 5 dps)   |
| Bow    | Pierce 2 + 1 HP dmg      | Pierce 3 + 2 HP dmg      | Pierce 5 + 3 HP dmg      |

### 3+ same-level combo bonuses

Collect three or more emblems of the **same kind and same level** during a single round, and the kind triggers a special:

| Kind   | 3+ same L1                                | 3+ same L2                                | 3+ same L3                                |
|--------|-------------------------------------------|-------------------------------------------|-------------------------------------------|
| Sword  | total dmg +60%                            | total dmg +75%                            | total dmg +100%                           |
| Shield | choose: stun the enemy (2+ rounds) **OR** stack armor with the same % bonus | same — choose stun or armor             | same — choose stun or armor               |
| Staff  | fireball: extra dmg + burn                | extra dmg + extended swarm                | extra dmg + Defense Debuff (3 rounds)     |
| Bow    | pierce + HP dmg, both scaled by bonus     | same                                      | also applies Bleed (3 rounds, 2 dps)      |

Each emblem past the 3rd at the same level adds an extra +20%.

### Status effects

Status effects measured in **rounds**, ticking at end-of-round:

- **Burn / Swarm / Cold** — DoT, refreshes to the longer duration if reapplied.
- **Bleed** — DoT, bow combo only.
- **Stun** — enemy skips attack for the duration.
- **Defense Debuff** — reduces enemy armor by 3 while active.

## Project Layout

```
project.godot              Godot project config (autoloads, display, input)
export_presets.cfg         iOS + macOS + Windows + Linux export configs
icon.svg                   App icon (silhouette of three towers)
.gitignore                 Godot-flavoured

scripts/
  autoload/                Singletons (GameState, SceneRouter, AudioBus)
  resources/               Custom Resource scripts (PieceType, Emblem,
                           StatusEffect, LevelResource, ChapterResource,
                           CastleResource, BossModifier)
  board/                   Board, Piece, MatchDetector, NoMovesDetector, input
  combat/                  Actor, CombatController, AbilityResolver
  progression/             CastleGenerator, SaveSystem
  scenes/                  Per-scene scripts (battle.gd, chapter_map.gd, ...)
  ui/                      HpBar, BattleActor, ActionScale, StatusStrip

scenes/
  main.tscn                Boot scene → main menu
  ui/
    main_menu.tscn
    game_over.tscn
    victory.tscn
  chapter_map.tscn         Three chapters of 5 levels + boss + King button
  battle.tscn              The match-3 battle scene + action scale + status

data/piece_types/          Designer-tunable piece stats (.tres):
                           sword.tres, shield.tres, staff.tres, bow.tres
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

Then `Project ▸ Export ▸ iOS ▸ Export Project...`. The generated Xcode project goes onto your Mac; sign + plug in + Run.

Touch input is wired through `InputEventScreenTouch` / `InputEventScreenDrag` (see `scripts/board/input_handler.gd`). Both **tap-then-tap-adjacent** and **swipe-to-swap** are supported.

## Steam / Desktop path

Desktop presets are already configured (`Linux/X11`, `macOS`, `Windows Desktop`). For Steamworks integration (achievements, cloud saves, Steam friends) add [GodotSteam](https://godotsteam.com/) — an MIT plugin that drops into `addons/`. The on-screen layout will need a landscape variant for desktop play; that's a `display.window/handheld/orientation` flip plus reworking `battle.tscn` anchors as a follow-up.

## Save Data

Progress is written atomically to `user://savegame.json` (`.tmp` + rename pattern). Save is keyed on `castle.chapter.level` triples; advancing past the King wipes the save and rolls a new (harder) castle.

To wipe progress from inside the app: `Main Menu ▸ Reset Save`.

## Tuning the Game

Most balance lives in three places:

- `scripts/progression/castle_generator.gd` — enemy HP / damage scaling per chapter, level, and castle index.
- `data/piece_types/*.tres` — per-piece `level_values`, `level_secondary`, and `combo_bonus_pct`.
- `scripts/combat/ability_resolver.gd` — stun/bleed/debuff round constants, plus the per-kind resolution logic.

If diagonal-8 matching feels too easy, set `Board.DIAGONAL_MIN_LENGTH = 4` in `scripts/board/board.gd` to require length-4+ for diagonal matches.

## Visuals

V1 ships with **all visuals drawn programmatically** (pieces, characters, HP bars, backgrounds, action scale, status strip). This keeps the project asset-free and unblocks playtest immediately. To upgrade visuals:

- Drop **Kenney.nl** CC0 pixel-art packs into `assets/pieces/`, `assets/characters/`, etc. See `assets/README.md` for the directory map.
- Replace `_draw()` in `scripts/board/piece.gd` and `scripts/ui/battle_actor.gd` with `Sprite2D` / `AnimatedSprite2D` texture loads.
- Replace `_draw()` in `scripts/ui/action_scale_slot.gd` with a `TextureRect` (or `NinePatchRect` for the frame) so emblem art slots in by piece kind + level.
- See `CREDITS.md` for the asset packs recommended.

The investor reference image (dark-fantasy, illustrated knights / king on a burning-castle backdrop, ornate framed HP bars) is the V2 art target — the mechanics it implies (action scale, emblems, status badges) are all live now.

## Testing Checklist

See `TESTING.md`.

## License

Code: MIT. Asset attributions: `CREDITS.md`.
