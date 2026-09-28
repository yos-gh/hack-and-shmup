extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: "+message)
		failures += 1
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.depth_view.set_process(false)
	game.practice.variant = 2
	game.practice.depth = 50
	game.practice.start(game)
	game.discovered[1] = true
	var e: Dictionary = game.enemies[0]
	game.player = e.p+Vector2(-400,0)
	game.camera_pos = game.player
	var sound = game.sound
	var audio = sound.enemy_audio
	audio.set_process(false)
	audio.reset()
	game.boss.seraph.start_laser(game.boss,game,e,false)
	check(audio.pending.has("seraph_charge"),"charge sound starts at the laser warning")
	game.boss.advance_lasers(game,0.1)
	check(not sound.boss_beam_active and not sound.boss_beam.playing,"no sustained sound before discharge")
	audio._process(0.1)
	check(audio.voices[0].stream == sound.clips.seraph_charge and audio.voices[0].playing,"charge owns protected warning voice")
	for i in range(50): audio.request(game,"siege_fire",game.player)
	audio._process(0.1)
	check(audio.voices[0].stream == sound.clips.seraph_charge,"ordinary fire cannot steal the charge cue")
	var beam: Dictionary = game.boss.lasers[0]
	beam.warning = 0.01
	game.boss.advance_lasers(game,0.02)
	check(audio.pending.has("boss_release") and sound.boss_beam_active,"discharge transient and sustain begin at firing")
	check(sound.boss_beam.playing and sound.boss_beam.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD,"one dedicated loop voice is active")
	check(sound.boss_beam.stream.loop_end == 48000 and sound.boss_beam.stream.format == AudioStreamWAV.FORMAT_16_BITS,"loop spans exactly one uncompressed stereo second")
	audio.reset()
	for voice in sound.voices: voice.stop()
	sound._process(0.5)
	var capture := AudioEffectCapture.new()
	AudioServer.add_bus_effect(0,capture)
	await create_timer(0.15).timeout
	capture.clear_buffer()
	await create_timer(0.25).timeout
	var energy := 0.0
	var samples := capture.get_buffer(capture.get_frames_available())
	for sample in samples: energy += sample.length_squared()
	check(energy > 0.001,"sustained energy sound reaches the real stereo mixer")
	sound.set_paused(true)
	check(sound.boss_beam.stream_paused,"pause suspends the loop")
	sound.set_paused(false)
	check(not sound.boss_beam.stream_paused,"resume restores the beam voice")
	sound.set_audio_mode(2)
	check(not sound.boss_beam.playing and not sound.boss_beam_active,"OFF stops sustained audio immediately")
	sound.set_audio_mode(1)
	game.boss.advance_lasers(game,0.01)
	check(sound.boss_beam.playing and not sound.music.playing,"SE-only restores an active beam without BGM")
	beam.duration = 0.01
	game.boss.advance_lasers(game,0.02)
	sound._process(0.5)
	check(not sound.boss_beam.playing,"beam end releases and stops its voice")
	game.boss.seraph.start_laser(game.boss,game,e,false)
	game.boss.lasers[0].warning = 0
	game.boss.advance_lasers(game,0.01)
	game.restart_attempt()
	check(not sound.boss_beam.playing and not sound.boss_beam_active,"retry clears sustained audio")
	e = game.enemies[0]
	game.discovered[1] = true
	game.player = e.p+Vector2(-400,0)
	game.boss.seraph.start_laser(game.boss,game,e,false)
	game.boss.lasers[0].warning = 0
	game.boss.advance_lasers(game,0.01)
	game.grace = 0
	game.die()
	check(not sound.boss_beam.playing,"death stops the loop before retry")
	game.practice.variant = 1
	game.practice.start(game)
	game.discovered[1] = true
	e = game.enemies[0]
	game.player = e.p+Vector2(-310,0)
	game.camera_pos = game.player
	audio.reset()
	game.boss.bastion.launch_orb(game,e)
	check(audio.pending.has("boss_orb_charge"),"large energy orb has a charge cue")
	audio.reset()
	game.boss.bastion.launch_missile(game,e,false)
	check(audio.pending.has("boss_mark"),"missile landing marker has an advance cue")
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	game.free()
	if failures == 0: print("PASS: boss telegraphs, real sustained mixer output and pause/mute/retry/death lifecycle")
	quit(1 if failures else 0)
