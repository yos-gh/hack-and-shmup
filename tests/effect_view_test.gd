extends SceneTree
## Hit/kill/shield feedback renders without touching combat state, the
## batched spark renderer leaves no ghost instances, and death bursts expire.
const Scenario = preload("res://tools/dev_scenario.gd")
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: "+message)
		failures += 1

func frame(game) -> void:
	game.queue_redraw()
	for i in range(2):
		await process_frame
		await RenderingServer.frame_post_draw

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
	game.set_depth_view(true)
	for kind in ["hit","shield","kill"]:
		game.effects.clear()
		game.particles.clear()
		game.damage_labels.clear()
		game.combat_feedback.enemy_hit(game.player+Vector2(70,0),1,kind == "shield",kind == "kill",game)
		var before := var_to_bytes([Scenario.digest(game),game.effects,game.particles,game.effects_rng.state])
		await frame(game)
		check(before == var_to_bytes([Scenario.digest(game),game.effects,game.particles,game.effects_rng.state]),"effect rendering is read-only: "+kind)
	game.particles.clear()
	game.particles.append({"p":game.player+Vector2(70,0),"v":Vector2(60,0),"life":0.3,"color":Color.WHITE})
	await frame(game)
	check(game.world_view.particle_batch.visible_instance_count == 1,"batched spark is submitted")
	game.particles.clear()
	await frame(game)
	check(game.world_view.particle_batch.visible_instance_count == 0,"empty particle batch leaves no ghost sparks")
	game.combat_feedback.enemy_hit(game.player+Vector2(70,0),1,false,true,game)
	game.replay_input = {"movement":Vector2.ZERO,"aim":Vector2.RIGHT,"primary":false,"secondary":false}
	game.grace = 2
	game._physics_process(0.4)
	check(game.effects.filter(func(e): return e.kind == 5).is_empty(),"death burst expires through normal lifetime processing")
	game.free()
	if failures == 0: print("PASS: read-only feedback rendering, spark batch hygiene and death burst expiry")
	quit(1 if failures else 0)
