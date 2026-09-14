extends CanvasLayer

var game: Node
var storage_path := ""
var panel: PanelContainer
var launcher: Button
var status: Label
var body: VBoxContainer
var scroll: ScrollContainer
var footer: HBoxContainer
var sliders: Dictionary = {}
var waiting_action := ""
var binding_buttons: Dictionary = {}
const ACTION_LABELS := {"move_left":"Left", "move_right":"Right", "move_up":"Up", "move_down":"Down", "fire_primary":"Primary", "fire_secondary":"Secondary", "weapon_previous":"Previous weapon", "weapon_next":"Next weapon"}

func setup(host: Node) -> void:
	game = host
	layer = 20
	launcher = Button.new()
	launcher.text = "SETTINGS / F10"
	launcher.position = Vector2(20,90)
	launcher.pressed.connect(open)
	add_child(launcher)
	panel = PanelContainer.new()
	panel.theme = preload("res://scripts/menu_theme.gd").create()
	launcher.theme = panel.theme
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_" + side,24)
	panel.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation",12)
	margin.add_child(layout)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 40
	layout.add_child(status)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	layout.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",10)
	scroll.add_child(body)
	footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation",10)
	layout.add_child(footer)
	for entry in [["Save",_save],["Reset",_reset],["Close",close]]:
		var button := Button.new()
		button.text = entry[0]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(entry[1])
		footer.add_child(button)
	call_deferred("_load_main_preferences")

func _load_main_preferences() -> void:
	# SceneTree-script tests and embedded studies are intentionally session-only.
	if get_tree().current_scene != game: return
	if storage_path.is_empty(): storage_path = "user://settings.json"
	var error: Error = game.preferences.load_file(storage_path)
	game.apply_preferences()
	if error not in [OK, ERR_FILE_NOT_FOUND]:
		open()
		status.text = "Settings could not be loaded (%s). Defaults restored; file kept until Save." % error_string(error)

func _process(_delta: float) -> void:
	launcher.visible = (game.title_screen or game.paused) and not game.practice.selecting and not panel.visible

func open() -> void:
	if not (game.title_screen or game.paused) or game.practice.selecting: return
	panel.show()
	launcher.hide()
	waiting_action = ""
	_rebuild()

func close() -> void:
	waiting_action = ""
	panel.hide()
	game.fire_armed = false
	launcher.show()
	launcher.grab_focus()

func _label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(label)

func _rebuild(focus_action: String = "") -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	binding_buttons.clear()
	sliders.clear()
	status.text = "Esc: close"
	_label("SETTINGS")
	_label("Changes apply immediately. Save to keep them.")
	for entry in [["master_volume","Master"],["music_volume","Music"],["effects_volume","Effects"]]:
		_label(entry[1])
		var value_label: Label = body.get_child(body.get_child_count()-1)
		var caption: String = entry[1]
		var slider := HSlider.new()
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = game.preferences.get(entry[0])
		value_label.text = caption + "  %d%%" % roundi(slider.value*100)
		slider.custom_minimum_size.y = 28
		var property: String = entry[0]
		slider.value_changed.connect(func(value: float):
			value_label.text = caption + "  %d%%" % roundi(value*100)
			game.preferences.set(property,value)
			game.apply_preferences())
		body.add_child(slider)
		sliders[property] = slider
	var flash := CheckButton.new()
	flash.text = "Reduce flashes"
	flash.button_pressed = game.preferences.reduce_flash
	flash.toggled.connect(func(value: bool): game.preferences.reduce_flash = value; game.queue_redraw())
	body.add_child(flash)
	_label("Keys — A-Z, 0-9 (reserved keys excluded). Esc cancels.")
	for action in game.preferences.ACTIONS:
		var row := HBoxContainer.new()
		body.add_child(row)
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = ACTION_LABELS[action] + " : " + game.preferences.binding_caption(action)
		button.pressed.connect(func(): waiting_action = action; status.text = "Press a new key (Esc: cancel)")
		row.add_child(button)
		var restore := Button.new()
		restore.text = "Default"
		restore.disabled = not game.preferences.bindings.has(action)
		restore.pressed.connect(func():
			if game.preferences.reset_binding(action):
				game.apply_preferences()
				_rebuild(action)
			else: status.text = "Default key is in use")
		row.add_child(restore)
		binding_buttons[action] = button
	if binding_buttons.has(focus_action): binding_buttons[focus_action].grab_focus()
	else: sliders.master_volume.grab_focus()

func handle_event(event: InputEvent) -> bool:
	if not panel.visible: return false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if waiting_action.is_empty(): close()
			else: waiting_action = ""; status.text = "Cancelled"
		elif not waiting_action.is_empty():
			if event.ctrl_pressed or event.alt_pressed or event.meta_pressed or event.shift_pressed:
				status.text = "Release Ctrl, Alt, Shift and other modifiers; use a single key."
				return true
			var problem: String = game.preferences.binding_problem(waiting_action,event.physical_keycode)
			if game.preferences.set_binding(waiting_action,event.physical_keycode):
				game.apply_preferences()
				var completed_action := waiting_action
				waiting_action = ""
				_rebuild(completed_action)
			else:
				status.text = {"reserved":"Menu key is reserved", "unsupported":"Use A-Z or 0-9", "collision":"Key already assigned"}.get(problem,"Key unavailable")
	return true

func _input(event: InputEvent) -> void:
	if panel.visible and (not waiting_action.is_empty() or (event is InputEventKey and event.keycode == KEY_ESCAPE)):
		handle_event(event)
		get_viewport().set_input_as_handled()

func _save() -> void:
	if storage_path.is_empty():
		status.text = "Session only: development and test sessions do not save settings"
		return
	if not storage_is_persistent():
		status.text = "Session only: browser storage unavailable"
		return
	var error: Error = game.preferences.save_file(storage_path)
	status.text = "Saved" if error == OK else "Save failed: " + error_string(error)

func storage_is_persistent() -> bool:
	return not OS.has_feature("web") or OS.is_userfs_persistent()

func _reset() -> void:
	game.preferences.reset()
	game.apply_preferences()
	_rebuild()
