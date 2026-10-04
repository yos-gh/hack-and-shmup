extends SceneTree

# Saves the menu screens as PNGs for layout review: title, upgrade cards, pause
# with its resume password, CONTINUE and the sound mode.
# Godot_console.exe --path . --script res://tools/menu_capture.gd -- --output=res://docs/validation
# Needs a display renderer (not --headless).

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var output := "res://docs/validation"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await shoot(game, output + "/menu-title.png")
	game.start_run()
	game.choosing = true
	game.choices.assign([0, 5, 2])
	await shoot(game, output + "/menu-cards.png")
	game.choices.assign([3, 6, 7])
	await shoot(game, output + "/menu-cards-2.png")
	game.choosing = false
	game.paused = true
	await shoot(game, output + "/menu-pause.png")
	game.password_entry.open(game)
	game.password_entry.text = "BAD-PASSWORD"
	game.password_entry.error = "INVALID PASSWORD"
	await shoot(game, output + "/menu-continue.png")
	game.return_to_title()
	if game.get("sound_mode") == null:
		quit(0)
		return
	game.sound_mode.open(game)
	game.sound_mode.choose(game, 4)
	await shoot(game, output + "/menu-sound.png")
	quit(0)

func shoot(game, path: String) -> void:
	game.menus.sync()
	for i in range(20): await process_frame
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(path) != OK: printerr("Cannot save capture: ", path)
	else: print("Saved ", path)
