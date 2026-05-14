# Assets

This directory is intentionally empty. The V1 build draws everything programmatically (see `scripts/board/piece.gd` and `scripts/ui/battle_actor.gd`).

To upgrade visuals, drop CC0 art into the following subfolders:

```
assets/pieces/        king.png shield.png spear.png archer.png
assets/characters/    player_idle.png player_attack.png player_hurt.png
                      enemy_idle.png enemy_attack.png enemy_hurt.png
                      boss_*.png king_throne.png
assets/backgrounds/   forest.png village.png wall.png courtyard.png
                      throne_room.png mountain.png coast.png desert.png
assets/ui/            hp_bar_bg.png hp_bar_fill.png buttons/*.png
assets/audio/sfx/     match.wav swap.wav hit.wav heal.wav victory.wav defeat.wav
assets/audio/music/   battle.ogg menu.ogg victory.ogg
assets/fonts/         display.ttf body.ttf
```

See `../CREDITS.md` for recommended Kenney.nl packs.

After dropping in assets, swap the programmatic `_draw()` calls for Sprite2D
texture loads. Most piece-level changes happen in `scripts/board/piece.gd`'s
`_draw()` — replace with `Sprite2D` configured against `PieceType.sprite_path`.
