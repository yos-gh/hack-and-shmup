extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	game._unhandled_input(key)
	print("Native title Esc dispatched; process must exit before the timeout")
	await create_timer(0.2).timeout
	push_error("FAIL: native title Esc did not exit")
	quit(1)
