extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: " + message)
		failures += 1

func motion(axis: int, value: float, device: int = 0) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	event.device = device
	return event

func button(index: int, pressed: bool = true, device: int = 0) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = pressed
	event.device = device
	return event

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.menus.sync()
	var controls = game.controls
	controls.observe_event(game,motion(JOY_AXIS_LEFT_X,0.1))
	controls.observe_event(game,motion(JOY_AXIS_LEFT_Y,-0.1))
	check(not controls.using_gamepad,"radial drift below 0.2 does not select gamepad")
	# Movement stays live in both schemes, so a pad without a right stick can
	# be paired with the mouse: sticks and the D-pad never switch the scheme.
	controls.observe_event(game,motion(JOY_AXIS_LEFT_X,0.8))
	check(not controls.using_gamepad,"left stick keeps mouse aim")
	controls.observe_event(game,button(JOY_BUTTON_DPAD_LEFT))
	controls.observe_event(game,button(JOY_BUTTON_DPAD_LEFT,false))
	check(not controls.using_gamepad,"D-pad keeps mouse aim")
	controls.observe_event(game,motion(JOY_AXIS_RIGHT_X,0.0))
	controls.observe_event(game,motion(JOY_AXIS_RIGHT_Y,-1.0))
	check(not controls.using_gamepad,"right stick alone keeps mouse aim")
	controls.observe_event(game,button(JOY_BUTTON_X))
	check(controls.using_gamepad,"a pad button selects gamepad")
	var expected: Vector2 = (game.screen_to_world(Vector2(0,-1)) - game.screen_to_world(Vector2.ZERO)).normalized()
	check(controls.aim(game).is_equal_approx(expected),"a right stick held before the switch aims at once, screen-to-world")
	controls.observe_event(game,motion(JOY_AXIS_RIGHT_X,1.0))
	controls.observe_event(game,motion(JOY_AXIS_RIGHT_Y,0.0))
	expected = (game.screen_to_world(Vector2(1,0)) - game.screen_to_world(Vector2.ZERO)).normalized()
	check(controls.aim(game).is_equal_approx(expected),"right stick uses screen-to-world aiming")
	controls.observe_event(game,motion(JOY_AXIS_RIGHT_Y,0.0))
	check(controls.aim(game).is_equal_approx(expected),"right-stick neutral retains the last aim")
	var first: Vector2i = controls.menu_direction(button(JOY_BUTTON_DPAD_RIGHT))
	var held: Vector2i = controls.menu_direction(button(JOY_BUTTON_DPAD_RIGHT))
	controls.observe_event(game,button(JOY_BUTTON_DPAD_RIGHT,false))
	var repeated: Vector2i = controls.menu_direction(button(JOY_BUTTON_DPAD_RIGHT))
	check(first == Vector2i.RIGHT and held == Vector2i.ZERO and repeated == Vector2i.RIGHT,"D-pad needs release before repeat")
	controls.menu_stick_held = false
	controls.observe_event(game,motion(JOY_AXIS_LEFT_X,0.8))
	var stick_first: Vector2i = controls.menu_direction(motion(JOY_AXIS_LEFT_X,0.8))
	controls.observe_event(game,motion(JOY_AXIS_LEFT_Y,0.01))
	var stick_drift: Vector2i = controls.menu_direction(motion(JOY_AXIS_LEFT_Y,0.01))
	check(stick_first == Vector2i.RIGHT and stick_drift == Vector2i.ZERO,"perpendicular drift cannot repeat a held stick")
	var stationary := InputEventMouseMotion.new()
	controls.observe_event(game,stationary)
	check(controls.using_gamepad,"stationary mouse event does not steal gamepad mode")
	var moved := InputEventMouseMotion.new()
	moved.relative = Vector2.ONE
	controls.observe_event(game,moved)
	check(controls.using_gamepad,"mouse movement alone keeps gamepad aim")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	controls.observe_event(game,wheel)
	check(controls.using_gamepad,"mouse wheel keeps gamepad aim")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	controls.observe_event(game,click)
	check(not controls.using_gamepad,"mouse click restores mouse aim")
	var keyboard := InputEventKey.new()
	keyboard.keycode = KEY_W
	keyboard.pressed = true
	controls.observe_event(game,motion(JOY_AXIS_TRIGGER_RIGHT,0.8))
	check(controls.using_gamepad,"trigger pull selects gamepad")
	controls.observe_event(game,motion(JOY_AXIS_TRIGGER_RIGHT,0.0))
	controls.observe_event(game,keyboard)
	check(controls.using_gamepad,"WASD keeps gamepad aim")
	controls.observe_event(game,click)
	controls.observe_event(game,button(JOY_BUTTON_A))
	check(controls.using_gamepad,"primary button selects gamepad")
	controls.joy_connection_changed(0,false,game)
	check(not controls.using_gamepad,"active controller disconnect restores mouse")
	game.menus._buttons()[0].grab_focus()
	game.menus._input(button(JOY_BUTTON_A))
	check(not game.title_screen and not game.fire_armed,"gamepad accept activates the focused title button once")
	game.free()
	if failures == 0: print("PASS: gamepad radial movement, aim retention, click/button scheme switching and menu latches")
	quit(1 if failures else 0)
