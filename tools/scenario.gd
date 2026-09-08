extends SceneTree

# Run with --script res://tools/scenario.gd -- --scenario=normal19 (or halo45).
# --frames=0 enables ordinary interactive play; otherwise fixed 60 Hz input.
const Scenario = preload("res://tools/dev_scenario.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var options := {"scenario": "normal19", "seed": "19045", "weapon": "1", "frames": "3600", "output": "user://scenario-report.json", "capture": ""}
	for argument in OS.get_cmdline_user_args():
		var pair := argument.trim_prefix("--").split("=", true, 1)
		if pair.size() != 2 or not options.has(pair[0]):
			printerr("Unknown argument: ", argument)
			quit(2)
			return
		options[pair[0]] = pair[1]
	if not options.scenario in ["normal19", "halo45"] or not options.seed.is_valid_int() or not options.weapon.is_valid_int() or not options.frames.is_valid_int() or int(options.weapon) < 0 or int(options.weapon) > 2 or int(options.frames) < 0:
		printerr("Expected scenario=normal19|halo45, integer seed, weapon=0..2, frames>=0")
		quit(2)
		return
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	Scenario.configure(game, options.scenario, int(options.seed), int(options.weapon))
	if int(options.frames) == 0:
		return
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	var samples: Array[float] = []
	var intervals: Array[float] = []
	var max_bullets := 0
	var previous := Time.get_ticks_usec()
	for frame in range(int(options.frames)):
		Scenario.input_frame(game, frame)
		var started := Time.get_ticks_usec()
		game._physics_process(1.0 / 60.0)
		samples.append((Time.get_ticks_usec() - started) / 1000.0)
		max_bullets = maxi(max_bullets, game.bullets.size())
		await process_frame
		var now := Time.get_ticks_usec()
		if frame > 0: intervals.append((now - previous) / 1000.0)
		previous = now
	if not options.capture.is_empty():
		if DisplayServer.get_name() == "headless":
			printerr("Capture requires a display renderer")
			quit(2)
			return
		await RenderingServer.frame_post_draw
		if root.get_texture().get_image().save_png(options.capture) != OK:
			printerr("Cannot save capture: ", options.capture)
			quit(2)
			return
	var report := {"options": options, "engine": Engine.get_version_info().string, "os": OS.get_name(), "cpu": OS.get_processor_name(), "renderer": DisplayServer.get_name(), "fixed_step_seconds": 1.0 / 60.0, "invulnerable_fixture": true, "initial_enemy_count": game.initial_enemies.size(), "max_bullets": max_bullets, "state_digest": Scenario.digest(game), "cpu_update_ms": stats(samples), "frame_interval_ms": stats(intervals)}
	var file := FileAccess.open(options.output, FileAccess.WRITE)
	if file == null:
		printerr("Cannot write report: ", options.output)
		quit(2)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print(JSON.stringify(report))
	game.free()
	quit()

func stats(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {}
	values.sort()
	return {"p95": values[mini(values.size()-1, int(ceil(values.size()*0.95))-1)], "p99": values[mini(values.size()-1, int(ceil(values.size()*0.99))-1)], "max": values[-1], "samples": values.size()}
