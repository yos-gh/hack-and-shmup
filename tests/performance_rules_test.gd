extends SceneTree
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: " + message)
		failures += 1

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.rng.seed = 0
	game.floor_number = 19
	game.new_floor()
	for i in range(game.rooms.size()): game.discovered[i] = true
	game.rebuild_enemy_buckets()
	var random := RandomNumberGenerator.new()
	random.seed = 17
	for i in range(2000):
		var anchor: Dictionary = game.enemies[i % game.enemies.size()]
		var p: Vector2 = anchor.p + Vector2(random.randf_range(-65,65), random.randf_range(-65,65))
		var expected: Dictionary = {}
		for e in game.enemies:
			if e.hp > 0 and game.attack_open(e.p) and p.distance_to(e.p) < 14:
				expected = e
				break
		check(game.bullet_target(p) == expected, "spatial lookup matches original collision order")
	# Sleeping mobs in unopened rooms are left out of the buckets; the lookup
	# must still match the brute-force scan with only some rooms open.
	game.discovered = {0:true,2:true}
	game.rebuild_enemy_buckets()
	for i in range(2000):
		var anchor: Dictionary = game.enemies[i % game.enemies.size()]
		var p: Vector2 = anchor.p + Vector2(random.randf_range(-65,65), random.randf_range(-65,65))
		var expected: Dictionary = {}
		for e in game.enemies:
			if e.hp > 0 and game.attack_open(e.p) and p.distance_to(e.p) < 14:
				expected = e
				break
		check(game.bullet_target(p) == expected, "partial discovery lookup matches original collision order")
	# The live Game inlines its hottest geometry queries; they must agree with
	# the shared FloorQueries versions and the original attack_open rule.
	const Queries = preload("res://scripts/floor_queries.gd")
	for i in range(20000):
		var cell: Vector2i = game.cells.keys()[i % game.cells.size()]
		var p: Vector2 = game.center(cell) + Vector2(random.randf_range(-48,48), random.randf_range(-48,48))
		if i % 5 == 0: p = (p/32.0).round()*32.0 + Vector2(random.randf_range(-0.01,0.01), random.randf_range(-0.01,0.01))
		var radius: float = [10.0,14.0,5.0,20.0,12.5][i % 5]
		check(game.tile(p) == Queries.tile(game,p), "inline tile matches FloorQueries")
		check(game.center(cell) == Queries.center(game,cell), "inline center matches FloorQueries")
		check(game.walkable(p,radius) == Queries.walkable(game,p,radius), "inline walkable matches FloorQueries")
		var room: int = 1 + i % (game.rooms.size()-1)
		check(game.entry_safe(p,room) == Queries.entry_safe(game,p,room), "inline entry_safe matches FloorQueries")
		var c: Vector2i = Queries.tile(game,p)
		check(game.attack_open(p) == (game.cells.has(c) and (game.cells[c] == -1 or game.discovered.has(game.cells[c]))), "inline attack_open matches the original rule")
	for i in range(game.rooms.size()): game.discovered[i] = true
	var first: Dictionary = game.enemies[0]
	var second: Dictionary = game.enemies[1]
	first.p = Vector2(-64,-64)
	second.p = first.p
	game.cells[game.tile(first.p)] = 1
	game.rebuild_enemy_buckets()
	for offset in [Vector2(-13,0),Vector2(13,0),Vector2(0,-13),Vector2(0,13)]:
		check(game.bullet_target(first.p+offset) == first, "hit spans negative-coordinate bucket boundaries")
	check(game.bullet_target(first.p+Vector2(14,0)).is_empty(), "exact radius keeps original strict inequality")
	first.hp = 0
	check(game.bullet_target(first.p) == second, "dead target is skipped without stale cache hits")
	game.discovered.erase(1)
	check(game.bullet_target(first.p).is_empty(), "undiscovered room blocks cached enemies")
	game.restart_attempt()
	check(game.enemy_buckets.is_empty() and game.patrol_elapsed.is_empty(), "retry clears spatial and idle state")
	game.title_screen = false
	game.time_left = 999
	game.grace = 999
	game.player = game.entrances[1][0]
	game._physics_process(1.0/60)
	for e in game.enemies:
		if e.room == 1: check(e.searching, "entry wakes every enemy immediately regardless of idle phase")
	print("PASS: spatial collision parity, partial discovery, inline geometry, boundaries, overlap order, death, entry and retry")
	game.free()
	quit(1 if failures else 0)
