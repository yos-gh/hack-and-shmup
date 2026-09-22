extends CanvasLayer

const Catalog = preload("res://scripts/combat_catalog.gd")
var game: Node
var surface: Control
var signature: Array = []
var cards: Array[Button] = []

func setup(host: Node) -> void:
	game = host
	layer = 10
	surface = Control.new()
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.theme = preload("res://scripts/menu_theme.gd").create()
	add_child(surface)

func _process(_delta: float) -> void: sync()

func sync() -> void:
	var screen: Vector2 = game.get_viewport_rect().size
	var state := "title" if game.title_screen else ("pause" if game.paused else ("cards" if game.choosing else ""))
	if game.practice.selecting: state = "practice"
	if state.is_empty() and signature == [""]: return
	var focused: Control = get_viewport().gui_get_focus_owner()
	var focus_index := focused.get_index() if focused != null and focused.get_parent() == surface and signature.size() > 1 and signature[1] == state else -1
	var next: Array = [screen,state,game.audio_mode,game.best_cleared,game.choices.duplicate(),game.player_stats(),game.session.run.expansion,game.session.run.recharge,DisplayServer.window_get_mode(),game.practice.variant,game.practice.depth,game.controls.using_gamepad]
	if state.is_empty(): next = [""]
	if next == signature:
		if not state.is_empty() and game.controls.using_gamepad:
			var focused_now: Control = get_viewport().gui_get_focus_owner()
			if focused_now == null or not (focused_now is Button) or focused_now.get_parent() != surface:
				_default_focus(state)
		return
	signature = next
	for child in surface.get_children():
		surface.remove_child(child)
		child.queue_free()
	cards.clear()
	if state.is_empty(): return
	var background = preload("res://scripts/menu_art.gd").new()
	background.game = game
	background.kind = state
	background.size = screen
	surface.add_child(background)
	if state == "title": _title(screen)
	elif state == "practice": _practice(screen)
	else: _battle_menu(screen,state == "pause")
	if focus_index >= 0 and focus_index < surface.get_child_count():
		surface.get_child(focus_index).grab_focus()
	elif game.controls.using_gamepad:
		_default_focus(state)

func _buttons() -> Array:
	return surface.get_children().filter(func(node): return node is Button)

func _default_focus(state: String) -> void:
	var buttons := _buttons()
	if buttons.is_empty(): return
	if state == "practice": buttons[7 if game.practice.variant == 3 else (8 if game.practice.variant == 4 else game.practice.variant)].grab_focus()
	else: buttons[0].grab_focus()

func _move_focus(direction: Vector2i) -> void:
	var buttons := _buttons()
	if buttons.is_empty(): return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused == null or not buttons.has(focused):
		_default_focus("practice" if game.practice.selecting else "")
		return
	var side := SIDE_LEFT if direction.x < 0 else (SIDE_RIGHT if direction.x > 0 else (SIDE_TOP if direction.y < 0 else SIDE_BOTTOM))
	var next: Control = focused.find_valid_focus_neighbor(side)
	if next != null and buttons.has(next): next.grab_focus()

func _activate_focused() -> void:
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused is Button and focused.get_parent() == surface: focused.pressed.emit()

