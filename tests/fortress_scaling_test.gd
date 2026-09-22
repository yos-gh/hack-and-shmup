extends SceneTree
const Fixture = preload("res://tools/balance_fixture.gd")
const Balance = preload("res://scripts/combat_balance.gd")
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: "+message)
		failures += 1
func near(value: float, expected: float) -> bool:
	return absf(value-expected) < 0.001
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.depth_view.set_process(false)
	var prior_hp := -1.0
	var prior_gap := INF
	for depth in [5,10,15,20,25,30,40,50,75,100]:
		Fixture.new().configure(game,depth,"standard",3,0)
		var e: Dictionary = game.enemies[0]
		var dps: float = Balance.primary_dps(game.power,game.fire_rate,float(Engine.physics_ticks_per_second))
		var relative_hp: float = e.max_hp/dps
		var gap: float = lerpf(54.0,36.0,e.low)-16.0*e.mid
		check(relative_hp >= prior_hp,"relative core health does not fall on floor %d" % depth)
		check(gap <= prior_gap,"radial opening does not widen on floor %d" % depth)
		if depth >= 25: check(gap < prior_gap or depth > 50,"radial opening narrows before floor 50")
		if depth == 5:
			check(near(relative_hp,7.15) and near(gap,54.0),"floor 5 easing")
			check(e.speed_scale < 0.7 and e.attack_scale > 1.3 and e.bullet_scale < 0.85,"floor 5 mobility and attack easing")
		if depth == 25: check(near(relative_hp,11.0) and near(gap,36.0) and near(e.speed_scale,1.0),"floor 25 anchor")
		if depth == 50: check(near(relative_hp,11.0) and near(gap,20.0) and near(e.attack_scale,1.0),"floor 50 anchor")
		if depth == 100: check(near(relative_hp,13.2) and e.attack_scale < 1.0 and e.speed_scale > 1.0,"floor 100 outpaces player growth")
		prior_hp = relative_hp
		prior_gap = gap
		print("SCALING: floor %d relative HP %.2f gap %.1f speed %.3f cadence %.3f" % [depth,relative_hp,gap,e.speed_scale,e.attack_scale])
	game.free()
	if failures == 0: print("PASS: fortress scales across low, middle and post-50 floors")
	quit(1 if failures else 0)
