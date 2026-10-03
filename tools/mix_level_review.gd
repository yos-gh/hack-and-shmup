extends SceneTree
## Record the real mixer output (Master bus) in a few representative moments with sound ON, for loudness checks:
## title music, stage music under sustained fire and kills, a boss fight with its attacks, and the loud one-shots
## (death, boss destruction) over music. Writes docs/validation/mix-<scene>.wav; measure them with
## `ffmpeg -i <file> -af ebur128=peak=true -f null -`. Runs in real time. `--audio-driver Dummy` keeps it silent.
var capture := AudioEffectCapture.new()

func _initialize() -> void: call_deferred("run")

func save_mix(samples: PackedVector2Array, name: String) -> void:
	var pcm := PackedByteArray()
	pcm.resize(samples.size()*4)
	var peak := 0.0
	for i in range(samples.size()):
		peak = maxf(peak,maxf(absf(samples[i].x),absf(samples[i].y)))
		pcm.encode_s16(i*4,roundi(clampf(samples[i].x,-1,1)*32767))
		pcm.encode_s16(i*4+2,roundi(clampf(samples[i].y,-1,1)*32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = true
	stream.mix_rate = int(AudioServer.get_mix_rate())
	stream.data = pcm
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/validation"))
	stream.save_to_wav("res://docs/validation/mix-%s.wav" % name)
	print("MIX %s: %.2fs peak %.3f" % [name,float(samples.size())/stream.mix_rate,peak])

func record(game, seconds: float, each_frame: Callable) -> PackedVector2Array:
	capture.clear_buffer()
	var samples := PackedVector2Array()
	var frames := int(seconds*60)
	for frame in range(frames):
		each_frame.call(frame)
		game._physics_process(1.0/60)
		await create_timer(1.0/60).timeout
		samples.append_array(capture.get_buffer(capture.get_frames_available()))
	return samples

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	capture.buffer_length = 1.0
	AudioServer.add_bus_effect(0,capture)
	game.sound.set_audio_on(true)
	# Title music.
	save_mix(await record(game, 8.0, func(_f): pass), "title")
	# A normal floor: its stage track under constant primary fire, a kill every half second, hits in between.
	game.start_run()
	game.grace = 1000
	save_mix(await record(game, 12.0, func(f):
		game.grace = 1000
		game.time_left = game.time_limit
		game.replay_input = {"movement":Vector2.ZERO,"aim":Vector2.RIGHT,"primary":true,"secondary":f%120 < 2}
		if f%30 == 0: game.sound.play_sfx("kill")
		elif f%10 == 5: game.sound.play_sfx("hit")), "stage")
	# A boss fight: Triad at depth 50, firing at it while its laser and attacks run.
	game.practice.variant = 2
	game.practice.depth = 50
	game.practice.start(game)
	game.discovered[1] = true
	var e: Dictionary = game.enemies[0]
	game.player = e.p+Vector2(-370,0)
	game.camera_pos = game.player
	e.active = true
	game.build_flow()
	e.laser_cd = 30
	game.boss.triad.start_laser(game.boss,game,e,false)
	save_mix(await record(game, 12.0, func(f):
		game.paused = false
		game.grace = 2
		e.hp = e.max_hp
		var firing: bool = f%180 < 120
		game.replay_input = {"movement":Vector2.ZERO,"aim":game.player.direction_to(e.p),"primary":firing,"secondary":firing and f%60 == 0}), "boss")
	game.sound.stop_boss_beam()
	# Loud one-shots over the boss music: death, then the boss destruction.
	save_mix(await record(game, 6.0, func(f):
		game.grace = 2
		e.hp = e.max_hp
		game.replay_input = {"movement":Vector2.ZERO,"aim":Vector2.RIGHT,"primary":false,"secondary":false}
		if f == 10: game.sound.play_sfx("death")
		if f == 190: game.sound.play_sfx("boss_destroy")), "events")
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	game.free()
	print("PASS: mix levels recorded")
	quit()
