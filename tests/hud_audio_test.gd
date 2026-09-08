extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: " + message)
		failures += 1

func run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("HUD/audio test requires a display and audio driver")
		quit(2)
		return
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var sound = game.sound
	sound.set_audio_mode(1)
	for i in range(20): sound.play_sfx("shock")
	check(not sound.voices[0].playing and not sound.voices[1].playing, "ordinary effects cannot occupy reserved alert slots")
	sound.play_sfx("warning")
	check(sound.voices[1].playing and sound.voices[1].stream == sound.clips.warning, "warning plays even with all ordinary slots full")
	sound.play_sfx("death")
	check(sound.voices[0].playing and not sound.voices[1].playing, "death replaces warning and takes reserved slot")
	sound.play_sfx("clear")
	check(sound.voices[0].stream == sound.clips.death, "clear cannot interrupt death")
	sound.play_sfx("shot")
	check(sound.voices[2].volume_db == -11, "new shots are quieter under critical feedback")
	sound.set_audio_mode(2)
	check(not sound.voices.any(func(voice: AudioStreamPlayer) -> bool: return voice.playing), "mute stops every reserved and ordinary voice")
	sound.reset_time_warning()
	check(not sound.update_time_warning(5.1), "no warning above five seconds")
	check(sound.update_time_warning(5.0), "first warning at five seconds")
	check(not sound.update_time_warning(4.9), "no repeated warning within a second")
	check(not sound.update_time_warning(6.0) and not sound.update_time_warning(4.8), "kill time bonus cannot repeat an already warned threshold")
	check(sound.update_time_warning(3.9), "next threshold warns")
	check(sound.update_time_warning(1.9) and not sound.update_time_warning(0), "skipped threshold does not burst multiple warnings; zero uses timeout")
	game.start_run()
	for weapon in range(3):
		game.sub_weapon = weapon
		game.fire_sub(Vector2.LEFT)
		check(game.sub_cd == game.SUB_COOLDOWNS[weapon], "weapon cooldown unchanged")
		check(game.hud.cooldown_fraction(game) == 0.0, "bar starts empty")
		game.sub_cd *= 0.5
		check(is_equal_approx(game.hud.cooldown_fraction(game),0.5), "bar reflects elapsed half cooldown")
		game.sub_weapon = (weapon+1)%3
		check(is_equal_approx(game.hud.cooldown_fraction(game),0.5), "switching weapon does not change cooldown progress")
	game.restart_attempt()
	check(game.hud.cooldown_fraction(game) == 1.0 and sound.warning_step == 6, "retry resets HUD and time warning")
	game.time_left = 4.9
	game.paused = true
	game._physics_process(1.0/60)
	check(sound.warning_step == 6, "pause does not request warnings")
	game.paused = false
	game.boss_floor = true
	game._physics_process(1.0/60)
	check(sound.warning_step == 6, "boss has no timer warning")
	game.boss_floor = false
	game._physics_process(1.0/60)
	check(sound.warning_step == 5, "normal gameplay requests low-time feedback")
	for width in [640,800,960,1280,1920]:
		var layout: Dictionary = game.hud.hud_layout(Vector2(width,800))
		check(layout.weapon.size.x > 100 and layout.weapon.position.x >= 240, "weapon column fits beside floor stats")
		check(layout.weapon.end.x < layout.timer.position.x and layout.timer.end.x <= width, "timer and weapon do not overlap")
		if layout.map.size.x > 0: check(layout.timer.end.x < layout.map.position.x and layout.map.end.x <= width, "minimap stays separate")
	game.free()
	if failures == 0: print("PASS: HUD cooldown/switching/layout and audio saturation/priority/mute/timer/retry")
	quit(1 if failures else 0)
