extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var sound = load("res://scripts/sound.gd").new()
	root.add_child(sound)
	await create_timer(0.2).timeout
	assert(sound.music.playing, "BGM playback")
	for key in sound.clips:
		sound.play_sfx(key)
		await create_timer(0.08).timeout
	assert(sound.voices.any(func(v: AudioStreamPlayer) -> bool: return v.playing), "SE playback")
	sound.set_paused(true)
	assert(sound.music.stream_paused, "pause audio")
	sound.set_paused(false)
	sound.set_audio_mode(1)
	assert(sound.music.volume_db == -80, "SE only mutes music")
	sound.play_sfx("shot")
	assert(sound.voices.any(func(v: AudioStreamPlayer) -> bool: return v.playing), "SE remains enabled")
	sound.set_audio_mode(2)
	assert(sound.music.volume_db == -80 and not sound.voices.any(func(v: AudioStreamPlayer) -> bool: return v.playing), "mute audio")
	sound.set_audio_mode(0)
	assert(sound.music.volume_db == -10, "restore music")
	print("PASS: BGM, nine SE clips, pause, mute and restore")
	sound.free()
	quit()
