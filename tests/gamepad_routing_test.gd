extends SceneTree

var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: " + message)
		failures += 1

func button(index: int, pressed: bool = true, device: int = 3) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = pressed
	event.device = device
	return event

func motion(axis: int, value: float, device: int = 3) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	event.device = device
	return event

func send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func tap(index: int) -> void:
	send(button(index))
	send(button(index,false))

func run() -> void:
	var connections_before := Input.joy_connection_changed.get_connections().size()
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.menus.sync()
	for pair in [[JOY_BUTTON_A,"fire_primary"],[JOY_BUTTON_LEFT_SHOULDER,"fire_primary"],[JOY_BUTTON_RIGHT_SHOULDER,"fire_secondary"],[JOY_BUTTON_B,"back"],[JOY_BUTTON_DPAD_LEFT,"move_left"],[JOY_BUTTON_DPAD_RIGHT,"move_right"],[JOY_BUTTON_DPAD_UP,"move_up"],[JOY_BUTTON_DPAD_DOWN,"move_down"]]:
		check(InputMap.event_is_action(button(pair[0]),pair[1]),"binding accepts nonzero device: " + pair[1])
	# Real viewport dispatch must not fall through to the built-in ui_* actions.
	send(motion(JOY_AXIS_TRIGGER_LEFT,0.8))
	game.menus.sync()
	check(root.gui_get_focus_owner() == game.menus._buttons()[0],"first pad input focuses Start")
	send(motion(JOY_AXIS_LEFT_Y,0.8))
	var focused: Control = root.gui_get_focus_owner()
	check(focused == game.menus._buttons()[1],"stick moves to practice once")
	send(motion(JOY_AXIS_LEFT_Y,0.9))
	send(motion(JOY_AXIS_LEFT_X,0.01))
	check(root.gui_get_focus_owner() == focused,"held stick and perpendicular drift do not reach default GUI navigation")
	send(motion(JOY_AXIS_LEFT_Y,0.0))
	send(motion(JOY_AXIS_LEFT_X,0.0))
	send(motion(JOY_AXIS_TRIGGER_LEFT,0.0))
	game.practice.open(game)
	game.menus.sync()
	game.menus._buttons()[4].grab_focus()
	tap(JOY_BUTTON_LEFT_SHOULDER)
	check(game.practice.depth == 10 and root.gui_get_focus_owner() == game.menus._buttons()[4],"practice plus retains focus after refresh")
	tap(JOY_BUTTON_LEFT_SHOULDER)
	check(game.practice.depth == 15,"practice plus can be pressed again without navigating back")
	# Held fire from a menu must remain disarmed until it is released.
	game.start_run()
	check(InputMap.event_is_action(motion(JOY_AXIS_TRIGGER_LEFT,1.0),"weapon_previous") and InputMap.event_is_action(motion(JOY_AXIS_TRIGGER_RIGHT,1.0),"weapon_next"),"triggers bind to Q/E actions on every device")
	send(motion(JOY_AXIS_TRIGGER_RIGHT,0.1))
	check(game.sub_weapon == 0,"trigger drift does not change weapon")
	send(motion(JOY_AXIS_TRIGGER_RIGHT,0.8))
	send(motion(JOY_AXIS_TRIGGER_RIGHT,0.9))
	check(game.sub_weapon == 1,"RT changes next weapon once per pull")
	send(motion(JOY_AXIS_TRIGGER_RIGHT,0.0))
	send(motion(JOY_AXIS_TRIGGER_RIGHT,0.8))
	check(game.sub_weapon == 2,"released RT can change again")
	send(motion(JOY_AXIS_TRIGGER_LEFT,0.8))
	check(game.sub_weapon == 1,"LT selects previous weapon independently")
	send(motion(JOY_AXIS_TRIGGER_RIGHT,0.0))
	send(motion(JOY_AXIS_TRIGGER_LEFT,0.0))
	game.paused = true
	send(motion(JOY_AXIS_TRIGGER_LEFT,0.8))
	check(game.sub_weapon == 1,"pause blocks trigger weapon changes")
	game.paused = false
	send(motion(JOY_AXIS_TRIGGER_LEFT,0.9))
	check(game.sub_weapon == 1,"trigger held through pause cannot leak a change")
	send(motion(JOY_AXIS_TRIGGER_LEFT,0.0))
	send(motion(JOY_AXIS_TRIGGER_LEFT,0.8))
	check(game.sub_weapon == 0,"released LT rearms after pause")
	send(motion(JOY_AXIS_TRIGGER_LEFT,0.0))
	game.choosing = true
	game.choices.assign([0,1,2])
	game.menus.sync()
	send(button(JOY_BUTTON_DPAD_RIGHT))
	focused = root.gui_get_focus_owner()
	check(focused == game.menus.cards[1],"D-pad selects second upgrade")
	send(button(JOY_BUTTON_DPAD_RIGHT))
	check(root.gui_get_focus_owner() == focused,"held D-pad cannot move twice through GUI")
	send(button(JOY_BUTTON_DPAD_RIGHT,false))
	var floor_before: int = game.floor_number
	send(button(JOY_BUTTON_A))
	check(game.floor_number == floor_before+1 and not game.choosing,"pad confirms one upgrade through viewport")
	check(game.controls.primary(game),"nonzero device updates held primary action")
	game._physics_process(0.016)
	check(not game.fire_armed and game.bullets.is_empty(),"upgrade confirmation cannot leak a shot")
	send(button(JOY_BUTTON_A,false))
	game._physics_process(0.016)
	check(game.fire_armed,"releasing pad confirmation rearms fire")
	send(button(JOY_BUTTON_LEFT_SHOULDER))
	game._physics_process(0.016)
	check(not game.bullets.is_empty(),"LB fires after menu release")
	send(button(JOY_BUTTON_LEFT_SHOULDER,false))
	send(button(JOY_BUTTON_RIGHT_SHOULDER))
	check(game.controls.secondary(game),"RB updates held secondary action")
	send(button(JOY_BUTTON_RIGHT_SHOULDER,false))
	# A shallow diagonal exceeds the radial deadzone. Mouse aiming must not
	# change its movement direction or speed while the left stick is held.
	send(motion(JOY_AXIS_LEFT_X,0.15))
	send(motion(JOY_AXIS_LEFT_Y,0.15))
	var before_mouse: Vector2 = game.controls.movement(game).normalized()
	check(before_mouse.is_equal_approx(Vector2.ONE.normalized()),"shallow diagonal moves above radial deadzone")
	var mouse := InputEventMouseMotion.new()
	mouse.position = Vector2(800,500)
	mouse.relative = Vector2.ONE
	send(mouse)
	check(not game.controls.using_gamepad and game.controls.movement(game).normalized().is_equal_approx(before_mouse),"mouse aim does not stop a held left stick")
	var movement_start: Vector2 = game.spawn_point
	game.player = movement_start
	game._physics_process(0.01)
	var shallow_distance: float = game.player.distance_to(movement_start)
	send(motion(JOY_AXIS_LEFT_X,1.0))
	send(motion(JOY_AXIS_LEFT_Y,1.0))
	game.player = movement_start
	game._physics_process(0.01)
	var full_distance: float = game.player.distance_to(movement_start)
	check(is_equal_approx(shallow_distance,full_distance) and is_equal_approx(full_distance,(game.SPEED+game.move_bonus)*0.01),"shallow and full diagonal stick input use the same fixed simulation speed")
	send(motion(JOY_AXIS_LEFT_X,0.0))
	send(motion(JOY_AXIS_LEFT_Y,0.0))
	check(game.controls.movement(game).is_zero_approx(),"stick release stops movement")
	for screen_direction in [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP,Vector2(1,1),Vector2(-1,1),Vector2(-1,-1),Vector2(1,-1)]:
		send(motion(JOY_AXIS_RIGHT_X,screen_direction.x))
		send(motion(JOY_AXIS_RIGHT_Y,screen_direction.y))
		var aim: Vector2 = game.controls.aim(game)
		var projected: Vector2 = game.world_to_screen(game.player+aim*100)-game.world_to_screen(game.player)
		check(projected.normalized().dot(screen_direction.normalized()) > 0.999,"stick aim matches displayed direction " + str(screen_direction))
	game.replay_input = {"cursor":game.world_to_screen(game.player+Vector2.LEFT*100)}
	check(game.controls.aim(game).is_equal_approx(Vector2.LEFT),"replay cursor overrides active pad")
	game.replay_input.aim = Vector2.DOWN
	check(game.controls.aim(game) == Vector2.DOWN,"explicit replay aim overrides cursor")
	game.replay_input.clear()
	send(motion(JOY_AXIS_RIGHT_X,0.0))
	send(motion(JOY_AXIS_RIGHT_Y,0.0))
	tap(JOY_BUTTON_B)
	check(game.paused,"B pauses through viewport")
	game.menus.sync()
	tap(JOY_BUTTON_B)
	check(game.title_screen and not game.paused,"second B returns to title")
	game.practice.variant = 0
	game.practice.open(game)
	game.menus.sync()
	send(button(JOY_BUTTON_DPAD_RIGHT))
	check(root.gui_get_focus_owner() == game.menus._buttons()[1],"D-pad is held before disconnect")
	Input.joy_connection_changed.emit(3,false)
	check(not game.controls.using_gamepad,"disconnect signal restores mouse")
	Input.joy_connection_changed.emit(3,true)
	send(button(JOY_BUTTON_DPAD_RIGHT))
	check(root.gui_get_focus_owner() == game.menus._buttons()[2],"disconnect clears held navigation before reconnect")
	send(button(JOY_BUTTON_DPAD_RIGHT,false))
	game.free()
	check(Input.joy_connection_changed.get_connections().size() == connections_before,"game lifetime does not retain a joy connection callback")
	if failures == 0: print("PASS: gamepad viewport routing, devices, focus retention, fire gating, mixed movement and projected aim")
	quit(1 if failures else 0)
