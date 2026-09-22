extends RefCounted

const JOY_DEADZONE := 0.2
const DPAD := {JOY_BUTTON_DPAD_LEFT: Vector2i.LEFT, JOY_BUTTON_DPAD_RIGHT: Vector2i.RIGHT, JOY_BUTTON_DPAD_UP: Vector2i.UP, JOY_BUTTON_DPAD_DOWN: Vector2i.DOWN}
var using_gamepad := false
var active_device := -1
var last_aim := Vector2.RIGHT
var left_sticks: Dictionary = {}
var right_sticks: Dictionary = {}
var menu_stick_held := false
var menu_dpad_held: Dictionary = {}
var trigger_held: Dictionary = {}

func pointer(game) -> Vector2:
	return game.replay_input.get("cursor", game.get_global_mouse_position())

func aim(game) -> Vector2:
	if game.replay_input.has("aim"): return game.replay_input.aim
	if game.replay_input.has("cursor"): return (game.screen_to_world(game.replay_input.cursor) - game.player).normalized()
	if using_gamepad: return last_aim
	var direction: Vector2 = (game.screen_to_world(pointer(game)) - game.player).normalized()
	if direction.length_squared() > 0.0: last_aim = direction
	return last_aim

func movement(game) -> Vector2:
	# Use one radial deadzone, independent of the current aiming device.
	# The simulation normalizes movement, preserving fixed speed and WASD.
	var direction := Vector2(Input.get_action_raw_strength("move_right")-Input.get_action_raw_strength("move_left"), Input.get_action_raw_strength("move_down")-Input.get_action_raw_strength("move_up"))
	if direction.length() <= JOY_DEADZONE: direction = Vector2.ZERO
	return game.replay_input.get("movement", direction)

func primary(game) -> bool:
	return game.replay_input.get("primary", Input.is_action_pressed("fire_primary"))

func secondary(game) -> bool:
	return game.replay_input.get("secondary", Input.is_action_pressed("fire_secondary"))

func _set_gamepad(game, device: int) -> void:
	using_gamepad = true
	active_device = device
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	game.queue_redraw()

func _set_mouse(game) -> void:
	using_gamepad = false
	active_device = -1
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	game.queue_redraw()

func joy_connection_changed(device: int, connected: bool, game) -> void:
	if not connected:
		left_sticks.erase(device)
		right_sticks.erase(device)
		for key in trigger_held.keys():
			if key.x == device: trigger_held.erase(key)
		menu_stick_held = false
		menu_dpad_held.clear()
		if device == active_device: _set_mouse(game)

# This runs from _input before GUI Controls consume the event. Releases and
# sub-dead-zone drift only clear navigation latches; they never change scheme.
func observe_event(game, event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if event.relative.length_squared() > 0.0: _set_mouse(game)
		return
	if event is InputEventMouseButton and event.pressed:
		_set_mouse(game)
		return
	if event is InputEventJoypadButton:
		if event.pressed: _set_gamepad(game,event.device)
		if DPAD.has(event.button_index) and not event.pressed: menu_dpad_held[event.button_index] = false
		return
	if event is InputEventJoypadMotion:
		if event.axis in [JOY_AXIS_TRIGGER_LEFT,JOY_AXIS_TRIGGER_RIGHT]:
			var key := Vector2i(event.device,event.axis)
			var held: bool = trigger_held.get(key,false)
			var pressed: bool = event.axis_value > JOY_DEADZONE
			trigger_held[key] = pressed
			if pressed: _set_gamepad(game,event.device)
			if pressed and not held and not game.title_screen and not game.paused and not game.practice.selecting:
				if event.is_action_pressed("weapon_next"): game.sub_weapon = (game.sub_weapon+1)%3
				elif event.is_action_pressed("weapon_previous"): game.sub_weapon = (game.sub_weapon+2)%3
			return
		if event.axis in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y]:
			var left: Vector2 = left_sticks.get(event.device, Vector2.ZERO)
			if event.axis == JOY_AXIS_LEFT_X: left.x = event.axis_value
			else: left.y = event.axis_value
			left_sticks[event.device] = left
			if left.length() <= JOY_DEADZONE: menu_stick_held = false
			if left.length() > JOY_DEADZONE: _set_gamepad(game,event.device)
		elif event.axis in [JOY_AXIS_RIGHT_X,JOY_AXIS_RIGHT_Y]:
			var right: Vector2 = right_sticks.get(event.device, Vector2.ZERO)
			if event.axis == JOY_AXIS_RIGHT_X: right.x = event.axis_value
			else: right.y = event.axis_value
			right_sticks[event.device] = right
			if right.length() > JOY_DEADZONE:
				_set_gamepad(game,event.device)
				var origin: Vector2 = game.screen_to_world(Vector2.ZERO)
				var transformed: Vector2 = game.screen_to_world(right) - origin
				if transformed.length_squared() > 0.0: last_aim = transformed.normalized()
		elif event.axis_value > JOY_DEADZONE:
			_set_gamepad(game,event.device)

