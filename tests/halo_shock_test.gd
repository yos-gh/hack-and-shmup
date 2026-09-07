extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var camping_hits := 0
	var moving_survivals := 0
	for moving in [false,true]:
		for direction in range(8):
			for timing in range(4):
				game.practice.depth = 45
				game.practice.variant = 2
				game.practice.start(game)
				var owner: Dictionary = game.enemies[0]
				owner.active = true
				owner.cd = 0.6
				game.discovered[1] = true
				game.grace = 0
				game.sub_weapon = 1
				game.sub_cd = timing*0.5
				for frame in range(720):
					var angle := direction*TAU/8 + frame/60.0*0.9 if moving else direction*TAU/8
					game.player = owner.p+Vector2.from_angle(angle)*(280.0 if moving else 100.0)
					if game.sub_cd <= 0: game.fire_sub(Vector2.RIGHT)
					game._physics_process(1.0/60)
					if game.pending_respawn: break
				if not moving and game.pending_respawn: camping_hits += 1
				if moving and not game.pending_respawn: moving_survivals += 1
	print("LV45 SHOCK: camping hits %d/32; moving survivals %d/32" % [camping_hits,moving_survivals])
	game.free()
	quit(0 if camping_hits == 32 and moving_survivals > 0 else 1)
