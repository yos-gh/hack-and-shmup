extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: "+message)
		failures += 1
func key(game, code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	game._unhandled_input(event)
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.return_to_title()
	game.best_cleared = 10
	key(game,KEY_B)
	check(game.practice.selecting and game.title_screen, "B opens selector")
	key(game,KEY_3)
	key(game,KEY_UP)
	key(game,KEY_UP)
	key(game,KEY_ENTER)
	check(game.practice.active and not game.title_screen and game.floor_number == 15 and game.boss_variant == 2, "selected boss and floor launch")
	check(is_equal_approx(game.power,2.45) and is_equal_approx(game.fire_rate,1.6) and is_equal_approx(game.move_bonus,60.0), "fourteen balanced upgrades applied")
	check(is_equal_approx(game.session.run.expansion,0.2) and is_equal_approx(game.session.run.recharge,0.2), "practice includes both sub upgrades")
	check(is_equal_approx(game.LANCE_WIDTH,54.6) and is_equal_approx(game.session.run.sub_cooldown(2),1.7/1.2), "practice sub geometry and cooldown are effective")
	game.enemies[0].hp = 1
	key(game,KEY_R)
	check(game.enemies == game.initial_enemies, "R retries chosen encounter")
	for e in game.enemies: e.hp = 0
	game.grace = 999
	game.player = game.stairs
	game._physics_process(0.016)
	check(game.practice.selecting and game.best_cleared == 10 and not game.choosing, "practice clear returns selector without changing record")
	key(game,KEY_ESCAPE)
	check(game.title_screen and not game.practice.selecting, "escape returns to title without quitting")
	key(game,KEY_ENTER)
	check(not game.practice.active and game.floor_number == 1 and game.power == 1, "normal run resets debug loadout")
	game.return_to_title()
	key(game,KEY_B)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = game.practice.button(game.get_viewport_rect().size,0).get_center()
	game._unhandled_input(click)
	check(game.practice.variant == 0 and game.practice.selecting, "mouse selects without starting")
	for depth in [5,30,45,50,100]:
		game.practice.depth = depth
		game.practice.start(game)
		var cards := 0
		for count in game.session.run.upgrade_counts.values(): cards += count
		check(cards == depth-1,"practice never loses capped cards or grants extra cards")
		if depth >= 30:
			check(is_equal_approx(game.session.run.expansion,0.5) and is_equal_approx(game.session.run.recharge,0.5),"high-floor practice caps both sub upgrades")
			check(is_equal_approx(game.LANCE_WIDTH,78.0),"high-floor practice has double lance width")
		game.restart_attempt()
		check(game.session.run.upgrade_counts.values().reduce(func(total,count): return total+count,0) == depth-1,"retry retains practice build")
	game.practice.depth = 100
	game.practice.start(game)
	check(is_equal_approx(game.SPEED+game.move_bonus,635.0),"practice MOVE SPEED stops at 635")
	check(is_equal_approx(game.power,14.8) and is_equal_approx(game.fire_rate,7.2),"speed beyond the cap becomes damage and fire rate")
	if failures == 0: print("PASS: debug input, upgrades, retry and record isolation")
	game.free()
	quit(1 if failures else 0)