func menu_direction(event: InputEvent) -> Vector2i:
	if event is InputEventJoypadButton and event.pressed and DPAD.has(event.button_index):
		if menu_dpad_held.get(event.button_index, false): return Vector2i.ZERO
		menu_dpad_held[event.button_index] = true
		return DPAD[event.button_index]
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y]:
		var stick: Vector2 = left_sticks.get(event.device, Vector2.ZERO)
		if stick.length() <= JOY_DEADZONE:
			menu_stick_held = false
			return Vector2i.ZERO
		if menu_stick_held: return Vector2i.ZERO
		menu_stick_held = true
		if absf(stick.x) >= absf(stick.y): return Vector2i.RIGHT if stick.x > 0 else Vector2i.LEFT
		return Vector2i.DOWN if stick.y > 0 else Vector2i.UP
	return Vector2i.ZERO

func gamepad_accept(event: InputEvent) -> bool:
	return event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_A,JOY_BUTTON_LEFT_SHOULDER]

# Event routing keeps the original context priority and one-shot semantics.
func handle_event(game, event: InputEvent) -> void:
	if game.view_comparison and event is InputEventKey and event.pressed and not event.echo and event.is_action_pressed("compare_view"):
		game.set_depth_view(not game.depth_enabled)
		return
	if game.view_comparison and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F7:
		var next := 15.0 if game.view_pitch_degrees < 1 else (25.0 if game.view_pitch_degrees < 20 else (35.0 if game.view_pitch_degrees < 30 else 0.0))
		game.set_view_pitch(next)
		return
	if game.practice.selecting:
		if event is InputEventKey or event is InputEventMouseButton: game.practice.input(game,event)
		elif event is InputEventJoypadButton and event.pressed and event.is_action_pressed("back"): game.return_to_title()
		return
	if (event is InputEventKey or event is InputEventJoypadButton) and event.pressed and not (event is InputEventKey and event.echo):
		if event is InputEventKey and event.is_action_pressed("cycle_audio"):
			game.cycle_audio()
			return
		if game.title_screen:
			if event.is_action_pressed("confirm"): game.start_run()
			elif event.is_action_pressed("boss_practice"): game.practice.open(game)
			elif event.is_action_pressed("back") and not OS.has_feature("web"): game.get_tree().quit()
			return
		if game.practice.active and event is InputEventKey and event.is_action_pressed("boss_practice"):
			game.practice.open(game)
			return
		if game.practice.active and event is InputEventKey and event.is_action_pressed("retry_attempt"):
			game.restart_attempt()
			return
		if event.is_action_pressed("back"):
			if game.paused: game.return_to_title()
			else: game.paused = true
			return
		if game.paused: return
		if event is InputEventKey and event.is_action_pressed("weapon_previous"): game.sub_weapon = (game.sub_weapon + 2) % 3
		if event is InputEventKey and event.is_action_pressed("weapon_next"): game.sub_weapon = (game.sub_weapon + 1) % 3
		if game.choosing and event is InputEventKey:
			for i in range(3):
				if event.is_action_pressed("select_%d" % (i+1)):
					game.upgrade(i)
					return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
			if game.title_screen:
				if game.audio_button_rect().has_point(event.position):
					if event.button_index == MOUSE_BUTTON_LEFT: game.cycle_audio()
				elif game.fullscreen_button_rect().has_point(event.position):
					if event.button_index == MOUSE_BUTTON_LEFT: game.toggle_fullscreen()
				else: game.start_run()
				return
			if game.paused:
				game.paused = false
				game.fire_armed = false
				game.sound.set_paused(false)
				return
		if game.title_screen or game.paused: return
		if event.is_action_pressed("weapon_next"): game.sub_weapon = (game.sub_weapon + 1) % 3
		if event.is_action_pressed("weapon_previous"): game.sub_weapon = (game.sub_weapon + 2) % 3
		if game.choosing and event.button_index == MOUSE_BUTTON_LEFT:
			var s: Vector2 = game.get_viewport_rect().size
			for i in range(3):
				if game.upgrade_card_rect(s, i).has_point(event.position):
					game.fire_armed = false
					game.upgrade(i)
					return
