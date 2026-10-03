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
	check(sound.audio_on, "startup has sound on")
	check(sound.music.bus == StringName(sound.output_bus_name), "BGM bypasses the SE limiter and feeds the output stage")
	var output_index: int = AudioServer.get_bus_index(sound.output_bus_name)
	check(AudioServer.get_bus_send(AudioServer.get_bus_index(sound.effects_bus_name)) == StringName(sound.output_bus_name), "SE feed the output stage")
	var output_limiter = AudioServer.get_bus_effect(output_index, 0)
	check(output_limiter is AudioEffectHardLimiter and output_limiter.ceiling_db < 0.0 and output_limiter.pre_gain_db == sound.OUTPUT_GAIN_DB, "output stage adds makeup gain under a ceiling")
	check(sound.clips.has("hit"), "approved nonlethal hit clip installed")
	for key in ["shot","scatter","shock","lance","hit","kill","hunter_lock","death"]:
		check(sound.clips[key].mix_rate == 48000 and sound.clips[key].stereo, "approved 48 kHz stereo effect: " + key)
	check(sound.music.playback_type == AudioServer.PLAYBACK_TYPE_STREAM, "use the Godot mixer on Web")
	check(sound.music.stream is AudioStreamOggVorbis and sound.music_key == sound.music_lib.TITLE, "BGM starts on the title track")
	check(sound.music.stream.loop and sound.music.stream.loop_offset == sound.music_lib.LOOP_OFFSETS[sound.music_key], "BGM loops from its loop point")
	for voice in sound.voices:
		check(voice.playback_type == AudioServer.PLAYBACK_TYPE_STREAM, "SE uses the Godot mixer")
		check(voice.bus == sound.effects_bus_name, "SE routes through its dedicated limiter")
	for clip in sound.clips.values():
		check(clip.format == AudioStreamWAV.FORMAT_16_BITS, "SE uses PCM")
	await create_timer(0.2).timeout
	check(sound.music.playing and sound.music.volume_db == sound.MUSIC_DB, "startup plays BGM at its level")
	var before: float = sound.music.get_playback_position()
	for i in range(45):
		sound.set_paused(false)
		await create_timer(0.01).timeout
	check(sound.music.get_playback_position() > before, "repeated unpause keeps music advancing")
	for key in sound.clips:
		sound.play_sfx(key)
		await create_timer(0.08).timeout
	check(sound.voices.any(func(v: AudioStreamPlayer) -> bool: return v.playing), "SE playback")
	sound.play_sfx("death")
	await create_timer(0.05).timeout
	sound.set_paused(true)
	check(sound.voices[0].stream_paused, "pause freezes effects")
	check(not sound.music.stream_paused, "music keeps playing on the pause screen")
	var effect_position: float = sound.voices[0].get_playback_position()
	var paused_position: float = sound.music.get_playback_position()
	for i in range(5):
		sound.set_paused(true)
		await create_timer(0.01).timeout
	check(absf(sound.voices[0].get_playback_position()-effect_position) < 0.02, "a paused effect stays frozen")
	check(sound.music.get_playback_position() > paused_position, "music advances while paused")
	sound.set_paused(false)
	sound.set_audio_on(false)
	check(sound.music.volume_db == -80 and not sound.music.playing and not sound.voices.any(func(v: AudioStreamPlayer) -> bool: return v.playing), "OFF stops music and effects")
	sound.play_sfx("shot")
	check(not sound.shot_voice.playing, "effects stay silent while sound is off")
	sound.set_audio_on(true)
	check(sound.music.volume_db == sound.MUSIC_DB and sound.music.playing, "restore music")
	if failures == 0: print("PASS: BGM, SE clips, pause, mute and restore")
	sound.music.stop()
	for voice in sound.voices: voice.stop()
	sound.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.1).timeout
	quit(1 if failures else 0)
