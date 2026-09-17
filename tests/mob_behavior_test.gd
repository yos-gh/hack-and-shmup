extends SceneTree
const Catalog = preload("res://scripts/combat_catalog.gd")
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: "+message)
		failures += 1
func enemy(kind: int, p: Vector2) -> Dictionary:
	return {"kind":kind,"p":p,"hp":2.0,"dir":Vector2.RIGHT,"push":Vector2.ZERO,"active":true,"searching":true,"room":1,"cd":1.0,"charge":0.0,"stun":0.0,"notice":0.0,"turn_speed":2.0,"flank_side":1}
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	for depth in [1,4,5,6,9,10,11,19,45]:
		game.floor_number = depth
		game.rng.seed = 93
		game.new_floor()
		var counts := {}
		for e in game.enemies:
			if not counts.has(e.room): counts[e.room] = {4:0,5:0}
			if e.kind in [4,5]:
				counts[e.room][e.kind] += 1
				check(is_equal_approx(e.hp,game.enemy_health(1,depth)),"new mobs have sniper health")
				check(game.entry_safe(e.p,e.room),"new spawn respects entrance")
		for room in counts:
			check(counts[room][4] <= 6 and counts[room][5] <= 2,"room population caps")
			if depth < 6 or game.boss_floor: check(counts[room][4] == 0,"flanker unlocks after first boss")
			elif room != 0: check(counts[room][4] > 0,"flanker present after unlock")
			if depth < 11 or game.boss_floor: check(counts[room][5] == 0,"interceptor unlocks after second boss")
			elif room != 0: check(counts[room][5] > 0,"interceptor present after unlock")
		if not game.boss_floor:
			for room in counts:
				var members: Array = game.enemies.filter(func(e): return e.room == room)
				var expected_snipers := 0
				var expected_shields := 0
				for i in range(members.size()):
					if i%7 == 0: expected_snipers += 1
					elif i%11 == 0: expected_shields += 1
				check(members.filter(func(e): return e.kind == 1).size() == expected_snipers and members.filter(func(e): return e.kind == 2).size() == expected_shields,"new mobs replace chasers only")
	game.boss_floor = false
	game.cells.clear()
	for x in range(45):
		for y in range(28): game.cells[Vector2i(x,y)] = 1
	game.rooms.assign([Rect2i(0,0,1,1),Rect2i(0,0,45,28)])
	game.discovered = {1:true}
	game.entrances = {1:[]}
	game.player = Vector2(500,400)
	game.camera_pos = game.player
	game.build_flow()
	var flanker := enemy(4,Vector2(200,400))
	var motion: Vector2 = game.mobs.velocity(game,flanker,0.1,Vector2.ZERO)
	check(motion.x > 0 and motion.y > 0 and is_equal_approx(motion.length(),120),"flanker approaches the side at fixed speed")
	flanker.p = game.player-Vector2(70,0)
	motion = game.mobs.velocity(game,flanker,0.1,Vector2.ZERO)
	check(motion.x > 0,"flanker closes rather than orbiting forever")
	# Block the lateral lookahead while retaining the straight chase route.
	flanker.p = Vector2(200,400)
	var blocked_cell: Vector2i = game.tile(flanker.p+Vector2.RIGHT.rotated(PI/3)*64)
	game.cells.erase(blocked_cell)
	motion = game.mobs.velocity(game,flanker,0.1,Vector2.ZERO)
	check(motion == game.mobs.chase(game,flanker,120),"blocked flank falls back to existing chase flow")
	game.cells[blocked_cell] = 1
	# The Interceptor reserves its warp for corridors, not room repositioning.
	for x in range(10,45):
		for y in range(28): game.cells[Vector2i(x,y)] = -1
	var interceptor := enemy(5,Vector2(100,400))
	game.mobs.reset()
	for i in range(12): game.mobs.velocity(game,interceptor,0.1,Vector2.ZERO)
	check(interceptor.get("warp_warning",0.0) == 0,"standing still never triggers intercept")
	for i in range(4): game.mobs.velocity(game,interceptor,0.1,Vector2.RIGHT)
	check(interceptor.get("warp_warning",0.0) > 0,"sustained escape starts a visible warning")
	var target: Vector2 = interceptor.warp_target
	var second := enemy(5,Vector2(100,450))
	for i in range(12): game.mobs.velocity(game,second,0.1,Vector2.RIGHT)
	check(second.get("warp_warning",0.0) == 0,"only one simultaneous warp")
	game.mobs.velocity(game,interceptor,0.9,Vector2.RIGHT)
	check(interceptor.p == target and interceptor.arrival > 0 and interceptor.warp_cd == 5,"warp completes at fixed target with recovery")
	game.player = target
	check(not game.enemy_touches_player(interceptor),"arrival cannot cause contact damage")
	game.hurt_enemy(interceptor,0.5,Vector2.RIGHT)
	check(interceptor.hp == 1.5,"arrival remains vulnerable")
	game.player = Vector2(500,400)
	var cancelled := enemy(5,Vector2(100,400))
	game.mobs.reset()
	for i in range(4): game.mobs.velocity(game,cancelled,0.1,Vector2.RIGHT)
	game.player = cancelled.warp_target
	game.mobs.velocity(game,cancelled,0.9,Vector2.ZERO)
	check(cancelled.p == Vector2(100,400) and cancelled.get("arrival",0.0) == 0,"approaching landing cancels warp safely")
	check(not game.mobs.landing_valid(game,game.player+Vector2(1000,0)),"offscreen landing rejected")
	game.player = Vector2(500,400)
	game.cells[game.tile(game.player)] = 1
	game.cells[game.tile(Vector2(740,400))] = 1
	game.entrances[1] = [Vector2(740,400)]
	check(not game.mobs.landing_valid(game,Vector2(740,400)),"entrance clearance applies to teleport")
	game.entrances[1] = []
	var wall_target := Vector2(740,400)
	game.cells.erase(game.tile(wall_target))
	check(not game.mobs.landing_valid(game,wall_target),"wall landing rejected")
	game.cells[game.tile(wall_target)] = 2
	check(not game.mobs.landing_valid(game,wall_target),"another room cannot receive a warp")
	game.cells[game.tile(wall_target)] = 1
	game.mobs.warp_owner = second
	second.hp = 0
	game.mobs.begin_frame()
	check(game.mobs.warp_owner.is_empty(),"killing the warper frees the warning slot")
	game.mobs.warp_owner = cancelled
	game.restart_attempt()
	check(game.mobs.warp_owner.is_empty() and game.enemies == game.initial_enemies,"retry clears special state")
	check_corridor_intercept(game)
	game.free()
	if failures == 0: print("PASS: five-floor unlocks, low HP, population caps, flank movement, warp telegraph/recovery/cancel and retry")
	quit(1 if failures else 0)

