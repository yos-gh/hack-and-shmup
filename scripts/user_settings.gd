extends RefCounted

# Explicit I/O: constructing settings never reads or writes player preferences.
# Menu integration owns when to load, apply and save; run records are excluded.
const VERSION := 1
const PATH := "user://settings.json"
const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "fire_primary", "fire_secondary", "weapon_previous", "weapon_next"]
const RESERVED_KEYS := [KEY_ESCAPE, KEY_ENTER, KEY_SPACE, KEY_M, KEY_B, KEY_R, KEY_F6, KEY_1, KEY_2, KEY_3, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]
var master_volume := 1.0
var music_volume := 1.0
var effects_volume := 1.0
var reduce_shake := false
var reduce_flash := false
var bindings: Dictionary = {}

func reset() -> void:
	master_volume = 1.0
	music_volume = 1.0
	effects_volume = 1.0
	reduce_shake = false
	reduce_flash = false
	bindings.clear()

func serialize() -> Dictionary:
	return {"version": VERSION, "master_volume": master_volume, "music_volume": music_volume,
		"effects_volume": effects_volume, "reduce_shake": reduce_shake,
		"reduce_flash": reduce_flash, "bindings": bindings.duplicate(true)}

func _volume(value: Variant) -> float:
	if not (value is float or value is int): return 1.0
	if not is_finite(float(value)): return 1.0
	return clampf(float(value), 0.0, 1.0)

func _valid_key(value: Variant) -> bool:
	if not (value is int or value is float): return false
	var number := float(value)
	if not is_finite(number) or number != floor(number): return false
	# Initial remapping supports physical Latin letters and digits only.
	return ((number >= KEY_A and number <= KEY_Z) or (number >= KEY_0 and number <= KEY_9)) and int(number) not in RESERVED_KEYS

func deserialize(data: Variant) -> Error:
	reset()
	if not data is Dictionary: return ERR_INVALID_DATA
	var version: Variant = data.get("version")
	if not (version is int or version is float): return ERR_UNAVAILABLE
	if version != VERSION: return ERR_UNAVAILABLE
	master_volume = _volume(data.get("master_volume", 1.0))
	music_volume = _volume(data.get("music_volume", 1.0))
	effects_volume = _volume(data.get("effects_volume", 1.0))
	reduce_shake = data.get("reduce_shake") is bool and data.get("reduce_shake")
	reduce_flash = data.get("reduce_flash") is bool and data.get("reduce_flash")
	var saved: Variant = data.get("bindings", {})
	if saved is Dictionary:
		# Validate the complete mapping; ambiguous bindings fall back together.
		var candidate: Dictionary = {}
		for action in ACTIONS:
			if saved.has(action):
				if not _valid_key(saved[action]): return OK
				candidate[action] = int(saved[action])
		if _unique_keys(candidate): bindings = candidate
	return OK

func _unique_keys(candidate: Dictionary) -> bool:
	var used: Array[int] = []
	for action in ACTIONS:
		var keys: Array[int] = []
		if candidate.has(action): keys.append(candidate[action])
		else:
			for event in ProjectSettings.get_setting("input/" + action, {}).get("events", []):
				if event is InputEventKey: keys.append(event.physical_keycode if event.physical_keycode != 0 else event.keycode)
		for key in keys:
			if key in used: return false
			used.append(key)
	return true

func set_binding(action: String, physical_key: int) -> bool:
	if action not in ACTIONS or not _valid_key(physical_key): return false
	var candidate := bindings.duplicate()
	candidate[action] = physical_key
	if not _unique_keys(candidate): return false
	bindings = candidate
	return true

func reset_binding(action: String) -> bool:
	if action not in ACTIONS: return false
	var candidate := bindings.duplicate()
	candidate.erase(action)
	if not _unique_keys(candidate): return false
	bindings = candidate
	return true

func binding_problem(action: String, physical_key: int) -> String:
	if action not in ACTIONS: return "unsupported"
	if physical_key in RESERVED_KEYS: return "reserved"
	if not _valid_key(physical_key): return "unsupported"
	var candidate := bindings.duplicate()
	candidate[action] = physical_key
	return "" if _unique_keys(candidate) else "collision"

func binding_caption(action: String) -> String:
	var captions: PackedStringArray = []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			captions.append(OS.get_keycode_string(event.physical_keycode if event.physical_keycode else event.keycode))
		elif event is InputEventMouseButton:
			captions.append({MOUSE_BUTTON_LEFT:"LMB",MOUSE_BUTTON_RIGHT:"RMB",MOUSE_BUTTON_WHEEL_UP:"Wheel Up",MOUSE_BUTTON_WHEEL_DOWN:"Wheel Down"}.get(event.button_index,event.as_text()))
	return "/".join(captions)

func controls_caption() -> String:
	return "%s/%s/%s/%s MOVE   %s FIRE   %s SUB   %s / %s SWITCH" % [binding_caption("move_up"),binding_caption("move_left"),binding_caption("move_down"),binding_caption("move_right"),binding_caption("fire_primary"),binding_caption("fire_secondary"),binding_caption("weapon_previous"),binding_caption("weapon_next")]

func apply_bindings() -> void:
	for action in ACTIONS:
		InputMap.action_erase_events(action)
		if bindings.has(action):
			var event := InputEventKey.new()
			event.physical_keycode = bindings[action]
			InputMap.action_add_event(action, event)
		else:
			for event in ProjectSettings.get_setting("input/" + action, {}).get("events", []):
				InputMap.action_add_event(action, event.duplicate())

func load_file(path: String = PATH) -> Error:
	reset()
	if not FileAccess.file_exists(path): return ERR_FILE_NOT_FOUND
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return FileAccess.get_open_error()
	if file.get_length() > 65536: return ERR_INVALID_DATA
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK: return ERR_PARSE_ERROR
	return deserialize(json.data)

func save_file(path: String = PATH) -> Error:
	# Write completely before replacing the old file. Never serialize objects.
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(serialize(), "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: return error
	return DirAccess.rename_absolute(path + ".tmp", path)


