extends RefCounted

func bind_to(game) -> void:
	game.combat_events.enemy_hit.connect(enemy_hit.bind(game))
	game.combat_events.player_died.connect(player_died.bind(game))

func enemy_hit(position: Vector2, damage: float, blocked: bool, killed: bool, game) -> void:
	# Brief, local impact marks; bounded independently of weapon effects.
	var impact_count := 0
	for effect in game.effects:
		if effect.kind == 2: impact_count += 1
	if impact_count < 32:
		game.effects.append({"kind":2,"p":position,"life":0.10,"blocked":blocked})
	if blocked:
		game.sound.play_sfx("shield")
		game.burst(position,Color.SKY_BLUE,3)
		return
	var offset := Vector2((game.damage_labels.size() % 3 - 1) * 13, -18)
	game.damage_labels.append({"p":position+offset,"damage":damage,"life":0.65})
	if game.damage_labels.size() > 96: game.damage_labels.pop_front()
	if killed:
		game.sound.play_sfx("kill")
		var death_count := 0
		for effect in game.effects:
			if effect.kind == 5: death_count += 1
		if death_count < 16: game.effects.append({"kind":5,"p":position,"life":0.30})
	game.burst(position,Color("ff647c"),3)

func player_died(reason: String, game) -> void:
	game.sound.play_sfx("timeout" if reason == "TIME UP" else "death")
	if reason == "TIME UP": game.timeout_banner = 1.0
	else:
		game.hit_flash = 0.25
		game.hit_banner = 0.8
