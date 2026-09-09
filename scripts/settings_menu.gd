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
	for entry in [["Save / 保存",_save],["Reset / 初期値",_reset],["Close / 閉じる",close]]:
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
	status.text = "Esc: close / 閉じる"
	_label("SETTINGS / 設定")
	_label("Changes apply immediately. Save to keep them. / 即時反映・保存で次回も有効")
	for entry in [["master_volume","Master / 全体"],["music_volume","Music / 音楽"],["effects_volume","Effects / 効果音"]]:
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
	flash.text = "Reduce death flash / 死亡時の閃光を軽減"
	flash.button_pressed = game.preferences.reduce_flash
	flash.toggled.connect(func(value: bool): game.preferences.reduce_flash = value; game.queue_redraw())
	body.add_child(flash)
	_label("Keys / キー割当 — A-Z, 0-9 (reserved keys excluded). Esc cancels.")
	for action in game.preferences.ACTIONS:
		var row := HBoxContainer.new()
		body.add_child(row)
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = ACTION_LABELS[action] + " : " + game.preferences.binding_caption(action)
		button.pressed.connect(func(): waiting_action = action; status.text = "Press a new key / キーを押してください (Esc: cancel)")
		row.add_child(button)
		var restore := Button.new()
		restore.text = "Default / 初期値"
		restore.disabled = not game.preferences.bindings.has(action)
		restore.pressed.connect(func():
			if game.preferences.reset_binding(action):
				game.apply_preferences()
				_rebuild(action)
			else: status.text = "Default key is in use / 初期キーが他の操作で使用されています")
		row.add_child(restore)
		binding_buttons[action] = button
	if binding_buttons.has(focus_action): binding_buttons[focus_action].grab_focus()
	else: sliders.master_volume.grab_focus()

func handle_event(event: InputEvent) -> bool:
	if not panel.visible: return false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if waiting_action.is_empty(): close()
			else: waiting_action = ""; status.text = "Cancelled / 取り消しました"
		elif not waiting_action.is_empty():
			if event.ctrl_pressed or event.alt_pressed or event.meta_pressed or event.shift_pressed:
				status.text = "Use a single key / Ctrl・Alt・Shiftなどを離してください"
				return true
			var problem: String = game.preferences.binding_problem(waiting_action,event.physical_keycode)
			if game.preferences.set_binding(waiting_action,event.physical_keycode):
				game.apply_preferences()
				var completed_action := waiting_action
				waiting_action = ""
				_rebuild(completed_action)
			else:
				status.text = {"reserved":"Menu key is reserved / メニュー操作に予約されたキーです", "unsupported":"Use A-Z or 0-9 / 英字・数字の単独キーを指定してください", "collision":"Key already assigned / 他の操作に割り当て済みです"}.get(problem,"Key unavailable / 使用できないキーです")
	return true

func _input(event: InputEvent) -> void:
	if panel.visible and (not waiting_action.is_empty() or (event is InputEventKey and event.keycode == KEY_ESCAPE)):
		handle_event(event)
		get_viewport().set_input_as_handled()

func _save() -> void:
	if storage_path.is_empty():
		status.text = "Session only / 開発・テスト起動では保存しません"
		return
	if not storage_is_persistent():
		status.text = "Session only: browser storage unavailable / ブラウザー保存が使えないため今回のみ有効です"
		return
	var error: Error = game.preferences.save_file(storage_path)
	status.text = "Saved / 保存しました" if error == OK else "Save failed / 保存失敗: " + error_string(error)

func storage_is_persistent() -> bool:
	return not OS.has_feature("web") or OS.is_userfs_persistent()

func _reset() -> void:
	game.preferences.reset()
	game.apply_preferences()
	_rebuild()
