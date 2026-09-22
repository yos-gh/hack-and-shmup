extends RefCounted

var selecting := false
var active := false
var variant := 0
var depth := 5
const PRACTICE_UPGRADES := [0,1,6,7,3,2]
const CAPPED_FALLBACK := [0,1,3,2]

func open(game) -> void:
	game.return_to_title()
	selecting = true
	game.queue_redraw()

func start(game) -> void:
	game.start_run()
	active = true
	game.floor_number = depth
	# Spend exactly one legal card per cleared floor, including capped sub upgrades.
	var fallback_index := 0
	for i in range(depth-1):
		var kind: int = PRACTICE_UPGRADES[i%PRACTICE_UPGRADES.size()]
		if not game.session.run.can_upgrade(kind):
			kind = CAPPED_FALLBACK[fallback_index%CAPPED_FALLBACK.size()]
			fallback_index += 1
		game.apply_upgrade(kind)
	game.new_floor(variant)

func button(screen: Vector2, index: int) -> Rect2:
	var center := screen*0.5-Vector2(0,24)
	var width := minf(210,(screen.x-120)/5)
	if index in [0,1,2,7,8]:
		var column: int = index-4 if index >= 7 else index
		return Rect2(Vector2((screen.x-width*5-64)*0.5+column*(width+16),center.y-110),Vector2(width,72))
	if index == 3: return Rect2(center+Vector2(-180,10),Vector2(64,48))
	if index == 4: return Rect2(center+Vector2(116,10),Vector2(64,48))
	if index == 5: return Rect2(center+Vector2(-160,142),Vector2(320,52))
	return Rect2(center+Vector2(-160,214),Vector2(320,40))

func activate(game, index: int) -> void:
	if not selecting: return
	if index < 0 or index > 8: return
	if index == 7: variant = 3
	elif index == 8: variant = 4
	elif index < 3: variant = index
	elif index == 3: depth = maxi(depth-5,5)
	elif index == 4: depth = mini(depth+5,100)
	elif index == 5: start(game)
	else: game.return_to_title()
	game.queue_redraw()

func input(game, event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("back"): game.return_to_title()
		elif event.is_action_pressed("practice_left"): variant = (variant+4)%5
		elif event.is_action_pressed("practice_right"): variant = (variant+1)%5
		elif event.is_action_pressed("practice_up"): depth = mini(depth+5,100)
		elif event.is_action_pressed("practice_down"): depth = maxi(depth-5,5)
		elif event.is_action_pressed("confirm"): start(game)
		elif event.is_action_pressed("cycle_audio"): game.cycle_audio()
		else:
			for i in range(3):
				if event.is_action_pressed("select_%d" % (i+1)): variant = i
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in range(9):
			if not button(game.get_viewport_rect().size,i).has_point(event.position): continue
			activate(game,i)
			break
	game.queue_redraw()
