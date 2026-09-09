extends RefCounted

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
	match kind:
		0: power += 0.35
		1: fire_rate += 0.2
		2: move_bonus += 20.0
		3: power += 0.2; move_bonus += 10.0
