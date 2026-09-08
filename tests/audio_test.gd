extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: " + message)
		failures += 1
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var sound = load("res://scripts/sound.gd").new()
	root.add_child(sound)
	check(sound.music.playback_type == AudioServer.PLAYBACK_TYPE_STREAM, "use the Godot mixer on Web")
	check(sound.music.stream.format == AudioStreamWAV.FORMAT_16_BITS, "BGM uses PCM")
	check(sound.music.stream.loop_end == sound.music.stream.data.size() / 2, "full PCM loop")
	for voice in sound.voices:
		check(voice.playback_type == AudioServer.PLAYBACK_TYPE_STREAM, "SE uses the Godot mixer")
	for clip in sound.clips.values():
		check(clip.format == AudioStreamWAV.FORMAT_16_BITS, "SE uses PCM")
	await create_timer(0.2).timeout
	check(sound.music.playing, "BGM playback")
	var before: float = sound.music.get_playback_position()
	for i in range(45):
		sound.set_paused(false)
		await create_timer(0.01).timeout
	check(sound.music.get_playback_position() > before, "repeated unpause keeps music advancing")
	for key in sound.clips:
		sound.play_sfx(key)
		await create_timer(0.08).timeout
	check(sound.voices.any(func(v: AudioStreamPlayer) -> bool: return v.playing), "SE playback")
	sound.set_paused(true)
	check(sound.music.stream_paused, "pause audio")
	var paused_position: float = sound.music.get_playback_position()
	for i in range(5):
		sound.set_paused(true)
		await create_timer(0.01).timeout
	check(absf(sound.music.get_playback_position()-paused_position)<0.05, "repeated pause stays frozen")
	sound.set_paused(false)
	sound.set_audio_mode(1)
	check(sound.music.volume_db == -80, "SE only mutes music")
	sound.play_sfx("shot")
	check(sound.voices.any(func(v: AudioStreamPlayer) -> bool: return v.playing), "SE remains enabled")
	sound.set_audio_mode(2)
	check(sound.music.volume_db == -80 and not sound.voices.any(func(v: AudioStreamPlayer) -> bool: return v.playing), "mute audio")
	sound.set_audio_mode(0)
	check(sound.music.volume_db == -10, "restore music")
	if failures == 0: print("PASS: BGM, SE clips, pause, mute and restore")
	sound.music.stop()
	for voice in sound.voices: voice.stop()
	sound.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.1).timeout
	quit(1 if failures else 0)
