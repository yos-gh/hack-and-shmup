extends SceneTree
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: " + message)
		failures += 1

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.start_run()
	game.set_physics_process(false)
	var room_counts: Dictionary = {}
	for seed_value in range(100):
		game.rng.seed = seed_value
		game.new_floor()
		game.build_flow()
		room_counts[game.rooms.size()] = true
		check(game.rooms.size() >= 7 and game.rooms.size() <= 10, "variable room count")
		for room in game.rooms:
			check(room.size.x >= 18 and room.size.y >= 16, "larger rooms")
			check(game.flow.has(room.get_center()), "every room reachable")
		for enemy in game.enemies:
			if enemy.kind == 1: check(enemy.hp == 1.0, "floor one sniper has one HP")
			if enemy.kind == 2: check(enemy.hp == 1.0, "shield body has one HP")
		check(game.flow.has(game.tile(game.stairs)), "stairs reachable seed %d" % seed_value)
		for e in game.enemies:
			check(game.flow.has(game.tile(e.p)), "enemy reachable")
			check(game.entry_safe(e.p, e.room), "spawn away from every entrance")
	check(room_counts.size() > 1, "room count varies across seeds")
	for frame in range(600): game._physics_process(1.0 / 60.0)
	for enemy in game.enemies:
		check(game.entry_safe(enemy.p, enemy.room), "idle patrol preserves entry buffer")
	game.grace = 0
	game.power = 2.0
	game.player = game.stairs
	var count: int = game.enemies.size()
	game.enemies[0].hp = 0.1
	game.enemies[0].p = game.player
	game.die()
	game._physics_process(0.016)
	check(game.player == game.spawn_point, "instant respawn")
	check(game.power == 2.0 and game.enemies.size() == count, "upgrade and enemy count persistence")
	check(game.enemies == game.initial_enemies, "enemy position and health reset")
	check(game.time_left == game.time_limit, "timer reset")
	var e := {"kind": 2, "charge": 1.0, "dir": Vector2.RIGHT, "hp": 10.0, "push": Vector2.ZERO, "p": Vector2.ZERO}
	game.hurt_enemy(e, 2, Vector2.LEFT)
	check(e.hp == 10 and e.push == Vector2(-180,0), "shield blocks damage but takes knockback")
	check((Vector2.RIGHT*410+e.push).x == 230, "frontal knockback slows charge")
	e.push = Vector2.ZERO
	game.hurt_enemy(e, 2, Vector2.RIGHT)
	check(e.hp == 8 and e.push == Vector2(180,0), "unshielded charge takes damage and knockback")
	e.hp = 1.0
	game.hurt_enemy(e,9,Vector2.LEFT,260)
	check(e.hp == 1.0, "lance no longer ignores frontal shield")
	e.hp = 1.0
	game.hurt_enemy(e,1,Vector2.RIGHT)
	check(e.hp <= 0, "one main shot kills unshielded body")
	game.player = game.stairs
	game._physics_process(0.016)
	check(game.choosing, "stairs offer upgrades")
	check(game.best_cleared == 1, "record counts cleared floor")
	game.upgrade(0)
	check(game.floor_number == 2 and not game.choosing, "next floor")
	game.player = game.center(game.rooms[1].get_center())
	game.grace = 100
	for frame in range(300): game._physics_process(1.0 / 60.0)
	check(game.enemies.any(func(enemy: Dictionary) -> bool: return enemy.active), "room activates enemies")
	game.new_floor()
	game.grace = 100
	game.time_left = 0.001
	game._physics_process(0.016)
	check(game.pending_respawn and game.death_reason == "TIME UP", "timeout bypasses grace")
	game._physics_process(0.016)
	check(game.time_left == game.time_limit, "timeout retries reset clock")
	game.paused = true
	var clock_before: float = game.time_left
	game._physics_process(0.5)
	check(game.time_left == clock_before, "pause freezes clock")
	game.paused = false
	game.cells.clear()
	for x in range(25):
		for y in range(5): game.cells[Vector2i(x,y)] = 0 if x < 8 else 1
	game.discovered = {0: true}
	game.player = game.center(Vector2i(3,2))
	var target: Vector2 = game.center(Vector2i(8,2))
	check(not game.attack_reaches(game.player,target), "unentered room blocks attack")
	var foe := {"kind": 0, "charge": 0.0, "dir": Vector2.ZERO, "hp": 100.0, "push": Vector2.ZERO, "p": target}
	game.enemies.assign([foe])
	game.sub_weapon = 1
	game.fire_sub(Vector2.RIGHT)
	check(foe.hp == 100, "shock cannot hit unentered room")
	game.sub_weapon = 2
	game.fire_sub(Vector2.RIGHT)
	check(foe.hp == 100, "lance cannot hit unentered room")
	game.discovered[1] = true
	var foe2: Dictionary = foe.duplicate(true)
	foe2.p += Vector2(64,0)
	game.enemies.assign([foe,foe2])
	var flank: Dictionary = foe.duplicate(true)
	flank.p = game.player + Vector2(96,30)
	var outside: Dictionary = foe.duplicate(true)
	outside.p = game.player + Vector2(96,35)
	game.enemies.append(flank)
	game.enemies.append(outside)
	game.fire_sub(Vector2.RIGHT)
	check(flank.hp < 100 and outside.hp == 100, "wide lance hits flank within visible width plus enemy body")
	check(foe.hp < 100 and foe2.hp < 100, "lance pierces multiple targets")
	foe.p = game.player + Vector2(64,0)
	game.sub_weapon = 1
	game.emit_shot(foe.p,Vector2.LEFT,100,1,true)
	game.fire_sub(Vector2.RIGHT)
	check(foe.push.length() >= 650 and game.bullets.is_empty(), "shock pushes and clears bullets")
	var watcher := {"kind":1,"p":game.player+Vector2(96,0),"room":0,"active":false,"searching":false,"notice":0.5,"turn_speed":2.0,"dir":Vector2.RIGHT,"charge":0.0,"cd":0.25}
	game.update_awareness(watcher,0,0.2)
	check(watcher.searching and not watcher.active, "entry begins search without immediate activation")
	for frame in range(150): game.update_awareness(watcher,0,0.016)
	check(watcher.active, "turn and sight activate enemy")
	check(watcher.cd >= 0.55, "newly alerted enemy gives full attack warning")
	watcher.active = false
	watcher.notice = 0.0
	watcher.dir = Vector2.LEFT
	game.cells.erase(Vector2i(4,2))
	game.update_awareness(watcher,0,0.016)
	check(not watcher.active, "wall prevents visual detection")
	var contact := {"kind":0,"p":game.player+Vector2(16,0)}
	check(not game.enemy_touches_player(contact), "outer player ring is not hurtbox")
	contact.p = game.player+Vector2(14,0)
	check(game.enemy_touches_player(contact), "central five pixel core collides")
	check(game.sound.clips.size()==9 and game.sound.music.stream.loop_end > 0, "audio assets and loop loaded")
	check(not game.attack_reaches(game.player,foe.p), "walls block area effects")
	print("PASS: combat entry barrier, lance piercing, shock push and bullet clear, timeout and pause")
	print("PASS: 100 connected maps; respawn persistence; shield; upgrades; 300 simulation frames")
	game.damage_labels.clear()
	var victim := {"kind":0,"hp":10.0,"charge":0.0,"p":game.player,"push":Vector2.ZERO}
	game.hurt_enemy(victim,1.35,Vector2.RIGHT)
	check(game.damage_labels.size()==1 and is_equal_approx(game.damage_labels[0].damage,1.35), "fractional damage label")
	game.sub_weapon = 0
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_Q
	game._unhandled_input(key)
	check(game.sub_weapon == 2, "Q wraps backward")
	key.keycode = KEY_E
	game._unhandled_input(key)
	check(game.sub_weapon == 0, "E wraps forward")
	key.echo = true
	game._unhandled_input(key)
	check(game.sub_weapon == 0, "key repeat ignored")
	game.restart_attempt()
	check(game.damage_labels.is_empty(), "retry clears damage text")
	print("PASS: damage text and Q/E switching")
	key.echo = false
	key.keycode = KEY_ESCAPE
	game._unhandled_input(key)
	check(game.paused, "Esc pauses")
	game._unhandled_input(key)
	check(game.title_screen and not game.paused, "second Esc returns to title")
	var record: int = game.best_cleared
	var title_time: float = game.time_left
	game._physics_process(1.0)
	check(game.time_left == title_time, "title freezes gameplay")
	key.keycode = KEY_ENTER
	game._unhandled_input(key)
	check(not game.title_screen and game.floor_number == 1 and game.best_cleared == record, "new run preserves record")
	key.keycode = KEY_ESCAPE
	game._unhandled_input(key)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	game._unhandled_input(click)
	check(not game.paused and not game.fire_armed, "click resumes without firing")
	check(absf(game.sound.music.stream.loop_end / float(game.sound.music.stream.mix_rate) - 6.4) < 0.01, "full WAV loop despite compression")
	print("PASS: title, pause transitions, in-memory record, full length BGM loop")
	game.free()
	quit(1 if failures > 0 else 0)
