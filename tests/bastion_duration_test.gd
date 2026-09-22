extends SceneTree
const Fixture = preload("res://tools/balance_fixture.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.depth_view.set_process(false)
	var failed := false
	for depth in [5,25,50]:
		Fixture.new().configure(game,depth,"standard",4,0)
		var e: Dictionary = game.enemies[0]
		game.player = e.p+Vector2(-300,0)
		game.build_flow()
		var elapsed := 0.0
		for frame in range(4200):
			game.grace = 2.0
			var follow: Vector2 = e.p+Vector2(-300,0)-game.player
			game.replay_input = {"movement":follow if follow.length() > 8 else Vector2.ZERO,"aim":game.player.direction_to(e.p),"primary":frame%180 > 0 and frame%180 <= 54,"secondary":false}
			game._physics_process(1.0/60.0)
			elapsed = (frame+1)/60.0
			if game.stairs_unlocked: break
		print("BASTION TIME: floor %d, 30%% firing uptime, %.2fs, clear=%s" % [depth,elapsed,game.stairs_unlocked])
		if not game.stairs_unlocked or elapsed > 60:
			failed = true
			push_error("FAIL: bastion intermittent primary budget")
	game.free()
	if not failed: print("PASS: bastion intermittent primary clears within one minute")
	quit(1 if failed else 0)
