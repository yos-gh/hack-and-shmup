extends SceneTree

# Hidden sound mode: the title emblem opens it, it lists every OGG in assets/music, picking a track drives the music
# selection, and Esc / BACK return to the title without starting a run.

const SoundMode = preload("res://scripts/sound_mode.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: " + message)
		failures += 1

func click(game, point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = point
	game._unhandled_input(event)

func run() -> void:
	var keys: Array = SoundMode.catalog().map(func(entry): return entry.key)
	var files: Array = []
	for file in DirAccess.get_files_at("res://assets/music"):
		if file.ends_with(".ogg"): files.append(file.get_basename())
	files.sort()
	var sorted := keys.duplicate()
	sorted.sort()
	check(sorted == files, "sound mode lists every BGM asset exactly once")
	check(SoundMode.display_name("stage_tresillo_rush") == "TRESILLO RUSH", "display names drop the category prefix")

	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var screen: Vector2 = game.get_viewport_rect().size
	var center: Vector2 = SoundMode.emblem_center(screen)
	click(game, center + Vector2(0, 40))
	check(game.title_screen and game.sound_mode.selecting, "clicking the title emblem opens sound mode")
	check(game.sound_mode.track == game.sound.music_lib.TITLE, "sound mode starts on the track already playing")
	game.menus.sync()
	var buttons: Array = game.menus._buttons()
	check(buttons.size() == keys.size() + 3, "one button per track plus back and the two settings")
	for i in range(keys.size()):
		var rect: Rect2 = game.sound_mode.button(screen, i)
		check(rect.position.x >= 0 and rect.end.x <= screen.x and rect.end.y < game.sound_mode.progress_rect(screen).position.y - 80, "track button fits above the now-playing caption: %d" % i)
	var unused: int = game.sound_mode.index_of(game.sound.music_lib.RESERVED.theme)
	buttons[unused].pressed.emit()
	check(game.sound_mode.track == game.sound.music_lib.RESERVED.theme, "an unused track can be picked")
	check(game.sound.music_lib.track_for(game) == game.sound.music_lib.RESERVED.theme, "music follows the picked track")
	click(game, Vector2(screen.x * 0.5, screen.y - 30))
	check(game.title_screen and game.sound_mode.selecting, "clicks inside sound mode never start a run")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	game._unhandled_input(escape)
	check(game.title_screen and not game.sound_mode.selecting, "Esc returns to the title")
	check(game.sound.music_lib.track_for(game) == game.sound.music_lib.TITLE, "the title track returns with the title")
	click(game, center + Vector2(0, 120))
	check(not game.title_screen, "a title click away from the emblem still starts a run")
	game.return_to_title()
	game.sound_mode.open(game)
	game.start_run()
	check(not game.sound_mode.selecting, "starting a run clears sound mode")
	if failures == 0: print("PASS: sound mode opens from the emblem, lists every track and returns to the title")
	quit(1 if failures else 0)
