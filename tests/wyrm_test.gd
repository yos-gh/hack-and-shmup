extends SceneTree
## Abyss Wyrm rules: 25-floor placement, arena cover, telegraphed breaches,
## alternating first-form patterns, head-only damage, the form split and the
## second form's body, charge and music.
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: "+message)
		failures += 1

func step(game, seconds: float) -> void:
	for i in range(roundi(seconds*60)):
		game.grace = 2
		game.replay_input = {"movement":Vector2.ZERO,"aim":Vector2.RIGHT,"primary":false,"secondary":false}
		game._physics_process(1.0/60.0)

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
	check(game.rooms[1].size.x*game.rooms[1].size.y > 48*36,"arena is larger than the Iron Citadel's")
	for cell in wyrm.COVER_CELLS:
		check(not game.walkable(game.center(cell)),"pillar is solid cover")
		var room: Rect2i = game.rooms[1]
		var edge: int = mini(mini(cell.x-room.position.x,room.end.x-cell.x-2),mini(cell.y-room.position.y,room.end.y-cell.y-2))
		check(edge <= 5,"pillars line the outer wall")
	check(is_equal_approx(e.hp,e.max_hp) and is_equal_approx(e.hp_floor,e.phase_hp*wyrm.SECOND_FORM),"two forms share the health bar")

	# First form: holes are telegraphed before anything rises, and nothing can be hit underground.
	game.player = e.home+Vector2(-420,0)
	var wait := 0
	while not e.active and wait < 300:
		step(game,1.0/60.0)
		wait += 1
	check(e.active and e.state == "under" and e.head_hole != Vector2.INF and e.submerged,"breach points are marked before the wyrm rises")
	check(e.head_hole.distance_to(game.player) >= 260,"the head breaches away from the player")
	check(game.enemy_bullet_radius(e) == 0.0 and not wyrm.touches(e,e.head_hole,game.PLAYER_HIT_RADIUS),"a submerged wyrm cannot be hit or touched")
	var hp: float = e.hp
	game.hurt_enemy(e,1,Vector2.RIGHT)
	check(e.hp == hp-1,"direct damage is unshielded")
	e.hp = hp
	var frames := 1
	while e.state != "exposed" and frames < 400:
		step(game,1.0/60.0)
		frames += 1
	check(e.state == "exposed" and not e.submerged and e.rise == 0 and absf(frames/60.0-wyrm.FIRST_UNDER_TIME-wyrm.EMERGE_TIME) < 0.05,"the head rises after its warning")
	check(game.boss.lasers.size() == 1 and game.boss.lasers[0].get("triad",false) and game.boss.lasers[0].width >= 80,"even breaches open with the broad tracking beam")
	check(game.enemy_bullet_radius(e) == wyrm.CORE,"the exposed head is the weak point")
	# Links stop shots; the head takes them.
	var link: Dictionary = e.segments[0]
	check(wyrm.intercept_bullet(game,{"p":link.p,"damage":1.0,"hostile":false}),"armoured links stop player shots")
	check(not wyrm.intercept_bullet(game,{"p":e.p+e.face*20,"damage":1.0,"hostile":false}),"shots reach the head")
	step(game,8.0)
	check(e.rise == 1,"the wyrm dives and breaches somewhere else")
	var guard := 0
	while e.state != "exposed" and guard < 600:
		step(game,1.0/60.0)
		guard += 1
	check(game.boss.lasers.is_empty() and e.volleys.any(func(v): return v.kind == "ring"),"odd breaches switch to drifting gapped rings")

	# The form cannot be skipped by one large hit; the breach follows.
	game.hurt_enemy(e,e.max_hp,Vector2.RIGHT,0,true)
	check(is_equal_approx(e.hp,e.hp_floor) and e.hp > 0,"damage stops at the end of the first form")
	step(game,1.0/60.0)
	check(e.phase == 2 and e.state in ["breach_dive","breach_wait"],"losing the first form starts the breach")
	check(game.sound.music_lib.track_for(game) == "boss_recca_dark_v2","the second form has its own track")
	hp = e.hp
	game.hurt_enemy(e,10,Vector2.RIGHT,0,true)
	check(e.hp == hp,"the wyrm is untouchable while it tunnels")
	step(game,wyrm.BREACH_DIVE+wyrm.BREACH_WAIT+0.1)
	check(e.state == "roam" and e.hp_floor == 0.0 and not e.submerged,"the second form tears free")
	step(game,10.0)
	var out: int = e.segments.filter(func(s): return s.z >= 0).size()
	check(out == wyrm.SEGMENTS+1,"every link has left the hole")
	var spaced := true
	for i in range(1,e.segments.size()-1):
		if e.segments[i].p.distance_to(e.segments[i-1].p) > wyrm.SPACING+1: spaced = false
	check(spaced,"links follow the head's path at fixed spacing")
	check(game.walkable(e.p,wyrm.HEAD_RADIUS-8),"the head stays clear of walls and pillars")
	# Charge: the lane is fixed before the dash and stops short of walls.
	e.p = e.home+Vector2(-250,0)
	e.heading = 0.0
	game.player = e.home+Vector2(250,0)
	e.charge_cd = 0
	e.move_mode = "prowl"
	e.move_time = 0
	step(game,1.0/60.0)
	if e.move_mode == "charge_warning":
		var lane: Vector2 = e.charge_end
		step(game,0.5)
		check(e.charge_end == lane,"the charge lane does not follow the player")
		check(game.walkable(lane,wyrm.HEAD_RADIUS),"the charge stops short of walls and pillars")
	else: check(false,"a ready charge begins with a warning")
	# Body beams are telegraphed and keep their heading.
	e.beam_cd = 0
	e.move_mode = "prowl"
	e.move_time = 5
	step(game,1.0/60.0)
	var beams: Array = game.boss.lasers.filter(func(b): return b.has("mount"))
	check(beams.size() >= 2 and beams.all(func(b): return b.warning > 0.5),"body beams start with a warning")
	if not beams.is_empty():
		var heading: Vector2 = beams[0].heading
		step(game,0.5)
		check(beams[0].heading == heading,"body beams never swing")
	game.hurt_enemy(e,e.hp+1,Vector2.RIGHT,0,true)
	step(game,1.0/60.0)
	check(game.stairs_unlocked and game.enemies.is_empty(),"the head's defeat opens the stairs")
	game.free()
	if failures == 0: print("PASS: Abyss Wyrm placement, breach warnings, alternating patterns, head-only damage, two forms, charge and body beams")
	quit(1 if failures else 0)
