# Three Towers — Manual Testing Checklist

Run from the Godot editor on desktop first, then on an iPhone build.

## Board mechanics

- [ ] Boot the game, tap **Play**. `Chapter 1` is unlocked, later checkpoints/blocks locked.
- [ ] Open level 1 — battle scene loads, **9×9** board fills with four piece colors.
- [ ] **Tap-then-tap**: tap one piece (highlights), tap an orthogonally-adjacent piece — they swap; matches resolve; cascade triggers.
- [ ] **Swipe**: press on a piece, swipe in any of four directions — swaps in that direction.
- [ ] **Invalid swap**: swap two adjacent pieces that produce no match — they animate, then animate back; no effect fires.
- [ ] **Diagonals disabled**: three-in-a-row along a diagonal does *not* count as a match (`DIAGONAL_MIN_LENGTH = 99`).
- [ ] **Cascade**: after a match, pieces fall, the top refills, and any new matches also resolve and fire their own effects.
- [ ] **No-moves shuffle**: when the board has zero possible swaps, pieces animate-shuffle in place until a move exists.
- [ ] **Idle hint**: leave the board untouched for ~6s — two pieces of a valid move pulse until you tap.

## Match types

- [ ] **Match-3** horizontal or vertical → effective level 1.
- [ ] **Match-4** horizontal or vertical → effective level 2.
- [ ] **Match-5+** horizontal or vertical → effective level 3.
- [ ] **2×2 square** of same kind → effective level 2 (`is_square` flag).
- [ ] **L-corner** (a row-of-3 and a column-of-3 sharing a corner cell) → effective level 2 (`had_corner` flag).
- [ ] Effective level drives mana gain, per-match effect strength, and combo grouping — verify by reading the mana increment matches the table below.

## Combat — mana bar + special attacks

- [ ] Mana bar visible above the board, range 0–300, with tick marks at 100 / 200 / 300.
- [ ] Each match adds mana:
  - Match-3 → **+20**.
  - 2×2 square / L-corner → **+30**.
  - Match-4 → **+35**.
  - Match-5+ or any effective-L3 → **+55**.
- [ ] Spec button is **disabled** until mana ≥ 100.
- [ ] At 100 mana the button glows **blue** (L1 — Shield Bash).
- [ ] At 200 mana the button glows **gold** (L2 — Spinning Strike).
- [ ] At 300 mana the button glows **red** (L3 — Shadow Strike).
- [ ] Tapping the spec button at any charge tier burns **all** mana (drops to 0) and fires that tier.
- [ ] **L1 — Shield Bash**: 8 damage + **5s STUN** on enemy (status badge `Stun` appears; enemy auto-attacks stop ticking for the duration).
- [ ] **L2 — Spinning Strike**: 30 damage, **bypasses armor**.
- [ ] **L3 — Shadow Strike**: 42 damage + **8s bleed** (2 dps).
- [ ] During the spec animation the player auto-attack loop is paused (no double-tap during FX).

## Combat — auto-attack loops

- [ ] **Player auto-attack** ticks roughly every **1.8s** for 6 base damage (jittered ±20%).
- [ ] **Enemy auto-attack** ticks every `level.enemy_attack_interval` (boss / king authoring uses fast 1.4s).
- [ ] When a status `Stun` is active on either actor, that actor's auto-attack skips ticks until the stun expires.
- [ ] Both loops stop when either actor reaches 0 HP.
- [ ] Loops pause briefly during a player spec animation.

## Combat — per-kind match effects

- [ ] **Sword** match → enemy takes damage (`level_values` × longest-run bonus when run ≥ 6).
- [ ] **Shield** match → player armor goes up by `level_values[level]` (no popup, no choice — direct gain).
- [ ] **Staff** match → enemy gains a DoT:
  - L1 → **Burn** (duration sec, dps from `level_secondary`).
  - L2 → **Swarm**.
  - L3 → **Cold**.
- [ ] **Bow** match → strips enemy armor (pierce = `level_values`) and deals small HP damage (`level_secondary`).
- [ ] DoT damage ticks every 1.0s (status timer); float text appears over the enemy on each tick.
- [ ] **Cascade combo bonus**: chaining 3+ matches of the same kind & level inside a single cascade adds bonus damage at cascade end — bonus comes from `combo_bonus_pct[level-1]` in the piece's `.tres`; each extra same-tier match past the 3rd adds `combo_bonus_step_pct`.

## Items

- [ ] Item cells spawn periodically during refill (~4% per refilled cell baseline).
- [ ] Spawn rate scales with player HP pressure: ×1.5 below 60% HP, ×2.5 below 30% HP.
- [ ] Forced spawn floor: at least one item attempts to appear every ~30s.
- [ ] Item cells **cannot be swapped or moved**; they anchor their column during gravity (pieces stack on top of them).
- [ ] Adjacent matches (8-dir, the cleared cells in the resolved batch) decrement item integrity by the count of adjacent cleared cells.
- [ ] When integrity reaches 0 the item breaks: small particle burst, slot empties, gravity/refill replaces it.
- [ ] Verify each item triggers its effect on break:
  - **Shield** (integrity 1, instant) → player gains **+5 armor**.
  - **Broken Shield** (integrity 6) → enemy gets **-3 armor for 10s** (`ARMOR_DEBUFF_ITEM` status).
  - **Red Potion** (integrity 6) → player heals **+25 HP**.
  - **Sword+** (integrity 1, instant) → player gets **+3 attack for 10s** (`ATTACK_BUFF` status).
  - **Acid** (integrity 1, instant) → enemy gets **5s ACID_BURN** DoT (4 dps).
  - **Fire Bomb** (integrity 1, instant) → enemy gets **5s IGNITE** DoT (5 dps).
