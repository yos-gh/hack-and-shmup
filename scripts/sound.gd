extends Node

var music := AudioStreamPlayer.new()
var voices: Array[AudioStreamPlayer] = []
var clips: Dictionary = {}
var audio_mode := 0
var headless := false
var paused_state := false

func _ready() -> void:
	headless = DisplayServer.get_name() == "headless"
	for key in ["shot","scatter","shock","lance","shield","kill","death","clear","timeout"]:
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
	if not headless: music.play()

func play_sfx(key: String) -> void:
	if audio_mode == 2 or headless: return
	if key in ["timeout", "death"]:
		voices[0].stream = clips[key]
		voices[0].play()
		return
	for voice in voices:
		if not voice.playing:
			voice.stream = clips[key]
			voice.play()
			return

func set_paused(value: bool) -> void:
	# Web Sample playback restarts on every unpause call, even when already running.
	# Apply transitions only; game physics may request the same state every frame.
	if value == paused_state: return
	paused_state = value
	music.stream_paused = value
	for voice in voices: voice.stream_paused = value

func set_audio_mode(value: int) -> void:
	audio_mode = posmod(value,3)
	music.volume_db = -10 if audio_mode == 0 else -80
	if audio_mode == 2:
		for voice in voices: voice.stop()
