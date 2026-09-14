extends SceneTree
## Ordinary 60Hz movement/fire replay. No protection, timer or camera overrides.
var destination := "res://docs/validation/polish/after/journey"
var recording := true
func _initialize() -> void: call_deferred("run")
func route(game, goal: Vector2i) -> Array[Vector2i]:
	var start: Vector2i = game.tile(game.player)
	var parents := {start:start}
	var queue: Array[Vector2i] = [start]
	var index := 0
	while index<queue.size() and not parents.has(goal):
		var here := queue[index]
		index += 1
		for direction in [Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]:
			var next: Vector2i = here+direction
			if parents.has(next) or not game.cells.has(next): continue
			parents[next] = here
			queue.append(next)
	var result: Array[Vector2i] = []
	if not parents.has(goal): return result
	var cursor := goal
	while cursor != start:
		result.push_front(cursor)
		cursor = parents[cursor]
	return result
func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): destination = argument.trim_prefix("--output=")
		if argument == "--no-record": recording = false
	DirAccess.make_dir_recursive_absolute(destination)
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.start_run()
	game.rng.seed = 19045
	game.effects_rng.seed = 19045 ^ 0x5EED
	game.sub_weapon = 1
	game.new_floor()
	game.set_depth_view(true)
	var path := route(game,game.tile(game.stairs))
	var output_index := 0
	var clear_frame := -1
	var input_log: Array = []
	for frame in range(3600):
		if game.pending_respawn:
			game._physics_process(1.0/60)
			path = route(game,game.tile(game.stairs))
		while not path.is_empty() and game.player.distance_to(game.center(path[0]))<4: path.pop_front()
		var movement: Vector2 = game.player.direction_to(game.center(path[0])) if not path.is_empty() else Vector2.ZERO
		var target: Vector2 = game.player+Vector2.RIGHT*100
		var nearest := 100000.0
		for enemy in game.enemies:
			var distance: float = game.player.distance_squared_to(enemy.p)
			if game.attack_open(enemy.p) and game.attack_reaches(game.player,enemy.p) and distance<nearest:
				nearest = distance
				target = enemy.p
		if frame%15 == 0: path = route(game,game.tile(game.stairs))
		movement = evade(game,movement)
		game.replay_input = {"movement":movement,"aim":game.player.direction_to(target),"primary":frame>0,"secondary":frame>0 and nearest<150*150}
		input_log.append([movement.x,movement.y,game.replay_input.aim.x,game.replay_input.aim.y,game.replay_input.primary,game.replay_input.secondary])
		game._physics_process(1.0/60)
		if DisplayServer.get_name() != "headless":
			await process_frame
			await RenderingServer.frame_post_draw
		if frame%2 == 0 and recording:
			root.get_texture().get_image().save_png(destination+"/%05d.png" % output_index)
			output_index += 1
		if game.choosing and clear_frame<0: clear_frame = frame
		if clear_frame>=0 and frame>clear_frame+45: break
	var file := FileAccess.open(destination+"/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"cleared":clear_frame>=0,"clear_frame":clear_frame,"deaths":game.deaths,"kills":game.kills,"frames":input_log.size(),"normal_rules":true,"input":input_log},"\t"))
	print("PASS: journey recorded; clear frame=",clear_frame," deaths=",game.deaths)
	game.free()
	quit()

func evade(game, desired: Vector2) -> Vector2:
	var best := desired
	var best_score := -INF
	for index in range(9):
		var direction := Vector2.ZERO if index == 8 else Vector2.from_angle(index*TAU/8)
		var velocity: Vector2 = direction*(game.SPEED+game.move_bonus)
		var ahead: Vector2 = game.player+velocity*0.15
		if not game.walkable(ahead,game.PLAYER_HIT_RADIUS): continue
		var score: float = direction.dot(desired)*15
		for enemy in game.enemies:
			if not game.attack_open(enemy.p) or game.player.distance_squared_to(enemy.p)>180*180: continue
			var enemy_velocity: Vector2 = enemy.dir*game.Catalog.ENEMIES[2].charge_speed if enemy.charge>0 else enemy.p.direction_to(game.player)*game.ENEMY_MOVE_SPEED
			var relative: Vector2 = enemy.p-game.player
			var motion := enemy_velocity-velocity
			var time := clampf(-relative.dot(motion)/maxf(1,motion.length_squared()),0,0.25)
			var distance := (relative+motion*time).length()
			score -= maxf(0,48-distance)*8
		for bullet in game.bullets:
			if not bullet.hostile or bullet.p.distance_squared_to(game.player)>200*200: continue
			var relative: Vector2 = bullet.p-game.player
			var motion: Vector2 = bullet.v-velocity
			var time := clampf(-relative.dot(motion)/maxf(1,motion.length_squared()),0,0.25)
			var distance := (relative+motion*time).length()
			score -= maxf(0,22-distance)*14
		if score>best_score:
			best_score = score
			best = direction
	return best
