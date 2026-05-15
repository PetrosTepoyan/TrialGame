# Three Towers

A medieval-fantasy match-3 battle game for iOS (and later: Android, macOS, Windows, Linux, Steam). Built in **Godot 4** (GDScript).

## Concept

A single day of war. Each castle has three towers. Each tower stands at the end of a chapter of five blocks of skirmishes. After all three towers fall, the castle's King takes the field. Beat him and you ride out to the next castle — the cycle continues forever, scaling in difficulty.

The **9×9** board is stocked with four "army" pieces:

| Piece  | What it does on match                                             |
|--------|-------------------------------------------------------------------|
| Sword  | Direct damage to the enemy                                        |
| Shield | Armor for you                                                     |
| Staff  | DoT effects on the enemy (Burn / Swarm / Cold by match tier)      |
| Bow    | Armor-pierce + flat HP damage                                     |

Matches are **horizontal and vertical only** — diagonals are disabled on the 9×9 board.

## Combat loop — real-time mana + spec attacks

Combat is **real-time**, not turn-based. Both actors run their own auto-attack timers; you steer the fight by matching pieces.

- **Player auto-attack** — ticks every ~1.8s for the player's base damage.
- **Enemy auto-attack** — ticks on the level's `enemy_attack_interval`.
- **Status timer** — 1.0s tick that runs DoTs and decays status durations on both actors.
- **Stun** pauses the stunned actor's auto-attack until it expires.

### Per-match effects (fire immediately)

Each successful match fires its piece-kind effect immediately. No emblem queue, no round wait.

| Kind   | L1                                | L2                                | L3                                |
|--------|-----------------------------------|-----------------------------------|-----------------------------------|
| Sword  | small damage                      | more damage                       | top damage (bonus for run ≥ 6)    |
| Shield | +armor to player                  | +armor to player                  | +armor to player                  |
| Staff  | **Burn** DoT on enemy             | **Swarm** DoT on enemy            | **Cold** DoT on enemy             |
| Bow    | small pierce + HP damage          | more pierce + HP damage           | top pierce + HP damage            |

### Match tiers

| Match shape                                | Effective level |
|--------------------------------------------|-----------------|
| Match-3 (horizontal or vertical)           | 1               |
| Match-4 (horizontal or vertical)           | 2               |
| 2×2 square of same kind                    | 2               |
| L-corner (3+3 sharing a corner)            | 2               |
| Match-5+ (horizontal or vertical)          | 3               |

### Cascade combo bonus

Chain 3+ matches of the **same kind & same level** inside a single cascade and the kind drops a bonus damage pulse at cascade-end. Bonus % comes from `combo_bonus_pct` in each piece's `.tres`; each additional same-level match past the 3rd adds `combo_bonus_step_pct`.

### Mana bar + special attacks

Matches also award mana into a 0–300 bar:

| Trigger                        | Mana |
|--------------------------------|------|
| Match-3                        | 20   |
| 2×2 square / L-corner          | 30   |
| Match-4                        | 35   |
| Match-5+ or any effective L3   | 55   |

The spec button below the bar enables at 100 mana and changes color as you cross 200 / 300. Tap to fire — **the whole bar is consumed regardless of tier**, downshifting to the highest tier you have currently charged.

| Tier | Name             | Effect                                           |
|------|------------------|--------------------------------------------------|
| L1   | Shield Bash      | 8 damage + **5s stun** on enemy                  |
| L2   | Spinning Strike  | 30 damage, **bypasses armor**                    |
| L3   | Shadow Strike    | 42 damage + **8s bleed** (2 dps)                 |

### Status effects

Status effects measured in **seconds** (real-time), ticking on the status timer:

