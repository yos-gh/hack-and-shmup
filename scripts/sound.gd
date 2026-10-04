extends Node

var enemy_audio = preload("res://scripts/enemy_audio.gd").new()

var music := AudioStreamPlayer.new()
var music_lib = preload("res://scripts/music.gd").new()
# Track now loaded in the music player, and the one it is fading out toward.
var music_key := ""
var pending_music := ""
var music_fade := 1.0
var voices: Array[AudioStreamPlayer] = []
var clips: Dictionary = {}
var audio_on := true
var headless := false
var paused_state := false
var warning_step := 6
var critical_priority := 0
var hit_gap := 0.0
var burst_gaps: Dictionary = {}
var effects_bus_name := ""
# Final stage for music and effects: makeup gain and a ceiling below full scale (there is no in-game volume setting).
var output_bus_name := ""
var boss_beam := AudioStreamPlayer2D.new()
# Primary fire retriggers one mono voice, like a sound-driver channel, so rapid fire never smears.
var shot_voice := AudioStreamPlayer.new()
var shot_rng := RandomNumberGenerator.new()
# A cue that should follow, not bury under, the critical sound on slot 0.
var after_critical := ""
var boss_beam_active := false
var boss_beam_level := -60.0
const CRITICAL_PRIORITIES := {"boss_destroy": 1, "clear": 2, "death": 3, "timeout": 3}
# Every clip is rendered at one loudness (tools/generate_sfx.py); this table is the mix.
const MIX := {
	"death": -2.0, "boss_destroy": -2.0, "timeout": -4.0, "clear": -8.0, "stairs": -9.0,
	"warning": -6.0, "shock": -2.0, "scatter": -3.0, "lance": -3.0,
	"kill": -6.0, "armor_break": -7.0, "shield": -13.0, "hit": -13.0, "armor": -15.0, "shot": -12.0,
	"arrival": -10.0, "select": -10.0, "ready": -14.0, "pickup": -11.0, "buff_end": -15.0,
	"sniper_fire": -11.0, "siege_fire": -10.0, "halo_fire": -10.0, "pearl_fire": -14.0, "hunter_fire": -9.0,
	"hunter_lock": -5.0, "boss_mark": -4.0, "triad_charge": -5.0, "boss_orb_charge": -6.0, "boss_release": -7.0,
	"charge": -8.0, "warp": -10.0, "triad_beam": -12.0,
	# Enemy cues play through centred AudioStreamPlayer2D voices (0.5 per channel, -6 dB) and lose up to
	# 3 dB with distance. The hammer is the boss's signature hit: the impact sits near kill, and the launch
	# rises over the boss_mark it shares a moment with.
	"citadel_hammer_launch": 1.0, "citadel_hammer_impact": 3.0,
	# Abyss Wyrm: the rumble warns of the next breach; the breach itself is a heavy hit like the hammer.
	"wyrm_rumble": -2.0, "wyrm_breach": 2.0,
	# The bombardment's slag column and landing chunks sit with the hammer; the cage is a warning.
	"wyrm_plume": 1.0, "wyrm_slag": 0.0, "wyrm_cage": -4.0,
}
const DUCK := 6.0
# Tracks are mastered to about -16 LUFS (titles and the card screen quieter); this places them under the effects.
const MUSIC_DB := -8.0
# Measured with tools/mix_level_review.gd: combat sits around -17 LUFS and boss attacks peak just into the limiter.
const OUTPUT_GAIN_DB := 4.0
const OUTPUT_CEILING_DB := -1.0
const MUSIC_FADE := 0.4
const BURST_GAPS := {"kill": 0.045, "shield": 0.045, "armor": 0.05, "armor_break": 0.08, "select": 0.05}

func _ready() -> void:
	headless = DisplayServer.get_name() == "headless"
	# Buses only send to buses before them, so the output stage is created first.
	output_bus_name = "GameOutput_%s" % get_instance_id()
	AudioServer.add_bus()
	var output_index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(output_index, output_bus_name)
	var output_limiter := AudioEffectHardLimiter.new()
	output_limiter.pre_gain_db = OUTPUT_GAIN_DB
	output_limiter.ceiling_db = OUTPUT_CEILING_DB
	AudioServer.add_bus_effect(output_index, output_limiter)
	effects_bus_name = "GameEffects_%s" % get_instance_id()
	AudioServer.add_bus()
	var bus_index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus_index, effects_bus_name)
	AudioServer.set_bus_send(bus_index, output_bus_name)
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -2.5
	limiter.pre_gain_db = -2.0
	AudioServer.add_bus_effect(bus_index, limiter)
	for key in MIX:
		clips[key] = load("res://assets/audio/" + key + ".wav")
	music.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	music.bus = output_bus_name
	add_child(music)
	music_key = music_lib.TITLE
	music.stream = music_lib.stream(music_key)
	_refresh_music_level()
	for i in range(12):
		var voice := AudioStreamPlayer.new()
		voice.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		voice.bus = effects_bus_name
		add_child(voice)
		voice.volume_db = -5
		voices.append(voice)
	shot_voice.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	shot_voice.bus = effects_bus_name
	shot_voice.stream = clips.shot
	add_child(shot_voice)
	add_child(enemy_audio)
	for voice in enemy_audio.voices: voice.bus = effects_bus_name
	# A dedicated, bounded voice follows beam state, never the general shot pool.
	var beam_loop: AudioStreamWAV = clips.triad_beam.duplicate()
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
	# Music keeps playing on the pause screen (and keeps fading between tracks); effects freeze.
	_advance_music_fade(delta)
	if paused_state: return
	if after_critical != "" and not voices[0].playing:
		var key := after_critical
		after_critical = ""
		play_sfx(key)
	var target: float = MIX.triad_beam if boss_beam_active else -60.0
	if boss_beam_active and enemy_audio.voices[0].playing: target -= DUCK
	boss_beam_level = move_toward(boss_beam_level,target,180*delta)
	boss_beam.volume_db = boss_beam_level
	if not boss_beam_active and boss_beam_level <= -60: boss_beam.stop()

