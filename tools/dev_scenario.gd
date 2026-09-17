extends RefCounted

# Explicit development entry point; tools/ is excluded from release exports.
static func configure(game, scenario: String, seed_value: int, weapon: int) -> void:
	game.start_run()
	game.floor_number = {"normal11":11,"normal19":19,"siege5":5,"hunter15":15,"halo45":45}[scenario]
	for i in range(game.floor_number - 1): game.apply_upgrade([0, 1, 3, 2][i % 4])
	game.rng.seed = seed_value
	game.effects_rng.seed = seed_value ^ 0x5EED
	game.sub_weapon = weapon
	game.new_floor({"siege5":0,"hunter15":1,"halo45":2}.get(scenario,-1))
	game.player = game.spawn_point if scenario == "normal11" else (game.center(Vector2i(3, 1)) if game.boss_floor else game.entrances[1][0])
	game.camera_pos = game.player
	if scenario != "normal11": game.discovered[1] = true
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
	return var_to_bytes([game.cells, game.enemies, game.bullets, game.player, game.kills, game.rng.state, game.boss.options, game.boss.salvos, game.boss.lasers, game.boss.pending_summons]).hex_encode().sha256_text()
