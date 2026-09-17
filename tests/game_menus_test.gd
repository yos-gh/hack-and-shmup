extends SceneTree
var failures := 0
func _initialize(): call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: " + message)
		failures += 1
func run():
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var menus = game.menus
	menus.sync()
	var buttons: Array = menus.surface.get_children().filter(func(node): return node is Button)
	check(buttons.size() == 4, "title has start, practice, audio and fullscreen controls")
	buttons[2].grab_focus()
	buttons[2].pressed.emit()
	check(game.audio_mode == 2 and game.title_screen, "audio button does not start run")
	check(root.gui_get_focus_owner() != null and root.gui_get_focus_owner().text == "AUDIO: OFF", "refresh retains keyboard focus")
	buttons = menus.surface.get_children().filter(func(node): return node is Button)
	buttons[0].pressed.emit()
	check(not game.title_screen and not game.fire_armed, "start control suppresses firing")
	game.choosing = true
	game.choices.assign([0,1,2])
	menus.sync()
	check(menus.cards.size() == 3, "three resource-driven cards")
	for i in range(3):
		check(menus.cards[i].get_rect() == game.upgrade_card_rect(game.get_viewport_rect().size,i), "card and legacy pointer hit region agree")
	var depth: int = game.floor_number
	menus.cards[1].pressed.emit()
	menus.choose(1)
	check(game.floor_number == depth+1 and not game.choosing and not game.fire_armed, "card commits only once")
	game.choosing = true
	menus.sync()
	menus.cards[2].grab_focus()
	await process_frame
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	root.push_input(enter)
	var release := InputEventKey.new()
	release.keycode = KEY_ENTER
	root.push_input(release)
	check(game.floor_number == depth+2 and not game.choosing, "viewport Enter activates focused card exactly once")
	game.paused = true
	menus.sync()
	buttons = menus.surface.get_children().filter(func(node): return node is Button)
	buttons[0].pressed.emit()
	check(not game.paused and not game.fire_armed, "resume control preserves input gate")
	game.paused = true
	menus.sync()
	for width in [640,960,1280]:
		var screen := Vector2(width,720)
		for i in range(3):
			var rect: Rect2 = game.upgrade_card_rect(screen,i)
			check(rect.position.x >= 0 and rect.end.x <= width, "cards fit supported widths")
	game.practice.open(game)
	menus.sync()
	buttons = menus.surface.get_children().filter(func(node): return node is Button)
	check(buttons.size() == 7, "practice uses seven Control buttons")
	buttons[2].pressed.emit()
	check(game.practice.variant == 2, "boss button updates selected variant")
	menus.sync()
	buttons = menus.surface.get_children().filter(func(node): return node is Button)
	buttons[4].grab_focus()
	var up := InputEventKey.new()
	up.keycode = KEY_UP
	up.pressed = true
	root.push_input(up)
	check(game.practice.depth == 10, "focused control preserves practice arrow shortcut")
	# Exercise the viewport route while a button owns focus, not just the handler.
	for item in [[KEY_A,1,10],[KEY_D,2,10],[KEY_D,0,10],[KEY_A,2,10],[KEY_W,2,15],[KEY_S,2,10]]:
		var wasd := InputEventKey.new()
		wasd.keycode = item[0]
		wasd.pressed = true
		root.push_input(wasd)
		wasd = wasd.duplicate()
		wasd.pressed = false
		root.push_input(wasd)
		check(game.practice.variant == item[1] and game.practice.depth == item[2], "WASD selects once with GUI focus and wraps bosses")
	game.practice.depth = 100
	game.practice.activate(game,4)
	check(game.practice.depth == 100, "practice upper depth bound retained")
	game.practice.depth = 5
	game.practice.activate(game,3)
	check(game.practice.depth == 5, "practice lower depth bound retained")
	var record: int = game.best_cleared
	game.practice.activate(game,5)
	game.practice.activate(game,5)
	check(game.practice.active and not game.practice.selecting and game.boss_variant == 2 and game.floor_number == 5 and game.best_cleared == record, "practice start is guarded and preserves record")
	game.queue_free()
	await process_frame
	if failures == 0: print("PASS: Control menus, focus, resource cards, single transition and bounds")
	quit(1 if failures else 0)
