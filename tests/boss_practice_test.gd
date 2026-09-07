extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: "+message)
		failures += 1
func key(game, code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	game._unhandled_input(event)
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var layouts := {}
	game.floor_number = 15
	for seed_value in range(80):
		game.rng.seed = seed_value
		game.new_floor(0)
		var positions := []
		for e in game.enemies:
			positions.append(e.p)
			check(e.p.distance_to(game.entrances[1][0]) > 140, "turrets keep entry safe")
			check(game.cells.get(game.tile(e.p),-1) == 1, "turrets stay in arena")
			for other in game.enemies:
				if other != e: check(e.p.distance_to(other.p) >= 190, "turrets maintain minimum spacing")
		layouts[str(positions)] = true
		game.restart_attempt()
		check(game.enemies == game.initial_enemies, "retry preserves layout")
	check(layouts.size() == 8, "eight bounded turret layouts")
	game.new_floor(2)
	game.discovered[1] = true
	var owner: Dictionary = game.enemies[0]
	game.boss.fire_halo(game,owner,Vector2.LEFT)
	check(game.boss.options.size() == 3 and game.enemies.size() == 1, "three non-enemy options")
	game.rebuild_enemy_buckets()
	for option in game.boss.options:
		check(game.bullet_target(option.p).is_empty(), "options do not intercept player shots")
	game.bullets.clear()
	game.boss.advance_attacks(game,0.71)
	check(game.bullets.any(func(b): return b.p.distance_to(owner.p) > 140), "shots originate from satellites")
	owner.hp = 0
	game.boss.advance_attacks(game,0.016)
	check(game.boss.options.is_empty() and game.boss.salvos.is_empty(), "death clears satellites and scheduled fire")
	game.return_to_title()
	game.best_cleared = 10
	key(game,KEY_B)
	check(game.practice.selecting and game.title_screen, "B opens selector")
	key(game,KEY_3)
	key(game,KEY_UP)
	key(game,KEY_UP)
	key(game,KEY_ENTER)
	check(game.practice.active and not game.title_screen and game.floor_number == 15 and game.boss_variant == 2, "selected boss and floor launch")
	check(is_equal_approx(game.power,3.0) and is_equal_approx(game.fire_rate,1.8) and is_equal_approx(game.move_bonus,90.0), "fourteen normal upgrades applied")
	game.enemies[0].hp = 1
	key(game,KEY_R)
	check(game.enemies == game.initial_enemies, "R retries chosen encounter")
	for e in game.enemies: e.hp = 0
	game.grace = 999
	game.player = game.stairs
	game._physics_process(0.016)
	check(game.practice.selecting and game.best_cleared == 10 and not game.choosing, "practice clear returns selector without changing record")
	key(game,KEY_ESCAPE)
	check(game.title_screen and not game.practice.selecting, "escape returns to title without quitting")
	key(game,KEY_ENTER)
	check(not game.practice.active and game.floor_number == 1 and game.power == 1, "normal run resets debug loadout")
	game.return_to_title()
	key(game,KEY_B)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = game.practice.button(game.get_viewport_rect().size,0).get_center()
	game._unhandled_input(click)
	check(game.practice.variant == 0 and game.practice.selecting, "mouse selects without starting")
	if failures == 0: print("PASS: layout variety and clearance, satellite attacks, debug input, upgrades, retry and record isolation")
	game.free()
	quit(1 if failures else 0)
