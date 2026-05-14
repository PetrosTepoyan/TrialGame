# Three Towers — Manual Testing Checklist

These checks should be run from the Godot editor on desktop and again on an iPhone build, before considering a build shippable.

## Board mechanics

- [ ] Boot the game, tap **Play**. `Chapter 1` is unlocked, levels 2–6 are locked.
- [ ] Open level 1 — battle scene loads, 9×9 board fills with four piece colors.
- [ ] **Tap-then-tap**: tap one piece (it highlights), tap an orthogonally-adjacent piece — they swap; match resolves; cascade triggers.
- [ ] **Swipe**: press on a piece, swipe up / down / left / right — it swaps in the swiped direction.
- [ ] **Invalid swap**: swap two adjacent pieces that do not create a match — they animate, then animate back, and the enemy attacks (turn penalty).
- [ ] **Match-3 horizontal** registers a hit on the enemy HP bar.
- [ ] **Match-3 vertical** registers a hit.
- [ ] **Match-3 diagonal (both axes)** each register a hit.
- [ ] **Match-4** in any axis: damage roughly doubles, the player keeps the turn, a **Bomb** tile (dark with glowing-gold border) is placed at the cell the swap moved a piece into.
- [ ] **Match-5** in any axis: damage ~triples, the player keeps the turn, a **Crossed-Swords** tile (purple with glowing-gold border) is placed at the swap target.
- [ ] **Cascade**: after a match the pieces fall, top refills, and any new matches also resolve. Cascade-induced matches do **not** spawn additional power-ups (only the player's first match per move can).
- [ ] **No-moves shuffle**: when the board has zero possible swaps, pieces animate-shuffle in place.
- [ ] **Bomb detonation**: swap a Bomb tile with any orthogonal neighbor — the bomb is consumed and a 3×3 area around it clears, dealing bonus damage proportional to cells cleared.
- [ ] **Crossed-Swords detonation**: swap a Crossed-Swords tile with any neighbor — it clears its entire row + column. Damage bypasses enemy armor.
- [ ] Power-ups never appear from refill — only from the player's own match-4 / match-5.

## Piece effects

- [ ] **Spear** match → red `-N` floats over the enemy.
- [ ] **Archer** match → red `-N` floats over the enemy AND ignores armor (vs. a boss with `inherent_armor > 0`).
- [ ] **Shield** match → green `+N` floats over the player; the player's `ARM x` label increases.
- [ ] **King** match → red `-N` floats over the enemy AND the bottom-bar `Rally` counter increases.
- [ ] When `Rally` hits 100, the **Royal Command** button enables; pressing it clears a random row and resets `Rally` to 0.

## Combat & progression

- [ ] Reducing the enemy to 0 HP: the enemy slumps and the chapter map opens; the cleared level shows "Cleared" and the next level unlocks.
- [ ] Reducing the player to 0 HP: the player slumps and the Game-Over screen opens; **Retry** restarts the same level.
- [ ] Completing all 5 levels of chapter 1 unlocks the **Tower** boss.
- [ ] Defeating the tower boss unlocks chapter 2.
- [ ] After all 3 tower bosses fall, **Fight the King** unlocks.
- [ ] Defeating the King: Victory screen → **Continue** → next castle generated (castle index increments, enemy stats scale up).

## Saving

- [ ] Win a few levels, then **fully quit** the app (terminate the process) and reopen — completed levels are still marked Cleared and the same castle is loaded.
- [ ] **Main Menu ▸ Reset Save** wipes progress and re-rolls castle 1.
- [ ] If the app is killed mid-write, the next launch still loads the previous save (atomic `.tmp` + rename pattern).

## iPhone-specific

- [ ] Portrait orientation locked. Rotating the device does not flip the game.
- [ ] All HUD elements (top HP bars, level title, pause button, rally button) are clear of the notch / Dynamic Island and the home indicator.
- [ ] Touch input has no perceptible delay (tap → highlight, swipe → swap).
- [ ] Closing the app and reopening from background restores the same screen.

## Performance

- [ ] During a long cascade (6+ chains) the framerate stays at 60 fps in the editor.
- [ ] Memory is stable across 5+ battles (no leak from un-freed pieces).

## Known tuning levers if it feels off

- Too easy with diagonals? Set `Board.DIAGONAL_MIN_LENGTH = 4` in `scripts/board/board.gd`.
- Enemy damage too punishing? Lower `enemy_damage` in `scripts/progression/castle_generator.gd` (or reduce the `difficulty_multiplier` curve).
- Match-4 / match-5 not punchy enough? Tune `match4_multiplier` / `match5_multiplier` in `data/piece_types/*.tres`.
