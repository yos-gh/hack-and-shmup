extends SceneTree
## Abyss Wyrm rules: 25-floor placement, arena cover, telegraphed breaches, the
## crawling first form and its three patterns, the shielded core, the form
## split, the second form's movement (never wedged on cover), charge, body
## beams, the bombardment with its chasing beam, and the debug shortcuts.
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: "+message)
		failures += 1

func step(game, seconds: float, movement: Vector2 = Vector2.ZERO) -> void:
	for i in range(maxi(1,roundi(seconds*60))):
		game.grace = 2
		game.replay_input = {"movement":movement,"aim":Vector2.RIGHT,"primary":false,"secondary":false}
		game._physics_process(1.0/60.0)

func until(game, condition: Callable, limit: float) -> bool:
	var frames := 0
	while not condition.call() and frames < limit*60:
		step(game,1.0/60.0)
		frames += 1
	return condition.call()

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.depth_view.set_process(false)
	var wyrm = game.boss.wyrm
	game.start_run()
	for depth in [25,50,75,100]:
		game.floor_number = depth
		game.new_floor()
		check(game.boss_variant == 3,"floor %d is the Abyss Wyrm" % depth)
	game.practice.variant = 3
	game.practice.depth = 25
	game.practice.start(game)
	game.set_physics_process(false)
	game.discovered[1] = true
	var e: Dictionary = game.enemies[0]
	var room: Rect2i = game.rooms[1]
	check(room.size.x*room.size.y > 56*44,"arena is larger than before")
	var box: Rect2 = wyrm.inner(e)
	for cell in wyrm.COVER_CELLS:
		check(not game.walkable(game.center(cell)),"pillar is solid cover")
		var edge: int = mini(mini(cell.x-room.position.x,room.end.x-cell.x-2),mini(cell.y-room.position.y,room.end.y-cell.y-2))
		check(edge <= 5,"pillars line the outer wall")
		check(not box.grow(wyrm.HEAD_CLEAR).intersects(Rect2(Vector2(cell)*game.TILE,Vector2.ONE*game.TILE*2)),"the head's open middle holds no cover")
	check(is_equal_approx(e.hp,e.max_hp) and is_equal_approx(e.hp_floor,e.phase_hp*wyrm.SECOND_FORM),"two forms share the health bar")

	# First form: holes are marked before anything rises; nothing can be hit underground.
	game.player = e.home+Vector2(-620,0)
	check(until(game,func(): return e.active,5.0),"the wyrm wakes when the player enters")
	check(e.state == "under" and e.head_hole != Vector2.INF and e.submerged,"breach points are marked before the wyrm rises")
	check(e.head_hole.distance_to(game.player) >= 300,"the head breaches away from the player")
	check(game.enemy_bullet_radius(e) == 0.0 and not wyrm.touches(e,e.head_hole,game.PLAYER_HIT_RADIUS),"a submerged wyrm cannot be hit or touched")
	check(until(game,func(): return e.state == "exposed",3.0) and not e.submerged and e.pattern == "beam","the head rises after its warning")
	var hole: Vector2 = e.hole
	step(game,1.1)
	check(e.lead.distance_to(hole) > 300 and e.segments.filter(func(s): return s.z >= 0).size() >= 3,"the head crawls away from its hole and draws the body out")
	step(game,0.3)
	check(game.boss.lasers.any(func(b): return b.get("triad",false) and b.width >= 100),"the first breach opens with the broad tracking beam")
	# The core and its plates: a broken plate opens the core from that side,
	# and the hole stays on that bearing while the head turns.
	var hp: float = e.hp
	game.hurt_enemy(e,1,Vector2.LEFT)
	check(e.hp == hp and e.plates[0].hp < e.plates[0].max_hp,"plates guard the core")
	wyrm.damage_plate(game,e,0,e.plates[0].max_hp)
	game.hurt_enemy(e,1,Vector2.LEFT)
	check(e.hp == hp-1,"a broken plate exposes the core")
	e.face = e.face.rotated(1.2)
	game.hurt_enemy(e,1,Vector2.LEFT)
	check(e.hp == hp-2,"the hole keeps its bearing as the head turns")
	e.hp = hp
	check(game.enemy_bullet_radius(e) == wyrm.CORE,"the exposed core is the weak point")
	var link: Dictionary = e.segments.filter(func(s): return s.z >= 0)[0]
	check(wyrm.intercept_bullet(game,{"p":link.p,"damage":1.0,"hostile":false}),"armoured links stop player shots")
	check(not wyrm.intercept_bullet(game,{"p":e.p,"damage":1.0,"hostile":false}),"shots reach the core")
	check(until(game,func(): return e.state == "dive",12.0),"the wyrm dives after its pattern")
	check(until(game,func(): return e.state == "under",6.0) and e.rise == 1 and e.segments.all(func(s): return s.z < 0),"the whole body sinks before the next breach")
	check(until(game,func(): return e.state == "exposed",4.0) and e.pattern == "rings","the second breach fires drifting rings")
	step(game,2.0)
	check(e.volleys.any(func(v): return v.kind == "ring") or game.bullets.size() > 60,"rings fill the arena")
	check(until(game,func(): return e.state == "exposed" and e.pattern == "barrage" and e.beam_started,25.0),"the third breach calls the bombardment")
	check(e.windup > 0 and e.shells.is_empty(),"the head rears before any shell is marked")
	step(game,wyrm.WINDUP+0.05)
	var shells: Array = e.shells
	check(shells.size() >= 20,"shells cover the whole arena")
	var reach := 0.0
	for shell in shells: reach = maxf(reach,shell.p.distance_to(e.home))
	check(reach > 700,"the bombardment reaches the outer wall")
	var first_wave: Array = shells.filter(func(s): return s.wave == 0)
	var open_ground := false
	for k in range(36):
		var probe: Vector2 = game.player+Vector2.from_angle(k*TAU/12)*(80+70*(k/12))
		if not game.walkable(probe): continue
		if first_wave.all(func(s): return s.p.distance_to(probe) > s.r+game.PLAYER_HIT_RADIUS): open_ground = true
	check(open_ground,"the first wave leaves open ground beside the player")
	var row: int = int(floor((game.player.y-e.shell_origin.y)/wyrm.SHELL_CELL))
	check(first_wave.all(func(s): return int(floor((s.p.y-24-e.shell_origin.y)/wyrm.SHELL_CELL)) != row or int(floor((s.p.y+24-e.shell_origin.y)/wyrm.SHELL_CELL)) != row),"the first wave leaves the player's row open to run along")
	check(shells.all(func(s): return s.impact >= s.warn-0.001 or s.wave == 0) and first_wave.all(func(s): return s.impact >= 1.9),"every shell is marked before it lands")
	check(e.rear > 0.9 and not game.boss.lasers.any(func(b): return b.get("chase",false)),"the head rears to spit, and rests before the chasing beam")
	step(game,wyrm.BEAM_GAP+0.05)
	check(e.rear < 0.05 and game.boss.lasers.any(func(b): return b.get("chase",false) and b.turn_rate <= 0.45),"a chasing beam joins the bombardment once the head is down")

	# The form cannot be skipped by one large hit; the breach follows.
	game.hurt_enemy(e,e.max_hp,Vector2.RIGHT,0,true)
	check(is_equal_approx(e.hp,e.hp_floor) and e.hp > 0,"damage stops at the end of the first form")
	step(game,1.0/60.0)
	check(e.phase == 2 and e.state in ["breach_dive","breach_wait"] and e.shells.is_empty(),"losing the first form starts the breach")
	check(game.sound.music_lib.track_for(game) == "boss_recca_dark_v2","the second form has its own track")
	hp = e.hp
	game.hurt_enemy(e,10,Vector2.RIGHT,0,true)
	check(e.hp == hp,"the wyrm is untouchable while it tunnels")
	check(until(game,func(): return e.state == "roam",6.0) and e.hp_floor == 0.0,"the second form tears free")
	step(game,10.0)
	check(e.segments.filter(func(s): return s.z >= 0).size() == wyrm.SEGMENTS+1,"every link has left the hole")
	var spaced := true
	for i in range(1,e.segments.size()-1):
		if e.segments[i].p.distance_to(e.segments[i-1].p) > wyrm.SPACING+1: spaced = false
	check(spaced,"links follow the head's path at fixed spacing")
	# Hug a pillar, where the old head used to wedge itself; it must keep moving.
	game.player = game.center(wyrm.COVER_CELLS[0])+Vector2(32,96)
	var stalled := 0.0
	var worst := 0.0
	var last: Vector2 = e.lead
	for i in range(60*20):
		step(game,1.0/60.0)
		if e.move_mode in ["prowl","stalk","evade"] and e.lead.distance_to(last) < 0.2: stalled += 1.0/60.0
		else: stalled = 0.0
		worst = maxf(worst,stalled)
		last = e.lead
		if not e.move_mode in ["charge","recoil"] and not wyrm.inner(e).grow(2).has_point(e.lead): worst = 99.0
	check(worst < 1.0,"the head never stalls or strays toward cover outside a charge")
	# Charge: the lane is fixed before the dash and keeps the head off cover.
	wyrm.reset_path(e,e.home,PI)
	e.traveled = wyrm.body_length()
	e.charge_cd = 0
	e.barrage_cd = 99
	e.cage_cd = 99
	e.move_mode = "prowl"
	e.move_time = 0
	game.player = e.home+Vector2(-600,0)
	step(game,1.0/60.0)
	if e.move_mode == "charge_warning":
		var lane: Vector2 = e.charge_end
		step(game,0.4)
		check(e.charge_end == lane,"the charge lane does not follow the player")
		check(wyrm.clear_disc(game,lane,wyrm.HEAD_CLEAR),"the charge stops short of walls and pillars")
		check(until(game,func(): return e.move_mode == "prowl",8.0),"after a charge the head returns to the middle")
	else: check(false,"a ready charge begins with a warning")
	# Body beams are telegraphed and keep their heading.
	e.beam_cd = 0
	e.charge_cd = 99
	e.cage_cd = 99
	e.move_mode = "prowl"
	e.move_time = 5
	step(game,1.0/60.0)
	# Only the beams just raised; an older volley may still be firing.
	var beams: Array = game.boss.lasers.filter(func(b): return b.has("mount") and b.warning > b.warning_total-0.1)
	check(beams.size() >= 1 and beams.all(func(b): return b.warning > 0.5),"body beams start with a warning")
	if not beams.is_empty():
		var heading: Vector2 = beams[0].heading
		step(game,0.5)
		check(beams[0].heading == heading,"body beams never swing")
	e.move_mode = "prowl"
	e.move_time = 5
	e.barrage_cd = 0
	step(game,1.0/60.0)
	check(e.move_mode == "barrage" and e.windup > 0,"the second form calls the bombardment too")
	var neck: float = e.face.angle()
	step(game,wyrm.WINDUP+0.05)
	check(e.shells.size() >= 20 and absf(angle_difference(neck,e.face.angle())) < 2.4*(wyrm.WINDUP+0.1),"the bombardment starts without snapping the neck")
	# The shock cage: a warned ring that a Shockwave clears.
	e.shells.clear()
	game.bullets.clear()
	wyrm.start_cage(game,e)
	step(game,wyrm.CAGE_WARNING+0.05)
	var caged: int = game.bullets.filter(func(b): return b.hostile and absf(b.p.distance_to(e.cages[0].p if not e.cages.is_empty() else game.player)-wyrm.CAGE_RADIUS) < 120).size()
	check(game.bullets.filter(func(b): return b.hostile).size() >= wyrm.CAGE_COUNT*2-20,"the cage closes a double ring around the player")
	step(game,2.2)
	game.sub_weapon = 1
	game.sub_cd = 0
	var before: int = game.bullets.filter(func(b): return b.hostile and b.p.distance_to(game.player) <= game.SHOCK_RADIUS).size()
	game.fire_sub(Vector2.RIGHT)
	check(before > 0 and game.bullets.filter(func(b): return b.hostile and b.p.distance_to(game.player) <= game.SHOCK_RADIUS).is_empty(),"a Shockwave clears the closing cage")
	# The last stretch of the second form steps the pressure up once more.
	e.hp = e.phase_hp*wyrm.SECOND_FORM*0.2
	e.move_mode = "prowl"
	step(game,1.0/60.0)
	check(wyrm.frenzied(e) and e.frenzy and e.cage_cd <= 1.5,"low health sends the second form into a frenzy")
	# Shells kill on open ground, over cover too.
	game.grace = 0
	e.shells = [{"p":game.player,"r":wyrm.SHELL_RADIUS,"impact":0.01,"warn":1.0,"fired":false,"wave":0}]
	wyrm.advance_shells(game.boss,game,e,0.02)
	check(game.pending_respawn,"a shell landing on the player kills")
	game.pending_respawn = false
	e.hp_floor = 0.0
	game.hurt_enemy(e,e.hp+1,Vector2.RIGHT,0,true)
	step(game,1.0/60.0)
	check(game.stairs_unlocked and game.enemies.is_empty(),"the core's defeat opens the stairs")

	# Debug shortcuts: invincibility and the second-form skip.
	game.practice.variant = 3
	game.practice.depth = 25
	game.practice.start(game)
	game.set_physics_process(false)
	game.discovered[1] = true
	e = game.enemies[0]
	game.debug_invincible = true
	game.grace = 0
	game.die()
	check(not game.pending_respawn,"debug invincibility ignores hits")
	game.debug_invincible = false
	wyrm.skip_form(game)
	game.player = e.home+Vector2(-620,0)
	check(until(game,func(): return e.state == "roam",8.0),"the second-form skip reaches the prowling form")
	game.free()
	if failures == 0: print("PASS: Abyss Wyrm placement, cover, breach warnings, crawling patterns, shielded core, two forms, unstuck movement, charge, body beams, bombardment and debug shortcuts")
	quit(1 if failures else 0)
