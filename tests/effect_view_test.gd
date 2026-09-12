extends SceneTree
const Scenario = preload("res://tools/dev_scenario.gd")
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: "+message)
		failures += 1

func frame(game) -> Image:
	game.queue_redraw()
	for i in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Effect view test requires a display renderer")
		quit(2)
		return
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	Scenario.configure(game,"normal19",19045,1)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.enemies.clear()
	game.bullets.clear()
	game.banner = 0
	game.set_depth_view(true)
	var baseline: Image = await frame(game)
	DirAccess.make_dir_recursive_absolute("res://docs/validation/effects")
	for kind in ["hit","shield","kill"]:
		game.effects.clear()
		game.particles.clear()
		game.damage_labels.clear()
		game.combat_feedback.enemy_hit(game.player+Vector2(70,0),1,kind == "shield",kind == "kill",game)
		if kind == "kill":
			for effect in game.effects:
				if effect.kind == 5: effect.life = 0.18
		var before := var_to_bytes([Scenario.digest(game),game.effects,game.particles,game.effects_rng.state])
		var visible: Image = await frame(game)
		check(before == var_to_bytes([Scenario.digest(game),game.effects,game.particles,game.effects_rng.state]),"effect rendering is read-only: "+kind)
		var center: Vector2i = Vector2i(game.world_to_screen(game.player+Vector2(70,0)))
		var changed := 0
		for y in range(-26,27):
			for x in range(-26,27):
				var point := center+Vector2i(x,y)
				if visible.get_pixelv(point).get_luminance()>baseline.get_pixelv(point).get_luminance()+0.05: changed += 1
		check(changed>25,"impact effect has visible local pixels: "+kind)
		visible.save_png("res://docs/validation/effects/"+kind+".png")
	for remaining in [0.02,0.01,0.000001]:
		for effect in game.effects:
			if effect.kind == 5: effect.life = remaining
		await frame(game)
	# Existing lifetime processing must also remove the new bounded death bursts.
	game.replay_input = {"movement":Vector2.ZERO,"aim":Vector2.RIGHT,"primary":false,"secondary":false}
	game.grace = 2
	game._physics_process(0.4)
	check(game.effects.filter(func(e): return e.kind == 5).is_empty(),"death burst expires through existing lifetime processing")
	game.free()
	if failures == 0: print("PASS: hit/shield/death pixels, read-only draw and death burst expiry")
	quit(1 if failures else 0)
