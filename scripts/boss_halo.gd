extends RefCounted

# Variant-specific behavior; attack queues and warnings remain shared in Boss.

func radial_angle(boss, index: int, count: int) -> float:
	# Four 54-degree clusters separated by persistent 36-degree corridors.
	var sector := index % 4
	var local_index := index / 4
	var local_count := (count-1-sector)/4+1
	return sector*TAU/4.0 + lerpf(-0.47,0.47,float(local_index)/maxi(local_count-1,1))

func fire_halo(boss, game, e: Dictionary, toward: Vector2) -> void:
	var phase: int = e.shots % 3
	boss.deploy_options(game,e,phase)
	if phase == 0:
		# Re-aim each short fan: small deliberate movement streams the bullets.
		var opening: int = boss.salvos.size()
		for i in range(4+mini(boss.tier(game),2)):
			boss.queue_aimed(e,i*0.22,3+2*mini(boss.tier(game),2),0.13,190.0)
		# The opening fan follows the normal core warning; the rest are timed.
		boss.emit_salvo(game,boss.salvos[opening])
		boss.salvos.remove_at(opening)
	elif phase == 1:
		game.enemy_attack_cue("halo_fire",e.p)
		var count: int = 12+boss.tier(game)*4
		var rotation := int(e.shots/3)*0.20
		for i in range(count):
			game.emit_shot(e.p,Vector2.from_angle(boss.radial_angle(i,count)+rotation),165.0,1,true,1200)
		# Static obstacles plus aimed pressure, separated in time and color.
		boss.queue_aimed(e,0.55,3,0.10,190.0)
		boss.queue_aimed(e,0.95,3+2*mini(boss.tier(game)/3,2),0.10,190.0)
	else:
		# Lock a pincer to the old position; the center stays traversable.
		for wave in range(3):
			var offsets := PackedFloat32Array()
			var count := 3+mini(boss.tier(game),4)
			for side in [-1,1]:
				for i in range(count):
					offsets.append(side*(0.70-wave*0.16)+(i-(count-1)*0.5)*0.045)
			var salvo := {"owner":e,"delay":wave*0.35,"offsets":offsets,"speed":175.0,"aim":toward}
			if wave == 0: boss.emit_salvo(game,salvo)
			else: boss.salvos.append(salvo)
		boss.queue_aimed(e,1.20,3,0.12,190.0)

func deploy_options(boss, game, e: Dictionary, phase: int) -> void:
	# Harmless satellites hold their formation during each firing sequence.
	boss.options.clear()
	var count := 3+mini(boss.tier(game)/2,2)
	var radius := 215.0+mini(boss.tier(game),7)*5.0
	for i in range(count):
		var angle := -PI/2+i*TAU/count+phase*0.35+int(e.shots/3)*0.30
		var origin: Vector2 = e.p+Vector2.from_angle(angle)*radius
		boss.options.append({"p":origin,"owner":e,"life":2.5})
		boss.queue_aimed(e,0.45+i*0.28,3+2*mini(boss.tier(game)/3,1),0.18,110.0)
		var salvo: Dictionary = boss.salvos[-1]
		salvo.origin = origin
		if phase == 2: salvo.aim = origin.direction_to(game.player).rotated((i-(count-1)*0.5)*0.18)
		if origin.distance_to(game.player) < 100: salvo.delay += 0.35
		# The fast follow-up overtakes the slow fence. Both lock the same aim,
		# leaving adjacent lanes open instead of tracking every escape movement.
		salvo.aim = origin.direction_to(game.player) if phase != 2 else salvo.aim
		boss.queue_aimed(e,salvo.delay+0.55,3,0.18,220.0)
		boss.salvos[-1].origin = origin
		boss.salvos[-1].aim = salvo.aim

func advance(boss, game, e: Dictionary, delta: float, toward: Vector2) -> Vector2:
	if e.cd <= 0:
		boss.fire_halo(game,e,toward)
		e.shots += 1
		# Fixed recovery after the sequence; depth adds bullets, not reaction speed.
		e.cd = 2.5
	return Vector2.ZERO
