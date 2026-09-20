extends SceneTree
const Fixture = preload("res://tools/balance_fixture.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.depth_view.set_process(false)
	var fixture := Fixture.new()
	var failures := 0
	# Bound low/high depth and primary/sub-focused extremes for each boss.
	# At 120px the enlarged bodies catch all Scatter pellets; that deliberate
	# close-range burst is measured separately, not subject to the 10s target.
	for sample in [[5,"standard",0],[15,"sub",1],[100,"primary",2],[100,"sub",1]]:
		for variant in range(3):
			var row: Dictionary = fixture.measure(game,sample[0],sample[1],variant,sample[2],true,1801,240.0)
			if row.outcome != "clear" or row.seconds < 10.0 or row.seconds > 30.0:
				push_error("FAIL: combined boss duration " + JSON.stringify(row))
				failures += 1
			else: print("PASS: combined boss %d floor %d %s weapon %d: %.2fs" % [variant,sample[0],sample[1],sample[2],row.seconds])
	game.free()
	quit(1 if failures else 0)
