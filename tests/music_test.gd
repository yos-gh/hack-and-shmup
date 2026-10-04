extends SceneTree

# Background music: every track loads as a looping OGG with its loop point, the screen picks the right track,
# a floor keeps its track through retries, consecutive floors never repeat a song, and consecutive boss floors
# never repeat a boss.

const Music = preload("res://scripts/music.gd")
const Generator = preload("res://scripts/floor_generator.gd")
const Settings = preload("res://scripts/floor_settings.gd")

var failures := 0

class FakeGame:
	var title_screen := false
	var choosing := false
	var boss_floor := false
	var stairs_unlocked := false
	var boss_variant := 0
	var floor_revision := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: " + message)
		failures += 1

func run() -> void:
	check_tracks()
	check_selection()
	check_boss_generation()
	check_game_wiring()
	if failures == 0: print("PASS: music tracks, loop points, per-floor selection without repeats, retry continuity and boss rotation")
	quit(1 if failures else 0)

func check_tracks() -> void:
	var keys: Array = Music.STAGE + Music.BOSS + [Music.WYRM_SECOND, Music.TITLE, Music.CARDS, Music.COOLING] + Music.RESERVED.values()
	check(keys.size() == Music.LOOP_OFFSETS.size(), "every track has exactly one loop point")
	for key in keys:
		var stream: AudioStreamOggVorbis = Music.stream(key)
		check(stream != null, "track loads: " + key)
		if stream == null: continue
		var plain: AudioStreamOggVorbis = load(Music.DIR + key + ".ogg")
		check(plain.loop and is_equal_approx(plain.loop_offset, Music.LOOP_OFFSETS[key]), "import settings carry the loop point: " + key)
		check(stream.get_length() > 30.0 and stream.loop_offset < stream.get_length() - 20.0, "loop point lies well inside the track: " + key)

func check_selection() -> void:
	var music = Music.new()
	music.rng.seed = 7
	var game := FakeGame.new()
	game.title_screen = true
	check(music.track_for(game) == Music.TITLE, "title screen plays the title track")
	game.title_screen = false
	game.choosing = true
	check(music.track_for(game) == Music.CARDS, "card select plays the intermission")
	game.choosing = false
	game.boss_floor = true
	for variant in range(3):
		game.boss_variant = variant
		check(music.track_for(game) == Music.BOSS[variant], "each boss has its own track")
	game.stairs_unlocked = true
	check(music.track_for(game) == Music.COOLING, "a defeated boss gives way to the cooling loop until the stairs")
	game.stairs_unlocked = false
	game.boss_floor = false
	var previous := ""
	var block: Dictionary = {}
	for floor_index in range(14 * 6):
		game.floor_revision += 1
		var track: String = music.track_for(game)
		check(track in Music.STAGE, "normal floors play stage tracks")
		check(track != previous, "the same song never plays on two floors in a row")
		for retry in range(3): check(music.track_for(game) == track, "a retry keeps the floor's track")
		block[track] = true
		if floor_index % 14 == 13:
			check(block.size() == Music.STAGE.size(), "every stage track plays once before any repeats")
			block.clear()
		previous = track

func check_boss_generation() -> void:
	var generator = Generator.new()
	for previous in range(3):
		var seen: Dictionary = {}
		for seed_value in range(60):
			var settings := Settings.new()
			settings.depth = 10
			settings.previous_boss = previous
			var data = generator.generate(settings, seed_value)
			check(data.boss_variant != previous, "a seeded boss pick avoids the previous boss %d" % previous)
			seen[data.boss_variant] = true
		check(seen.size() == 2, "both other bosses remain possible after boss %d" % previous)
	var first: Dictionary = {}
	for seed_value in range(60):
		var settings := Settings.new()
		settings.depth = 5
		first[generator.generate(settings, seed_value).boss_variant] = true
	check(first.size() == 3, "the first boss of a run can be any boss")
	var after_wyrm: Dictionary = {}
	for seed_value in range(60):
		var settings := Settings.new()
		settings.depth = 30
		settings.previous_boss = 3
		after_wyrm[generator.generate(settings, seed_value).boss_variant] = true
		settings.depth = 50
		check(generator.generate(settings, seed_value).boss_variant == 3, "every 25th floor is the Abyss Wyrm")
	check(after_wyrm.size() == 3 and not after_wyrm.has(3), "after the Abyss Wyrm any regular boss can follow")
	var forced := Settings.new()
	forced.depth = 15
	forced.boss_choice = 1
	forced.previous_boss = 1
	check(generator.generate(forced, 3).boss_variant == 1, "an explicit boss choice (practice) is kept")

func check_game_wiring() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.sound.update_music(game)
	check(game.sound.music_key == Music.TITLE, "startup shows the title track")
	game.start_run()
	game.sound.update_music(game)
	var stage_track: String = game.sound.music_key
	check(stage_track in Music.STAGE, "a run starts on a stage track")
	game.grace = 0
	game.die()
	game.restart_attempt()
	game.sound.update_music(game)
	check(game.sound.music_key == stage_track, "the track keeps playing through a miss and retry")
	game.choosing = true
	game.sound.update_music(game)
	check(game.sound.music_key == Music.CARDS, "the card screen switches to the intermission")
	game.choosing = false
	var previous_boss := -1
	var bosses := 0
	for depth in range(2, 61):
		game.floor_number = depth
		game.new_floor()
		game.sound.update_music(game)
		if game.boss_floor:
			bosses += 1
			check(game.sound.music_key == Music.BOSS[game.boss_variant], "boss floors play their boss's track")
			game.stairs_unlocked = true
			game.sound.update_music(game)
			check(game.sound.music_key == Music.COOLING, "the cooling loop follows the boss's defeat")
			check(game.boss_variant != previous_boss, "consecutive boss floors bring a different boss")
			previous_boss = game.boss_variant
		else:
			check(game.sound.music_key != stage_track, "a new floor changes the stage track")
			stage_track = game.sound.music_key
	check(bosses == 12, "twelve boss floors visited")
	game.return_to_title()
	game.sound.update_music(game)
	check(game.sound.music_key == Music.TITLE, "returning to the title restores the title track")
	game.free()
