extends SceneTree

const Scenario = preload("res://tools/dev_scenario.gd")
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
	check(game.replay_input.is_empty() and game.title_screen, "normal launch remains interactive title")
	for scenario in ["normal19", "halo45"]:
		var expected := ""
		for repeat in range(2):
			Scenario.configure(game, scenario, 19045, 1)
			check(game.walkable(game.player, game.PLAYER_HIT_RADIUS), "fixture starts on walkable ground")
			check(game.sub_weapon == 1 and game.floor_number == (19 if scenario == "normal19" else 45), "requested equipment and depth")
			for frame in range(180):
				Scenario.input_frame(game, frame)
				game._physics_process(1.0 / 60.0)
			var result := Scenario.digest(game)
			if repeat == 0: expected = result
			else: check(result == expected, "same seed and input reproduce " + scenario)
	Scenario.configure(game, "normal19", 1, 0)
	var first := Scenario.digest(game)
	Scenario.configure(game, "normal19", 2, 2)
	check(first != Scenario.digest(game), "different seeds produce different fixtures")
	game.start_run()
	check(game.replay_input.is_empty(), "starting ordinary play releases replay input")
	game.free()
	if failures == 0: print("PASS: scenario seed, equipment, walkability and fixed-input replay")
	quit(1 if failures else 0)
