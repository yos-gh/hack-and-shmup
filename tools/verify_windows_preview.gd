extends SceneTree

func _init() -> void:
	var forbidden_paths := ["res://addons/sentry", "res://assets/catalog.json"]
	for path in forbidden_paths:
		if FileAccess.file_exists(path) or DirAccess.open(path) != null:
			push_error("FAIL: preview package contains %s" % path)
			quit(1)
			return
	print("PASS: preview package has no Sentry runtime or asset manifest")
	quit(0)
