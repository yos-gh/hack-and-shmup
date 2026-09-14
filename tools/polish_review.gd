extends SceneTree
const Scenario = preload("res://tools/dev_scenario.gd")
var destination := "res://docs/validation/polish/after"
func _initialize() -> void: call_deferred("run")
func percentile(values: Array[float]) -> float:
	values.sort()
	return values[mini(values.size()-1,int(values.size()*0.95))]
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): destination = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(destination)
	var reports: Array = []
	for scenario in ["normal19","siege5","hunter15","halo45","burst80"]:
		var game = load("res://main.tscn").instantiate()
		root.add_child(game)
		Scenario.configure(game,"normal19" if scenario == "burst80" else scenario,19045,1)
		game.set_depth_view(true)
		game.set_physics_process(false)
		game.set_process_unhandled_input(false)
		var frames: Array[float] = []
		var cpu: Array[float] = []
		var first_effect := 0.0
		for frame in range(240):
			Scenario.input_frame(game,frame)
			if scenario == "burst80": game.replay_input = {"movement":Vector2.ZERO,"aim":Vector2.RIGHT,"primary":false,"secondary":false}
			var begin := Time.get_ticks_usec()
			if scenario == "burst80" and frame == 100:
				for i in range(80):
					var enemy: Dictionary = game.enemies[i]
					enemy.kind = 0
					enemy.hp = 1
					enemy.p = game.player+Vector2.from_angle(i*TAU/80)*(25+i%5*12)
					game.hurt_enemy(enemy,100,Vector2.RIGHT)
			game._physics_process(1.0/60.0)
			var update_ms := (Time.get_ticks_usec()-begin)/1000.0
			await process_frame
			await RenderingServer.frame_post_draw
			var elapsed := (Time.get_ticks_usec()-begin)/1000.0
			if frame == (100 if scenario == "burst80" else 0): first_effect = elapsed
			if frame >= 60 and (scenario != "burst80" or (frame >= 100 and frame < 125)):
				frames.append(elapsed)
				cpu.append(update_ms)
			if frame == (103 if scenario == "burst80" else 180):
				root.get_texture().get_image().save_png(destination+"/"+scenario+".png")
		reports.append({"scenario":scenario,"p95_frame_ms":percentile(frames),"p95_cpu_ms":percentile(cpu),"first_effect_ms":first_effect,"digest":Scenario.digest(game),"samples":frames.size()})
		game.free()
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	for menu in ["title","cards","pause","practice"]:
		if menu == "cards":
			game.start_run()
			game.choosing = true
			game.choices.assign([0,1,2])
		if menu == "pause":
			game.choosing = false
			game.paused = true
		if menu == "practice": game.practice.open(game)
		for i in range(25):
			await process_frame
			await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(destination+"/"+menu+".png")
	game.free()
	var file := FileAccess.open(destination+"/performance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"gpu":RenderingServer.get_video_adapter_name(),"cpu":OS.get_processor_name(),"note":"Fixed 60Hz protected stationary fixture, normal camera; uncapped frame wall time includes renderer and scheduling, not GPU-only timing.","reports":reports},"\t"))
	print("PASS: polish review ",destination)
	quit()