func check_corridor_intercept(game) -> void:
	# Actual movement during the full tell, not a stationary player at trigger time.
	game.start_run()
	game.set_physics_process(false)
	game.floor_number = 11
	for i in range(10): game.apply_upgrade([0,1,3,2][i%4])
	game.cells.clear()
	for x in range(15):
		for y in range(13): game.cells[Vector2i(x,y)] = 1
	for x in range(15,56):
		for y in range(5,8): game.cells[Vector2i(x,y)] = -1
	game.rooms.assign([Rect2i(-8,0,4,4),Rect2i(0,0,15,13)])
	game.entrances = {1:[Vector2(464,208)]}
	game.discovered = {0:true,1:true}
	game.player = Vector2(400,208)
	game.camera_pos = game.player
	game.stairs = Vector2(-10000,-10000)
	game.time_left = 60
	game.grace = 0
	game.build_flow()
	var warper := enemy(5,Vector2(80,80))
	warper.active = false
	warper.searching = false
	warper.dir = Vector2.LEFT
	warper.notice = 0.65
	game.enemies.assign([warper])
	var warned := false
	var arrived := false
	var trigger_position := Vector2.ZERO
	var arrival_player := Vector2.ZERO
	for frame in range(180):
		game.replay_input = {"movement":Vector2.RIGHT,"aim":Vector2.RIGHT,"primary":false,"secondary":false}
		game._physics_process(1.0/60)
		if warper.get("warp_warning",0.0) > 0 and not warned:
			warned = true
			trigger_position = game.player
		if warper.get("arrival",0.0) > 0:
			arrived = true
			arrival_player = game.player
			break
	check(warned and arrived,"room entry then uninterrupted corridor movement produces a warp")
	if arrived:
		check(game.cells.get(game.tile(warper.p),-2) == -1,"enemy actually arrives in corridor")
		check(warper.p.x > game.player.x+96 and game.player.x > trigger_position.x+100,"arrival stays ahead of a moving upgraded player")
		check(game.deaths == 0,"warp arrival grants time to respond")
		print("CORRIDOR: warning at ",trigger_position," arrival player=",arrival_player," target=",warper.p)
	# Around a bend: only connected corridor cells qualify, not a ray through a wall.
	game.cells.clear()
	for x in range(10,23):
		for y in range(10,13): game.cells[Vector2i(x,y)] = -1
	for x in range(20,23):
		for y in range(10,25): game.cells[Vector2i(x,y)] = -1
	game.player = game.center(Vector2i(18,11))
	game.camera_pos = game.player
	game.build_flow()
	var target: Vector2 = game.mobs.intercept_target(game,Vector2.RIGHT)
	check(target.is_finite() and game.walkable(target,14) and target.y > game.player.y+64,"connected lookahead follows corridor bend")
	var untouched := enemy(5,Vector2(80,80))
	untouched.active = false
	untouched.searching = false
	game.update_awareness(untouched,-1,1.0)
	check(not untouched.active,"unvisited enemies cannot ambush from unrelated rooms")
