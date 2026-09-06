extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: " + message)
		failures += 1
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	check(is_equal_approx(game.enemy_health(0,15),6.0), "floor 15 chaser HP")
	check(is_equal_approx(game.enemy_health(1,15),3.0), "floor 15 sniper HP")
	check(game.enemy_health(1,1) == 1.0 and game.enemy_health(2,30) == 1.0, "sniper starting HP and shield HP")
	game.floor_number = 15
	game.new_floor()
	for enemy in game.enemies:
		check(is_equal_approx(enemy.hp,[6.0,3.0,1.0][enemy.kind]), "generated enemies use adjusted HP")
	game.time_left = game.time_limit
	var initial_time: float = game.time_left
	for kind in range(3):
		var enemy := {"kind":kind,"hp":2.0,"push":Vector2.ZERO,"dir":Vector2.RIGHT,"p":Vector2.ZERO}
		var before: float = game.time_left
		game.hurt_enemy(enemy,1,Vector2.RIGHT)
		check(game.time_left == before, "nonlethal hit gives no time")
		game.hurt_enemy(enemy,99,Vector2.RIGHT)
		check(is_equal_approx(game.time_left,before+[0.1,0.2,0.3][kind]), "type-specific kill bonus")
		var after: float = game.time_left
		game.hurt_enemy(enemy,99,Vector2.RIGHT)
		check(game.time_left == after, "overkill cannot award twice")
	check(is_equal_approx(game.time_left,initial_time+0.6), "bonus can exceed initial time limit")
	game.restart_attempt()
	check(game.time_left == game.time_limit, "retry resets accumulated kill time")
	game.power = 1.7
	game.fire_rate = 1.4
	game.move_bonus = 40
	var stats: Array = game.player_stats()
	check(stats[0].value == "1.70x" and stats[0].detail == "+70%", "damage UI reads current upgrade")
	check(stats[1].value == "1.40x" and stats[1].detail == "+40%", "fire rate UI reads current upgrade")
	check(stats[2].value == "285" and stats[2].detail == "+40", "movement UI reads current upgrade")
	print("PASS: HP scaling, kill time bonuses, overkill, retry and shared stats")
	game.free()
	quit(1 if failures else 0)