func set_boss_beam(game, active: bool, point: Vector2 = Vector2.ZERO) -> void:
	boss_beam_active = active and audio_on and not game.pending_respawn and not game.title_screen
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

func hear_hit(_position: Vector2, damage: float, blocked: bool, killed: bool) -> void:
	if blocked and not paused_state:
		# Zero damage is a shield enemy's guarded front; damage is boss armor soaking it.
		play_sfx("armor" if damage > 0 else "shield")
		return
	if killed or hit_gap > 0 or paused_state: return
	hit_gap = 0.055
	play_sfx("hit")

func hear_boss_destroyed(_position: Vector2, _color: Color) -> void:
	play_sfx("boss_destroy")

func stop_boss_destruction() -> void:
	after_critical = ""
	if voices[0].stream == clips.boss_destroy: voices[0].stop()

func _exit_tree() -> void:
	for bus_name in [effects_bus_name, output_bus_name]:
		var bus_index := AudioServer.get_bus_index(bus_name)
		if bus_index > 0: AudioServer.remove_bus(bus_index)

func play_sfx(key: String) -> void:
	if not audio_on or headless: return
	if BURST_GAPS.has(key):
		if burst_gaps.get(key, 0.0) > 0: return
		burst_gaps[key] = BURST_GAPS[key]
	if CRITICAL_PRIORITIES.has(key):
		var priority: int = CRITICAL_PRIORITIES[key]
		if voices[0].playing and priority < critical_priority: return
		critical_priority = priority
		stop_boss_beam()
		enemy_audio.reset()
		for voice in voices: voice.stop()
		shot_voice.stop()
		_set_voice_level(0, MIX[key])
		voices[0].stream = clips[key]
		voices[0].play()
		return
	if key == "warning":
		if voices[0].playing: return
		_set_voice_level(1, MIX[key])
		voices[1].stream = clips[key]
		voices[1].play()
		return
	if voices[0].playing:
		if key == "stairs": after_critical = key
		if key in ["stairs", "arrival"]: return
	var duck := DUCK if voices[0].playing else 0.0
	if key == "shot":
		shot_voice.stop()
		shot_voice.volume_db = MIX.shot - duck
		shot_voice.pitch_scale = shot_rng.randf_range(0.97, 1.03)
		shot_voice.play()
		return
	# Slots 0/1 are reserved; repeated shots cannot exhaust or replace alerts.
	for i in range(2,voices.size()):
		var voice := voices[i]
		if not voice.playing:
			_set_voice_level(i, MIX[key] - duck)
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
	for voice in voices: voice.stream_paused = value
	shot_voice.stream_paused = value
	boss_beam.stream_paused = value

func set_audio_on(value: bool) -> void:
	audio_on = value
	enemy_audio.muted = not audio_on
	if enemy_audio.muted: enemy_audio.reset()
	_refresh_music_level()
	if not audio_on:
		after_critical = ""
		stop_boss_beam()
		for voice in voices: voice.stop()
		shot_voice.stop()

# Called every physics tick by Game: follows the screen (title, floor, boss, card select) without restarting the
# track on a retry. Switching fades the old track out first when it is audible.
func update_music(game) -> void:
	var wanted: String = music_lib.track_for(game)
	if wanted == (pending_music if pending_music != "" else music_key): return
	if music.playing:
		pending_music = wanted
	else:
		_switch_music(wanted)

# Sound mode: picking the track that is already playing starts it over.
func restart_music() -> void:
	if pending_music == "" and audio_on and not headless and music.is_inside_tree(): music.play()

func _advance_music_fade(delta: float) -> void:
	if pending_music == "": return
	music_fade = move_toward(music_fade, 0.0, delta / MUSIC_FADE)
	if audio_on: music.volume_db = MUSIC_DB + linear_to_db(maxf(music_fade, 0.001))
	if music_fade <= 0.0: _switch_music(pending_music)

func _switch_music(key: String) -> void:
	pending_music = ""
	music_fade = 1.0
	music_key = key
	music.stop()
	music.stream = music_lib.stream(key)
	_refresh_music_level()

func _refresh_music_level() -> void:
	music.volume_db = MUSIC_DB if audio_on else -80
	# Muting alone still decodes and mixes the looping track on Web.
	if not audio_on:
		music.stop()
	elif not headless and music.is_inside_tree() and not music.playing:
		music.play()

func _set_voice_level(index: int, baseline: float) -> void:
	voices[index].volume_db = baseline
