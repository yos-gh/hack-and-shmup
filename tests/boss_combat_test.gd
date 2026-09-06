extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.title_screen = false
	for level in range(6):
		var variant := level%3
		var upgrade_level := int(level/3)
		game.floor_number = 5 + upgrade_level*5
		game.power = 1.0 + upgrade_level*1.4
		game.fire_rate = 1.0 + upgrade_level*0.8
		game.new_floor(variant)
		game.player = game.center(Vector2i(1,1))
		# Measure damage and travel budget, not the bot's ability to dodge.
		game.grace = 999
		var elapsed := 0.0
		var prior_positions := {}
		while not game.stairs_unlocked and elapsed < 30.0:
			var target: Dictionary = {}
			var best := INF
			for e in game.enemies:
				var distance: float = game.player.distance_to(e.p)
				if e.kind == 3 and e.hp > 0 and distance < best: target = e; best = distance
			if not target.is_empty():
				var aim: Vector2 = game.player.direction_to(target.p)
				if best > 220: game.player = game.slide(game.player,aim*game.SPEED/60.0,game.PLAYER_HIT_RADIUS)
				# Lead moving targets by the observed velocity and bullet travel time.
				var target_id: int = game.enemies.find(target)
				var velocity: Vector2 = (target.p-prior_positions.get(target_id,target.p))*60.0
				prior_positions[target_id] = target.p
				aim = game.player.direction_to(target.p+velocity.limit_length(180.0)*best/1050.0)
				if game.main_cd <= 0:
					game.emit_shot(game.player,aim,1050,game.power,false)
					game.main_cd = 0.09/game.fire_rate
			game._physics_process(1.0/60)
			elapsed += 1.0/60
		if not game.stairs_unlocked:
			push_error("FAIL: boss damage/travel budget exceeds 30 seconds")
			game.free()
			quit(1)
			return
		print("PASS: actual MG clears boss %d in %.2fs at power %.1f / rate %.1f (dodging excluded)" % [variant,elapsed,game.power,game.fire_rate])
	game.free()
	quit()
