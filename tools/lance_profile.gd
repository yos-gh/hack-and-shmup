extends Node

# Lance cost profile: lane tracing, aiming-guide frames, firing and beam-effect
# frames, compared with the Shockwave guide on the same floor. Vsync is
# disabled, so frame times include CPU work that a capped frame would hide.
# Godot_console.exe --path . res://tools/lance_profile.tscn -- [--view=3d] [--output=<file>]
# In a Web export using this scene as main scene, the report is printed and
# stored in window.lanceProfile.
func _ready() -> void: run.call_deferred()

func average(values: Array) -> float:
	var total := 0.0
	for v in values: total += v
	return total/maxf(1,values.size())

func p95(values: Array) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[mini(sorted.size()-1,int(ceil(sorted.size()*0.95))-1)]

func frames(game, count: int, fire: bool) -> Array:
	var result := []
	for i in range(count):
		var aim := Vector2.from_angle(i/40.0)
		game.replay_input = {"movement":Vector2.ZERO,"aim":aim,"primary":false,"secondary":false}
		if fire and i % 18 == 0: game.fire_sub(aim)
		for effect in game.effects: effect.life -= 1.0/60
		game.effects = game.effects.filter(func(e): return e.life > 0)
		var start := Time.get_ticks_usec()
		game.queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		result.append((Time.get_ticks_usec()-start)/1000.0)
	return result

func run() -> void:
	var options := {"views":"2d,3d","output":""}
	for argument in OS.get_cmdline_user_args():
		var pair := argument.trim_prefix("--").split("=",true,1)
		if pair.size() == 2: options[pair[0]] = pair[1]
	var game = load("res://main.tscn").instantiate()
	get_tree().root.add_child(game)
	game.set_physics_process(false)
	preload("res://tools/dev_scenario.gd").configure(game,"normal19",19045,2)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	game.grace = 999
	game.time_left = 999
	var roster: Array = game.enemies.duplicate(true)
	var report := {"engine":Engine.get_version_info().string,"os":OS.get_name(),"runs":[]}
	if OS.has_feature("web"): report["browser"] = JavaScriptBridge.eval("navigator.userAgent")
	for view in options.views.split(","):
		game.set_depth_view(view == "3d")
		for i in range(30): await get_tree().process_frame
		var cases := []
		for expansion in [0.0,0.5]:
			game.session.run.expansion = expansion
			var trace_us := []
			for i in range(200):
				var start := Time.get_ticks_usec()
				game.LanceTrace.lanes(game,game.player,Vector2.from_angle(i*0.1))
				trace_us.append(float(Time.get_ticks_usec()-start))
			var fire_ms := []
			for i in range(20):
				game.enemies = roster.duplicate(true)
				game.rebuild_enemy_buckets()
				game.sub_cd = 0
				var start := Time.get_ticks_usec()
				game.fire_sub(Vector2.from_angle(i*0.3))
				fire_ms.append((Time.get_ticks_usec()-start)/1000.0)
			game.enemies = roster.duplicate(true)
			game.rebuild_enemy_buckets()
			game.effects.clear()
			game.sub_weapon = 1
			var shock: Array = await frames(game,180,false)
			game.sub_weapon = 2
			game.sub_cd = 0
			var guide: Array = await frames(game,180,false)
			var firing: Array = await frames(game,180,true)
			game.effects.clear()
			game.enemies = roster.duplicate(true)
			game.rebuild_enemy_buckets()
			cases.append({"width":game.LANCE_WIDTH,"lanes":game.LanceTrace.lanes(game,game.player,Vector2.RIGHT).size(),
				"trace_us_avg":average(trace_us),"fire_ms_avg":average(fire_ms),"fire_ms_max":fire_ms.max(),
				"shock_guide_frame_ms":{"avg":average(shock),"p95":p95(shock)},
				"lance_guide_frame_ms":{"avg":average(guide),"p95":p95(guide)},
				"lance_firing_frame_ms":{"avg":average(firing),"p95":p95(firing)}})
		report.runs.append({"view":view,"cases":cases})
	var text := JSON.stringify(report,"  ")
	print(text)
	if options.output != "":
		var file := FileAccess.open(options.output,FileAccess.WRITE)
		file.store_string(text)
	if OS.has_feature("web"): JavaScriptBridge.eval("window.lanceProfile = %s" % JSON.stringify(text))
	game.free()
	get_tree().quit()
