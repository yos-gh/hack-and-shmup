extends SceneTree

const Balance = preload("res://scripts/combat_balance.gd")
const Catalog = preload("res://scripts/combat_catalog.gd")
const Generator = preload("res://scripts/floor_generator.gd")
const Settings = preload("res://scripts/floor_settings.gd")
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: " + message)
		failures += 1

func run() -> void:
	for depth in range(1, 31):
		for kind in Catalog.ENEMIES:
			check(Balance.mob_health(kind, depth) == Catalog.ENEMIES[kind].health(depth), "all early mob health unchanged")
	for depth in [31, 40, 50, 60, 80, 100, 104, 200]:
		for kind in Catalog.ENEMIES:
			check(Balance.mob_health(kind, depth) >= Balance.mob_health(kind, depth - 1), "health monotone across depths")
		check(Balance.mob_health(Catalog.Enemy.SHIELD, depth) == 1.0, "shield remains one HP")
		check(Balance.mob_health(Catalog.Enemy.SNIPER, depth) <= Balance.reference_power(depth) * 2, "sniper reference two-shot cap")
	check(is_equal_approx(Balance.mob_health(Catalog.Enemy.CHASER, 50), 66.0), "floor 50 reference health")
	check(is_equal_approx(Balance.primary_dps(14.2, 9.0), 852.0), "104 screenshot real primary DPS")
	# Measure the same cooldown subtraction used by primary/sub fire, including frame rounding.
	for rate in [1.0, 1.2, 2.0, 3.25, 5.4, 5.58, 9.0]:
		var cooldown := 0.0
		var shots := 0
		for frame in range(3600):
			cooldown -= 1.0 / 60.0
			if cooldown <= 0:
				shots += 1
				cooldown = Catalog.PRIMARY.cooldown / rate
		check(absf(shots / 60.0 - Balance.primary_dps(1.0, rate)) <= 1.0 / 60.0 + 0.001, "predicted firing cadence matches runtime")
	var generator := Generator.new()
	for recharge in [0.0,0.1,0.5]:
		for weapon in range(3):
			var definition = Catalog.WEAPONS[weapon]
			var cooldown := 0.0
			var shots := 0
			for frame in range(7200):
				cooldown = maxf(0.0,cooldown - 1.0 / 60.0)
				if cooldown <= 0:
					shots += 1
					cooldown = definition.cooldown / (1.0+recharge)
			check(absf(shots / 120.0 - Balance.shots_per_second(definition.cooldown / (1.0+recharge))) <= 1.0/120.0+0.001, "sub cadence includes frame rounding")
	var settings := Settings.new()
	settings.depth = 99
	var weak_normal = generator.generate(settings, 93)
	settings.power = 14.2
	settings.fire_rate = 9.0
	settings.recharge = 0.5
	var strong_normal = generator.generate(settings, 93)
	check(weak_normal.enemies == strong_normal.enemies and weak_normal.rng.state == strong_normal.rng.state, "normal HP and composition independent of actual build")
	for enemy in strong_normal.enemies:
		check(enemy.hp == Balance.mob_health(enemy.kind,99), "normal generator uses shared high-floor health")
	settings.depth = 100
	settings.power = 14.2
	settings.fire_rate = 9.0
	for variant in range(3):
		settings.boss_choice = variant
		settings.recharge = 0.0
		var original = generator.generate(settings, 19045)
		settings.recharge = 0.5
		var charged = generator.generate(settings, 19045)
		check(charged.boss_max_hp > original.boss_max_hp, "boss accounts for recharge")
		check(original.rng.state == charged.rng.state and original.cells == charged.cells, "HP consumes no randomness and preserves layout")
		var sum := 0.0
		for enemy in charged.enemies: sum += enemy.hp
		check(is_equal_approx(sum, charged.boss_max_hp), "boss total matches health bar")
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.title_screen = false
	game.floor_number = 100
	game.power = 14.2
	game.fire_rate = 9.0
	game.session.run.recharge = 0.5
	game.new_floor(1)
	var boss_hp: float = game.boss_max_hp
	check(is_equal_approx(boss_hp, Balance.boss_health(14.2,9.0,0.5,1,Engine.physics_ticks_per_second,100)), "live generation passes recharge, ticks and depth")
	game.sub_weapon = 2
	check(game.boss_max_hp == boss_hp, "weapon switch does not change boss HP")
	game.floor_number = 104
	check(game.boss_max_hp == boss_hp, "boss HP remains a generated snapshot")
	game.floor_number = 100
	game.boss.summon(game, game.enemies[0])
	check(not game.boss.pending_summons.is_empty(), "summon fixture produces mobs")
	for enemy in game.boss.pending_summons:
		check(enemy.hp == Balance.mob_health(enemy.kind, 100), "summoned mob uses identical health")
	game.enemies[0].hp = 1
	game.restart_attempt()
	check(is_equal_approx(game.boss.health(game), boss_hp), "retry restores boss health")
	game.floor_number = 99
	game.new_floor()
	var starting_hp: float = game.enemies[0].hp
	game.enemies[0].hp = 0
	game.restart_attempt()
	check(game.enemies[0].hp == starting_hp, "retry restores high-floor mob health")
	var shield := {"kind":Catalog.Enemy.SHIELD,"hp":1.0,"push":Vector2.ZERO,"dir":Vector2.RIGHT,"p":Vector2.ZERO}
	game.hurt_enemy(shield, 14.2, Vector2.LEFT)
	check(shield.hp == 1.0, "front shield blocks upgraded damage")
	game.hurt_enemy(shield, 1.0, Vector2.RIGHT)
	check(shield.hp <= 0, "unshielded body dies in one base shot")
	game.free()
	if failures == 0: print("PASS: early/high-floor health, real cadence, boss recharge, summon parity, shields and retries")
	quit(1 if failures else 0)
