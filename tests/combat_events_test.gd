extends SceneTree

var failures := 0
var hits: Array = []
var deaths: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: "+message)
		failures += 1
func record_hit(position: Vector2, damage: float, blocked: bool, killed: bool) -> void:
	hits.append([position,damage,blocked,killed])
func record_death(reason: String) -> void: deaths.append(reason)
func run() -> void:
	var expected := PackedByteArray()
	for with_feedback in [false,true]:
		var game = load("res://main.tscn").instantiate()
		root.add_child(game)
		game.set_physics_process(false)
		game.rng.seed = 17
		game.effects_rng.seed = 99
		game.start_run()
		if not with_feedback:
			for connection in game.combat_events.enemy_hit.get_connections(): game.combat_events.enemy_hit.disconnect(connection.callable)
			for connection in game.combat_events.player_died.get_connections(): game.combat_events.player_died.disconnect(connection.callable)
		game.combat_events.enemy_hit.connect(record_hit)
		game.combat_events.player_died.connect(record_death)
		hits.clear()
		deaths.clear()
		var enemy: Dictionary = game.enemies[0]
		enemy.kind = 2
		enemy.hp = 1
		enemy.dir = Vector2.RIGHT
		game.hurt_enemy(enemy,9,Vector2.LEFT)
		check(enemy.hp == 1 and hits.size() == 1 and hits[0][2] and not hits[0][3],"shield block emits once without damage")
		game.hurt_enemy(enemy,0.25,Vector2.RIGHT)
		check(enemy.hp == 0.75 and hits.size() == 2 and hits[1][1] == 0.25 and not hits[1][3],"nonlethal hit value notification")
		var before: float = game.time_left
		game.hurt_enemy(enemy,1,Vector2.RIGHT)
		game.hurt_enemy(enemy,1,Vector2.RIGHT)
		check(hits.size() == 3 and hits[2][3] and is_equal_approx(game.time_left,before+0.3),"lethal hit and reward occur once")
		if with_feedback: check(game.damage_labels.size() == 2 and game.particles.size() == 9,"feedback produces original labels and particles")
		else: check(game.damage_labels.is_empty() and game.particles.is_empty(),"combat can run without feedback listener")
		game.grace = 0
		game.die("TIME UP")
		game.die("TIME UP")
		check(deaths == ["TIME UP"] and game.pending_respawn,"death event occurs once")
		var state := var_to_bytes([game.enemies,game.time_left,game.rng.state,game.deaths,game.pending_respawn,game.death_reason])
		if not with_feedback: expected = state
		else: check(state == expected,"feedback listeners cannot affect combat result or RNG")
		game.free()
	if failures == 0: print("PASS: shield/hit/kill/death event values, duplicate suppression and feedback-independent combat")
	quit(1 if failures else 0)