func _label(rect: Rect2, text: String, size: int = 18, ink: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.text = text
	label.add_theme_font_override("font",game.font if size>=20 else game.body_font)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",ink)
	surface.add_child(label)
	return label

# Decorative plates ignore input; button rectangles remain authoritative.
func _plate(rect: Rect2) -> void:
	var plate := Panel.new()
	plate.position = rect.position
	plate.size = rect.size
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101c27")
	style.border_color = Color("304956")
	style.set_border_width_all(1)
	plate.add_theme_stylebox_override("panel",style)
	surface.add_child(plate)

func _button(rect: Rect2, text: String, callback: Callable) -> Button:
	var button := preload("res://scripts/art_button.gd").new()
	button.position = rect.position
	button.size = rect.size
	button.text = text
	button.pressed.connect(callback)
	surface.add_child(button)
	return button

func _title(screen: Vector2) -> void:
	var y := screen.y*0.5
	# The vector wordmark is drawn by MenuArt, with no font dependency.
	_label(Rect2(24,y-58,screen.x-48,30),"ENDLESS DESCENT",18,Color("8194aa"))
	_label(Rect2(24,y+0,screen.x-48,40),"DEEPEST CLEARED  %02d" % game.best_cleared,24,Color("ffb95e"))
	_button(Rect2(screen.x*0.5-190,y+64,380,46),"START (A / LB)" if game.controls.using_gamepad else "START (Enter)",func():
		if game.title_screen: game.start_run(); sync())
	_button(Rect2(screen.x*0.5-190,y+122,380,42),"BOSS PRACTICE" if game.controls.using_gamepad else "BOSS PRACTICE (B)",func():
		if game.title_screen: game.practice.open(game); sync())
	_label(Rect2(24,y+185,screen.x-48,45),"LEFT STICK / DPAD MOVE / RIGHT STICK AIM" if game.controls.using_gamepad else "WASD MOVE / MOUSE AIM / Q & E WEAPONS",14,Color("8194aa"))
	var hint := "LEFT STICK / DPAD SELECT / A / LB CONFIRM" if game.controls.using_gamepad else "M AUDIO / RECORD LASTS UNTIL YOU QUIT"
	if not OS.has_feature("web"): hint += " / B QUIT" if game.controls.using_gamepad else " / ESC QUIT"
	_label(Rect2(24,y+240,screen.x-48,40),hint,14,Color("8194aa"))
	_button(game.audio_button_rect(),["AUDIO: ALL","AUDIO: SE ONLY","AUDIO: OFF"][game.audio_mode],func(): game.cycle_audio(); sync())
	var fullscreen := DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN,DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	_button(game.fullscreen_button_rect(),"WINDOWED" if fullscreen else "FULLSCREEN",func(): game.toggle_fullscreen(); sync())

func _battle_menu(screen: Vector2, is_pause: bool) -> void:
	var y: float = game.menu_origin_y(screen,is_pause)
	if is_pause:
		_label(Rect2(24,y-65,screen.x-48,40),"PAUSED",28)
		_button(Rect2(screen.x*0.5-170,y-10,340,44),"RESUME",func():
			if game.paused:
				game.paused = false
				game.fire_armed = false
				game.sound.set_paused(false)
				sync())
		_button(Rect2(screen.x*0.5-170,y+45,340,44),"TITLE (B)" if game.controls.using_gamepad else "TITLE (Esc)",func():
			if game.paused: game.return_to_title(); sync())
	else:
		_label(Rect2(24,y-165,screen.x-48,45),"FLOOR CLEARED — CHOOSE AN UPGRADE",24,Color("63f5ce"))
		_label(Rect2(24,y-115,screen.x-48,35),"LEFT STICK / DPAD: SELECT     A / LB: CONFIRM" if game.controls.using_gamepad else "CLICK / 1 / 2 / 3 / TAB + ENTER",16,Color("8194aa"))
		for i in range(3):
			var rect: Rect2 = game.upgrade_card_rect(screen,i)
			var definition = Catalog.UPGRADES[game.choices[i]]
			var button := _button(rect,"",func(): choose(i))
			button.tooltip_text = definition.title + ": " + definition.description
			cards.append(button)
			var icon = preload("res://scripts/menu_art.gd").new()
			icon.icon = preload("res://scripts/visual_icons.gd").UPGRADES[game.choices[i]]
			icon.position = rect.position+Vector2(12,32)
			icon.size = Vector2(64,64)
			surface.add_child(icon)
			_label(Rect2(rect.position+Vector2(78,8),Vector2(rect.size.x-90,24)),"UPGRADE / 0%d" % (i+1),12,Color("8194aa"))
			_label(Rect2(rect.position+Vector2(78,34),Vector2(rect.size.x-90,40)),definition.title,20,Color("63f5ce"))
			_label(Rect2(rect.position+Vector2(78,82),Vector2(rect.size.x-90,48)),definition.description.split(" ")[0],34,Color("dffff3"))
			_label(Rect2(rect.position+Vector2(16,130),Vector2(rect.size.x-32,54)),definition.description.substr(definition.description.find(" ")+1),12,Color("a4b3c6"))
	var stats: Array = game.player_stats()
	for i in range(stats.size()):
		var columns := 3 if i < 3 else 4
		var column := i if i < 3 else i-3
		var width := minf(230.0,(screen.x-48.0-(columns-1)*12)/columns)
		var x := (screen.x-columns*width-(columns-1)*12)*0.5+column*(width+12)
		var top: float = y+170 if i < 3 else y+278
		var height := 100.0 if i < 3 else 84.0
		_plate(Rect2(x,top,width,height))
		_label(Rect2(x+6,top+5,width-12,22),stats[i].name,12,Color("8194aa"))
		_label(Rect2(x+6,top+28,width-12,30),stats[i].value,27 if i < 3 else 23,Color("d9e8ed"))
		_label(Rect2(x+4,top+height-30,width-8,26),stats[i].detail,13 if i < 3 else 11,Color("91aaaf"))

func choose(index: int) -> void:
	if not game.choosing or game.paused or game.title_screen: return
	game.fire_armed = false
	game.upgrade(index)
	sync()

func _practice(screen: Vector2) -> void:
	var y := screen.y*0.5-24
	_label(Rect2(24,y-225,screen.x-48,48),"BOSS PRACTICE",30,Color("63f5ce"))
	_label(Rect2(24,y-177,screen.x-48,45),"LEFT STICK / DPAD: SELECT   A / LB: CONFIRM   B: BACK" if game.controls.using_gamepad else "A / D: BOSS   W / S: FLOOR   ARROW KEYS ALSO WORK   TAB + ENTER",15,Color("8194aa"))
	for i in range(9):
		var caption: String = game.boss.NAMES[3] if i == 7 else game.boss.NAMES[4] if i == 8 else game.boss.NAMES[i] if i < 3 else ["−","+","START","BACK (B)" if game.controls.using_gamepad else "BACK (Esc)"][i-3]
		var button := _button(game.practice.button(screen,i),caption,func(): game.practice.activate(game,i); sync())
		if i < 3 or i in [7,8]:
			button.toggle_mode = true
			button.set_pressed_no_signal((3 if i == 7 else (4 if i == 8 else i)) == game.practice.variant)
			if (3 if i == 7 else (4 if i == 8 else i)) == game.practice.variant: button.add_theme_color_override("font_color",Color("63f5ce"))
	var practice_buttons := _buttons()
	var tab_order := [0,1,2,7,8,3,4,5,6]
	for j in range(tab_order.size()):
		var current: Button = practice_buttons[tab_order[j]]
		current.focus_next = current.get_path_to(practice_buttons[tab_order[(j+1)%tab_order.size()]])
		current.focus_previous = current.get_path_to(practice_buttons[tab_order[(j+tab_order.size()-1)%tab_order.size()]])
	_label(Rect2(screen.x*0.5-110,y+10,220,48),"FLOOR %02d" % game.practice.depth,25)
	_label(Rect2(24,y+72,screen.x-48,56),"%d AUTO UPGRADES / NORMAL DAMAGE / NO RECORD" % (game.practice.depth-1),15,Color("8194aa"))

func _input(event: InputEvent) -> void:
	# Observe once, before GUI consumption, including neutral/release events.
	game.controls.observe_event(game,event)
	var direction: Vector2i = game.controls.menu_direction(event)
	if (event is InputEventJoypadButton or event is InputEventJoypadMotion) and (game.title_screen or game.paused or game.choosing or game.practice.selecting):
		sync()
		if direction != Vector2i.ZERO: _move_focus(direction)
		elif game.controls.gamepad_accept(event): _activate_focused()
		elif event.is_action_pressed("back"):
			game.controls.handle_event(game,event)
			sync()
		# Even held/neutral events must not reach Godot's default ui_* bindings.
		get_viewport().set_input_as_handled()
		return
	if not game.practice.selecting: return
	if event is InputEventKey and event.pressed and not event.echo:
		for action in ["practice_left","practice_right","practice_up","practice_down"]:
			if event.is_action_pressed(action):
				game.practice.input(game,event)
				get_viewport().set_input_as_handled()
				sync()
				return
