extends Node

var music := AudioStreamPlayer.new()
var voices: Array[AudioStreamPlayer] = []
var clips: Dictionary = {}
var audio_mode := 0
var headless := false
var paused_state := false
var warning_step := 6
var critical_priority := 0
var master_gain := 1.0
var music_gain := 1.0
var effects_gain := 1.0
var voice_levels: Array[float] = []
const CRITICAL_PRIORITIES := {"clear": 2, "death": 3, "timeout": 3}

func _ready() -> void:
	headless = DisplayServer.get_name() == "headless"
	for key in ["shot","scatter","shock","lance","shield","kill","death","clear","timeout","warning"]:
		clips[key] = load("res://assets/audio/" + key + ".wav")
	music.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(music)
	var loop: AudioStreamWAV = load("res://assets/audio/descent.wav").duplicate()
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = int(round(loop.get_length() * loop.mix_rate))
	music.stream = loop
	music.volume_db = -10
	for i in range(12):
		var voice := AudioStreamPlayer.new()
		voice.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		add_child(voice)
		voice.volume_db = -5
		voices.append(voice)
		voice_levels.append(-5.0)
	if not headless: music.play()

func play_sfx(key: String) -> void:
	if audio_mode == 2 or headless: return
	if CRITICAL_PRIORITIES.has(key):
		var priority: int = CRITICAL_PRIORITIES[key]
		if voices[0].playing and priority < critical_priority: return
		critical_priority = priority
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
	music.stream_paused = value
	for voice in voices: voice.stream_paused = value

func set_audio_mode(value: int) -> void:
	audio_mode = posmod(value,3)
	_refresh_music_level()
	if audio_mode == 2:
		for voice in voices: voice.stop()

func _safe_gain(value: float) -> float:
	return clampf(value, 0.0, 1.0) if is_finite(value) else 1.0

func set_levels(master: float, background: float, effects: float) -> void:
	master_gain = _safe_gain(master)
	music_gain = _safe_gain(background)
	effects_gain = _safe_gain(effects)
	_refresh_music_level()
	for i in range(voices.size()): _set_voice_level(i, voice_levels[i])

func _refresh_music_level() -> void:
	music.volume_db = -10 + linear_to_db(master_gain * music_gain) if audio_mode == 0 else -80

func _set_voice_level(index: int, baseline: float) -> void:
	voice_levels[index] = baseline
	voices[index].volume_db = baseline + linear_to_db(master_gain * effects_gain)
