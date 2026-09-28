extends SceneTree
## Native, uncapped deterministic rendering and simulation profile.
const Fixture = preload("res://tools/balance_fixture.gd")
class ProfileGame extends "res://scripts/game.gd":
	var paint_us := 0
	var hide_projectiles := false
	func _draw() -> void:
		var saved: Array[Dictionary] = bullets
		if hide_projectiles: bullets = []
		var started := Time.get_ticks_usec()
		super._draw()
		paint_us = Time.get_ticks_usec()-started
		bullets = saved

func _initialize() -> void: call_deferred("run")
func stats(values: Array) -> Dictionary:
	values.sort()
	var sum := 0.0
	for value in values: sum += value
	return {"mean":snappedf(sum/values.size(),0.001),"p95":values[int(values.size()*0.95)],"p99":values[int(values.size()*0.99)],"max":values[-1]}

func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var game := ProfileGame.new()
	root.add_child(game)
	game.set_physics_process(false)
	game.depth_view.set_process(false)
	var results := []
	for scenario in [[25,false],[25,true],[50,false],[25,false,0],[25,false,1],[25,false,2]]:
		var depth: int = scenario[0]
		var weapon: int = scenario[2] if scenario.size() > 2 else -1
		Fixture.new().configure(game,depth,"standard",2,1)
		if weapon >= 0: game.sub_weapon = weapon
		game.hide_projectiles = scenario[1]
		game.set_depth_view(true)
		game.depth_view.set_process(false)
		var e: Dictionary = game.enemies[0]
		game.player = e.p+Vector2(-380,40)
		game.camera_pos = game.player
		game.build_flow()
		game.banner = 0
		var physics := []
		var paint := []
		var sync_times := []
		var frames := []
		var calls := []
		var counts := []
		for frame in range(1080):
			game.grace = 2
			var firing: bool = weapon >= 0 and frame >= 600
			if firing: e.hp = e.max_hp # Keep the measurement window the same length.
			game.replay_input = {"movement":Vector2.ZERO,"aim":game.player.direction_to(e.p),"primary":firing,"secondary":firing}
			var frame_start := Time.get_ticks_usec()
			var started := Time.get_ticks_usec()
			game._physics_process(1.0/60.0)
			var tick_us := Time.get_ticks_usec()-started
			# Warm the real battle for ten seconds, then render eight seconds.
			if frame < 600: continue
			started = Time.get_ticks_usec()
			game.depth_view.sync(game)
			var sync_us := Time.get_ticks_usec()-started
			game.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			if frame < 630: continue
			physics.append(tick_us/1000.0)
			sync_times.append(sync_us/1000.0)
			paint.append(game.paint_us/1000.0)
			frames.append((Time.get_ticks_usec()-frame_start)/1000.0)
			calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			counts.append(game.bullets.size())
		var result := {"floor":depth,"weapon":weapon,"hide_projectiles":game.hide_projectiles,"physics_ms":stats(physics),"canvas_ms":stats(paint),"depth_sync_ms":stats(sync_times),"frame_ms":stats(frames),"draw_calls":stats(calls),"bullets":stats(counts)}
		results.append(result)
		print("SERAPH PROFILE: "+JSON.stringify(result))
	var args := OS.get_cmdline_user_args()
	var name: String = args[0] if not args.is_empty() else "latest"
	var file := FileAccess.open("res://docs/validation/seraph-profile-%s.json" % name,FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t"))
	game.free()
	print("PASS: native Seraph profile complete")
	quit()
