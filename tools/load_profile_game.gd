extends "res://scripts/game.gd"

# Development-only Game that times its own 2D draw callback for load_profile.gd.
var draw_usec := 0

func _draw() -> void:
	var started := Time.get_ticks_usec()
	super()
	draw_usec += Time.get_ticks_usec()-started
