extends RefCounted

# Variant-specific behavior; attack queues and warnings remain shared in Boss.

func fan_angle(boss, index: int, count: int) -> float:
	if count < 9: return (index-(count-1)*0.5)*0.13
	var left_count := int(ceil(count*0.5))
	if index < left_count:
		return lerpf(-0.85,-0.32,float(index)/maxi(left_count-1,1))
	return lerpf(0.32,0.85,float(index-left_count)/maxi(count-left_count-1,1))

func fire(boss, game, e: Dictionary, toward: Vector2) -> void:
	game.sound.play_sfx("siege_fire")
	var stage := clampi(boss.remaining(game),1,boss.TURRETS)-1
	var guided: bool = e.shots % 2 == 1
	var count := roundi(lerpf(boss.VOLLEY_COUNTS[stage],boss.MAX_VOLLEY_COUNTS[stage],boss.tier(game)/8.0))
	for i in range(count):
		var offset: float = boss.fan_angle(i,count)
		var aim := toward.rotated(offset)
		game.emit_shot(e.p,aim,boss.GUIDED_SPEED if guided else 190.0,1,true,900)
		if guided:
			game.bullets[-1]["homing_time"] = 1.0 if count < 9 else 0.0
			game.bullets[-1]["turn_rate"] = boss.GUIDED_TURN_RATE
			game.bullets[-1]["guided"] = true
			# Prevent homing from collapsing both lobes into the central gap.
			game.bullets[-1]["homing_offset"] = offset if count >= 9 else 0.0
	e.shots += 1
	e.cd = maxf(1.0,boss.SHOT_INTERVALS[stage]/boss.rate_scale(game))
	if stage <= 2: boss.turret_gap = 0.40
	if stage == 0 and e.shots % 3 == 0:
		# A delayed, readable aimed triplet breaks camping without filling the fan.
		boss.queue_aimed(e,0.45,3,0.11,210.0)

func advance(boss, game, e: Dictionary, delta: float, toward: Vector2) -> Vector2:
	if e.cd <= 0 and boss.turret_gap <= 0: boss.fire(game,e,toward)
	return Vector2.ZERO
