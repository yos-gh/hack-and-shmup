extends SceneTree

# Movie Maker uses the actual Godot audio mixer. Capture three full Ogg cycles.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var stream := AudioStreamOggVorbis.load_from_file(ProjectSettings.globalize_path("res://docs/audio/review/stage_01.ogg"))
	assert(stream != null)
	assert(absf(stream.get_length() - 48.0) < 0.002)
	stream.loop = true
	var player := AudioStreamPlayer.new()
	player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	player.stream = stream
	root.add_child(player)
	player.play()
	for frame in range(8646):
		await process_frame
	assert(player.playing)
	print("PASS: 48-second Ogg active through three mixer-rendered loops")
	player.free()
	quit()
