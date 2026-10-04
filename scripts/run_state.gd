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
# Boss variant met most recently in this run (-1 before the first boss floor).
var last_boss: int = -1
# Where the current floor began, for the resume password: the generator state
# and previous boss that rebuild it, and the kill count before it.
var floor_state: int = 0
var floor_previous_boss: int = -1
var floor_kills: int = 0

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
	last_boss = -1
	floor_state = 0
	floor_previous_boss = -1
	floor_kills = 0

func apply_upgrade(kind: int) -> void:
	if not can_upgrade(kind): return
	upgrade_counts[kind] = upgrade_counts.get(kind, 0) + 1
	recount_stats()

# Stats follow from the card counts alone, summed in catalog order so a run
# rebuilt from a resume password matches the original bit for bit.
func recount_stats() -> void:
	power = 1.0
	fire_rate = 1.0
	move_bonus = 0.0
	expansion = 0.0
	recharge = 0.0
	for kind in range(Catalog.UPGRADES.size()):
		var definition = Catalog.UPGRADES[kind]
		for i in range(upgrade_counts.get(kind, 0)):
			power += definition.power
			fire_rate += definition.fire_rate
			move_bonus += definition.move_speed
			expansion += definition.expansion
			recharge += definition.recharge

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
