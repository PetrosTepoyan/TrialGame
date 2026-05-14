# Three Towers — Manual Testing Checklist

Run from the Godot editor on desktop first, then on an iPhone build.

## Board mechanics

- [ ] Boot the game, tap **Play**. `Chapter 1` is unlocked, levels 2–6 locked.
- [ ] Open level 1 — battle scene loads, 9×9 board fills with four piece colors.
- [ ] **Tap-then-tap**: tap one piece (highlights), tap an orthogonally-adjacent piece — they swap; match resolves; cascade triggers.
- [ ] **Swipe**: press on a piece, swipe in any of four directions — swaps in that direction.
- [ ] **Invalid swap**: swap two adjacent pieces that produce no match — they animate, then animate back; no emblem is added.
- [ ] **Match-3 horizontal / vertical / both diagonals** all add a Level-1 emblem to the action scale.
- [ ] **Match-4** in any axis adds a Level-2 emblem.
- [ ] **Match-5** in any axis adds a Level-3 emblem.
- [ ] **Cascade**: after a match the pieces fall, top refills, and any new matches also resolve and add their own emblems.
- [ ] **No-moves shuffle**: when the board has zero possible swaps, pieces animate-shuffle in place.

## Action scale (5-emblem round system)

- [ ] Each match fills the next empty slot in the action-scale strip; the slot shows the piece's color, a mini icon, and 1/2/3 dots indicating level.
- [ ] On the 5th emblem, slots flash and the round resolves automatically.
- [ ] After resolution the slots clear, ready for the next 5 emblems.
- [ ] If a cascade adds emblems past the 5th, the extras visibly carry into the *next* round's action scale.
- [ ] Input is locked during round resolution (you cannot swap while the hero is acting).

## Per-piece round effects

- [ ] **Sword** emblems sum into one damage number that lands on the enemy when the round resolves (HP bar drops, red float-text appears).
- [ ] **Shield** emblems add green armor to your `ARM x` label; incoming enemy attacks then deplete that armor before HP.
- [ ] **Staff** L1 emblem applies **Burn** to enemy (3 rounds, ticks 5 dmg). The status-strip badge under the enemy HP shows `Burn 2` then `Burn 1` on subsequent rounds.
- [ ] **Staff** L2 emblem applies **Swarm** (5 rounds, 5 dps).
- [ ] **Staff** L3 emblem applies **Cold** (7 rounds, 5 dps).
- [ ] **Bow** emblems strip enemy armor first, then deal HP damage equal to their level_secondary value.

## Same-level 3-combos

- [ ] Three Level-1 Sword emblems in one round: total sword damage is +60% (e.g. 30 → 48).
- [ ] Three Level-2 Sword emblems: +75%; three Level-3: +100%.
- [ ] Four+ same-level emblems: each additional adds another +20% (configurable via `combo_bonus_step_pct`).
- [ ] **Shield** 3-combo: a popup asks "+Armor (boost) / Stun the enemy". Pressing either continues round resolution.
  - [ ] Choosing **Stun** applies a Stun status to the enemy — `Stun N` badge appears, the enemy skips its attack for N rounds, and the floating "STUNNED!" beat shows on the rounds it skips.
  - [ ] Choosing **Armor** stacks the boosted armor on the player.
- [ ] **Staff** 3xL3 combo: a "fireball" damage spike fires AND a `Defense Debuff 3` badge appears under the enemy HP; the enemy's effective armor visibly drops while it's active.
- [ ] **Bow** 3xL3 combo: a `Bleed 3` badge appears; on each subsequent round the enemy takes a tick of bleed damage.

## Status ticking

- [ ] After a DoT lands on the enemy, its rounds-remaining decreases each round; when it hits 0 the badge disappears.
- [ ] DoT damage applies AFTER the round's emblems resolve and AFTER the enemy attacks.
- [ ] Two DoTs of the same kind don't stack count; the longer/stronger one wins.

## Combat outcomes

- [ ] Reducing the enemy to 0 HP: it slumps, the chapter map opens, the level is marked Cleared, the next level unlocks.
- [ ] Reducing the player to 0 HP: hero slumps, Game-Over screen opens; **Retry** restarts the same level.
- [ ] Completing all 5 levels of chapter 1 unlocks the **Tower** boss.
- [ ] Defeating the tower boss unlocks chapter 2.
- [ ] After all 3 tower bosses fall, **Fight the King** unlocks.
- [ ] Defeating the King: Victory screen → **Continue** → next castle generated (castle index increments, enemy stats scale up).

## Saving

- [ ] Win a level, fully quit the app, reopen — completed levels still Cleared.
- [ ] **Main Menu ▸ Reset Save** wipes progress and re-rolls castle 1.

## iPhone-specific

- [ ] Portrait orientation locked.
- [ ] HUD elements (HP bars, action scale, level title, pause button, shield popup) clear of notch / Dynamic Island and home indicator.
- [ ] Touch input has no perceptible delay.

## Tuning levers if it feels off

- Diagonals too easy → `Board.DIAGONAL_MIN_LENGTH = 4` in `scripts/board/board.gd`.
- Enemy damage too punishing → lower `enemy_damage` in `scripts/progression/castle_generator.gd`.
- Combo bonuses too strong → tune `combo_bonus_pct` in `data/piece_types/*.tres`.
- Round too fast / slow → change `SCALE_CAPACITY` in `scripts/combat/combat_controller.gd` (currently 5, per spec).
- Stun too short / long → change `AbilityResolver.STUN_ROUNDS` (currently 2).
- Bleed too weak → tune `AbilityResolver.BLEED_DPS` and `BLEED_ROUNDS`.
