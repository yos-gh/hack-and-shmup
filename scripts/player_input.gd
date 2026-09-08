extends RefCounted

# The same screen-to-world conversion drives firing and presentation.
func pointer(game) -> Vector2:
	return game.replay_input.get("cursor", game.get_global_mouse_position())

func aim(game) -> Vector2:
	var direction: Vector2 = (pointer(game) - game.get_viewport_rect().size * 0.5 + game.camera_pos - game.player).normalized()
	return game.replay_input.get("aim", direction)

func movement(game) -> Vector2:
	var direction := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	return game.replay_input.get("movement", direction)

func primary(game) -> bool:
	return game.replay_input.get("primary", Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))

func secondary(game) -> bool:
	return game.replay_input.get("secondary", Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT))
