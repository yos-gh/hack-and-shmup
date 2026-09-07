extends RefCounted

var selecting := false
var active := false
var variant := 0
var depth := 5

func open(game) -> void:
	game.return_to_title()
	selecting = true
	game.queue_redraw()

func start(game) -> void:
	game.start_run()
	active = true
	game.floor_number = depth
	for i in range(depth-1): game.apply_upgrade([0,1,3,2][i%4])
	game.new_floor(variant)

func button(screen: Vector2, index: int) -> Rect2:
	var center := screen*0.5-Vector2(0,24)
	if index < 3: return Rect2(center+Vector2(-390+index*270,-110),Vector2(240,72))
	if index == 3: return Rect2(center+Vector2(-180,10),Vector2(64,48))
	if index == 4: return Rect2(center+Vector2(116,10),Vector2(64,48))
	if index == 5: return Rect2(center+Vector2(-160,142),Vector2(320,52))
	return Rect2(center+Vector2(-160,214),Vector2(320,40))

func input(game, event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE: game.return_to_title()
			KEY_LEFT: variant = (variant+2)%3
			KEY_RIGHT: variant = (variant+1)%3
			KEY_UP: depth = mini(depth+5,100)
			KEY_DOWN: depth = maxi(depth-5,5)
			KEY_1, KEY_2, KEY_3: variant = event.keycode-KEY_1
			KEY_ENTER, KEY_SPACE: start(game)
			KEY_M: game.cycle_audio()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in range(7):
			if not button(game.get_viewport_rect().size,i).has_point(event.position): continue
			if i < 3: variant = i
			elif i == 3: depth = maxi(depth-5,5)
			elif i == 4: depth = mini(depth+5,100)
			elif i == 5: start(game)
			else: game.return_to_title()
			break
	game.queue_redraw()

func draw(game, screen: Vector2) -> void:
	game.draw_rect(Rect2(Vector2.ZERO,screen),Color("0b111c"))
	var y := screen.y*0.5-24
	game.centered_title_label(screen,y-195,"BOSS PRACTICE",36,Color("63f5ce"))
	game.centered_title_label(screen,y-157,"LEFT / RIGHT: BOSS     UP / DOWN: FLOOR",15,Color("8194aa"))
	for i in range(7):
		var rect := button(screen,i)
		var ink := Color("63f5ce") if i == variant or i == 5 else Color("8194aa")
		game.draw_rect(rect,Color("182735"))
		game.draw_rect(rect,ink,false,1.5)
		var caption: String = game.boss.NAMES[i] if i < 3 else ["-","+","ENTER / START","ESC / BACK"][i-3]
		var width: float = game.font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
		game.label_at(Vector2(rect.get_center().x-width/2,rect.get_center().y+6),caption,18,ink)
	game.centered_title_label(screen,y+42,"FLOOR %02d" % depth,25)
	game.centered_title_label(screen,y+96,"%d AUTO UPGRADES / NORMAL DAMAGE / NO RECORD" % (depth-1),15,Color("8194aa"))
	game.centered_title_label(screen,y+128,"IN GAME: R RETRY / B SELECT / ESC PAUSE",14,Color("8194aa"))