- **Burn / Swarm / Cold** — DoT, refreshes to the longer duration if reapplied.
- **Bleed** — DoT (L3 spec's after-effect).
- **Ignite / Acid Burn** — DoTs from the Fire Bomb / Acid items.
- **Stun** — auto-attack pauses for the duration.
- **Armor Debuff** — Broken Shield item: -3 enemy armor for 10s.
- **Attack Buff** — Sword+ item: +3 player damage for 10s.
- **Ranged Shield** — CP2 archers: charge-based volley block.

## Board items

Item cells spawn periodically into refilled cells (~4% baseline, scales up as the player loses HP). They **cannot be swapped or moved** — they anchor their column during gravity. Adjacent matches (8-dir against the cells cleared in that batch) decrement integrity; on break the effect fires.

| Item          | Integrity | On break                                  |
|---------------|-----------|-------------------------------------------|
| Shield        | 1         | +5 player armor                           |
| Broken Shield | 6         | -3 enemy armor for 10s                    |
| Red Potion    | 6         | +25 player HP                             |
| Sword+        | 1         | +3 player attack for 10s                  |
| Acid          | 1         | 5s enemy ACID_BURN DoT (4 dps)            |
| Fire Bomb     | 1         | 5s enemy IGNITE DoT (5 dps)               |

Concurrent items capped at 3 on the board. Item resources live in `data/board_items/*.tres`; spawn logic in `scripts/board/item_spawner.gd`; effect dispatch in `scripts/board/item_effects.gd`.

## Progression

Each chapter is **5 blocks of (10 regular + 1 checkpoint)** = **55 levels per chapter**. A castle is **3 chapters + King** = **166 battles**. Castle index loops through the preset name pool after each King defeat.

Chapter 1 ships with five named checkpoint encounters; chapters 2/3 stay procedural for now.

| Block | Chapter-1 checkpoint        | Mechanic                                                                 |
|-------|-----------------------------|--------------------------------------------------------------------------|
| 0     | Forward Garrison (CP1)      | 5 enemies share one HP bar — boosted Shield + Red Potion spawns          |
| 1     | Wall Archers (CP2)          | Periodic ranged volleys; Shield items grant a 1-charge volley block      |
| 2     | Catacombs (CP3)             | Boss takes 2× damage from BURN / IGNITE / ACID_BURN; Acid + Fire Bomb up |
| 3     | Naval Pier (CP4)            | Heavy cannon every ~8s; firing any spec during the 2s telegraph cancels  |
| 4     | Supply Tower Warden (CP5)   | Keg-pressure + 20s resupply heal (10%) unless interrupted by L2+ spec or ≥200 damage during the telegraph |

### Death rollback

- **No checkpoint cleared in this chapter** → rewind to chapter start, **all run upgrades wiped**.
- **At least one checkpoint cleared** → rewind to (last checkpoint + 1), restore the **upgrade snapshot** locked at that checkpoint. Upgrades collected after the snapshot are lost.
- **"Start Fresh Run"** (main menu + in-battle settings) — manual full-progress wipe with confirmation.

### Upgrade picker

After every regular and checkpoint battle (not King) the player is offered **1-of-3 cards**: +Max HP / +Max Armor / +Damage (rare +20 Max HP variant). Checkpoint picks are locked into the snapshot so they survive a future death within the chapter.

## Project Layout

```
project.godot              Godot project config (autoloads, display, input)
export_presets.cfg         iOS + macOS + Windows + Linux export configs
icon.svg                   App icon (silhouette of three towers)
.gitignore                 Godot-flavoured

scripts/
  autoload/                Singletons (GameState, SceneRouter, AudioBus, Haptics, SafeArea)
  resources/               Custom Resource scripts (PieceType, BoardItem,
                           SpecialAttack, StatusEffect, LevelResource,
                           ChapterResource, CastleResource, BossModifier,
                           EncounterModifier, RunUpgrade)
  board/                   Board, Piece, MatchDetector, NoMovesDetector, input,
                           ItemPiece, ItemSpawner, ItemEffects
  combat/                  CombatActor, CombatController, ManaSystem,
                           AutoAttackLoop, MatchEffectApplier,
                           SpecialAttackResolver, encounter_behaviors/
  progression/             CastleGenerator, SaveSystem
  scenes/                  Per-scene scripts (battle.gd, chapter_map.gd,
                           upgrade_picker.gd, main_menu.gd, ...)
  ui/                      HpBar, BattleActor, ManaBar, SpecialAttackButton,
                           StatusStrip, SettingsPanel, TutorialOverlay
  debug/                   DebugMenu, DebugOverlay, ShakeDetector

scenes/
  main.tscn                Boot scene → main menu
  ui/
    main_menu.tscn
    game_over.tscn
    victory.tscn
    upgrade_picker.tscn
  chapter_map.tscn         5 blocks × (10 regular + 1 checkpoint) per chapter
  battle.tscn              The match-3 battle scene + mana bar + spec button

data/piece_types/          sword.tres, shield.tres, staff.tres, bow.tres
data/board_items/          shield, broken_shield, red_potion, sword_up, acid, fire_bomb
data/special_attacks/      shield_bash, spinning_strike, shadow_strike
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

Progress is written atomically to `user://savegame.json` (`.tmp` + rename pattern). Save format is **v2** (`SAVE_VERSION = 2`); a v1 save found on first launch is auto-wiped and the main menu shows a one-time banner.

Persisted: castle index, chapter index, block index, level-in-block, completed levels & stars, completed checkpoints, the last-checkpoint snapshot, run upgrades (live + locked snapshot), player derived stats, and tutorial / audio flags.

To wipe progress from inside the app: **Main Menu ▸ Start Fresh Run** (also available in the in-battle settings panel).

## Tuning the Game

Most balance lives in these places:

- `scripts/progression/castle_generator.gd` — enemy HP / damage curves per chapter / block / level / castle index, checkpoint and tower stats, chapter-1 encounter modifiers.
- `data/piece_types/*.tres` — per-piece `level_values`, `level_secondary`, `combo_bonus_pct`, `combo_bonus_step_pct`.
- `data/board_items/*.tres` — item integrity, effect magnitudes, durations, spawn weights, tints.
- `data/special_attacks/*.tres` — spec damage, stun seconds, armor-bypass flag.
- `scripts/combat/combat_controller.gd` — `PLAYER_INTERVAL_DEFAULT`, `mana_for_match()`, status-tick interval.
- `scripts/board/item_spawner.gd` — base spawn chance, HP-pressure multipliers, forced-spawn floor.
- `scripts/combat/encounter_behaviors/*.gd` — CP1..CP5 telegraph timers, ranged-volley periods, resupply heal fraction, interrupt threshold.

If diagonal-matching is ever wanted, set `Board.DIAGONAL_MIN_LENGTH` to a small number in `scripts/board/board.gd` (currently `99`, which disables them).

## Visuals

V1 ships with **all visuals drawn programmatically** (pieces, characters, HP bars, backgrounds, mana bar, status strip). This keeps the project asset-free and unblocks playtest immediately. To upgrade visuals:

- Drop **Kenney.nl** CC0 pixel-art packs into `assets/pieces/`, `assets/characters/`, etc. See `assets/README.md` for the directory map.
- Replace `_draw()` in `scripts/board/piece.gd` and `scripts/ui/battle_actor.gd` with `Sprite2D` / `AnimatedSprite2D` texture loads.
- Replace the programmatic mana-bar / spec-button styling in `scripts/ui/mana_bar.gd` and `scripts/ui/special_attack_button.gd` with `TextureProgressBar` / `TextureButton` once art is ready.
- See `CREDITS.md` for the asset packs recommended.

The investor reference image (dark-fantasy, illustrated knights / king on a burning-castle backdrop, ornate framed HP bars) is the V2 art target — the mechanics it implies (mana, spec attacks, status badges) are all live now.

## Localization

UI is currently English-only. A Russian translation is on the deferred list.

## Testing Checklist

See `TESTING.md`.

## License

Code: MIT. Asset attributions: `CREDITS.md`.
