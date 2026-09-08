extends RefCounted

# In-memory retry baseline. Deliberately excludes RNG, upgrades, deaths and record:
# retries keep the original progression and random-stream behavior.
var enemies: Array[Dictionary] = []
var kills := 0
var spawn := Vector2.ZERO
var time_limit := 0.0

func capture(game) -> void:
	enemies = game.enemies.duplicate(true)
	kills = game.kills
	spawn = game.spawn_point
	time_limit = game.time_limit

func restore(game) -> void:
	game.enemies = enemies.duplicate(true)
	game.kills = kills
	game.player = spawn
	game.time_left = time_limit
