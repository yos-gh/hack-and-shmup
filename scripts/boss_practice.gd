extends RefCounted

const Catalog = preload("res://scripts/combat_catalog.gd")
const FloorData = preload("res://scripts/floor_data.gd")

var selecting := false
var active := false
var variant := 0
var depth := 5
const PRACTICE_UPGRADES := [0,1,6,7,3,2]
const CAPPED_FALLBACK := [0,1,3,2]
# Test-play builds keep the status-screen MOVE SPEED at or below this; deep
# floors are otherwise too fast to control. Cards that would pass it fall back
# to damage and fire rate.
const TEST_MOVE_SPEED_CAP := 635.0
# Boss cards: Citadel, Bastion, Triad and the Abyss Wyrm. Buttons after them are
# FLOOR −, FLOOR +, START and BACK.
const BOSSES := 4
const MINUS := BOSSES
const PLUS := BOSSES+1
const START := BOSSES+2
const BACK := BOSSES+3

func open(game) -> void:
	game.return_to_title()
	selecting = true
	game.queue_redraw()

func start(game) -> void:
	game.start_run()
	active = true
	game.floor_number = depth
	auto_upgrades(game.session.run,depth-1,PRACTICE_UPGRADES)
	game.new_floor(variant)

# Spend exactly one legal card per cleared floor. Capped sub upgrades and speed
# past the test cap take the next allowed fallback card instead.
static func auto_upgrades(run, count: int, cycle: Array) -> void:
	var fallback_index := 0
	for i in range(count):
		var kind: int = cycle[i%cycle.size()]
		while not auto_allowed(run,kind):
			kind = CAPPED_FALLBACK[fallback_index%CAPPED_FALLBACK.size()]
			fallback_index += 1
		run.apply_upgrade(kind)

static func auto_allowed(run, kind: int) -> bool:
	return run.can_upgrade(kind) and FloorData.SPEED+run.move_bonus+Catalog.UPGRADES[kind].move_speed <= TEST_MOVE_SPEED_CAP+0.00001

func button(screen: Vector2, index: int) -> Rect2:
	var center := screen*0.5-Vector2(0,24)
	var width := minf(260,(screen.x-100-16*(BOSSES-1))/BOSSES)
	if index < BOSSES:
		return Rect2(Vector2((screen.x-width*BOSSES-16*(BOSSES-1))*0.5+index*(width+16),center.y-65),Vector2(width,72))
	if index == MINUS: return Rect2(center+Vector2(-180,66),Vector2(64,48))
	if index == PLUS: return Rect2(center+Vector2(116,66),Vector2(64,48))
	if index == START: return Rect2(center+Vector2(-160,145),Vector2(320,52))
	return Rect2(center+Vector2(-160,212),Vector2(320,40))

func activate(game, index: int) -> void:
	if not selecting: return
	if index < 0 or index > BACK: return
	if index < BOSSES: variant = index
	elif index == MINUS: depth = maxi(depth-5,5)
	elif index == PLUS: depth = mini(depth+5,100)
	elif index == START: start(game)
	else: game.return_to_title()
	game.queue_redraw()

func input(game, event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("back"): game.return_to_title()
		elif event.is_action_pressed("practice_left"): variant = (variant+BOSSES-1)%BOSSES
		elif event.is_action_pressed("practice_right"): variant = (variant+1)%BOSSES
		elif event.is_action_pressed("practice_up"): depth = mini(depth+5,100)
		elif event.is_action_pressed("practice_down"): depth = maxi(depth-5,5)
		elif event.is_action_pressed("confirm"): start(game)
		elif event.is_action_pressed("cycle_audio"): game.cycle_audio()
		elif event.is_action_pressed("toggle_display"): game.toggle_display()
		else:
			for i in range(3):
				if event.is_action_pressed("select_%d" % (i+1)): variant = i
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in range(BACK+1):
			if not button(game.get_viewport_rect().size,i).has_point(event.position): continue
			activate(game,i)
			break
	game.queue_redraw()
