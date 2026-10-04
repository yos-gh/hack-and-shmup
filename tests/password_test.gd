extends SceneTree
const RunPassword = preload("res://scripts/run_password.gd")
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: "+message)
		failures += 1
func key(game, code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	game._unhandled_input(event)
func floor_print(game) -> Array:
	return [game.floor_number,game.cells.size(),game.rooms.duplicate(),game.stairs,game.spawn_point,game.enemies.map(func(e): return [e.kind,e.p]),game.boss_floor,game.boss_variant if game.boss_floor else -1,game.time_limit,game.power,game.fire_rate,game.move_bonus,game.session.run.expansion,game.session.run.recharge,game.session.run.last_boss]
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var menus = game.menus

	# Climb past two boss floors with real card choices, sampling passwords.
	game.start_run()
	var samples: Array = []
	var picker := RandomNumberGenerator.new()
	picker.seed = 7
	while game.floor_number < 27:
		game.kills += 3
		if game.floor_number in [1,4,5,6,11,25,26]:
			game.sub_weapon = picker.randi_range(0,2)
			samples.append([RunPassword.encode(game.session.run),floor_print(game),game.sub_weapon,game.deaths,game.session.run.floor_kills])
		game.deaths += 1
		game.session.run.roll_choices(game.rng)
		game.choosing = true
		game.upgrade(picker.randi_range(0,game.choices.size()-1))
	for sample in samples:
		var password: String = sample[0]
		check(password.length() < 60 and password == password.to_upper(),"password stays short and upper-case: "+password)
		game.return_to_title()
		game.best_cleared = 0
		game.password_entry.open(game)
		game.password_entry.text = password.to_lower().replace("-"," ")
		game.password_entry.submit(game)
		check(not game.title_screen and not game.password_entry.selecting,"password resumes play")
		check(floor_print(game) == sample[1],"floor %d rebuilds identically" % sample[1][0])
		check(game.sub_weapon == sample[2] and game.deaths == sample[3] and game.kills == sample[4],"weapon, deaths and floor-start kills carry over")
		check(game.best_cleared == sample[1][0]-1,"record counts the floors behind the password")
		check(RunPassword.encode(game.session.run) == password,"a resumed floor shows the same password")

	# Tampering: every single-character change is rejected.
	var password: String = samples[-1][0]
	var rejected := 0
	var tried := 0
	for i in range(password.length()):
		if password[i] == "-": continue
		for replacement in ["0","7","K","Z"]:
			if replacement == password[i]: continue
			tried += 1
			if RunPassword.decode(password.substr(0,i)+replacement+password.substr(i+1)).has("error"): rejected += 1
	check(rejected == tried,"all %d one-character edits rejected (%d passed)" % [tried,tried-rejected])
	check(RunPassword.decode(password.substr(0,password.length()-1)).has("error"),"truncated password rejected")
	check(RunPassword.decode(password+"0").has("error"),"lengthened password rejected")
	check(RunPassword.decode("").has("error") and RunPassword.decode("HELLO WORLD!").has("error"),"junk rejected")

	# A well-formed password for an impossible run is rejected too.
	var forged = preload("res://scripts/run_state.gd").new()
	forged.floor_number = 40
	forged.upgrade_counts = {6:39}
	forged.floor_previous_boss = 1
	check(RunPassword.decode(RunPassword.encode(forged)).has("error"),"more expansion cards than the cap rejected")
	forged.upgrade_counts = {4:39}
	check(RunPassword.decode(RunPassword.encode(forged)).has("error"),"damage below the floor rejected")
	forged.upgrade_counts = {1:10}
	check(RunPassword.decode(RunPassword.encode(forged)).has("error"),"too few cards for the floor rejected")
	forged.upgrade_counts = {1:30,0:9}
	forged.floor_previous_boss = -1
	check(RunPassword.decode(RunPassword.encode(forged)).has("error"),"a deep floor without a previous boss rejected")
	forged.floor_previous_boss = 2
	check(not RunPassword.decode(RunPassword.encode(forged)).has("error"),"a legal floor-40 run accepted")
	forged.floor_number = 12345
	forged.upgrade_counts = {1:12344}
	check(RunPassword.decode(RunPassword.encode(forged)).floor_number == 12345,"endless floors encode")

	# Title CONTINUE replaces boss practice; bad input shows an error and stays.
	game.return_to_title()
	menus.sync()
	var buttons: Array = menus._buttons()
	check(buttons[1].text.begins_with("CONTINUE"),"title offers CONTINUE")
	buttons[1].pressed.emit()
	check(game.password_entry.selecting and menus._password_field() != null,"CONTINUE opens the password field")
	menus._password_field().text_changed.emit("NOT-A-PASSWORD")
	menus._password_field().text_submitted.emit("NOT-A-PASSWORD")
	check(game.password_entry.selecting and game.title_screen and game.password_entry.error == "INVALID PASSWORD","bad password stays on the screen")
	check(menus._password_field().text == "NOT-A-PASSWORD","typed text survives the error refresh")
	key(game,KEY_ESCAPE)
	check(game.title_screen and not game.password_entry.selecting,"Esc leaves CONTINUE for the title")
	key(game,KEY_C)
	check(game.password_entry.selecting,"C opens CONTINUE")
	game.return_to_title()

	# Pause shows the password and copies it on click; practice has none.
	game.start_run()
	game.paused = true
	menus.sync()
	buttons = menus._buttons()
	var shown: Button = buttons[-1]
	check(shown.text == RunPassword.encode(game.session.run),"pause shows the password")
	shown.pressed.emit()
	check(menus.password_copied and game.paused,"click copies without resuming")
	if DisplayServer.get_name() != "headless": check(DisplayServer.clipboard_get() == shown.text,"clipboard holds the password")
	game.paused = false
	menus.sync()
	check(not menus.password_copied,"copied notice clears after the pause")
	game.practice.depth = 10
	game.practice.start(game)
	game.paused = true
	menus.sync()
	check(menus._buttons().size() == 4,"practice pause shows no password")
	game.queue_free()
	await process_frame
	if failures == 0: print("PASS: resume passwords rebuild floors, reject edits, and drive pause and CONTINUE")
	quit(1 if failures else 0)
