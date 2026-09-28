extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: "+message)
		failures += 1
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.depth_view.set_process(false)
	game.start_run()
	var seen := {}
	for depth in range(1,101):
		game.floor_number = depth
		game.new_floor()
		check(game.boss_floor == (depth%5 == 0),"bosses replace every fifth floor only")
		if game.boss_floor:
			seen[game.boss_variant] = true
			check(game.boss_variant in [0,1,2] and game.enemies.size() == 1 and game.enemies[0].has("plates"),"normal selection contains only shielded large bosses")
	check(seen.size() == 3,"normal runs select all three large bosses")
	check(game.boss.NAMES.size() == 3,"catalog has no retired bosses")
	for variant in range(3):
		for depth in [5,25,50,100]:
			game.floor_number = depth
			game.new_floor(variant)
			check(game.rooms.size() == 2 and not game.stairs_unlocked,"boss arena starts locked")
			check(game.flow.has(game.tile(game.stairs)),"stairs remain reachable")
			check(game.enemies[0].p.distance_to(game.entrances[1][0]) > 200,"entry is clear of boss")
			game._physics_process(1.0/60)
			check(not game.pending_respawn and game.time_left == 0 and game.bullets.is_empty(),"no time limit or fire before entry")
			game.grace = 999
			game.player = game.stairs
			game._physics_process(1.0/60)
			check(not game.choosing,"locked stairs cannot skip encounter")
			game.enemies[0].hp = 1
			game.restart_attempt()
			check(game.enemies == game.initial_enemies and game.bullets.is_empty() and game.boss.lasers.is_empty(),"retry restores core, shields and attacks")
			var e: Dictionary = game.enemies[0]
			game.hurt_enemy(e,e.hp+1,Vector2.RIGHT,0,true)
			game.grace = 999
			game._physics_process(1.0/60)
			check(game.stairs_unlocked and game.enemies.is_empty(),"core defeat unlocks stairs")
			game.player = game.stairs
			game._physics_process(1.0/60)
			check(game.choosing,"boss stairs offer upgrade")
			game.upgrade(0)
			check(not game.boss_floor and game.stairs_unlocked and game.time_left > 0,"next floor returns to normal progression")
	game.free()
	if failures == 0: print("PASS: three large bosses, five-floor cadence, safe entry, retry, victory and progression at 5/25/50/100F")
	quit(1 if failures else 0)
