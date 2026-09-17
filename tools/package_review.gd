extends SceneTree
## Run using Godot --main-pack exported.pck --script this absolute path; release templates ignore --script.
var destination := ""
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		push_error("FAIL: "+message)
		failures += 1
func capture(game, name: String) -> void:
	for i in range(15):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(destination+"/"+name+".png")
func click(point: Vector2) -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		root.push_input(event,true)
func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): destination = argument.trim_prefix("--output=")
	if destination.is_empty():
		printerr("An absolute --output directory is required")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(destination)
	check(not FileAccess.file_exists("res://tools/polish_review.gd"),"running exported PCK, not source project")
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	check(game.depth_enabled and game.view_pitch_degrees == 25,"packaged startup uses 3D")
	check(game.audio_mode == 1 and game.sound.audio_mode == 1,"packaged default is SE ONLY")
	check(game.font.get_font_name().contains("Rajdhani") and game.body_font.get_font_name().contains("Barlow"),"packaged font imports load")
	check(FileAccess.file_exists("res://assets/fonts/Barlow-OFL.txt"),"font notices are included in PCK")
	await capture(game,"title")
	click(Vector2(root.size.x*0.5,root.size.y*0.5+72))
	check(not game.title_screen,"exported START button accepts viewport input")
	for frame in range(90):
		game.replay_input = {"movement":Vector2.RIGHT,"aim":Vector2.RIGHT,"primary":frame>0,"secondary":false}
		game._physics_process(1.0/60)
		await process_frame
		await RenderingServer.frame_post_draw
	check(game.player != game.spawn_point,"packaged movement advances")
	await capture(game,"play")
	game.paused = true
	await capture(game,"pause")
	game.paused = false
	game.choosing = true
	game.choices.assign([0,1,2])
	await capture(game,"cards")
	var floor_before: int = game.floor_number
	click(game.upgrade_card_rect(Vector2(root.size),1).get_center())
	check(game.floor_number == floor_before+1 and not game.choosing,"packaged card input advances exactly one floor")
	game.practice.open(game)
	await capture(game,"practice")
	if failures == 0: print("PASS: exported Windows resources, 3D startup, fonts, actual button input, movement, menus, SE ONLY and font notices")
	game.free()
	quit(1 if failures else 0)
