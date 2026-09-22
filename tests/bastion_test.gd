extends SceneTree
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
	for depth in [5,25,50]:
		Fixture.new().configure(game,depth,"standard",4,0)
		var e: Dictionary = game.enemies[0]
		check(game.boss_variant == 4 and game.rooms[1].size == Vector2i(32,42),"practice opens tall bastion arena")
		check(e.turrets.size() == (8 if depth >= 50 else 6),"turret tier")
		check(e.p.x == game.center(Vector2i(26,1)).x,"stronghold occupies the east wall")
		check(game.boss.bastion.gun_position(e,0).y < e.p.y-530 and game.boss.bastion.gun_position(e,5).y > e.p.y+530,"emplacements span the taller room")
		var arm: PackedVector2Array = game.boss.bastion.arm_joints(e,0)
		check(arm.size() == 3 and arm[0].x > arm[1].x and arm[1].x > arm[2].x,"each gun has a wall socket and articulated elbow")
		e.age = 1.0
		check(arm[1].distance_to(game.boss.bastion.arm_joints(e,0)[1]) > 5,"arm elbow articulates as the gun moves")
		e.age = 0.0
		check(not game.walkable(e.p+Vector2(70,0),game.PLAYER_HIT_RADIUS),"solid wall prevents a route behind the core")
		check(game.attack_reaches(game.boss.bastion.gun_position(e,2),e.p+Vector2(-300,0)),"open center lane preserves turret pressure")
		check(not game.attack_reaches(e.p,game.center(Vector2i(12,-7))),"mid-room pillars provide cover when approached")
		check(e.turrets[0].role == 0 and e.turrets[1].role == 1 and e.turrets[2].role == 2,"distinct fan, gatling and seeker emplacements")
		check(game.time_limit == 0 and e.plates.size() == 12,"untimed shielded core")
		var bullets_before: int = game.bullets.size()
		game.boss.bastion.launch_missile(game,e,false)
		var staged: Dictionary = e.slam[-1]
		check(game.bullets.size() == bullets_before and staged.source == game.boss.bastion.missile_port(e,staged.p),"missile launch visual adds no damaging projectile")
		check(game.boss.bastion.missile_visual_position(staged).distance_to(staged.source) < 0.1,"missile begins at wall launcher")
		staged.time = staged.warning*0.85
		check(game.boss.bastion.missile_visual_position(staged).x == staged.source.x and game.boss.bastion.missile_visual_position(staged).y < staged.source.y,"missile launches toward the top of the screen")
		staged.time = staged.warning*0.2
		check(game.boss.bastion.missile_visual_position(staged).x == staged.p.x and game.boss.bastion.missile_visual_position(staged).y < staged.p.y,"missile returns above the warned landing point")
		e.slam.clear()
		game.boss.bastion.turret_burst(game.boss,e,1,false)
		check(game.boss.salvos.size() >= 3,"gatling emplacement fires a burst")
		game.boss.salvos.clear()
		game.boss.bastion.pattern(game.boss,game,e,"guided",false)
		check(game.boss.salvos.any(func(s): return s.get("guided",false) and s.offsets.size() > 1),"seeker launches a homing fan")
		game.boss.salvos.clear()
		var turret: Dictionary = e.turrets[0]
		var shot := {"p":game.boss.bastion.gun_position(e,0),"damage":turret.hp,"hostile":false}
		check(game.boss.bastion.intercept_bullet(game,shot) and turret.hp == 0,"moving turret can be destroyed")
		game.boss.bastion.advance(game.boss,game,e,7.1,Vector2.LEFT)
		check(turret.hp == turret.max_hp,"turret rebuilds")
		game.player = e.p+Vector2(-310,0)
		game.build_flow()
		var seen := {}
		var peak := 0
		for frame in range(1800):
			game.grace = 2
			game.replay_input = {"movement":Vector2.ZERO,"aim":Vector2.RIGHT,"primary":false,"secondary":false}
			game._physics_process(1.0/60.0)
			for b in game.bullets:
				if b.has("pattern"): seen[b.pattern] = true
				if b.get("energy_orb",false): seen["orb"] = true
			if not e.slam.is_empty(): seen["missile"] = true
			peak = maxi(peak,game.bullets.size())
		check(seen.has("radial") and seen.has("fan") and seen.has("direct") and seen.has("guided") and seen.has("orb") and seen.has("missile"),"layered pattern catalog at floor %d" % depth)
		check(peak < 500,"projectile budget")
		print("BASTION: floor %d patterns=%s peak=%d" % [depth,seen.keys(),peak])
		game.bullets.clear()
		game.boss.bastion.launch_orb(game,e)
		var orb: Dictionary = game.bullets[-1]
		check(orb.orb_phase == "charge" and orb.orb_radius == 18,"orb begins small on the core")
		check(game.boss.bastion.orb_absorbs_area(game,orb.p,1),"orb absorbs shockwave")
		check(game.boss.bastion.orb_absorbs_lance(game,[{"p":orb.p+Vector2(-80,0),"end":orb.p+Vector2(80,0),"width":20.0}]),"orb absorbs lance")
		for frame in range(66):
			game.grace = 2
			game._physics_process(1.0/60.0)
		check(orb.orb_phase == "flight" and orb.orb_radius >= 49,"orb doubles in size before launch")
		var launch_speed: float = orb.v.length()
		for frame in range(38):
			game.grace = 2
			game._physics_process(1.0/60.0)
		check(orb.v.length() > launch_speed+50,"orb accelerates toward the player")
		game.emit_shot(orb.p,Vector2.RIGHT,100,1,false,100)
		game.bullets[-1]["probe"] = true
		game.grace = 2
		game._physics_process(1.0/60.0)
		check(not game.bullets.any(func(b): return b.get("probe",false)) and orb.orb_flash > 0,"orb absorbs primary fire")
		turret.hp = 0
		game.restart_attempt()
		check(game.boss_variant == 4 and game.enemies[0].turrets[0].hp > 0,"retry restores selected stronghold and its guns")
	game.free()
	if failures == 0: print("PASS: bastion layout, destructible arms, regeneration and layered attacks")
	quit(1 if failures else 0)
