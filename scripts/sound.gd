extends Node

var enemy_audio = preload("res://scripts/enemy_audio.gd").new()

var music := AudioStreamPlayer.new()
var voices: Array[AudioStreamPlayer] = []
var clips: Dictionary = {}
var audio_mode := 1
var headless := false
var paused_state := false
var warning_step := 6
var critical_priority := 0
var hit_gap := 0.0
var burst_gaps: Dictionary = {}
var effects_bus_name := ""
var boss_beam := AudioStreamPlayer2D.new()
var boss_beam_active := false
var boss_beam_level := -60.0
const CRITICAL_PRIORITIES := {"boss_destroy": 1, "clear": 2, "death": 3, "timeout": 3}

func _ready() -> void:
	headless = DisplayServer.get_name() == "headless"
	effects_bus_name = "GameEffects_%s" % get_instance_id()
	AudioServer.add_bus()
	var bus_index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus_index, effects_bus_name)
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -2.5
	limiter.pre_gain_db = -2.0
	AudioServer.add_bus_effect(bus_index, limiter)
	for key in ["shot","scatter","shock","lance","hit","shield","kill","death","clear","timeout","warning","siege_fire","hunter_lock","hunter_fire","sniper_fire","halo_fire","seraph_charge","seraph_beam","boss_orb_charge","boss_mark","boss_release"]:
		clips[key] = load("res://assets/audio/" + key + ".wav")
	clips["boss_destroy"] = load("res://assets/audio/boss_destroy.wav")
	music.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(music)
	var loop: AudioStreamWAV = load("res://assets/audio/descent.wav").duplicate()
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = int(round(loop.get_length() * loop.mix_rate))
	music.stream = loop
	_refresh_music_level()
	for i in range(12):
		var voice := AudioStreamPlayer.new()
		voice.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		voice.bus = effects_bus_name
		add_child(voice)
		voice.volume_db = -5
		voices.append(voice)
	add_child(enemy_audio)
	for voice in enemy_audio.voices: voice.bus = effects_bus_name
	# A dedicated, bounded voice follows beam state, never the general shot pool.
	var beam_loop: AudioStreamWAV = clips.seraph_beam.duplicate()
	beam_loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	beam_loop.loop_begin = 0
	beam_loop.loop_end = beam_loop.data.size()/4 # Stereo 16-bit PCM frames.
	boss_beam.stream = beam_loop
	boss_beam.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	boss_beam.bus = effects_bus_name
	boss_beam.max_distance = 2000
	boss_beam.attenuation = 0
	boss_beam.panning_strength = 0.25
	add_child(boss_beam)
	_refresh_music_level()

func _process(delta: float) -> void:
	hit_gap = maxf(0, hit_gap - delta)
	for key in burst_gaps: burst_gaps[key] = maxf(0, burst_gaps[key] - delta)
	if paused_state: return
	var target: float = -16.0 if boss_beam_active else -60.0
	if boss_beam_active and enemy_audio.voices[0].playing: target -= 6
	boss_beam_level = move_toward(boss_beam_level,target,180*delta)
	boss_beam.volume_db = boss_beam_level
	if not boss_beam_active and boss_beam_level <= -60: boss_beam.stop()

func set_boss_beam(game, active: bool, point: Vector2 = Vector2.ZERO) -> void:
	boss_beam_active = active and audio_mode != 2 and not game.pending_respawn and not game.title_screen
	if not boss_beam_active: return
	boss_beam.position = game.world_to_screen(point)
	if not headless and not boss_beam.playing:
		boss_beam.volume_db = -60
		boss_beam_level = -60
		boss_beam.play()
		boss_beam.stream_paused = paused_state

func stop_boss_beam() -> void:
	boss_beam_active = false
	boss_beam_level = -60
	boss_beam.stop()

func hear_hit(_position: Vector2, _damage: float, blocked: bool, killed: bool) -> void:
	if blocked or killed or hit_gap > 0 or paused_state: return
	hit_gap = 0.055
	play_sfx("hit")

func hear_boss_destroyed(_position: Vector2, _color: Color) -> void:
	play_sfx("boss_destroy")

func stop_boss_destruction() -> void:
	if voices[0].stream == clips.boss_destroy: voices[0].stop()

func _exit_tree() -> void:
	var bus_index := AudioServer.get_bus_index(effects_bus_name)
	if bus_index > 0: AudioServer.remove_bus(bus_index)

func play_sfx(key: String) -> void:
	if audio_mode == 2 or headless: return
	if key in ["kill", "shield"]:
		if burst_gaps.get(key, 0.0) > 0: return
		burst_gaps[key] = 0.045
	if CRITICAL_PRIORITIES.has(key):
		var priority: int = CRITICAL_PRIORITIES[key]
		if voices[0].playing and priority < critical_priority: return
		critical_priority = priority
		stop_boss_beam()
		enemy_audio.reset()
		for voice in voices: voice.stop()
		_set_voice_level(0, -5)
		voices[0].stream = clips[key]
		voices[0].play()
		return
	if key == "warning":
		if voices[0].playing: return
		_set_voice_level(1, -5)
		voices[1].stream = clips[key]
		voices[1].play()
		return
	# Slots 0/1 are reserved; repeated shots cannot exhaust or replace alerts.
	for i in range(2,voices.size()):
		var voice := voices[i]
		if not voice.playing:
			_set_voice_level(i, -11 if voices[0].playing else -5)
			voice.stream = clips[key]
			voice.play()
			return

func reset_time_warning() -> void:
	warning_step = 6

func update_time_warning(seconds_left: float) -> bool:
	var step := ceili(seconds_left)
	if step < 1 or step > 5 or step >= warning_step: return false
	warning_step = step
	play_sfx("warning")
	return true

func set_paused(value: bool) -> void:
	# Web Sample playback restarts on every unpause call, even when already running.
	# Apply transitions only; game physics may request the same state every frame.
	if value == paused_state: return
	paused_state = value
	enemy_audio.set_paused(value)
	music.stream_paused = value
	for voice in voices: voice.stream_paused = value
	boss_beam.stream_paused = value

func set_audio_mode(value: int) -> void:
	audio_mode = posmod(value,3)
	enemy_audio.muted = audio_mode == 2
	if enemy_audio.muted: enemy_audio.reset()
	_refresh_music_level()
	if audio_mode == 2:
		stop_boss_beam()
		for voice in voices: voice.stop()

func _refresh_music_level() -> void:
	music.volume_db = -10 if audio_mode == 0 else -80
	# Muting alone still decodes and mixes the looping track on Web.
	if audio_mode != 0:
		music.stop()
	elif not headless and music.is_inside_tree() and not music.playing:
		music.play()
		music.stream_paused = paused_state

func _set_voice_level(index: int, baseline: float) -> void:
	voices[index].volume_db = baseline
