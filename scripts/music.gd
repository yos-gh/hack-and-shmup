extends RefCounted

# Background music catalog and selection. Tracks are OGG Vorbis in assets/music, rendered from the REAPER projects
# described in assets/README.md. Each loops from LOOP_OFFSETS[key] seconds to its end (the files end on a bar line).
# Selection never touches gameplay RNG: floor generation and replays stay unchanged.

const DIR := "res://assets/music/"
# A new normal floor draws from this shuffled bag; retries keep the floor's track.
const STAGE := [
	"stage_ignition", "stage_wire_runner", "stage_deep_drift", "stage_overdrive", "stage_afterburner",
	"stage_static_field", "stage_tresillo_rush", "stage_rave_signal", "stage_dub_depth", "stage_electro_pulse",
	"stage_starfall_run", "stage_origin_drive", "stage_afterimage", "stage_reverse_city",
]
# Indexed by boss variant: Iron Citadel, Bastion of Stars, Triad Battery.
const BOSS := ["boss_red_alert", "boss_dread_engine", "boss_triad_lattice"]
const TITLE := "title_gate_of_the_deep"
const CARDS := "intermission_card_select"
# After a boss falls, until the player takes the stairs: a quiet, beatless loop instead of the boss track.
const COOLING := "intermission_cooling"
# Ready for content that does not exist yet: the final boss's two forms and an ending theme.
const RESERVED := {"final_boss_1": "boss_abyss_core", "final_boss_2": "boss_recca_dark_v2", "theme": "theme_recca_style_bgm"}
const LOOP_OFFSETS := {
	"stage_ignition": 12.6316, "stage_wire_runner": 12.0, "stage_deep_drift": 26.6667, "stage_overdrive": 11.5663,
	"stage_afterburner": 0.0, "stage_static_field": 14.5455, "stage_tresillo_rush": 12.3077, "stage_rave_signal": 6.2338,
	"stage_dub_depth": 14.7692, "stage_electro_pulse": 7.0588, "stage_starfall_run": 6.4865, "stage_origin_drive": 6.3158,
	"stage_afterimage": 0.0, "stage_reverse_city": 6.8571,
	"boss_red_alert": 11.1628, "boss_dread_engine": 8.0, "boss_triad_lattice": 6.5753, "boss_abyss_core": 13.3333,
	"boss_recca_dark_v2": 13.7143, "title_gate_of_the_deep": 64.0, "intermission_card_select": 40.0, "intermission_cooling": 48.0,
	"theme_recca_style_bgm": 12.8,
}

var rng := RandomNumberGenerator.new()
var bag: Array[String] = []
var last_stage := ""
var floor_key := -1
var floor_track := ""

func _init() -> void:
	rng.randomize()

static func stream(key: String) -> AudioStreamOggVorbis:
	var loaded: AudioStreamOggVorbis = load(DIR + key + ".ogg")
	loaded.loop = true
	loaded.loop_offset = LOOP_OFFSETS.get(key, 0.0)
	return loaded

# Shuffle bag: every stage track plays once before any repeats, and a refill never starts with the track that
# just ended, so the same song never plays on two floors in a row.
func next_stage() -> String:
	if bag.is_empty():
		for key in STAGE: bag.append(key)
		for i in range(bag.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var swap := bag[i]; bag[i] = bag[j]; bag[j] = swap
		if bag.size() > 1 and bag[bag.size() - 1] == last_stage:
			var swap := bag[0]; bag[0] = bag[bag.size() - 1]; bag[bag.size() - 1] = swap
	last_stage = bag.pop_back()
	return last_stage

# The track the current screen should play. A floor is identified by its revision, so a retry (same floor,
# regenerated from its snapshot) keeps its track and only a newly generated floor draws a new one.
func track_for(game) -> String:
	if game.title_screen: return TITLE
	if game.choosing: return CARDS
	if game.boss_floor: return COOLING if game.stairs_unlocked else BOSS[clampi(game.boss_variant, 0, BOSS.size() - 1)]
	if game.floor_revision != floor_key:
		floor_key = game.floor_revision
		floor_track = next_stage()
	return floor_track
