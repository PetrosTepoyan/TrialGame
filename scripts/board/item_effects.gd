class_name ItemEffects
extends RefCounted

# Static dispatcher: takes a broken BoardItem and applies its effect to the
# player / enemy. Called by CombatController after Board emits item_broken.

# Armor cap when an item restores player armor — actor.gd has no max_armor
# field, so we clamp here. Tuned in Phase I if the value feels off.
const PLAYER_ARMOR_CAP: int = 99

static func apply_effect(item: BoardItem, player: CombatActor, enemy: CombatActor) -> void:
	if item == null:
		return
	match item.effect_kind:
		BoardItem.EffectKind.ENEMY_ARMOR_DEBUFF:
			var s := StatusEffect.new(StatusEffect.Kind.ARMOR_DEBUFF_ITEM, item.effect_duration, 0, int(item.effect_magnitude))
			if enemy != null:
				enemy.apply_status(s)
		BoardItem.EffectKind.PLAYER_RESTORE_ARMOR:
			if player != null:
				var amt: int = int(item.effect_magnitude)
				var headroom: int = max(0, PLAYER_ARMOR_CAP - player.armor)
				if amt > headroom:
					amt = headroom
				if amt > 0:
					player.add_armor(amt)
		BoardItem.EffectKind.PLAYER_HEAL:
			if player != null:
				player.heal(int(item.effect_magnitude))
		BoardItem.EffectKind.PLAYER_ATTACK_BUFF:
			var b := StatusEffect.new(StatusEffect.Kind.ATTACK_BUFF, item.effect_duration, 0, int(item.effect_magnitude))
			if player != null:
				player.apply_status(b)
		BoardItem.EffectKind.ENEMY_ACID_DOT:
			var a := StatusEffect.new(StatusEffect.Kind.ACID_BURN, item.effect_duration, int(item.effect_magnitude), 0)
			if enemy != null:
				enemy.apply_status(a)
		BoardItem.EffectKind.ENEMY_FIRE_DOT:
			var f := StatusEffect.new(StatusEffect.Kind.IGNITE, item.effect_duration, int(item.effect_magnitude), 0)
			if enemy != null:
				enemy.apply_status(f)
