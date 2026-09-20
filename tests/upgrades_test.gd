extends SceneTree
const Catalog = preload("res://scripts/combat_catalog.gd")
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
	var run_state = game.session.run
	check(Catalog.UPGRADES.size() == 8,"eight cards")
	for i in range(5): game.apply_upgrade(4)
	check(is_equal_approx(game.power,0.5) and game.move_bonus == 150,"skirmisher stacks additively")
	check(not run_state.can_upgrade(4),"cannot spend damage below floor")
	game.apply_upgrade(4)
	check(game.move_bonus == 150,"rejected penalty grants no benefit")
	run_state.reset()
	for i in range(2): game.apply_upgrade(5)
	check(is_equal_approx(game.power,1.9) and game.SPEED+game.move_bonus == 185,"juggernaut reaches safe speed floor")
	check(not run_state.can_upgrade(5),"full speed penalty is required")
	game.apply_upgrade(2)
	check(not run_state.can_upgrade(5),"partial penalty cannot be clipped")
	game.apply_upgrade(2)
	check(run_state.can_upgrade(5),"speed growth permits another deliberate slowdown")
	run_state.reset()
	check(game.LANCE_WIDTH == 39.0,"base lance width unchanged")
	game.apply_upgrade(6)
	check(is_equal_approx(game.LANCE_WIDTH,46.8),"one expansion adds twenty percent lance width")
	check(game.player_stats()[5].value == "1.20x" and game.player_stats()[5].detail == "+20% / MAX +100%","lance stat displays new increment and cap")
	run_state.reset()
	for i in range(7):
		game.apply_upgrade(6)
		game.apply_upgrade(7)
	check(is_equal_approx(run_state.expansion,0.5) and is_equal_approx(run_state.recharge,0.5),"sub upgrades capped at five")
	check(is_equal_approx(game.SHOCK_RADIUS,Catalog.WEAPONS[1].reach*1.25),"shock scales half as much as scatter")
	check(is_equal_approx(game.LANCE_WIDTH,78.0),"lance width doubles at five expansion stacks")
	check(game.player_stats()[5].value == "2.00x" and game.player_stats()[5].detail == "+100% / MAX +100%","maximum lance stat matches gameplay")
	var random := RandomNumberGenerator.new()
	random.seed = 41
	var saved: int = random.state
	run_state.roll_choices(random)
	var first: Array = game.choices.duplicate()
	random.state = saved
	run_state.roll_choices(random)
	check(first == game.choices,"seeded offers reproduce")
	for i in range(80):
		run_state.roll_choices(random)
		check(game.choices.size() == 3 and game.choices[0] != game.choices[1] and game.choices[1] != game.choices[2] and game.choices[0] != game.choices[2],"three distinct offers")
		check(6 not in game.choices and 7 not in game.choices,"capped cards excluded")
	game.cells.clear()
	for x in range(50):
		for y in range(20): game.cells[Vector2i(x,y)] = 0
	game.discovered = {0:true}
	game.player = Vector2(300,300)
	game.enemies.clear()
	game.sub_weapon = 0
	game.fire_sub(Vector2.RIGHT)
	check(is_equal_approx(game.bullets[0].life,run_state.sub_reach(0)/Catalog.WEAPONS[0].speed),"scatter projectile uses upgraded range")
	check(is_equal_approx(game.sub_cd,Catalog.WEAPONS[0].cooldown/1.5),"recharge is rate, not half cooldown")
	var cooldown: float = game.sub_cd
	game.sub_weapon = 2
	check(game.sub_cd == cooldown,"weapon switch cannot reset cooldown")
	var rays: Array = game.LanceTrace.lanes(game,game.player,Vector2.RIGHT)
	check(is_equal_approx(rays.size()*rays[0].width,game.LANCE_WIDTH),"lance trace shares upgraded width")
	var edge_enemy := {"kind":0,"p":game.player+Vector2(100,48)}
	check(game.LanceTrace.hits(game,edge_enemy,rays,Vector2.RIGHT),"upgraded lance hits target outside previous maximum width")
	run_state.expansion = 0.0
	check(not game.LanceTrace.hits(game,edge_enemy,game.LanceTrace.lanes(game,game.player,Vector2.RIGHT),Vector2.RIGHT),"same target misses base lance")
	run_state.expansion = 0.5
	var full: PackedVector2Array = game.world_view.shock_outline(game,game.player,game.SHOCK_RADIUS)
	run_state.reset()
	var base: PackedVector2Array = game.world_view.shock_outline(game,game.player,game.SHOCK_RADIUS)
	check(full[0].distance_to(game.player) > base[0].distance_to(game.player),"range changes invalidate radial cache")
	check(game.world_view.damage_number(1.0) == "10" and game.world_view.damage_number(1.35) == "14","damage labels are scaled integers")
	game.apply_upgrade(6)
	game.apply_upgrade(7)
	game.restart_attempt()
	check(is_equal_approx(run_state.expansion,0.1) and is_equal_approx(run_state.recharge,0.1),"retry retains new stats")
	game.choosing = true
	game.choices.assign([5,6,7])
	game.title_screen = false
	game.menus.sync()
	check(game.player_stats().size() == 7 and game.player_stats()[3].value == "1.10x" and game.player_stats()[6].value == "1.10x","all seven current stats exposed")
	for pause in [false,true]:
		game.paused = pause
		game.menus.sync()
		var captions: Array = game.menus.surface.get_children().filter(func(n): return n is Label).map(func(n): return n.text)
		for stat in game.player_stats(): check(stat.name in captions,"cards and pause display "+stat.name)
	game.start_run()
	check(run_state.expansion == 0 and run_state.recharge == 0 and run_state.upgrade_counts.is_empty(),"new run resets all stacks")
	game.free()
	if failures == 0: print("PASS: eight cards, tradeoffs, caps, seeded offers, sub geometry/cooldowns, integer damage and both status screens")
	quit(1 if failures else 0)
