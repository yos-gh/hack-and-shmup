extends RefCounted

const Practice = preload("res://scripts/boss_practice.gd")

# Explicit development entry point; tools/ is excluded from release exports.
static func configure(game, scenario: String, seed_value: int, weapon: int) -> void:
	game.start_run()
	game.floor_number = {"normal11":11,"normal19":19,"citadel5":5,"bastion15":15,"triad45":45}[scenario]
	Practice.auto_upgrades(game.session.run, game.floor_number - 1, [0, 1, 3, 2])
	game.rng.seed = seed_value
	game.effects_rng.seed = seed_value ^ 0x5EED
	game.sub_weapon = weapon
	game.new_floor({"citadel5":0,"bastion15":1,"triad45":2}.get(scenario,-1))
	game.player = game.spawn_point if scenario == "normal11" else (game.center(Vector2i(3, 1)) if game.boss_floor else game.entrances[1][0])
	game.camera_pos = game.player
	if scenario != "normal11": game.discovered[1] = true
	game.build_flow()
	game.queue_redraw()

# Any depth from its ordinary spawn: one automatic upgrade per cleared floor
# (MOVE SPEED capped like boss practice),
# normal damage and timer. Boss floors use boss_choice 0..2, or -1 for the seeded pick.
static func configure_floor(game, depth: int, seed_value: int, weapon: int, boss_choice: int = -1) -> void:
	game.start_run()
	game.floor_number = depth
	Practice.auto_upgrades(game.session.run, depth - 1, [0, 1, 3, 2])
	game.rng.seed = seed_value
	game.effects_rng.seed = seed_value ^ 0x5EED
	game.sub_weapon = weapon
	game.new_floor(boss_choice)
	game.build_flow()
	game.queue_redraw()

static func input_frame(game, frame: int) -> void:
	# Stationary rotating fire samples all directions without live-device input.
	# Protection is only for measurement, never interactive play or game balance.
	game.grace = 2.0
	game.time_left = 120.0
	game.fire_armed = true
	game.replay_input = {"movement": Vector2.ZERO, "aim": Vector2.from_angle(frame / 120.0), "primary": true, "secondary": true}

static func digest(game) -> String:
	return var_to_bytes([game.cells, game.enemies, game.bullets, game.player, game.kills, game.rng.state, game.boss.salvos, game.boss.lasers]).hex_encode().sha256_text()
