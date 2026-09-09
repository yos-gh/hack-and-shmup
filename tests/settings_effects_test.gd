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
	var sound = game.sound
	var menu = game.settings_menu
	menu.open()
	check(menu.panel.visible and game.title_screen, "title settings open without starting run")
	await process_frame
	await process_frame
	check(menu.footer.get_global_rect().end.y <= menu.panel.size.y, "footer stays within viewport")
	check(menu.footer.position.y >= menu.scroll.position.y + menu.scroll.size.y, "footer stays outside scrolling content")
	menu.binding_buttons.weapon_next.grab_focus()
	await process_frame
	await process_frame
	check(menu.scroll.scroll_vertical > 0, "keyboard focus reveals lower settings")
	menu.waiting_action = "move_left"
	var remap := InputEventKey.new()
	remap.keycode = KEY_J
	remap.physical_keycode = KEY_J
	remap.pressed = true
	remap.ctrl_pressed = true
	menu.handle_event(remap)
	check(not game.preferences.bindings.has("move_left") and menu.waiting_action == "move_left", "modified shortcut is not silently saved as a plain key")
	remap.ctrl_pressed = false
	menu.handle_event(remap)
	check(menu.binding_buttons.move_left.has_focus(), "rebind retains focus on edited action")
	game.preferences.reset()
	game.apply_preferences()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	menu.waiting_action = "move_left"
	game.controls.handle_event(game,escape)
	check(menu.waiting_action.is_empty() and menu.panel.visible, "escape cancels rebinding before closing menu")
	game.controls.handle_event(game,escape)
	check(not menu.panel.visible and game.title_screen, "escape closes settings without exiting title")
	game.start_run()
	menu.open()
	check(not menu.panel.visible, "settings cannot open during combat")
	game.paused = true
	menu.open()
	var before_time: float = game.time_left
	game._physics_process(0.5)
	check(game.time_left == before_time and menu.panel.visible, "paused settings freeze combat")
	game.controls.handle_event(game,escape)
	check(game.paused and not menu.panel.visible and not game.fire_armed, "closing settings preserves pause and prevents firing")
	var snapshot: PackedByteArray = var_to_bytes([game.player, game.enemies, game.time_left, game.rng.state, game.session.run.floor_number])
	game.preferences.master_volume = 0.5
	game.preferences.music_volume = 0.5
	game.preferences.effects_volume = 0.25
	game.preferences.reduce_flash = true
	game.apply_preferences()
	check(is_equal_approx(sound.music.volume_db, -10 + linear_to_db(0.25)), "master and music volume compose")
	check(is_equal_approx(sound.voices[0].volume_db, -5 + linear_to_db(0.125)), "master and effect volume compose")
	sound._set_voice_level(2, -11)
	sound.set_levels(1,1,1)
	check(sound.voices[2].volume_db == -11, "live volume changes retain critical ducking")
	sound.set_audio_mode(1)
	sound.set_levels(0.5,0.5,0.5)
	check(sound.music.volume_db == -80, "volume editing does not undo SE-only mode")
	sound.set_audio_mode(0)
	check(is_equal_approx(sound.music.volume_db,-10 + linear_to_db(0.25)), "music mode restores selected volume")
	sound.set_levels(0,1,1)
	check(sound.music.volume_linear == 0 and sound.voices[0].volume_linear == 0, "zero master is silent")
	sound.set_levels(NAN,INF,-1)
	check(sound.master_gain == 1 and sound.music_gain == 1 and sound.effects_gain == 0, "invalid direct gains sanitized")
	check(snapshot == var_to_bytes([game.player, game.enemies, game.time_left, game.rng.state, game.session.run.floor_number]), "preferences do not mutate combat or RNG")
	game.preferences.reset()
	game.apply_preferences()
	check(sound.music.volume_db == -10 and sound.voices[0].volume_db == -5, "default levels retain original mix")
	menu.storage_path = "user://settings-menu-test-%d.json" % OS.get_process_id()
	menu.open()
	game.preferences.music_volume = 0.3
	menu._save()
	check(menu.status.text.begins_with("Saved"), "menu save reports success")
	game.preferences.reset()
	current_scene = game
	menu._load_main_preferences()
	check(is_equal_approx(game.preferences.music_volume,0.3) and is_equal_approx(sound.music.volume_db,-10 + linear_to_db(0.3)), "main scene restores and applies saved preferences")
	current_scene = null
	DirAccess.remove_absolute(menu.storage_path)
	game.queue_free()
	await process_frame
	if failures == 0: print("PASS: settings audio levels, mute modes, ducking and combat isolation")
	quit(1 if failures else 0)
