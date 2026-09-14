extends SceneTree
const Scenario = preload("res://tools/dev_scenario.gd")
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		push_error("FAIL: "+message)
		failures += 1
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	check(game.depth_enabled and game.view_pitch_degrees == 25,"normal launch uses adopted 3D view")
	Scenario.configure(game,"normal19",19045,1)
	var fx = game.presentation
	fx.reset()
	var baseline := var_to_bytes([Scenario.digest(game),game.effects_rng.state,game.time_left])
	game.combat_events.weapon_fired.emit(game.player,Vector2.RIGHT,1)
	game.combat_events.charge_changed.emit(game.player,Vector2.RIGHT,true)
	game.combat_events.room_entered.emit(1,game.player)
	game.combat_events.stairs_opened.emit(game.stairs)
	game.combat_events.boss_destroyed.emit(game.player,Color.GOLD)
	game.combat_events.scene_changed.emit("cards")
	check(fx.muzzle>0 and fx.transition>0 and fx.pulses.size() == 5,"events produce independent presentation snapshots")
	check(baseline == var_to_bytes([Scenario.digest(game),game.effects_rng.state,game.time_left]),"all new notifications preserve combat and RNG")
	fx.track_motion(game,game.player-Vector2(4,0),game.player,0.04)
	check(fx.trails.size()>0,"movement creates a short trail")
	fx.advance(game,0.16)
	check(fx.trails.is_empty(),"motion tails disappear within 150ms after stopping")
	for i in range(200):
		fx.pulse("stop",game.player,Color.WHITE,0.2,10)
		fx.add_trail(game.player,Vector2.RIGHT,Color.WHITE,10,0.15)
	check(fx.pulses.size()<=32 and fx.trails.size()<=96,"decorative effects have separate hard bounds")
	var before: float = fx.clock
	game.paused = true
	game._physics_process(0.2)
	check(fx.clock == before,"pause freezes world presentation clock")
	game.paused = false
	game.restart_attempt()
	check(fx.pulses.is_empty() and fx.trails.is_empty() and fx.muzzle == 0,"retry clears spatial trails without delaying arrival")
	# Presentation may be disconnected without affecting any replay outcome.
	var digest := ""
	for enabled in [true,false]:
		Scenario.configure(game,"normal19",19045,1)
		if not enabled:
			for name in ["weapon_fired","charge_changed","room_entered","stairs_opened","scene_changed","boss_destroyed","actor_alerted","actor_fired"]:
				for connection in game.combat_events.get_signal_connection_list(name): game.combat_events.disconnect(name,connection.callable)
		for frame in range(180):
			Scenario.input_frame(game,frame)
			game._physics_process(1.0/60)
		if enabled: digest = Scenario.digest(game)
		else: check(Scenario.digest(game) == digest,"presentation notifications do not alter combat replay")
	game.free()
	if failures == 0: print("PASS: presentation event parity, bounds, expiry, pause, immediate retry and 3D startup")
	quit(1 if failures else 0)
