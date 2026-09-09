extends RefCounted

const Catalog = preload("res://scripts/combat_catalog.gd")

# Mutable progress for one run; session record and preferences live outside it.
var floor_number: int = 1
var deaths: int = 0
var kills: int = 0
var sub_weapon: int = 0
var power: float = 1.0
var fire_rate: float = 1.0
var move_bonus: float = 0.0
var choices: Array[int] = []

func reset() -> void:
	floor_number = 1
	deaths = 0
	kills = 0
	sub_weapon = 0
	power = 1.0
	fire_rate = 1.0
	move_bonus = 0.0
	choices.clear()

func apply_upgrade(kind: int) -> void:
	if kind < 0 or kind >= Catalog.UPGRADES.size(): return
	var definition = Catalog.UPGRADES[kind]
	power += definition.power
	fire_rate += definition.fire_rate
	move_bonus += definition.move_speed
