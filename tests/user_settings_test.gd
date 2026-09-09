extends SceneTree

const Settings = preload("res://scripts/user_settings.gd")
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: " + message)
		failures += 1
func run() -> void:
	var settings := Settings.new()
	var path := "user://settings-test-%d.json" % OS.get_process_id()
	check(settings.load_file(path) == ERR_FILE_NOT_FOUND, "missing preferences use defaults")
	settings.music_volume = 0.25
	settings.effects_volume = 0.0
	settings.reduce_flash = true
	check(settings.set_binding("move_left", KEY_J), "unused physical key accepted")
	check(not settings.set_binding("move_right", KEY_J), "custom binding collision rejected")
	check(not settings.set_binding("move_right", KEY_W), "default binding collision rejected")
	check(not settings.set_binding("move_left", KEY_ESCAPE), "escape remains available")
	check(not settings.set_binding("confirm", KEY_K), "menu controls remain protected")
	check(settings.save_file(path) == OK, "first save succeeds")
	var restored := Settings.new()
	check(restored.load_file(path) == OK and restored.serialize() == settings.serialize(), "disk round trip preserves settings")
	settings.music_volume = 0.5
	check(settings.save_file(path) == OK and restored.load_file(path) == OK and restored.music_volume == 0.5, "existing save atomically replaced")
	var copy := settings.serialize()
	copy.bindings.clear()
	check(settings.bindings.size() == 1, "serialized data is independent")
	settings.apply_bindings()
	var event := InputEventKey.new()
	event.physical_keycode = KEY_J
	check(event.is_action("move_left"), "physical remap is applied")
	settings.reset()
	settings.apply_bindings()
	event.physical_keycode = KEY_A
	check(event.is_action("move_left"), "default input restored")
	check(InputMap.action_get_events("weapon_next").size() == 2, "wheel and keyboard defaults retained")
	check(settings.deserialize({"version":1,"master_volume":-2,"music_volume":5,"effects_volume":"bad","reduce_flash":"true","bindings":{"move_left":KEY_D}}) == OK, "partially invalid document handled")
	check(settings.master_volume == 0 and settings.music_volume == 1 and settings.effects_volume == 1 and not settings.reduce_flash and settings.bindings.is_empty(), "values clamped and colliding map rejected")
	settings.deserialize({"version":1,"master_volume":NAN,"music_volume":INF,"bindings":{"move_left":65.5}})
	check(settings.master_volume == 1 and settings.music_volume == 1 and settings.bindings.is_empty(), "nonfinite and fractional values rejected")
	check(settings.deserialize({"version":99}) == ERR_UNAVAILABLE and settings.serialize() == Settings.new().serialize(), "unknown version returns defaults and error")
	check(settings.deserialize({"version":"1"}) == ERR_UNAVAILABLE, "invalid version type rejected")
	check(settings.deserialize([]) == ERR_INVALID_DATA, "nonobject document rejected")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{truncated")
	file.close()
	check(restored.load_file(path) == ERR_PARSE_ERROR and restored.bindings.is_empty(), "corrupt file clears stale preferences")
	check(FileAccess.get_file_as_string(path) == "{truncated", "loading does not overwrite a damaged file")
	DirAccess.remove_absolute(path)
	if failures == 0: print("PASS: settings persistence, validation, isolation and physical bindings")
	quit(1 if failures else 0)

