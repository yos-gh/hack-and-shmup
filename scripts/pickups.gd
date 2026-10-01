extends RefCounted
## Temporary power-ups. Carriers and boss supply are planned at floor
## generation from a stream derived from the floor seed, so a retry meets the
## same drops regardless of how the previous attempt consumed `game.rng`.

const Catalog = preload("res://scripts/combat_catalog.gd")

enum Kind { PHASE, SPRINT, SPREAD }
const NAMES := ["PHASE", "SPRINT", "SPREAD"]
const COLORS := [Color("f4f1ff"), Color("7ef0ff"), Color("ffd36b")]
const DURATIONS := [5.0, 10.0, 10.0]
const WEIGHTS := [25, 35, 40]
# No invulnerability in boss fights.
const BOSS_WEIGHTS := [0, 45, 55]
const PICK_RADIUS := 18.0
const SPEED_SCALE := 1.5
const SPREAD_ANGLE := 0.1745
# Expected carriers per enemy room by depth: rare to 20, occasional to 40,
# then several per room past 50.
const CARRIER_CURVE := [Vector2(1,0.05), Vector2(20,0.15), Vector2(40,0.5), Vector2(50,1.2), Vector2(60,2.0), Vector2(70,2.5)]
const BOSS_FIRST := 12.0
const BOSS_GAP_MIN := 16.0
const BOSS_GAP_MAX := 22.0
const BOSS_ENTRIES := 40
const BOSS_SPOT_CHOICES := 4
const BOSS_LIFETIME := 8.0
const BOSS_CLEARANCE := 30.0

# Field items: {"p", "kind", "life"}; life < 0 stays until the floor ends.
var items: Array[Dictionary] = []
var timers: Array[float] = [0.0, 0.0, 0.0]
var boss_clock := 0.0
var supply_index := 0

static func carriers_per_room(depth: int) -> float:
	if depth <= CARRIER_CURVE[0].x: return CARRIER_CURVE[0].y
	for i in range(1, CARRIER_CURVE.size()):
		var a: Vector2 = CARRIER_CURVE[i-1]
		var b: Vector2 = CARRIER_CURVE[i]
		if depth <= b.x: return lerpf(a.y, b.y, (depth-a.x)/(b.x-a.x))
	return CARRIER_CURVE[-1].y

static func pick_kind(random: RandomNumberGenerator, weights: Array) -> int:
	var total := 0
	for w in weights: total += w
	var roll := random.randi_range(0, total-1)
	for kind in range(weights.size()):
		roll -= weights[kind]
		if roll < 0: return kind
	return weights.size()-1

static func plan_floor(data, random_state: int) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = hash([random_state, "drops"])
	if data.boss_floor:
		plan_boss_supply(data, random)
		return
	var by_room: Dictionary = {}
	for i in range(data.enemies.size()):
		by_room.get_or_add(data.enemies[i].room, []).append(i)
	var expected := carriers_per_room(data.floor_number)
	for room in range(1, data.rooms.size()):
		var members: Array = by_room.get(room, [])
		var count := int(expected) + (1 if random.randf() < expected - int(expected) else 0)
		for n in range(mini(count, members.size())):
			var pick := random.randi_range(0, members.size()-1)
			data.enemies[members[pick]]["drop"] = pick_kind(random, WEIGHTS)
			members.remove_at(pick)

static func plan_boss_supply(data, random: RandomNumberGenerator) -> void:
	var spots: Array[Vector2] = []
	for cell in data.cells:
		if data.cells[cell] != 1: continue
		var p: Vector2 = data.center(cell)
		if data.walkable(p, 26.0): spots.append(p)
	spots.sort()
	data.boss_supply.clear()
	if spots.is_empty(): return
	var at := BOSS_FIRST
	for n in range(BOSS_ENTRIES):
		var choices: Array[Vector2] = []
		for c in range(BOSS_SPOT_CHOICES): choices.append(spots[random.randi_range(0, spots.size()-1)])
		data.boss_supply.append({"at": at, "spots": choices, "kind": pick_kind(random, BOSS_WEIGHTS)})
		at += random.randf_range(BOSS_GAP_MIN, BOSS_GAP_MAX)

func reset() -> void:
	items.clear()
	timers = [0.0, 0.0, 0.0]
	boss_clock = 0.0
	supply_index = 0

func invincible() -> bool:
	return timers[Kind.PHASE] > 0

func speed_scale() -> float:
	return SPEED_SCALE if timers[Kind.SPRINT] > 0 else 1.0

func spread() -> bool:
	return timers[Kind.SPREAD] > 0

func drop_from(e: Dictionary) -> void:
	if e.has("drop"): items.append({"p": e.p, "kind": e.drop, "life": -1.0})

func advance(game, delta: float) -> void:
	for kind in range(timers.size()): timers[kind] = maxf(0.0, timers[kind]-delta)
	if game.boss_floor and not game.stairs_unlocked: advance_supply(game, delta)
	for item in items:
		if item.life > 0: item.life = maxf(0.0, item.life-delta)
		if item.life != 0 and item.p.distance_to(game.player) <= PICK_RADIUS + game.PLAYER_HIT_RADIUS:
			# Same kind refreshes to full; kinds run side by side.
			timers[item.kind] = DURATIONS[item.kind]
			item.life = 0.0
			game.burst(item.p, COLORS[item.kind], 10)
			game.sound.play_sfx("select")
	items = items.filter(func(item: Dictionary) -> bool: return item.life != 0)

func advance_supply(game, delta: float) -> void:
	var core: Dictionary = {}
	for e in game.enemies:
		if e.kind == Catalog.Enemy.BOSS and e.hp > 0: core = e
	if core.is_empty() or not core.active: return
	boss_clock += delta
	while supply_index < game.boss_supply.size() and game.boss_supply[supply_index].at <= boss_clock:
		var entry: Dictionary = game.boss_supply[supply_index]
		supply_index += 1
		# One supply item at a time; a missed one is replaced by the next.
		items = items.filter(func(item: Dictionary) -> bool: return item.life < 0)
		var controller = game.boss.controller(game.boss_variant)
		for spot in entry.spots:
			if controller.touches(core, spot, BOSS_CLEARANCE): continue
			items.append({"p": spot, "kind": entry.kind, "life": BOSS_LIFETIME})
			break
