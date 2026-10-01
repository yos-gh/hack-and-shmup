extends Node

# Shockwave cost profile: the firing call and the frames of its 0.4 s effect,
# against idle frames with the Shockwave guide on the same floor. Vsync is
# disabled, so frame times include CPU work that a capped frame would hide.
# Godot_console.exe --path . res://tools/shock_profile.tscn -- [--views=2d,3d] [--output=<file>]
# In a Web export using this scene as main scene, the report is printed and
# stored in window.shockProfile.
func _ready() -> void: run.call_deferred()

func average(values: Array) -> float:
	var total := 0.0
	for v in values: total += v
	return total/maxf(1,values.size())

func p95(values: Array) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[mini(sorted.size()-1,int(ceil(sorted.size()*0.95))-1)]

func frame(game, fire: bool) -> Dictionary:
	game.replay_input = {"movement":Vector2.ZERO,"aim":Vector2.RIGHT,"primary":false,"secondary":false}
	var start := Time.get_ticks_usec()
	var fire_us := 0
	if fire:
		game.sub_cd = 0
		game.fire_sub(Vector2.RIGHT)
		fire_us = Time.get_ticks_usec()-start
	for effect in game.effects: effect.life -= 1.0/60
	game.effects = game.effects.filter(func(e): return e.life > 0)
	game.presentation.advance(game,1.0/60)
	game.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return {"ms":(Time.get_ticks_usec()-start)/1000.0,"fire_ms":fire_us/1000.0}

# Hostile bullets inside the blast so every one is tested; with kills, 60 mobs
# are packed around the player and die to the blast.
func crowd(game, roster: Array, bullets: int, kills: bool) -> void:
	game.enemies = roster.duplicate(true)
	for i in range(game.enemies.size()):
		var e: Dictionary = game.enemies[i]
		if e.kind == game.Catalog.Enemy.BOSS: continue
		e.hp = 1e9
		if kills and i < 60:
			e.p = game.player+Vector2.from_angle(i*TAU/60)*15
			e.hp = 1
	game.rebuild_enemy_buckets()
	game.bullets.clear()
	for i in range(bullets):
		var p: Vector2 = game.player+Vector2.from_angle(i*2.4)*(20.0+fmod(i*7.0,game.SHOCK_RADIUS-24.0))
		if game.attack_open(p): game.bullets.append({"p":p,"v":Vector2.ZERO,"damage":1.0,"hostile":true,"life":99.0})

func run() -> void:
	var options := {"views":"2d,3d","output":""}
	for argument in OS.get_cmdline_user_args():
		var pair := argument.trim_prefix("--").split("=",true,1)
		if pair.size() == 2: options[pair[0]] = pair[1]
	var game = load("res://main.tscn").instantiate()
	get_tree().root.add_child(game)
	game.set_physics_process(false)
	preload("res://tools/dev_scenario.gd").configure(game,"normal19",19045,1)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	game.grace = 999
	game.time_left = 999
	var roster: Array = game.enemies.duplicate(true)
	var report := {"engine":Engine.get_version_info().string,"os":OS.get_name(),"shock_radius":game.SHOCK_RADIUS,"runs":[]}
	if OS.has_feature("web"): report["browser"] = JavaScriptBridge.eval("navigator.userAgent")
	for view in options.views.split(","):
		game.set_depth_view(view == "3d")
		for i in range(30): await get_tree().process_frame
		var cases := []
		for setup in [[0,false],[200,false],[0,true]]:
			var bullets: int = setup[0]
			crowd(game,roster,bullets,setup[1])
			var idle := []
			for i in range(120): idle.append((await frame(game,false)).ms)
			var fire_frames := []
			var fire_calls := []
			var effect_frames := []
			for shot in range(8):
				crowd(game,roster,bullets,setup[1])
				var first: Dictionary = await frame(game,true)
				fire_frames.append(first.ms)
				fire_calls.append(first.fire_ms)
				for i in range(24): effect_frames.append((await frame(game,false)).ms)
				game.damage_labels.clear()
				game.particles.clear()
			cases.append({"hostile_bullets":bullets,"kills":setup[1],"idle_frame_ms":{"avg":average(idle),"p95":p95(idle),"max":idle.max()},
				"fire_call_ms":{"avg":average(fire_calls),"max":fire_calls.max()},
				"fire_frame_ms":{"avg":average(fire_frames),"max":fire_frames.max(),"first":fire_frames[0]},
				"effect_frame_ms":{"avg":average(effect_frames),"p95":p95(effect_frames),"max":effect_frames.max()}})
		report.runs.append({"view":view,"cases":cases})
	var text := JSON.stringify(report,"  ")
	print(text)
	if options.output != "":
		var file := FileAccess.open(options.output,FileAccess.WRITE)
		file.store_string(text)
	if OS.has_feature("web"): JavaScriptBridge.eval("window.shockProfile = %s" % JSON.stringify(text))
	game.free()
	get_tree().quit()
