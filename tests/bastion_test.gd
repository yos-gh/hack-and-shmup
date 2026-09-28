extends SceneTree
## Bastion of Stars rules: arena, destructible turrets, orb absorption, missiles, load and retry.
const Fixture = preload("res://tools/balance_fixture.gd")
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
	game.depth_view.set_process(false)
	var bastion = game.boss.bastion
	for depth in [5,50]:
		Fixture.new().configure(game,depth,"standard",1,0)
		var e: Dictionary = game.enemies[0]
		check(game.boss_variant == 1 and game.time_limit == 0 and e.plates.size() == 12,"untimed shielded core")
		check(e.turrets.size() == (8 if depth >= 50 else 6),"turret tier grows at floor 50")
		check(not game.walkable(e.p+Vector2(70,0),game.PLAYER_HIT_RADIUS),"solid wall prevents a route behind the core")
		check(not game.attack_reaches(e.p,game.center(Vector2i(12,-7))),"mid-room pillars provide cover")
		for age in [0.0,2.0,5.0,10.0]:
			e.age = age
			for gun in range(e.turrets.size()): check(game.walkable(bastion.gun_position(e,gun),23),"animated guns stay reachable, clear of wall and cover")
		e.age = 0.0

		# Missiles are telegraphed ground strikes, not travelling bullets.
		var bullets_before: int = game.bullets.size()
		bastion.launch_missile(game,e,false)
		check(game.bullets.size() == bullets_before and e.slam[-1].time > 0.5,"missile is a warned strike without a damaging projectile")
		e.slam.clear()

		var turret: Dictionary = e.turrets[0]
		var shot := {"p":bastion.gun_position(e,0),"damage":turret.hp,"hostile":false}
		check(bastion.intercept_bullet(game,shot) and turret.hp == 0,"moving turret can be destroyed")
		bastion.advance(game.boss,game,e,bastion.TURRET_REBUILD+0.1,Vector2.LEFT)
		check(turret.hp == turret.max_hp,"turret rebuilds")

		game.player = e.p+Vector2(-310,0)
		game.build_flow()
		var peak := 0
		for frame in range(1800):
			game.grace = 2
			game.replay_input = {"movement":Vector2.ZERO,"aim":Vector2.RIGHT,"primary":false,"secondary":false}
			game._physics_process(1.0/60.0)
			peak = maxi(peak,game.bullets.size())
		check(peak < 500,"bounded projectile load at floor %d" % depth)

		# The energy orb swallows every player weapon it touches.
		game.bullets.clear()
		bastion.launch_orb(game,e)
		var orb: Dictionary = game.bullets[-1]
		check(bastion.orb_absorbs_area(game,orb.p,1),"orb absorbs shockwave")
		check(bastion.orb_absorbs_lance(game,[{"p":orb.p+Vector2(-80,0),"end":orb.p+Vector2(80,0),"width":20.0,"origin":orb.p+Vector2(-80,0)}]),"orb absorbs lance")
		game.emit_shot(orb.p,Vector2.RIGHT,100,1,false,100)
		game.bullets[-1]["probe"] = true
		game.grace = 2
		game._physics_process(1.0/60.0)
		check(not game.bullets.any(func(b): return b.get("probe",false)),"orb absorbs primary fire")
		turret.hp = 0
		game.restart_attempt()
		check(game.boss_variant == 1 and game.enemies[0].turrets[0].hp > 0,"retry restores the stronghold and its guns")
	game.free()
	if failures == 0: print("PASS: Bastion arena, destructible turrets, orb absorption, warned missiles and retry")
	quit(1 if failures else 0)
