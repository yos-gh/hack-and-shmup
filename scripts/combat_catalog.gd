extends RefCounted

# Stable indexes preserve existing save-free gameplay and replay fixtures.
const UPGRADES = [preload("res://assets/definitions/upgrade_damage.tres"), preload("res://assets/definitions/upgrade_rate.tres"), preload("res://assets/definitions/upgrade_move.tres"), preload("res://assets/definitions/upgrade_hybrid.tres")]
const WEAPONS = [preload("res://assets/definitions/weapon_scatter.tres"), preload("res://assets/definitions/weapon_shock.tres"), preload("res://assets/definitions/weapon_lance.tres")]
const ENEMIES = [preload("res://assets/definitions/enemy_chaser.tres"), preload("res://assets/definitions/enemy_sniper.tres"), preload("res://assets/definitions/enemy_shield.tres")]
