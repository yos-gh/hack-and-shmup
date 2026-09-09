extends SceneTree

var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: " + message)
		failures += 1
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.settings_menu.open()
	game.settings_menu.waiting_action = "move_left"
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.title_screen and not game.paused and game.settings_menu.waiting_action.is_empty(), "focus loss cancels key capture without starting a run")
	game.settings_menu.close()
	game.start_run()
	game.fire_armed = true
	var before: PackedByteArray = var_to_bytes([game.player,game.enemies,game.time_left,game.rng.state,game.bullets])
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game._physics_process(3.0)
	check(game.paused and game.sound.paused_state and not game.fire_armed, "focus loss pauses combat/audio and disarms firing")
	check(before == var_to_bytes([game.player,game.enemies,game.time_left,game.rng.state,game.bullets]), "background time does not advance simulation")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(game.paused, "focus return requires explicit resume")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	game.controls.handle_event(game,click)
	game.replay_input = {"primary":true,"secondary":false,"movement":Vector2.ZERO,"aim":Vector2.RIGHT}
	game._physics_process(0.01)
	check(not game.paused and not game.fire_armed and game.bullets.is_empty(), "held fire cannot leak through resume")
	game.replay_input.primary = false
	game._physics_process(0.01)
	check(game.fire_armed, "release re-arms normal controls")
	game.choosing = true
	game.choices.assign([0,1,2])
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.choosing and not game.paused, "upgrade selection remains available after focus return")
	game.queue_free()
	await process_frame
	if failures == 0: print("PASS: focus pause, frozen state, key capture cancellation and resume gating")
	quit(1 if failures else 0)
