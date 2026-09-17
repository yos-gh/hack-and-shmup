extends SceneTree

const Scenario = preload("res://tools/dev_scenario.gd")
const ReviewSound = preload("res://tools/audio/review_sound.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var automatic := "--capture" in OS.get_cmdline_user_args()
	var smoke := "--smoke" in OS.get_cmdline_user_args()
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.remove_child(game.sound)
	game.sound.queue_free()
	game.sound = ReviewSound.new()
	game.add_child(game.sound)
	game.audio_mode = 0
	game.combat_events.enemy_hit.connect(game.sound.hear_hit)
	game.set_view_pitch(25.0)
	game.set_depth_view(true)
	if not automatic and not smoke:
		print("REVIEW: 48-second music excerpt and eight new effects; other sounds are placeholders")
		return
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	var frames := 90 if smoke else 2880
	for frame in range(frames):
		if frame % 720 == 0:
			var section := frame / 720
			Scenario.configure(game, "hunter15" if section == 3 else "normal19", 19045, section % 3)
		Scenario.input_frame(game, frame)
		# Demonstrate an actual death/retry without stopping the music.
		if frame == 1260:
			game.grace = 0.0
			game.die()
		game._physics_process(1.0 / 60.0)
		await process_frame
	print("PASS: review playback and combat capture completed")
	game.free()
	quit()
