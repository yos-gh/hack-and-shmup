extends SceneTree
const Fixture = preload("res://tools/balance_fixture.gd")
const Catalog = preload("res://scripts/combat_catalog.gd")
func _initialize() -> void: call_deferred("run")
func stats(values: Array[float]) -> Dictionary:
	values.sort()
	return {"p95":values[ceili(values.size()*0.95)-1],"max":values[-1],"samples":values.size()}
func run() -> void:
	if DisplayServer.get_name() == "headless": printerr("Rendering requires a display"); quit(2); return
	AudioServer.set_bus_mute(0,true)
	var fixture := Fixture.new()
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.set_view_pitch(25.0)
	game.set_depth_view(true)
	var rows: Array = []
	for scenario in [[49,-1],[99,-1],[100,1]]:
		fixture.configure(game,scenario[0],"standard",scenario[1],1)
		var samples: Array[float] = []
		var intervals: Array[float] = []
		var max_bullets := 0
		var max_mobs := 0
		var previous := Time.get_ticks_usec()
		for frame in range(600):
			fixture.drive(game,frame,true)
			# Performance fixture isolates surviving-enemy load, not the route timer.
			if not game.boss_floor: game.time_left = 999.0
			var started := Time.get_ticks_usec()
			game._physics_process(1.0/60.0)
			samples.append((Time.get_ticks_usec()-started)/1000.0)
			max_bullets = maxi(max_bullets,game.bullets.size())
			var mobs := 0
			for enemy in game.enemies:
				if Catalog.is_mob(enemy.kind): mobs += 1
			max_mobs = maxi(max_mobs,mobs)
			await process_frame
			var now := Time.get_ticks_usec()
			if frame > 0: intervals.append((now-previous)/1000.0)
			previous = now
		await RenderingServer.frame_post_draw
		var path := "res://docs/validation/high-floor/render-%d.png" % scenario[0]
		game.get_viewport().get_texture().get_image().save_png(path)
		rows.append({"depth":scenario[0],"boss":scenario[1],"cpu_ms":stats(samples),"frame_ms":stats(intervals),"max_bullets":max_bullets,"max_mobs":max_mobs,"protected":true,"route_timer_disabled":scenario[1]<0})
		print("RENDERED: ",JSON.stringify(rows[-1]))
	FileAccess.open("res://docs/validation/high-floor/render.json",FileAccess.WRITE).store_string(JSON.stringify({"engine":Engine.get_version_info().string,"cpu":OS.get_processor_name(),"renderer":DisplayServer.get_name(),"rows":rows},"\t"))
	game.free()
	print("PASS: rendered high-floor workload and screenshots")
	quit()
