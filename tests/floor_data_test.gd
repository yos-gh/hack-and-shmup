extends SceneTree

const Generator = preload("res://scripts/floor_generator.gd")
const Settings = preload("res://scripts/floor_settings.gd")
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: " + message)
		failures += 1
func digest(data) -> PackedByteArray:
	return var_to_bytes([data.cells,data.rooms,data.room_shapes,data.entrances,data.enemies,data.room_links,data.corridor_cells,data.spawn_point,data.stairs,data.goal_room,data.time_limit,data.boss_variant,data.boss_max_hp,data.rng.state])
func run() -> void:
	# No Game, sound, viewport or scene instance is needed to build any floor.
	var generator := Generator.new()
	var settings := Settings.new()
	var tree_count := root.get_child_count()
	for depth in [1,4,5,6,9,10,11,15,19,45,99]:
		settings.depth = depth
		for seed_value in range(10):
			var data = generator.generate(settings,seed_value)
			var second = generator.generate(settings,seed_value)
			check(digest(data) == digest(second),"seed deterministically reproduces the entire result")
			check(data.flow.has(data.tile(data.stairs)) and data.walkable(data.spawn_point),"spawn and stairs reachable")
			check(data.flow.size() == data.cells.size(),"every generated floor cell is connected")
			for enemy in data.enemies:
				check(data.flow.has(data.tile(enemy.p)),"every enemy lies in connected floor")
				if not data.boss_floor: check(data.entry_safe(enemy.p,enemy.room),"normal spawn preserves entrance clearance")
			check(data.time_limit == 0 if data.boss_floor else data.time_limit > data.route_seconds,"time budget has the correct boss/normal semantics")
			var original := digest(second)
			data.enemies[0].hp = -1
			data.entrances.clear()
			data.cells.clear()
			check(digest(second) == original,"results never share mutable layout or enemy containers")
	check(root.get_child_count() == tree_count,"generation does not add scene nodes")
	settings.depth = 19
	var normal = generator.generate(settings,77)
	settings.move_bonus = 80
	var fast = generator.generate(settings,77)
	check(normal.cells == fast.cells and normal.enemies == fast.enemies and fast.time_limit < normal.time_limit,"movement bonus changes only the route budget")
	settings.depth = 45
	for variant in range(3):
		settings.boss_choice = variant
		settings.power = 1
		var weak = generator.generate(settings,3)
		settings.power = 2
		var strong = generator.generate(settings,3)
		check(weak.boss_variant == variant and strong.boss_max_hp > weak.boss_max_hp,"explicit variant and loadout control boss output")
		check(weak.cells == strong.cells,"loadout does not alter boss terrain")
	var random := RandomNumberGenerator.new()
	random.seed = 456
	random.randf()
	var before := random.state
	var from_state = generator.generate_from_state(settings,before)
	check(random.state == before,"state input does not mutate caller RNG")
	check(digest(from_state) == digest(generator.generate_from_state(settings,before)),"saved random state reproduces generation")
	check(settings.depth == 45 and settings.boss_choice == 2 and settings.power == 2 and settings.move_bonus == 80,"caller settings remain untouched")
	if failures == 0: print("PASS: standalone seeded normal/boss floors, connectivity, entry safety, time budget and independent outputs")
	quit(1 if failures else 0)
