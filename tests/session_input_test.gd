extends SceneTree

var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: " + message)
		failures += 1
func key(game, code: int, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.echo = echo
	game._unhandled_input(event)
func click(game, button: int, position: Vector2 = Vector2(640,400)) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = position
	event.pressed = true
	game._unhandled_input(event)
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	# Verify configured values against engine constants, including physical WASD.
	for pair in [["move_up",KEY_W],["move_left",KEY_A],["move_down",KEY_S],["move_right",KEY_D]]:
		check(InputMap.action_get_events(pair[0])[0].physical_keycode == pair[1],"physical movement binding")
	for pair in [["confirm",KEY_ENTER],["back",KEY_ESCAPE],["compare_view",KEY_F6],["practice_up",KEY_UP],["practice_down",KEY_DOWN],["practice_left",KEY_LEFT],["practice_right",KEY_RIGHT]]:
		check(InputMap.action_get_events(pair[0])[0].keycode == pair[1],"menu binding matches engine constant")
	Input.action_press("move_right")
	Input.action_press("move_up")
	check(game.controls.movement(game) == Vector2(1,-1),"action movement preserves diagonal vector before simulation normalization")
	Input.action_release("move_right")
	Input.action_release("move_up")
	Input.action_press("fire_primary")
	check(game.controls.primary(game),"action primary held")
	game.replay_input = {"primary":false,"movement":Vector2.LEFT}
	check(not game.controls.primary(game) and game.controls.movement(game) == Vector2.LEFT,"replay overrides live actions")
	Input.action_release("fire_primary")
	game.replay_input.clear()
	click(game,MOUSE_BUTTON_LEFT,game.audio_button_rect().get_center())
	check(game.title_screen and game.audio_mode == 1,"audio click cannot start run")
	key(game,KEY_ENTER,true)
	check(game.title_screen,"confirm echo ignored")
	key(game,KEY_ENTER)
	check(not game.title_screen and not game.fire_armed,"confirm starts unarmed")
	key(game,KEY_E)
	key(game,KEY_E,true)
	check(game.sub_weapon == 1,"one weapon switch per press")
	click(game,MOUSE_BUTTON_WHEEL_DOWN)
	check(game.sub_weapon == 0,"wheel previous preserved")
	# Event routing uses InputMap rather than a hard-coded key.
	var remap := InputEventKey.new()
	remap.keycode = KEY_Z
	InputMap.action_add_event("weapon_next",remap)
	key(game,KEY_Z)
	check(game.sub_weapon == 1,"alternative action binding routes correctly")
	InputMap.action_erase_event("weapon_next",remap)
	key(game,KEY_ESCAPE)
	var time_before: float = game.time_left
	key(game,KEY_Q)
	game._physics_process(0.5)
	check(game.paused and game.sub_weapon == 1 and game.time_left == time_before,"pause blocks weapon and clock")
	click(game,MOUSE_BUTTON_LEFT)
	game.replay_input = {"primary":true,"secondary":false,"movement":Vector2.ZERO}
	game._physics_process(0.016)
	check(not game.paused and not game.fire_armed and game.bullets.is_empty(),"resume click does not leak a shot")
	game.replay_input.primary = false
	game._physics_process(0.016)
	check(game.fire_armed,"release rearms shooting")
	game.choosing = true
	game.choices.assign([0,1,2])
	var previous_floor: int = game.floor_number
	key(game,KEY_2)
	key(game,KEY_2,true)
	check(game.floor_number == previous_floor+1 and not game.choosing,"one upgrade and one floor transition")
	game.best_cleared = 12
	# Fifty retries across normal and all bosses; fill every transient owner list.
	for attempt in range(50):
		game.floor_number = 19 if attempt%4 == 0 else 45
		game.new_floor(-1 if attempt%4 == 0 else attempt%4-1)
		var baseline := var_to_bytes(game.initial_enemies)
		var owner: Dictionary = game.enemies[0]
		owner.hp = 0.1
		owner.p += Vector2(100,100)
		game.boss.options.append({"owner":owner,"p":owner.p,"life":1.0})
		game.boss.salvos.append({"owner":owner,"delay":1.0})
		game.boss.lasers.append({"owner":owner,"duration":1.0})
		game.boss.pending_summons.append({"p":owner.p})
		game.bullets.append({"p":owner.p})
		game.particles.append({"p":owner.p})
		game.effects.append({"kind":0})
		game.damage_labels.append({"damage":1})
		game.discovered[1] = true
		game.kills += 10
		game.grace = 0
		var deaths_before: int = game.deaths
		game.die()
		game.die()
		check(game.deaths == deaths_before+1,"duplicate death counted once")
		var random_before: int = game.rng.state
		var stats := [game.power,game.move_bonus,game.fire_rate,game.sub_weapon]
		game._physics_process(0.016)
		check(var_to_bytes(game.enemies) == baseline and var_to_bytes(game.initial_enemies) == baseline,"retry restores independent baseline")
		check(game.boss.options.is_empty() and game.boss.salvos.is_empty() and game.boss.lasers.is_empty() and game.boss.pending_summons.is_empty(),"retry clears all boss attacks")
		check(game.bullets.is_empty() and game.particles.is_empty() and game.effects.is_empty() and game.damage_labels.is_empty(),"retry clears transient presentation and projectiles")
		check(game.player == game.spawn_point and game.time_left == game.time_limit and game.kills == game.floor_start_kills and game.discovered == {0:true},"retry restores floor progress")
		check(game.rng.state == random_before and stats == [game.power,game.move_bonus,game.fire_rate,game.sub_weapon] and game.best_cleared == 12,"retry preserves RNG progression, upgrades and record")
	game.return_to_title()
	key(game,KEY_B)
	key(game,KEY_3)
	key(game,KEY_UP)
	key(game,KEY_ENTER)
	check(game.practice.active and game.boss_variant == 2 and game.floor_number == 10,"practice actions retain selection")
	key(game,KEY_R)
	check(not game.pending_respawn and game.enemies == game.initial_enemies,"practice retry uses snapshot")
	key(game,KEY_ESCAPE)
	key(game,KEY_ESCAPE)
	check(game.title_screen and not game.practice.active and not game.paused,"second escape returns to title")
	key(game,KEY_ENTER)
	check(game.floor_number == 1 and game.power == 1 and game.deaths == 0 and game.best_cleared == 12,"new run resets progression but keeps session record")
	game.free()
	if failures == 0: print("PASS: InputMap, remap, echo, pause/resume, cards, practice, 50 isolated retries and run reset")
	quit(1 if failures else 0)
