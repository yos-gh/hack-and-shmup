extends Node

# One pending cue per attack family; independent of combat and random streams.
const PRIORITY := {"pearl_fire":0,"sniper_fire":0,"siege_fire":1,"halo_fire":1,"charge":1,"warp":2,"hunter_fire":2,"hunter_lock":3,"triad_charge":4,"boss_orb_charge":3,"boss_mark":3,"boss_release":2,"citadel_hammer_launch":2,"citadel_hammer_impact":3}
# Levels come from the shared SE mix in sound.gd.
const WARNINGS := ["hunter_lock","triad_charge","boss_orb_charge","boss_mark"]
const GAP := 0.065
var pending: Dictionary = {}
var cooldown: Dictionary = {}
var voices: Array[AudioStreamPlayer2D] = []
var ranks: Array[float] = []
var levels: Array[float] = []
var paused := false
var muted := false

func _ready() -> void:
	for i in range(5):
		var voice := AudioStreamPlayer2D.new()
		voice.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		voice.max_distance = 2000
		voice.attenuation = 0.0
		voice.panning_strength = 0.45
		add_child(voice)
		voices.append(voice)
		ranks.append(-1)
		levels.append(-16)

func request(game, key: String, point: Vector2) -> void:
	if muted or paused or not PRIORITY.has(key) or not game.attack_open(point): return
	var distance: float = point.distance_to(game.player)
	if distance > 1200: return
	var screen: Vector2 = game.get_viewport_rect().size
	var relative: Vector2 = point-game.camera_pos
	var visible := Rect2(-screen*0.5,screen).has_point(relative)
	var score: float = PRIORITY[key]*4.0+(2.0 if visible else 0.0)+1.0/(1.0+distance/300.0)
	var cue := {"key":key,"score":score,"screen":relative+screen*0.5,"db":game.sound.MIX[key]-(0.0 if visible else 6.0)-minf(distance/300,3)}
	if not pending.has(key) or score > pending[key].score: pending[key] = cue

func take(delta: float) -> Array:
	if paused: return []
	for key in cooldown: cooldown[key] = maxf(0,cooldown[key]-delta)
	var result: Array = []
	for key in pending:
		if cooldown.get(key,0.0) <= 0:
			result.append(pending[key])
			cooldown[key] = GAP
	pending.clear()
	result.sort_custom(func(a,b): return a.score > b.score)
	return result

func _process(delta: float) -> void:
	var sound = get_parent()
	if paused or muted: return
	if sound.voices[0].playing:
		reset()
		return
	for cue in take(delta):
		if sound.headless: continue
		# Critical telegraphs have a reserved voice; ordinary volleys cannot steal it.
		var slot := 0 if cue.key in WARNINGS else -1
		if slot == 0 and voices[0].playing and ranks[0] >= cue.score: continue
		if slot < 0:
			for i in range(1,voices.size()):
				if not voices[i].playing:
					slot = i
					break
			if slot < 0:
				var weakest := 1
				for i in range(2,voices.size()):
					if ranks[i] < ranks[weakest]: weakest = i
				if cue.score > ranks[weakest]+0.1: slot = weakest
		if slot < 0: continue
		var voice := voices[slot]
		voice.position = cue.screen
		ranks[slot] = cue.score
		levels[slot] = cue.db
		voice.volume_db = cue.db
		voice.stream = sound.clips[cue.key]
		voice.play()
	refresh_mix()

func refresh_mix() -> void:
	for i in range(voices.size()):
		var duck := 6.0 if i > 0 and voices[0].playing else 0.0
		voices[i].volume_db = levels[i]-duck

func reset() -> void:
	pending.clear()
	cooldown.clear()
	for voice in voices: voice.stop()

func set_paused(value: bool) -> void:
	paused = value
	if value: reset()
	# Transient attack sounds never resume after a pause.
