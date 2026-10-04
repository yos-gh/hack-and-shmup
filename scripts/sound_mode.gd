extends RefCounted

# Hidden sound test: clicking the emblem above the title wordmark opens a jukebox of every BGM in assets/music,
# tracks the game does not use yet included. Picking a track fades over to it; leaving returns to the title.

const Music = preload("res://scripts/music.gd")
const Boss = preload("res://scripts/boss.gd")
const ROWS := 8
# Click radius around the title emblem, in viewport pixels (the outer ring is 58 px).
const EMBLEM_RADIUS := 62.0

var selecting := false
var track := ""

# Every track in play order: title, stages, bosses, intermissions, then the unused ones.
static func catalog() -> Array[Dictionary]:
	var list: Array[Dictionary] = [{"key": Music.TITLE, "use": "TITLE SCREEN"}]
	for key in Music.STAGE: list.append({"key": key, "use": "STAGE"})
	for i in range(Music.BOSS.size()): list.append({"key": Music.BOSS[i], "use": "BOSS / " + Boss.NAMES[i]})
	list.append({"key": Music.WYRM_SECOND, "use": "BOSS / ABYSS WYRM, SECOND FORM"})
	list.append({"key": Music.CARDS, "use": "UPGRADE SELECT"})
	list.append({"key": Music.COOLING, "use": "AFTER A BOSS FALLS"})
	for key in Music.RESERVED.values(): list.append({"key": key, "use": "UNUSED"})
	return list

# "stage_tresillo_rush" -> "TRESILLO RUSH"
static func display_name(key: String) -> String:
	return key.substr(key.find("_")+1).replace("_", " ").to_upper()

static func emblem_center(screen: Vector2) -> Vector2:
	return Vector2(screen.x*0.5, screen.y*0.5-222)

static func hits_emblem(screen: Vector2, point: Vector2) -> bool:
	return point.distance_to(emblem_center(screen)) <= EMBLEM_RADIUS

func open(game) -> void:
	game.return_to_title()
	selecting = true
	track = game.sound.music_key
	game.queue_redraw()

func close(game) -> void:
	game.return_to_title()

func choose(game, index: int) -> void:
	var list := catalog()
	if not selecting or index < 0 or index >= list.size(): return
	if list[index].key == track: game.sound.restart_music()
	track = list[index].key
	game.sound.update_music(game)

func index_of(key: String) -> int:
	var list := catalog()
	for i in range(list.size()):
		if list[i].key == key: return i
	return -1

func grid_top(screen: Vector2) -> float:
	return screen.y*0.5-240

# Track buttons fill columns of ROWS; index == catalog().size() is BACK.
func button(screen: Vector2, index: int) -> Rect2:
	var count := catalog().size()
	var top := grid_top(screen)
	if index >= count: return Rect2(screen.x*0.5-160, top+ROWS*48+144, 320, 42)
	var columns := ceili(float(count)/ROWS)
	var width := minf(360, (screen.x-100-16*(columns-1))/columns)
	var left := (screen.x-width*columns-16*(columns-1))*0.5
	return Rect2(left+(index/ROWS)*(width+16), top+(index%ROWS)*48, width, 40)

# Playback bar under the now-playing caption, drawn by MenuArt.
func progress_rect(screen: Vector2) -> Rect2:
	return Rect2(screen.x*0.5-260, grid_top(screen)+ROWS*48+106, 520, 4)

func input(game, event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("back"): close(game)
		elif event.is_action_pressed("cycle_audio"): game.cycle_audio()
	elif event is InputEventJoypadButton and event.pressed and event.is_action_pressed("back"):
		close(game)