- [ ] Concurrent items capped at **3** on the board.

## Encounters — Chapter 1 checkpoints

Block index → encounter (level 11 of each block):

- [ ] **CP1 — Forward Garrison** (block 0): defeat **5 enemies in sequence** on a single shared HP bar. Killing one swaps in the next without firing `battle_won`. Shield and red potion items spawn-boosted.
- [ ] **CP2 — Wall Archers** (block 1): periodic ranged **volley telegraph** (~1.5s warning), then a hit for 10 damage. A broken Shield item also grants a single-charge **RANGED_SHIELD** status that absorbs one full volley. Shield items spawn-boosted.
- [ ] **CP3 — Catacombs** (block 2): boss takes **2× damage** from BURN / IGNITE / ACID_BURN DoTs. Acid and Fire Bomb items spawn-boosted.
- [ ] **CP4 — Naval Pier** (block 3): heavy cannon every ~8s with a **2s telegraph**; firing **any spec attack during the telegraph** cancels the shot.
- [ ] **CP5 — Supply Tower Warden** (block 4, tower boss): keg-pressure mechanic *plus* a **20s resupply telegraph** that heals 10% max HP unless interrupted by an **L2+ spec** or **≥200 damage** during the telegraph window. Fire Bomb item spawn-boosted; Red Potion suppressed.

## Progression

- [ ] Each chapter has **55 levels** = 5 blocks × (10 regular battles + 1 checkpoint).
- [ ] Checkpoint slots fall at level-in-block index **10** for blocks 0..4 (CP1, CP2, CP3, CP4, CP5/Tower).
- [ ] Beating CP5 (the tower boss) advances to chapter 2.
- [ ] **Total per castle**: 3 chapters × 55 + 1 King = **166 levels**.
- [ ] Beating the King wipes battle progress and advances `castle_index`; castle index **loops** through preset names/subtitles.
- [ ] **Death before any chapter checkpoint cleared**: rewind to start of current chapter, **all run upgrades wiped**.
- [ ] **Death after at least one checkpoint cleared this chapter**: rewind to (last checkpoint + 1), **run upgrades restored** from the snapshot locked at that checkpoint. Non-locked upgrades collected after the snapshot are lost.
- [ ] **Start Fresh Run**: available on main menu and in-battle settings panel; confirms then wipes all progress.

## Upgrade picker

- [ ] After every regular battle and every checkpoint battle, the **1-of-3 upgrade picker** appears with three cards.
- [ ] Choices are drawn from: **+10 Max HP**, **+2 Max Armor**, **+1 Damage** (rare **+20 Max HP** appears ~25% of the time).
- [ ] Choosing a card applies the upgrade to the run.
- [ ] If the cleared level was a **checkpoint**, the picker shows a "this reward is locked in" subline and the chosen upgrade is added to `run_upgrades_locked_at_checkpoint` snapshot — survives the next death.
- [ ] The picker is **skipped** for the King fight (final battle of the castle).

## Save system

- [ ] Save file at `user://savegame.json`, atomic `.tmp` + rename.
- [ ] Save format version is **2** (`SAVE_VERSION = 2`).
- [ ] First load on an existing **v1 save**: file is auto-wiped, `save_was_wiped_this_launch` flag flips on, and the main menu shows a one-time banner. Dismissing the banner clears the flag.
- [ ] Quit and reopen after winning a level — completed levels, current block/level-in-block, run upgrades, and checkpoint snapshot all persist.

## Debug menu

Open with the shake / debug gesture. Tabs:

- [ ] **Stats** — live readouts of mana, HP, status effects, etc.
- [ ] **Combat** — live enemy damage, player max HP / enemy max HP, **mana spinbox**, **Fire L1/L2/L3 spec** buttons, **Infinite mana** toggle, **Auto-attack damage = 0** toggle.
- [ ] **Items** — force-trigger each of the six items (skips spawn/break path and applies the effect directly).
- [ ] **Board** — read `DIAGONAL_MIN_LENGTH` / `MAX_CASCADE_DEPTH`; **Force reshuffle**.
- [ ] **Progression** — **Jump to CP1..CP5 / Tower**, **Mark checkpoint cleared**, **Force death + rollback**.
- [ ] **Audio**, **Haptics**, **Cheats** — sliders / toggles.

## iPhone-specific

- [ ] Portrait orientation locked.
- [ ] Safe-area respected: HUD (HP bars, mana bar, status badges, level label, pause/exit, spec button) clears notch / Dynamic Island and home indicator.
- [ ] Touch input responsive on the 9×9 board at **108px** piece size; no perceptible swap delay.

## Tuning levers if it feels off

- Mana gain per match → `CombatController.mana_for_match()` in `scripts/combat/combat_controller.gd`.
- Spec damage / status → `data/special_attacks/*.tres` and `scripts/combat/special_attack_resolver.gd`.
- Player auto-attack tempo → `CombatController.PLAYER_INTERVAL_DEFAULT`.
- Item spawn rate / pressure curve → `ItemSpawner.BASE_SPAWN_CHANCE_PER_REFILL` and `_hp_pressure_multiplier()` in `scripts/board/item_spawner.gd`.
- Item integrity / effect numbers → `data/board_items/*.tres`.
- Per-kind match effect numbers → `data/piece_types/*.tres` (`level_values`, `level_secondary`, `combo_bonus_pct`).
- Enemy HP / damage curves → `scripts/progression/castle_generator.gd`.
- Checkpoint encounter values → the `EncounterModifier` builders in `castle_generator.gd` (CP1..CP5).
