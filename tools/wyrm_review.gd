extends SceneTree
# Abyss Wyrm review: plays the real encounter with a protected player who
# circles the arena and fires the primary at the head's core whenever it is
# out. Saves captures of each telegraph and attack to docs/validation/wyrm-*.png
# and prints how long each form lasted. Run with a display for the captures;
# --headless --no-capture only measures. Options: --floor=50, --fire=0.6
# (share of each second spent firing), --form=2 (start at the second form).
var output := "res://docs/validation"
func _initialize() -> void: call_deferred("run")
func capture(game, name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	game.paused = false
	# Frame the boss and the player together for the still; play resumes from the real camera.
	var camera: Vector2 = game.camera_pos
	var e: Dictionary = game.enemies[0]
	game.camera_pos = (e.p if not e.submerged or e.state != "under" else e.head_hole).lerp(game.player,0.4)
	# A few frames, so meshes seen for the first time have their shaders ready.
	for i in range(3):
		game.paused = false
		game.depth_view.sync(game)
		game.queue_redraw()
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/wyrm-%s.png" % [output,name])
	game.camera_pos = camera
func run() -> void:
	var depth := 25
	var duty := 1.0
	var captures := true
	var form := 1
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--floor="): depth = int(argument.trim_prefix("--floor="))
		if argument.begins_with("--fire="): duty = float(argument.trim_prefix("--fire="))
		if argument.begins_with("--form="): form = int(argument.trim_prefix("--form="))
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
	if form == 2: game.boss.wyrm.skip_form(game)
	game.player = e.home+Vector2(-560,0)
	game.camera_pos = game.player
	game.build_flow()
	game.banner = 0
	var seen := {}
	var first_form := -1.0 if form == 1 else 0.0
	var second_form := -1.0
	var orbit := PI
	var longest_still := 0.0
	var still := 0.0
	var last_lead: Vector2 = e.lead
	for frame in range(60*300):
		var t: float = frame/60.0
		game.grace = 2
		game.paused = false # a focus-loss pause would freeze the review window
		# Circle the arena at a fixed radius; fire only part of each second.
		orbit += 0.3/60.0
		var goal: Vector2 = e.home+Vector2.from_angle(orbit)*Vector2(560,420)
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
		if e.state == "roam" and not e.move_mode in ["barrage","charge_warning"]:
			still = still+1.0/60.0 if e.lead.distance_to(last_lead) < 0.5 else 0.0
			longest_still = maxf(longest_still,still)
		last_lead = e.lead
		var key := ""
		var beam_live: bool = game.boss.lasers.any(func(beam): return beam.get("triad",false) and beam.warning <= 0 and beam.duration < beam.peak_duration-0.6)
		if e.phase == 1 and e.state == "under" and e.state_time < 0.4: key = "omen"
		elif e.phase == 1 and e.state == "exposed" and e.pattern == "beam" and beam_live: key = "beam"
		elif e.phase == 1 and e.state == "exposed" and e.pattern == "rings" and e.exposed_time > 2.5: key = "rings"
		elif e.phase == 1 and e.state == "exposed" and e.pattern == "barrage" and e.shells.any(func(s): return not s.fired and s.impact < 0.8): key = "barrage-1"
		elif e.phase == 1 and e.state == "dive" and e.traveled > e.dive_at+200: key = "dive"
		elif e.state == "breach_wait" and e.state_time < 0.6: key = "breach"
		elif e.state == "roam" and e.traveled > 900 and e.traveled < 980: key = "roam"
		elif e.state == "roam" and e.move_mode == "charge_warning" and e.move_time < 0.4: key = "charge-lane"
		elif game.boss.lasers.any(func(beam): return beam.has("mount") and beam.warning < 0.3): key = "body-beams"
		elif e.state == "roam" and e.move_mode == "barrage" and beam_live and e.shells.any(func(s): return not s.fired and s.impact < 0.8): key = "barrage-2"
		if captures and key != "" and not seen.has(key):
			seen[key] = true
			print("capture %s at %.1fs" % [key,t])
			await capture(game,key)
	print("Abyss Wyrm floor %d, fire duty %.2f: first form %.1fs, second form %.1fs; longest stop while roaming %.1fs" % [depth,duty,first_form,second_form,longest_still])
	game.free()
	quit()
