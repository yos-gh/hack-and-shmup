extends "res://scripts/sound.gd"

# Development-only audition. Final game audio is installed after listening approval.
const REVIEW := "res://docs/audio/review/"
func _ready() -> void:
	super._ready()
	music.stop()
	for key in ["shot", "scatter", "shock", "lance", "hit", "kill", "hunter_lock", "death"]:
		clips[key] = AudioStreamWAV.load_from_file(ProjectSettings.globalize_path(REVIEW + key + ".wav"))
		assert(clips[key] != null, "Missing review effect: " + key)
	var loop := AudioStreamOggVorbis.load_from_file(ProjectSettings.globalize_path(REVIEW + "stage_01.ogg"))
	assert(loop != null, "Missing review music")
	loop.loop = true
	music.stream = loop
	set_audio_mode(0)
	if not headless: music.play()

func _refresh_music_level() -> void:
	music.volume_db = -2 if audio_mode == 0 else -80
