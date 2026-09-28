extends SceneTree
## Record the real native SE-only mixer, including normal weapon masking.
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
	stream.save_to_wav("res://docs/validation/%s.wav" % name)
	print("MIX %s: %.2fs peak %.3f" % [name,float(samples.size())/stream.mix_rate,peak])
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.depth_view.set_process(false)
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 1.0
	AudioServer.add_bus_effect(0,capture)
	for variant in [2,1]:
		game.practice.variant = variant
		game.practice.depth = 50
		game.practice.start(game)
		game.discovered[1] = true
		var e: Dictionary = game.enemies[0]
		game.player = e.p+Vector2(-370,0)
		game.camera_pos = game.player
		game.sub_weapon = 0
		game.banner = 0
		e.active = true
		game.build_flow()
		capture.clear_buffer()
		var samples := PackedVector2Array()
		if variant == 2:
			e.laser_cd = 30
			game.boss.seraph.start_laser(game.boss,game,e,false)
		else:
			e.cd = 30
			game.boss.bastion.launch_orb(game,e)
		for frame in range(690 if variant == 2 else 240):
			game.paused = false
			game.grace = 2
			e.hp = e.max_hp
			if variant == 1 and frame == 140: game.boss.bastion.launch_missile(game,e,false)
			var firing: bool = frame > 0 and frame%180 < 45
			game.replay_input = {"movement":Vector2.ZERO,"aim":game.player.direction_to(e.p),"primary":firing,"secondary":firing}
			game._physics_process(1.0/60)
			await create_timer(1.0/60).timeout
			samples.append_array(capture.get_buffer(capture.get_frames_available()))
		game.sound.stop_boss_beam()
		save_mix(samples,"seraph-laser-mix" if variant == 2 else "bastion-heavy-mix")
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	game.free()
	print("PASS: native boss SE-only mixes recorded")
	quit()
