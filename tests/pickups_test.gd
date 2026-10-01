extends SceneTree

const Generator = preload("res://scripts/floor_generator.gd")
const Settings = preload("res://scripts/floor_settings.gd")
const Pickups = preload("res://scripts/pickups.gd")
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: " + message)
		failures += 1
func carriers(enemies: Array) -> Array:
	var result := []
	for i in range(enemies.size()):
		if enemies[i].has("drop"): result.append([i,enemies[i].drop])
	return result
func run() -> void:
	var generator := Generator.new()
	var settings := Settings.new()
	# Rare early, several per room deep; boss floors carry no mob drops.
	var averages := {}
	for depth in [1,20,40,60]:
		settings.depth = depth if depth % 5 else depth+1
		var total := 0
		for seed_value in range(20):
			total += carriers(generator.generate(settings,seed_value).enemies).size()
		averages[depth] = total/20.0
	check(averages[1] < 1.5 and averages[20] < 2.5 and averages[40] > averages[20] and averages[60] > 10.0,"carrier count follows the depth curve %s" % averages)
	settings.depth = 33
	check(carriers(generator.generate(settings,4).enemies) == carriers(generator.generate(settings,4).enemies),"carriers are seeded")
	settings.depth = 10
	var boss_data = generator.generate(settings,3)
	check(carriers(boss_data.enemies).is_empty() and boss_data.boss_supply.size() == Pickups.BOSS_ENTRIES,"boss floors use a supply schedule")
	var phase_supply := false
	for entry in boss_data.boss_supply: phase_supply = phase_supply or entry.kind == Pickups.Kind.PHASE
	check(not phase_supply,"no invulnerability in boss supply")

	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run()
	game.floor_number = 61
	game.new_floor()
	var planned := carriers(game.enemies)
	check(not planned.is_empty(),"deep floor has carriers")
	game.replay_input = {"movement":Vector2.ZERO,"aim":Vector2.RIGHT,"primary":false,"secondary":false}
	var carrier: Dictionary = game.enemies[planned[0][0]]
	var drop_point: Vector2 = carrier.p
	carrier.hp = 0
	game._physics_process(1.0/60)
	check(game.pickups.items.size() == 1 and game.pickups.items[0].p == drop_point,"killing a carrier leaves a persistent item")
	game.player = drop_point
	game.grace = 0
	game.pickups.advance(game,1.0/60)
	var kind: int = planned[0][1]
	check(game.pickups.items.is_empty() and game.pickups.timers[kind] == Pickups.DURATIONS[kind],"touching the item starts its effect")
	game.pickups.timers[kind] = 1.0
	game.pickups.drop_from({"p":game.player,"drop":kind})
	game.pickups.advance(game,1.0/60)
	check(game.pickups.timers[kind] == Pickups.DURATIONS[kind],"same kind refreshes to full, not additive")
	game.pickups.timers[Pickups.Kind.PHASE] = 2.0
	game.die()
	check(not game.pending_respawn,"phase ignores hits")
	game.pickups.timers[Pickups.Kind.PHASE] = 0.0
	game.pickups.timers[Pickups.Kind.SPREAD] = 2.0
	game.player = game.spawn_point
	game.bullets.clear()
	game.main_cd = 0
	game.fire_armed = true
	game.replay_input.primary = true
	game._physics_process(1.0/60)
	var shots := 0
	for b in game.bullets: if not b.hostile: shots += 1
	check(shots == 3,"spread fires three primary shots")
	game.replay_input.primary = false
	game.pickups.timers[Pickups.Kind.PHASE] = 0.0
	game.grace = 0
	# Spend the shared stream unevenly, then retry: carriers are unchanged.
	for i in range(37): game.rng.randf()
	game.die()
	game._physics_process(1.0/60)
	check(carriers(game.enemies) == planned and game.pickups.items.is_empty() and game.pickups.timers.max() == 0.0,"retry restores carriers and clears items and effects")

	game.floor_number = 10
	game.new_floor()
	var core: Dictionary = game.enemies[0]
	core.active = true
	game.pickups.advance_supply(game,Pickups.BOSS_FIRST+0.01)
	check(game.pickups.items.size() == 1 and game.pickups.items[0].life == Pickups.BOSS_LIFETIME,"boss supply arrives on schedule")
	var first: Dictionary = game.pickups.items[0].duplicate()
	game.restart_attempt()
	game.enemies[0].active = true
	game.pickups.advance_supply(game,Pickups.BOSS_FIRST+0.01)
	check(game.pickups.items.size() == 1 and game.pickups.items[0] == first,"boss supply repeats after retry")
	game.free()
	if failures == 0: print("PASS: seeded carriers, depth curve, pickup effects, refresh stacking, retry and boss supply")
	quit(1 if failures else 0)
