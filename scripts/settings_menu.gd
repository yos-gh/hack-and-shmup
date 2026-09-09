extends CanvasLayer

var game: Node
var storage_path := ""
var panel: PanelContainer
var launcher: Button
var status: Label
var body: VBoxContainer
var waiting_action := ""
var binding_buttons: Dictionary = {}
const ACTION_LABELS := {"move_left":"Left / 左へ移動", "move_right":"Right / 右へ移動", "move_up":"Up / 上へ移動", "move_down":"Down / 下へ移動", "fire_primary":"Primary / 主射撃", "fire_secondary":"Secondary / 副射撃", "weapon_previous":"Previous weapon / 前の武器", "weapon_next":"Next weapon / 次の武器"}

func setup(host: Node) -> void:
	game = host
	layer = 20
	launcher = Button.new()
	launcher.text = "SETTINGS / F10"
	launcher.position = Vector2(20,90)
	launcher.pressed.connect(open)
	add_child(launcher)
	panel = PanelContainer.new()
	var theme := Theme.new()
	var background := StyleBoxFlat.new()
	background.bg_color = Color("0b111c")
	theme.set_stylebox("panel", "PanelContainer", background)
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("263847") if state in ["hover","pressed"] else Color("182735")
		box.border_color = Color("63f5ce")
		box.set_border_width_all(1 if state in ["hover","focus"] else 0)
		box.content_margin_top = 4
		box.content_margin_bottom = 4
		theme.set_stylebox(state,"Button",box)
	panel.theme = theme
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_" + side,24)
	panel.add_child(margin)
	var scroll := ScrollContainer.new()
	margin.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",10)
	scroll.add_child(body)
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
	waiting_action = ""
	_rebuild()

func close() -> void:
	waiting_action = ""
	panel.hide()
	game.fire_armed = false
	launcher.grab_focus()

func _label(text: String) -> void:
	var label := Label.new()
	label.text = text
	body.add_child(label)

func _rebuild() -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	binding_buttons.clear()
	_label("SETTINGS / 設定")
	_label("Changes apply immediately. Save to keep them. / 即時反映・保存で次回も有効")
	for entry in [["master_volume","Master / 全体"],["music_volume","Music / 音楽"],["effects_volume","Effects / 効果音"]]:
		_label(entry[1])
		var slider := HSlider.new()
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = game.preferences.get(entry[0])
		slider.custom_minimum_size.y = 28
		var property: String = entry[0]
		slider.value_changed.connect(func(value: float):
			game.preferences.set(property,value)
			game.apply_preferences())
		body.add_child(slider)
	var flash := CheckButton.new()
	flash.text = "Reduce death flash / 死亡時の閃光を軽減"
	flash.button_pressed = game.preferences.reduce_flash
	flash.toggled.connect(func(value: bool): game.preferences.reduce_flash = value; game.queue_redraw())
	body.add_child(flash)
	_label("Keys / キー割当 — A-Z, 0-9 (reserved keys excluded). Esc cancels.")
	for action in game.preferences.ACTIONS:
		var button := Button.new()
		button.text = ACTION_LABELS[action] + " : " + _binding_text(action)
		button.pressed.connect(func(): waiting_action = action; status.text = "Press a new key / キーを押してください (Esc: cancel)")
		body.add_child(button)
		binding_buttons[action] = button
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(status)
	for entry in [["Save / 保存",_save],["Reset / 初期値",_reset],["Close / 閉じる (Esc)",close]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(entry[1])
		body.add_child(button)
	body.get_child(3).grab_focus()

func _binding_text(action: String) -> String:
	var captions: PackedStringArray = []
	for event in InputMap.action_get_events(action): captions.append(event.as_text())
	return " / ".join(captions)

func handle_event(event: InputEvent) -> bool:
	if not panel.visible: return false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if waiting_action.is_empty(): close()
			else: waiting_action = ""; status.text = "Cancelled / 取り消しました"
		elif not waiting_action.is_empty():
			if game.preferences.set_binding(waiting_action,event.physical_keycode):
				game.apply_preferences()
				waiting_action = ""
				_rebuild()
			else: status.text = "Key unavailable or already assigned / 予約済み・重複したキーです"
	return true

func _input(event: InputEvent) -> void:
	if panel.visible and (not waiting_action.is_empty() or (event is InputEventKey and event.keycode == KEY_ESCAPE)):
		handle_event(event)
		get_viewport().set_input_as_handled()

func _save() -> void:
	if storage_path.is_empty():
		status.text = "Session only / 開発・テスト起動では保存しません"
		return
	var error: Error = game.preferences.save_file(storage_path)
	status.text = "Saved / 保存しました" if error == OK else "Save failed / 保存失敗: " + error_string(error)

func _reset() -> void:
	game.preferences.reset()
	game.apply_preferences()
	_rebuild()
