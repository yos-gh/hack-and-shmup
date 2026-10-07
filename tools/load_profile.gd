extends SceneTree

# Whole-game load profile: a deep normal floor with every mob alerted and
# converging on a protected, stationary player who fires the primary (and the
# chosen subweapon) in a rotating aim. Mob HP is inflated so the crowd stays at
# its full count for the whole window. Simulation, 3D sync, 2D draw, render CPU
# and frame interval are recorded separately.
#
# Godot_console.exe --path . --max-fps 0 --disable-vsync --script res://tools/load_profile.gd -- --floor=40 --output=<file>
# Options: --floor=N --seed=S --weapon=0..2 --mobs=N (cap alive mobs) --fire=0|1 --view=2d|3d
#          --warmup=600 --frames=600 --output=<json> --capture=<png>
# Diagnostics: --hide=<3D batch keys> hides batches, --msaa=0|2|4 sets 3D MSAA,
# --fx=0 hides the full-screen pass, --depth_scale=N renders N x the 3D pixels,
# --light=1 plays in the LIGHT display (no bloom, no 3D MSAA; overrides --msaa).
const Scenario = preload("res://tools/dev_scenario.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var options := {"floor":"40","seed":"19045","weapon":"1","mobs":"999","fire":"1","view":"3d","alert":"99","hide":"","msaa":"2","capture":"","depth_scale":"1","fx":"1","light":"0","warmup":"600","frames":"600","output":""}
	for argument in OS.get_cmdline_user_args():
		var pair := argument.trim_prefix("--").split("=",true,1)
		if pair.size() != 2 or not options.has(pair[0]):
			printerr("Unknown argument: ",argument)
			quit(2)
			return
		options[pair[0]] = pair[1]
	var game = load("res://main.tscn").instantiate()
	game.set_script(load("res://tools/load_profile_game.gd"))
	root.add_child(game)
	Scenario.configure_floor(game,int(options.floor),int(options.seed),int(options.weapon))
	game.set_depth_view(options.view == "3d")
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.debug_invincible = true
	game.depth_view.set_process(false)
	var kept := 0
	var alive: Array[Dictionary] = []
	for e in game.enemies:
		if kept >= int(options.mobs): continue
		kept += 1
		e.hp *= 1000000.0
		alive.append(e)
	game.enemies = alive
	# Rooms 1..alert are discovered with their mobs alerted; the rest stay asleep.
	for i in range(1,mini(int(options.alert)+1,game.rooms.size())): game.discovered[i] = true
	for e in game.enemies:
		if not game.discovered.has(e.room): continue
		e.active = true
		e.searching = true
	# Diagnostics: hide named 3D batches (comma list) or change 3D MSAA.
	for key in options.hide.split(",",false):
		for child in game.depth_view.stage.get_children():
			if child is MultiMeshInstance3D and (child.multimesh == game.depth_view.batches.get(key) or child.multimesh == game.depth_view.batches.get(key+"_wire")): child.visible = false
	game.depth_view.viewport.msaa_3d = {"0":Viewport.MSAA_DISABLED,"2":Viewport.MSAA_2X,"4":Viewport.MSAA_4X}[options.msaa]
	if options.light == "1": game.toggle_display()
	if options.fx == "0":
		for child in game.get_children():
			if child is CanvasLayer and child.layer == 50: child.visible = false
	var instances := {}
	for key in game.depth_view.batches: instances[key] = game.depth_view.batches[key].visible_instance_count
	var vp_rid: RID = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid,true)
	var depth_rid: RID = game.depth_view.viewport.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(depth_rid,true)
	var phys: Array[float] = []
	var sync: Array[float] = []
	var draw: Array[float] = []
	var render_cpu: Array[float] = []
	var depth_cpu: Array[float] = []
	var render_gpu: Array[float] = []
	var depth_gpu: Array[float] = []
	var interval: Array[float] = []
	var draw_calls: Array[float] = []
	var counts := {"enemies":0.0,"bullets":0.0,"effects":0.0,"particles":0.0,"labels":0.0}
	var total := int(options.warmup)+int(options.frames)
	var previous := Time.get_ticks_usec()
	for frame in range(total):
		game.grace = 0.0
		game.time_left = 120.0
		game.fire_armed = true
		var firing: bool = options.fire == "1"
		game.replay_input = {"movement":Vector2.ZERO,"aim":Vector2.from_angle(frame/120.0),"primary":firing,"secondary":firing}
		var started := Time.get_ticks_usec()
		game._physics_process(1.0/60.0)
		var physics_ms := (Time.get_ticks_usec()-started)/1000.0
		started = Time.get_ticks_usec()
		if game.depth_enabled: game.depth_view._process(1.0/60.0)
		# Diagnostic fill-rate amplifier: same framing, more 3D pixels.
		if options.depth_scale != "1": game.depth_view.viewport.size = Vector2i(game.get_viewport_rect().size*float(options.depth_scale))
		var sync_ms := (Time.get_ticks_usec()-started)/1000.0
		game.draw_usec = 0
		await process_frame
		var now := Time.get_ticks_usec()
		if frame < int(options.warmup):
			previous = now
			continue
		phys.append(physics_ms)
		sync.append(sync_ms)
		draw.append(game.draw_usec/1000.0)
		render_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp_rid))
		depth_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(depth_rid))
		render_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp_rid))
		depth_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(depth_rid))
		draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		interval.append((now-previous)/1000.0)
		previous = now
		counts.enemies += game.enemies.size()
		counts.bullets += game.bullets.size()
		counts.effects += game.effects.size()
		counts.particles += game.particles.size()
		counts.labels += game.damage_labels.size()
	if not options.capture.is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(options.capture)
	for key in counts: counts[key] = snappedf(counts[key]/int(options.frames),0.1)
	var report := {"options":options,"engine":Engine.get_version_info().string,"cpu":OS.get_processor_name(),"gpu":RenderingServer.get_video_adapter_name(),"mean_counts":counts,"instances_at_start":instances,"cells":game.cells.size(),"state_digest":Scenario.digest(game),
		"physics_ms":stats(phys),"depth_sync_ms":stats(sync),"draw_2d_ms":stats(draw),"render_cpu_ms":stats(render_cpu),"depth_render_cpu_ms":stats(depth_cpu),
		"render_gpu_ms":stats(render_gpu),"depth_render_gpu_ms":stats(depth_gpu),"draw_calls":stats(draw_calls),"frame_interval_ms":stats(interval)}
	if not options.output.is_empty():
		var file := FileAccess.open(options.output,FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"\t"))
		file.close()
	if "prof" in game:
		for key in game.prof: game.prof[key] = snappedf(game.prof[key]/1000.0/total,0.001)
		report["physics_sections_ms"] = game.prof
	print(JSON.stringify(report))
	game.free()
	quit()

func stats(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {}
	var sum := 0.0
	for v in values: sum += v
	values.sort()
	return {"mean":snappedf(sum/values.size(),0.001),"p50":snappedf(values[values.size()/2],0.001),"p95":snappedf(values[mini(values.size()-1,int(ceil(values.size()*0.95))-1)],0.001),"max":snappedf(values[-1],0.001)}
