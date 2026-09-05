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
	game.floor_number = 20
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
	print("PASS: spatial collision parity, boundaries, overlap order, death, entry and retry")
	game.free()
	quit(1 if failures else 0)
