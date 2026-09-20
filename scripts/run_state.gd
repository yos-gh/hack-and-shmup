extends RefCounted

const Catalog = preload("res://scripts/combat_catalog.gd")

# Mutable progress for one run; the session record lives outside it.
const MIN_POWER := 0.5
const MIN_MOVE_BONUS := -60.0
var expansion: float = 0.0
var recharge: float = 0.0
var upgrade_counts: Dictionary = {}
var floor_number: int = 1
var deaths: int = 0
var kills: int = 0
var sub_weapon: int = 0
var power: float = 1.0
var fire_rate: float = 1.0
var move_bonus: float = 0.0
var choices: Array[int] = []

func reset() -> void:
	expansion = 0.0
	recharge = 0.0
	upgrade_counts.clear()
	floor_number = 1
	deaths = 0
	kills = 0
	sub_weapon = 0
	power = 1.0
	fire_rate = 1.0
	move_bonus = 0.0
	choices.clear()

func apply_upgrade(kind: int) -> void:
	if not can_upgrade(kind): return
	var definition = Catalog.UPGRADES[kind]
	power += definition.power
	fire_rate += definition.fire_rate
	move_bonus += definition.move_speed
	expansion += definition.expansion
	recharge += definition.recharge
	upgrade_counts[kind] = upgrade_counts.get(kind, 0) + 1

func can_upgrade(kind: int) -> bool:
	if kind < 0 or kind >= Catalog.UPGRADES.size(): return false
	var definition = Catalog.UPGRADES[kind]
	if definition.max_stacks > 0 and upgrade_counts.get(kind, 0) >= definition.max_stacks: return false
	return power + definition.power >= MIN_POWER - 0.00001 and move_bonus + definition.move_speed >= MIN_MOVE_BONUS

func roll_choices(random: RandomNumberGenerator) -> void:
	var pool: Array[int] = []
	for kind in range(Catalog.UPGRADES.size()):
		if can_upgrade(kind): pool.append(kind)
	choices.clear()
	while choices.size() < 3 and not pool.is_empty():
		var pick := random.randi_range(0, pool.size()-1)
		choices.append(pool[pick])
		pool.remove_at(pick)

func sub_reach(weapon: int) -> float:
	return Catalog.WEAPONS[weapon].reach * (1.0 + expansion * (0.5 if weapon == 1 else 1.0))

func lance_width() -> float:
	return Catalog.WEAPONS[2].width * lance_width_multiplier()

func lance_width_multiplier() -> float:
	return 1.0 + expansion * 2.0

func sub_cooldown(weapon: int) -> float:
	return Catalog.WEAPONS[weapon].cooldown / (1.0 + recharge)
