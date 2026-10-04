extends SceneTree
# Abyss Wyrm review: plays the real encounter with a protected player who
# circles the arena and fires the primary at the head whenever it is out.
# Saves captures of each telegraph and attack to docs/validation/wyrm-*.png and
# prints how long each form lasted. Run with a display for the captures;
# --headless --no-capture only measures. Optional: --floor=50, --fire=0.6 (duty).
var output := "res://docs/validation"
func _initialize() -> void: call_deferred("run")
func capture(game, name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	game.depth_view.sync(game)
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/wyrm-%s.png" % [output,name])
func run() -> void:
	var depth := 25
	var duty := 1.0
	var captures := true
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--floor="): depth = int(argument.trim_prefix("--floor="))
		if argument.begins_with("--fire="): duty = float(argument.trim_prefix("--fire="))
		if argument == "--no-capture": captures = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.practice.variant = 3
	game.practice.depth = depth
	game.practice.start(game)
	game.set_depth_view(true)
	game.discovered[1] = true
	var e: Dictionary = game.enemies[0]
	game.player = e.home+Vector2(-420,0)
	game.camera_pos = game.player
	game.build_flow()
	game.banner = 0
	var seen := {}
	var first_form := -1.0
	var second_form := -1.0
	var orbit := PI
	for frame in range(60*240):
		var t: float = frame/60.0
		game.grace = 2
		game.paused = false # a focus-loss pause would freeze the review window
		# Circle the arena at a fixed radius; fire only part of each second.
		orbit += 0.35/60.0
		var goal: Vector2 = e.home+Vector2.from_angle(orbit)*Vector2(400,280)
		var move: Vector2 = goal-game.player
		var firing: bool = not e.submerged and fmod(t,1.0) < duty
		game.replay_input = {"movement":move if move.length() > 8 else Vector2.ZERO,"aim":game.player.direction_to(e.p),"primary":firing,"secondary":false}
		game.fire_armed = true
		game._physics_process(1.0/60.0)
		if game.enemies.is_empty():
			second_form = t-first_form
			break
		if game.enemies[0] != e:
			printerr("encounter restarted at %.1fs (%s)" % [t,game.death_reason])
			break
		if e.phase == 2 and first_form < 0: first_form = t
		var key := ""
		if e.phase == 1 and e.state == "under" and e.state_time < 0.5: key = "omen-%d" % mini(e.rise,1)
		elif e.phase == 1 and e.state == "exposed" and e.rise%2 == 0 and game.boss.lasers.any(func(beam): return beam.warning > 0.2 and beam.warning < 0.5): key = "laser-warning"
		elif e.phase == 1 and e.state == "exposed" and e.rise%2 == 1 and e.state_time > 3.0: key = "exposed"
		elif e.phase == 1 and e.state == "exposed" and e.rise%2 == 0 and game.boss.lasers.any(func(beam): return beam.warning <= 0): key = "head-laser"
		elif e.phase == 1 and e.state == "exposed" and e.rise%2 == 1 and e.state_time < 2.5: key = "rings"
		elif e.state == "breach_wait" and e.state_time < 0.6: key = "breach"
		elif e.state == "roam" and e.traveled > 700 and e.traveled < 760: key = "roam"
		elif e.move_mode == "charge_warning" and e.move_time < 0.4: key = "charge-lane"
		elif game.boss.lasers.any(func(beam): return beam.has("mount") and beam.warning < 0.3): key = "body-beams"
		elif e.state == "roam" and e.tail_cycle == 2 and e.tail_cd > 3.0*e.attack_scale: key = "tail-burst"
		if captures and key != "" and not seen.has(key):
			seen[key] = true
			print("capture %s at %.1fs" % [key,t])
			await capture(game,key)
	print("Abyss Wyrm floor %d, fire duty %.2f: first form %.1fs, second form %.1fs, deaths avoided by protection" % [depth,duty,first_form,second_form])
	game.free()
	quit()
