# Assets

This directory ships with **Kenney CC0 placeholder art and audio** so the game runs and looks/sounds like a real product before any custom art arrives. See `../CREDITS.md` for sources.

## Current contents

```
pieces/                sword.png shield.png staff.png bow.png        (Tiny Dungeon)
characters/            hero.png enemy.png enemy_slime.png enemy_warrior.png
characters/bosses/     watchtower_warden.png drum_tower_warden.png
                       keep_warden.png king.png
ui/                    panel_brown.png panel_brown_pressed.png       (Pixel UI Pack)
audio/sfx/             swap.ogg match.ogg invalid.ogg hit.ogg round_execute.ogg
audio/music/           menu.mp3 battle.mp3                            (Kevin MacLeod CC-BY)
```

Each subfolder also keeps the original Kenney `LICENSE.txt` (CC0).

## How the code finds these files

- `scripts/board/piece.gd` looks up `res://assets/pieces/<kind>.png` per piece kind. Missing file → falls back to a programmatic icon.
- `scripts/ui/battle_actor.gd` looks up `res://assets/characters/hero.png` / `enemy.png` (or a custom `sprite_path` set in the editor). Missing file → falls back to a programmatic figure.
- `scripts/ui/action_scale_slot.gd` reuses the same piece sprites for the action-scale icons.
- `scripts/autoload/audio.gd` preloads the SFX at startup; missing files degrade silently.

## How to swap in different art

1. Replace any `.png` in `pieces/` or `characters/` — keep the filename and the new sprite will be picked up automatically.
2. For richer character art (e.g. the dark-fantasy illustrated knights in the investor reference), use larger PNGs and adjust `SPRITE_SCALE` in `piece.gd` / `battle_actor.gd` accordingly.
3. To swap a single boss enemy, set `BattleActor.sprite_path` on the `EnemyBattle` node in `battle.tscn`.

## How to add music

Drop a track into `audio/music/` and call `AudioBus.play_music(load("res://assets/audio/music/<file>.ogg"))` from the relevant scene (e.g. `main_menu.gd` for menu, `battle.gd` for combat).

[Kevin MacLeod / incompetech.com](https://incompetech.com) has CC-BY medieval tracks ("Hard Boiled", "Volatile Reaction", "Heroic Age", "Returning Heroes") — just credit him on the About screen.
