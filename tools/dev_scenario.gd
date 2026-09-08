extends RefCounted

# Explicit development entry point; tools/ is excluded from release exports.
static func configure(game, scenario: String, seed_value: int, weapon: int) -> void:
	game.start_run()
	game.floor_number = 19 if scenario == "normal19" else 45
	for i in range(game.floor_number - 1): game.apply_upgrade([0, 1, 3, 2][i % 4])
	game.rng.seed = seed_value
	game.effects_rng.seed = seed_value ^ 0x5EED
	game.sub_weapon = weapon
	game.new_floor(2 if scenario == "halo45" else -1)
	game.player = game.center(Vector2i(3, 1)) if game.boss_floor else game.entrances[1][0]
	game.camera_pos = game.player
	game.discovered[1] = true
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
