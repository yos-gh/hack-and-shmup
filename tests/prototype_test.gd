extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: " + message)
		failures += 1
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	check(game.title_screen and game.audio_mode == 1,"arcade startup")
	game.start_run()
	game.replay_input = {"movement":Vector2.RIGHT,"aim":Vector2.RIGHT,"primary":false,"secondary":false}
	game._physics_process(1.0/60)
	check(game.player != game.spawn_point and game.time_left < game.time_limit,"movement and timer advance")
	game.apply_upgrade(0)
	var power: float = game.power
	game.grace = 0
	game.die()
	game._physics_process(1.0/60)
	check(game.player == game.spawn_point and game.enemies == game.initial_enemies,"immediate retry restores floor")
	check(game.power == power and game.deaths == 1 and game.time_left == game.time_limit,"retry preserves upgrades and resets timer")
	game.replay_input.movement = Vector2.ZERO
	game.player = game.stairs
	game._physics_process(1.0/60)
	check(game.choosing and game.choices.size() == 3 and game.best_cleared == 1,"stairs offer three cards")
	game.upgrade(0)
	check(game.floor_number == 2 and not game.choosing,"card advances floor")
	game.time_left = 0.001
	game._physics_process(1.0/60)
	check(game.pending_respawn and game.death_reason == "TIME UP","timeout bypasses grace")
	game._physics_process(1.0/60)
	game.return_to_title()
	game.start_run()
	check(game.floor_number == 1 and game.power == 1 and game.best_cleared == 1,"new run resets build and retains session record")
	game.free()
	if failures == 0: print("PASS: arcade startup, movement, combat retry, cards, descent, timeout and new run")
	quit(1 if failures else 0)
