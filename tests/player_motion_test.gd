extends SceneTree
const Motion = preload("res://scripts/player_motion.gd")
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: "+message)
		failures += 1
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.cells = {}
	for x in range(-5,6):
		for y in range(-5,6):
			if x != 0 or y != 0: game.cells[Vector2i(x,y)] = 0
	var rng_state: int = game.rng.state
	for rotation in range(4):
		# Rotate about the obstacle center to exercise all four corner approaches.
		var angle := rotation*PI/2
		var start := Vector2(16,16)+(Vector2(-6,-3)-Vector2(16,16)).rotated(angle)
		var movement := Vector2.RIGHT.rotated(angle)*4
		var position := start
		for i in range(18):
			var next := Motion.move(game,position,movement,5)
			check(game.walkable(next,5),"corner correction stays outside obstacle")
			check(position.distance_to(next)<=movement.length()+0.001,"assistance cannot boost speed")
			position = next
		check((position-start).dot(movement.normalized())>40,"grazing all four corners clears obstacle")
		check(game.slide(start,movement,5).is_equal_approx(start),"legacy enemy slide is unchanged")
	var stopped := Vector2(-6,16)
	for i in range(20): stopped = Motion.move(game,stopped,Vector2(4,0),5)
	check(stopped.x < -5 and is_equal_approx(stopped.y,16),"head-on wall does not steer sideways")
	check(Motion.move(game,stopped,Vector2.ZERO,5)==stopped,"released input stops immediately")
	var large_step := Motion.move(game,Vector2(-20,16),Vector2(100,0),5)
	check(large_step.x < -5,"large time steps cannot tunnel through obstacle")
	var open := Vector2(-80,-80)
	check(Motion.move(game,open,Vector2(7,3),5).is_equal_approx(open+Vector2(7,3)),"open-space motion is unchanged")
	check(game.rng.state == rng_state,"assistance consumes no gameplay randomness")
	game.free()
	if failures == 0: print("PASS: player corner escape, legacy enemy slide, head-on stop, speed, idle and swept safety")
	quit(1 if failures else 0)
