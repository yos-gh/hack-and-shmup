extends RefCounted

# The same screen-to-world conversion drives firing and presentation.
func pointer(game) -> Vector2:
	return game.replay_input.get("cursor", game.get_global_mouse_position())

func aim(game) -> Vector2:
	var direction: Vector2 = (pointer(game) - game.get_viewport_rect().size * 0.5 + game.camera_pos - game.player).normalized()
	return game.replay_input.get("aim", direction)

func movement(game) -> Vector2:
	var direction := Vector2(Input.get_axis("move_left","move_right"), Input.get_axis("move_up","move_down"))
	return game.replay_input.get("movement", direction)

func primary(game) -> bool:
	return game.replay_input.get("primary", Input.is_action_pressed("fire_primary"))

func secondary(game) -> bool:
	return game.replay_input.get("secondary", Input.is_action_pressed("fire_secondary"))

# Event routing keeps the original context priority and one-shot semantics.
func handle_event(game, event: InputEvent) -> void:
	if game.view_comparison and event is InputEventKey and event.pressed and not event.echo and event.is_action_pressed("compare_view"):
		game.set_depth_view(not game.depth_enabled)
		return
	if game.practice.selecting:
		game.practice.input(game,event)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("cycle_audio"):
			game.cycle_audio()
			return
		if game.title_screen:
			if event.is_action_pressed("confirm"): game.start_run()
			elif event.is_action_pressed("boss_practice"): game.practice.open(game)
			elif event.is_action_pressed("back") and not OS.has_feature("web"): game.get_tree().quit()
			return
		if game.practice.active and event.is_action_pressed("boss_practice"):
			game.practice.open(game)
			return
		if game.practice.active and event.is_action_pressed("retry_attempt"):
			game.restart_attempt()
			return
		if event.is_action_pressed("back"):
			if game.paused: game.return_to_title()
			else: game.paused = true
			return
		if game.paused: return
		if event.is_action_pressed("weapon_previous"): game.sub_weapon = (game.sub_weapon + 2) % 3
		if event.is_action_pressed("weapon_next"): game.sub_weapon = (game.sub_weapon + 1) % 3
		if game.choosing:
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
