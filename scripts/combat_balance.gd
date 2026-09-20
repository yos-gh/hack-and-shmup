extends RefCounted
## Shared, deterministic health and sustained-fire estimates. HP uses internal units.

const Catalog = preload("res://scripts/combat_catalog.gd")
const BOSS_DAMAGE_SECONDS := 12.0
# VECTOR loses player attack time to movement and summon interception.
const BOSS_HP_FACTORS := [1.0, 0.90, 1.0]
const SCATTER_REFERENCE_HITS := 6

static func reference_power(depth: int) -> float:
	return 1.0 + 13.2 * (depth - 1) / 103.0

static func reference_rate(depth: int) -> float:
	return 1.0 + 8.0 * (depth - 1) / 103.0

static func mob_health(kind: int, depth: int) -> float:
	var base: float = Catalog.ENEMIES[kind].health(depth)
	if depth <= 30 or kind == Catalog.Enemy.SHIELD: return base
	var growth: float = pow(1.0 + (depth - 30) / 20.0, 3.0)
	if kind == Catalog.Enemy.SNIPER:
		return minf(base * sqrt(growth), 2.0 * reference_power(depth))
	return base * growth

static func shots_per_second(cooldown: float, ticks: float = 60.0) -> float:
	# Match the runtime's one shot per physics tick and discarded cooldown overshoot.
	return ticks / maxf(1.0, ceil(cooldown * ticks - 0.000001))

static func primary_dps(power: float, rate: float, ticks: float = 60.0) -> float:
	return power * Catalog.PRIMARY.damage * shots_per_second(Catalog.PRIMARY.cooldown / rate, ticks)

static func sub_dps(power: float, recharge: float, weapon: int, ticks: float = 60.0) -> float:
	var definition = Catalog.WEAPONS[weapon]
	var hits: int = SCATTER_REFERENCE_HITS if weapon == 0 else 1
	return power * definition.damage * hits * shots_per_second(definition.cooldown / (1.0 + recharge), ticks)

static func hunter_depth_factor(depth: int) -> float:
	return lerpf(1.0,0.75,clampf((depth-30)/15.0,0.0,1.0))

static func boss_health(power: float, rate: float, recharge: float, variant: int, ticks: float = 60.0, depth: int = 1) -> float:
	var secondary := 0.0
	for weapon in range(3): secondary = maxf(secondary, sub_dps(power, recharge, weapon, ticks))
	var depth_factor: float = hunter_depth_factor(depth) if variant == 1 else 1.0
	return (primary_dps(power, rate, ticks) + secondary) * BOSS_DAMAGE_SECONDS * BOSS_HP_FACTORS[variant] * depth_factor
