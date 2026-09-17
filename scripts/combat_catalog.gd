extends RefCounted

# Stable indexes preserve existing save-free gameplay and replay fixtures.
enum Enemy { CHASER, SNIPER, SHIELD, BOSS, FLANKER, INTERCEPTOR }
const UPGRADES = [preload("res://assets/definitions/upgrade_damage.tres"), preload("res://assets/definitions/upgrade_rate.tres"), preload("res://assets/definitions/upgrade_move.tres"), preload("res://assets/definitions/upgrade_hybrid.tres"), preload("res://assets/definitions/upgrade_skirmisher.tres"), preload("res://assets/definitions/upgrade_juggernaut.tres"), preload("res://assets/definitions/upgrade_expansion.tres"), preload("res://assets/definitions/upgrade_capacitor.tres")]
const WEAPONS = [preload("res://assets/definitions/weapon_scatter.tres"), preload("res://assets/definitions/weapon_shock.tres"), preload("res://assets/definitions/weapon_lance.tres")]
const ENEMIES = {Enemy.CHASER: preload("res://assets/definitions/enemy_chaser.tres"), Enemy.SNIPER: preload("res://assets/definitions/enemy_sniper.tres"), Enemy.SHIELD: preload("res://assets/definitions/enemy_shield.tres"), Enemy.FLANKER: preload("res://assets/definitions/enemy_flanker.tres"), Enemy.INTERCEPTOR: preload("res://assets/definitions/enemy_interceptor.tres")}
const PRIMARY = preload("res://assets/definitions/weapon_primary.tres")

static func is_mob(kind: int) -> bool:
	return ENEMIES.has(kind)
