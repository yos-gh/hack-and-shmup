extends RefCounted
## Abyss Wyrm: the boss of every 25th floor. A mechanical serpent that first
## breaches the floor from telegraphed holes, head and tail apart, then tears
## free and prowls the arena. Only the head takes damage; the armoured neck,
## body and tail stop shots. Each form holds one ordinary boss's health.
const Balance = preload("res://scripts/combat_balance.gd")
const Visual = preload("res://scripts/wyrm_visuals.gd")
const INK := Color("8fc8ff")
const RAGE_INK := Color("ff6a88")
const CORE := 48.0           # head radius for shots
const HEAD_RADIUS := 54.0    # head radius for contact
const SEGMENTS := 16
const HEAD_GAP := 64.0       # head centre to the first body segment
const SPACING := 42.0
const TAIL_GAP := 48.0
const BODY_RADIUS := [38.0,20.0]
const NECK := 3
const TAIL_LINKS := 4
const NECK_REACH := 132.0
const TAIL_REACH := 150.0
const HOLE_RADIUS := 80.0
const TAIL_HOLE_RADIUS := 60.0
const BREACH_RADIUS := 96.0
const UNDER_TIME := 1.3
const FIRST_UNDER_TIME := 1.8
const EMERGE_TIME := 0.5
const DIVE_TIME := 0.55
const LASER_WARNING := 1.0
const BREACH_DIVE := 0.6
const BREACH_WAIT := 1.7
const MUZZLE := 84.0
const HP_FACTOR := 9.5
# The second form's share of the first form's health; the HUD marks the split.
const SECOND_FORM := 0.8
# Pillars sit along the outer wall of the 56×44 arena, leaving the middle open.
const COVER_CELLS := [Vector2i(11,-18),Vector2i(27,-18),Vector2i(43,-18),Vector2i(11,16),Vector2i(27,16),Vector2i(43,16),
	Vector2i(4,-9),Vector2i(4,8),Vector2i(50,-9),Vector2i(50,8)]

func setup(data, e: Dictionary) -> void:
	var dps: float = Balance.primary_dps(data.power,data.fire_rate,data.physics_ticks)
	var low: float = clampf((data.floor_number-5)/20.0,0.0,1.0)
	var mid: float = clampf((data.floor_number-25)/25.0,0.0,1.0)
	var late: float = maxf(0.0,data.floor_number-50)
	e["low"] = low
	e["mid"] = mid
	e["expert"] = data.floor_number >= 50
	e["attack_scale"] = lerpf(1.35,1.0,low)
	e["speed_scale"] = lerpf(0.75,1.0,low)*(1.0+0.001*late)
	# The head is only exposed part of the time, so each form's health is a
	# little under a Triad core while the fight runs about a minute per form.
	var combined_dps: float = dps+Balance.sub_dps(data.power,data.recharge,0,data.physics_ticks)*0.5
	e["phase_hp"] = combined_dps*HP_FACTOR*lerpf(0.6,1.0,low*low)*(1.0+0.004*late)
	e["max_hp"] = e.phase_hp*(1.0+SECOND_FORM)
	e.hp = e.max_hp
	e["hp_floor"] = e.phase_hp*SECOND_FORM
	e["home"] = data.center(Vector2i(28,0))-Vector2(16,16)
	e["cover_points"] = []
	for cell in COVER_CELLS: e.cover_points.append(data.center(cell)+Vector2(16,16))
	e["phase"] = 1
	e["state"] = "under"
	e["state_time"] = FIRST_UNDER_TIME
	e["rise"] = 0
	e["rise_amount"] = 0.0
	e["head_hole"] = Vector2.INF
	e["tail_hole"] = Vector2.INF
	e["emerge_dir"] = Vector2.LEFT
	e["tail_dir"] = Vector2.RIGHT
	e["face"] = Vector2.LEFT
	e["submerged"] = true
	e["segments"] = []
	e["tail"] = e.home
	e["tail_z"] = -40.0
	e["head_z"] = -40.0
	e["volleys"] = []
	e["fan_cd"] = 0.0
	e["fan_cycle"] = 0
	e["missile_cd"] = 0.0
	e["age"] = 0.0
	e["bite"] = 0.0
	e["last_player"] = Vector2.INF
	e["player_velocity"] = Vector2.ZERO
	e["still_time"] = 0.0
	# Second form.
	e["trail"] = PackedVector2Array()
	e["traveled"] = 0.0
	e["breach"] = e.home
	e["heading"] = PI
	e["move_mode"] = "prowl"
	e["move_time"] = 0.0
	e["move_target"] = e.home
	e["move_side"] = 1.0
	e["charge_cd"] = 5.0
	e["charge_start"] = e.home
	e["charge_end"] = e.home
	e["charge_dir"] = Vector2.LEFT
	e["orb_cd"] = 3.0
	e["aimed_cd"] = 1.5
	e["aimed_cycle"] = 0
	e["beam_cd"] = 4.5
	e["broadside_cd"] = 2.4
	e["broadside_cycle"] = 0
	e["tail_cd"] = 3.2
	e["tail_cycle"] = 0
	e.p = e.home
	e.dir = Vector2.LEFT
	e.cd = 1.0

func rage(e: Dictionary) -> bool:
	return e.hp <= e.phase_hp*(SECOND_FORM+0.5) if e.phase == 1 else e.hp <= e.phase_hp*SECOND_FORM*0.5

func ink(e: Dictionary) -> Color:
	return INK.lerp(RAGE_INK,0.65) if rage(e) else INK

func muzzle(e: Dictionary) -> Vector2:
	return e.p+e.face*MUZZLE

func tail_muzzle(e: Dictionary) -> Vector2:
	return e.tail

func mount_position(e: Dictionary, index: int) -> Vector2:
	if index < 0 or index >= e.segments.size(): return e.p
	return e.segments[index].p

func touches(e: Dictionary, player: Vector2, radius: float) -> bool:
	if e.get("submerged",true) and e.phase == 1 and e.state == "under": return false
	if not e.get("submerged",true) and e.p.distance_to(player) < HEAD_RADIUS+radius: return true
	for segment in e.segments:
		if segment.z < 0: continue
		if segment.p.distance_to(player) < segment.radius+radius: return true
	return e.tail_z >= 0 and e.tail.distance_to(player) < 18.0+radius

# Armoured links stop player shots; the head itself is left to the normal hit test.
func intercept_bullet(game, bullet: Dictionary) -> bool:
	for e in game.enemies:
		if not e.has("segments") or e.hp <= 0: continue
		for segment in e.segments:
			if segment.z < 0: continue
			if bullet.p.distance_squared_to(segment.p) < segment.radius*segment.radius:
				game.combat_events.enemy_hit.emit(bullet.p,0.0,true,false)
				return true
	return false

func block_damage(_game, _e: Dictionary, _damage: float, _direction: Vector2) -> bool:
	return false

func shock(game, e: Dictionary, damage: float) -> void:
	if e.submerged: return
	if game.player.distance_to(e.p) <= game.SHOCK_RADIUS+CORE and game.attack_reaches(game.player,e.p):
		game.hurt_enemy(e,damage,game.player.direction_to(e.p),0,true)

func lance(game, e: Dictionary, rays: Array, direction: Vector2, damage: float) -> void:
	if e.submerged: return
	if game.LanceTrace.hits(game,e,rays,direction): game.hurt_enemy(e,damage,direction,0,true)

func on_destroyed(game, e: Dictionary) -> void:
	for segment in e.segments:
		if segment.z >= 0: game.burst(segment.p,ink(e),6)

# ---------------------------------------------------------------- shots

func emit_field(game, origin: Vector2, direction: Vector2, speed: float, tone: int) -> void:
	game.emit_shot(origin,direction,speed,1,true,1300)
	game.bullets[-1].merge({"pattern":"radial","field":true,"pressure":false,"tone":tone})

func emit_needle(game, origin: Vector2, direction: Vector2, speed: float) -> void:
	game.emit_shot(origin,direction,speed,1,true,1300)
	game.bullets[-1].merge({"pressure":true,"pattern":"wyrm_aimed"})

# A full ring with `gaps` evenly spaced escape lanes, each `gap_width` wide.
func fire_ring(game, origin: Vector2, count: int, speed: float, gaps: int, gap_width: float, base: float, tone: int) -> void:
	for i in range(count):
		var angle := base+i*TAU/count
		var open := false
		for k in range(gaps):
			if absf(angle_difference(angle,base+k*TAU/gaps)) < gap_width*0.5: open = true
		if not open: emit_field(game,origin,Vector2.from_angle(angle),speed,tone)

func fire_fan(game, e: Dictionary) -> void:
	var origin := tail_muzzle(e)
	var lead: float = 0.3 if e.expert and e.fan_cycle%2 == 1 else 0.0
	var aim: Vector2 = origin.direction_to(game.player+e.player_velocity*lead)
	var count: int = (7 if e.expert else 5)+(2 if rage(e) else 0)
	for i in range(count):
		emit_needle(game,origin,aim.rotated((i-(count-1)*0.5)*0.15),205.0+20.0*e.mid)
	e.fan_cycle += 1
	game.enemy_attack_cue("siege_fire",origin)

func fire_missiles(game, e: Dictionary) -> void:
	var origin := tail_muzzle(e)
	var aim: Vector2 = origin.direction_to(game.player)
	for side in ([-1.0,1.0] if not rage(e) else [-1.0,0.0,1.0]):
		game.emit_shot(origin,aim.rotated(side*0.55),160.0,1,true,1300)
		game.bullets[-1].merge({"guided":true,"pressure":false,"homing_time":2.4,"turn_rate":1.6,"pattern":"missile"})
	game.enemy_attack_cue("siege_fire",origin)

func start_head_laser(boss, game, e: Dictionary) -> void:
	game.enemy_attack_cue("triad_charge",e.p,false)
	var heading: Vector2 = e.face
	var duration: float = 4.0+0.8*e.mid+(0.6 if rage(e) else 0.0)
	var origin: Vector2 = e.p+heading*MUZZLE
	boss.lasers.append({"owner":e,"a":origin,"b":game.attack_end(origin,heading,1600),"heading":heading,
		"warning":LASER_WARNING,"warning_total":LASER_WARNING,"duration":duration,"peak_duration":duration,"triad":true,
		"turn_rate":(0.28+0.08*e.mid)*(1.2 if rage(e) else 1.0),"width":84.0,"muzzle":MUZZLE,"hue":Color("bfe2ff"),"charge_radius":34.0})

func end_lasers(boss, e: Dictionary) -> void:
	for beam in boss.lasers:
		if beam.owner == e: beam.duration = 0

func advance_volleys(game, e: Dictionary, delta: float) -> void:
	for volley in e.volleys:
		volley.t -= delta
		if volley.t > 0: continue
		match volley.kind:
			"ring":
				if e.submerged: continue
				fire_ring(game,muzzle(e),volley.count,volley.speed,volley.gaps,volley.gap,volley.base,0)
				game.enemy_attack_cue("halo_fire",e.p)
			"side":
				var index: int = volley.index
				if index >= e.segments.size() or e.segments[index].z < 0: continue
				var segment: Dictionary = e.segments[index]
				var normal: Vector2 = segment.dir.orthogonal()
				for side in [-1.0,1.0]:
					for spread in volley.spread:
						emit_field(game,segment.p+normal*side*segment.radius,(normal*side).rotated(spread),volley.speed,1 if index%4 == 1 else 0)
				if volley.get("cue",false): game.enemy_attack_cue("pearl_fire",segment.p,false)
			"aimed":
				var origin := muzzle(e)
				var lead: float = volley.get("lead",0.0)
				emit_needle(game,origin,origin.direction_to(game.player+e.player_velocity*lead),volley.speed)
				game.enemy_attack_cue("sniper_fire",origin,false)
	e.volleys = e.volleys.filter(func(v: Dictionary) -> bool: return v.t > 0)

# ---------------------------------------------------------------- first form: burrowing

func pick_holes(game, e: Dictionary) -> void:
	var player: Vector2 = game.player
	var best := Vector2.INF
	var best_tail := Vector2.INF
	var best_score := -INF
	for attempt in range(48):
		var head: Vector2 = e.home+Vector2(game.rng.randf_range(-580,580),game.rng.randf_range(-400,400))
		var angle: float = game.rng.randf_range(0,TAU)
		var tail: Vector2 = head+Vector2.from_angle(angle)*game.rng.randf_range(320,560)
		if not hole_clear(game,e,head,HOLE_RADIUS+NECK_REACH*0.5) or not hole_clear(game,e,tail,TAIL_HOLE_RADIUS+40): continue
		var score: float = minf(head.distance_to(player),420.0)+minf(tail.distance_to(player),260.0)*0.6
		if e.head_hole != Vector2.INF: score += minf(head.distance_to(e.head_hole),300.0)*0.5
		if head.distance_to(player) < 300 or tail.distance_to(player) < 210: score -= 1000
		if score > best_score:
			best_score = score
			best = head
			best_tail = tail
	if best == Vector2.INF:
		best = e.home
		best_tail = e.home+Vector2(320,0)
	e.head_hole = best
	e.tail_hole = best_tail
	var toward: Vector2 = best.direction_to(player)
	e.emerge_dir = toward if not toward.is_zero_approx() else Vector2.LEFT
	e.tail_dir = best_tail.direction_to(best).rotated(PI)
	e.face = e.emerge_dir

func hole_clear(game, e: Dictionary, p: Vector2, radius: float) -> bool:
	if not game.walkable(p,radius): return false
	for point in e.cover_points:
		if point.distance_to(p) < radius+40: return false
	return true

func burrow_pose(e: Dictionary) -> void:
	var t: float = e.rise_amount
	var lift: float = t*t*(3.0-2.0*t)
	var hole: Vector2 = e.head_hole
	e.p = hole+e.emerge_dir*NECK_REACH*lift
	e.submerged = t < 0.35
	var segments: Array = []
	# The neck arches out of the hole up to the raised head.
	for i in range(NECK):
		var k: float = 1.0-float(i+1)/(NECK+1)
		var p: Vector2 = hole.lerp(e.p,k)
		var z: float = lerpf(-30.0,30.0,lift)*k+sin(k*PI)*16.0*lift
		segments.append({"p":p,"dir":e.emerge_dir,"radius":lerpf(30.0,37.0,k),"z":z if lift > 0.15 else -40.0,"kind":"neck"})
	# The tail rises from its own hole, its tip swaying over the floor.
	var sway: float = sin(e.age*2.1)*0.35
	var tip: Vector2 = e.tail_hole+e.tail_dir.rotated(sway)*TAIL_REACH*lift
	for i in range(TAIL_LINKS):
		var k: float = float(i)/TAIL_LINKS
		var p: Vector2 = e.tail_hole.lerp(tip,k)
		segments.append({"p":p,"dir":e.tail_dir.rotated(sway*k),"radius":lerpf(28.0,17.0,k),"z":(lerpf(-24.0,20.0,lift)*(0.4+0.6*k)) if lift > 0.15 else -40.0,"kind":"body"})
	e.tail = tip
	e.tail_z = lerpf(-24.0,24.0,lift)
	e.head_z = lerpf(-40.0,30.0,lift)
	e.segments = segments

func begin_emerge(game, e: Dictionary) -> void:
	e.state = "emerge"
	e.state_time = EMERGE_TIME
	game.enemy_attack_cue("wyrm_breach",e.head_hole)
	game.burst(e.head_hole,INK,14)
	game.burst(e.tail_hole,INK,8)
	for hole in [[e.head_hole,HOLE_RADIUS],[e.tail_hole,TAIL_HOLE_RADIUS]]:
		if game.player.distance_to(hole[0]) < hole[1]+game.PLAYER_HIT_RADIUS: game.die()

func begin_exposed(boss, game, e: Dictionary) -> void:
	e.state = "exposed"
	var odd: bool = e.rise%2 == 1
	e.fan_cd = 0.6
	e.missile_cd = 0.5
	if not odd:
		# Pattern A: a broad, slowly tracking beam from the head; aimed fans from the tail.
		start_head_laser(boss,game,e)
		var duration: float = boss.lasers[-1].duration
		e.volleys.append({"t":LASER_WARNING+duration+0.1,"kind":"ring","count":44,"speed":150.0,"gaps":3,"gap":deg_to_rad(44.0),"base":e.face.angle()+PI/3})
		e.state_time = LASER_WARNING+duration+0.55
	else:
		# Pattern B: ring after ring with three escape lanes that drift sideways,
		# so the player keeps running with the gap; homing missiles from the tail.
		var waves: int = 7 if rage(e) else 6
		var drift: float = (0.21+0.04*e.mid)*(1.0 if (e.rise/2)%2 == 0 else -1.0)
		var base: float = e.face.angle()+PI/3
		var gap: float = deg_to_rad(lerpf(52.0,42.0,e.low)-8.0*e.mid)
		for wave in range(waves):
			e.volleys.append({"t":0.35+wave*0.62*e.attack_scale,"kind":"ring","count":56+roundi(8*e.mid),"speed":150.0+15.0*e.mid,"gaps":3,"gap":gap,"base":base+wave*drift})
		e.state_time = 0.35+waves*0.62*e.attack_scale+0.45

func advance_burrow(boss, game, e: Dictionary, delta: float) -> void:
	if e.head_hole == Vector2.INF: pick_holes(game,e)
	e.state_time -= delta
	match e.state:
		"under":
			e.rise_amount = 0.0
			if e.state_time <= 0: begin_emerge(game,e)
		"emerge":
			e.rise_amount = clampf(1.0-e.state_time/EMERGE_TIME,0,1)
			if e.state_time <= 0: begin_exposed(boss,game,e)
		"exposed":
			e.rise_amount = 1.0
			var laser := false
			for beam in boss.lasers:
				if beam.owner == e:
					laser = true
					e.face = beam.heading
			if not laser:
				var toward: Vector2 = e.p.direction_to(game.player)
				e.face = Vector2.from_angle(rotate_toward(e.face.angle(),toward.angle(),1.4*delta))
			if e.rise%2 == 0:
				e.fan_cd -= delta
				if e.fan_cd <= 0:
					fire_fan(game,e)
					e.fan_cd = (0.85 if rage(e) else 1.05)*e.attack_scale
			else:
				e.missile_cd -= delta
				if e.missile_cd <= 0:
					fire_missiles(game,e)
					e.missile_cd = (1.25 if rage(e) else 1.5)*e.attack_scale
			if e.state_time <= 0:
				e.state = "dive"
				e.state_time = DIVE_TIME
				end_lasers(boss,e)
		"dive":
			e.rise_amount = clampf(e.state_time/DIVE_TIME,0,1)
			if e.state_time <= 0:
				e.state = "under"
				e.state_time = UNDER_TIME*e.attack_scale
				e.rise += 1
				pick_holes(game,e)
				game.enemy_attack_cue("wyrm_rumble",e.head_hole,false)
	burrow_pose(e)

# ---------------------------------------------------------------- transition

func begin_breach(boss, game, e: Dictionary) -> void:
	e.phase = 2
	e.hp_floor = e.hp
	e.volleys.clear()
	end_lasers(boss,e)
	# The beast drops every shot in flight as it tears loose; a clean start.
	for b in game.bullets:
		if b.hostile:
			game.burst(b.p,INK,1)
			b.life = 0
	e.state = "breach_dive" if e.state in ["emerge","exposed","dive"] else "breach_wait"
	e.state_time = BREACH_DIVE if e.state == "breach_dive" else BREACH_WAIT
	e.breach = e.home
	game.enemy_attack_cue("boss_release",e.p)

func advance_breach(boss, game, e: Dictionary, delta: float) -> void:
	e.state_time -= delta
	if e.state == "breach_dive":
		e.rise_amount = clampf(minf(e.rise_amount,e.state_time/BREACH_DIVE),0,1)
		burrow_pose(e)
		if e.state_time <= 0:
			e.state = "breach_wait"
			e.state_time = BREACH_WAIT
			game.enemy_attack_cue("wyrm_rumble",e.breach,false)
		return
	e.rise_amount = 0.0
	e.p = e.breach
	e.submerged = true
	e.segments = []
	if e.state_time > 0: return
	# Burst out at the centre, already moving away from the player.
	if game.player.distance_to(e.breach) < BREACH_RADIUS+game.PLAYER_HIT_RADIUS: game.die()
	game.burst(e.breach,INK,22)
	game.enemy_attack_cue("wyrm_breach",e.breach)
	e.state = "roam"
	e.submerged = false
	e.hp_floor = 0.0
	var away: Vector2 = game.player.direction_to(e.breach)
	e.heading = (away if not away.is_zero_approx() else Vector2.RIGHT).angle()
	e.face = Vector2.from_angle(e.heading)
	e.trail = PackedVector2Array([e.breach])
	e.traveled = 0.0
	enter_mode(game,e,"prowl")
	place_body(e)

# ---------------------------------------------------------------- second form: prowling

func enter_mode(game, e: Dictionary, mode: String) -> void:
	e.move_mode = mode
	match mode:
		"prowl":
			var target: Vector2 = e.p
			for attempt in range(12):
				target = e.home+Vector2(game.rng.randf_range(-540,540),game.rng.randf_range(-360,360))
				if target.distance_to(e.p) > 320 and target.distance_to(game.player) > 160: break
			e.move_target = target
			e.move_time = game.rng.randf_range(2.4,3.4)
		"stalk":
			e.move_side = -e.move_side
			e.move_time = game.rng.randf_range(2.2,3.0)
		"evade":
			e.move_target = (e.p+game.player.direction_to(e.p)*360).clamp(e.home-Vector2(560,380),e.home+Vector2(560,380))
			e.move_time = 1.4
		"charge_warning":
			var aim: Vector2 = game.player+e.player_velocity*0.3*e.mid
			e.charge_dir = e.p.direction_to(aim)
			if e.charge_dir.is_zero_approx(): e.charge_dir = Vector2.from_angle(e.heading)
			e.charge_start = e.p
			e.charge_end = e.p
			for distance in range(16,roundi(640+120*e.mid)+1,16):
				var next: Vector2 = e.p+e.charge_dir*distance
				if not game.walkable(next,HEAD_RADIUS+4): break
				e.charge_end = next
			if e.p.distance_to(e.charge_end) < 180:
				enter_mode(game,e,"prowl")
				return
			e.move_time = maxf(1.05*e.attack_scale,absf(angle_difference(e.heading,e.charge_dir.angle()))/3.0+0.35)*(0.88 if rage(e) else 1.0)
			game.enemy_attack_cue("boss_mark",e.p,false)
			for beam in game.boss.lasers:
				if beam.owner == e: beam.duration = 0
		"charge":
			e.move_time = e.p.distance_to(e.charge_end)/charge_speed(e)+0.05
			game.enemy_attack_cue("boss_release",e.p)
		"recoil":
			e.move_time = 0.8
			e.charge_cd = (5.0 if rage(e) else 6.5)*e.attack_scale

func charge_speed(e: Dictionary) -> float:
	return (430.0+60.0*e.mid)*e.speed_scale

func next_mode(game, e: Dictionary) -> void:
	match e.move_mode:
		"charge_warning": enter_mode(game,e,"charge")
		"charge": enter_mode(game,e,"recoil")
		_:
			if e.charge_cd <= 0 and e.p.distance_to(game.player) > 240: enter_mode(game,e,"charge_warning")
			elif e.still_time > 1.6 or (e.move_mode == "prowl" and game.rng.randf() < 0.55): enter_mode(game,e,"stalk")
			else: enter_mode(game,e,"prowl")

func steer(game, e: Dictionary, desired: float, turn_rate: float, delta: float) -> void:
	# Look ahead for walls and pillars; bend toward the nearest clear heading.
	var best := desired
	for k in range(9):
		var trial: float = desired+(0.0 if k == 0 else (((k+1)/2)*0.38*(1 if k%2 == 1 else -1)))
		var clear := true
		for reach in [70.0,130.0]:
			if not game.walkable(e.p+Vector2.from_angle(trial)*reach,HEAD_RADIUS): clear = false
		if clear:
			best = trial
			break
		if k == 8: best = e.p.angle_to_point(e.home)
	e.heading = rotate_toward(e.heading,best,turn_rate*delta)

func advance_roam(boss, game, e: Dictionary, delta: float) -> void:
	var angry: bool = rage(e)
	e.move_time -= delta
	e.charge_cd -= delta
	if e.move_mode in ["prowl","stalk"] and e.p.distance_to(game.player) < 200: enter_mode(game,e,"evade")
	if e.move_time <= 0: next_mode(game,e)
	var beam_busy := false
	for beam in boss.lasers:
		if beam.owner == e and beam.duration > 0: beam_busy = true
	var speed: float = ((150.0 if angry else 120.0)+20.0*e.mid)*e.speed_scale
	var turn_rate := 1.15
	match e.move_mode:
		"prowl", "evade":
			steer(game,e,e.p.angle_to_point(e.move_target),turn_rate,delta)
			if e.p.distance_to(e.move_target) < 60: e.move_time = minf(e.move_time,0.2)
		"stalk":
			var to_player: Vector2 = e.p.direction_to(game.player)
			var target: Vector2 = game.player+to_player.orthogonal()*e.move_side*260-to_player*60
			steer(game,e,e.p.angle_to_point(target),turn_rate*1.1,delta)
		"charge_warning":
			e.heading = rotate_toward(e.heading,e.charge_dir.angle(),3.0*delta)
			speed = 30.0
		"charge":
			e.heading = e.charge_dir.angle()
			speed = charge_speed(e)
		"recoil":
			steer(game,e,e.heading,0.6,delta)
			speed = 60.0
	if beam_busy and e.move_mode != "charge": speed = minf(speed,60.0)
	var step: Vector2 = Vector2.from_angle(e.heading)*speed*delta
	if e.move_mode == "charge": step = step.limit_length(e.p.distance_to(e.charge_end))
	if game.walkable(e.p+step,HEAD_RADIUS-6):
		e.p += step
		e.traveled += step.length()
	elif e.move_mode == "charge":
		enter_mode(game,e,"recoil")
	else:
		e.heading = rotate_toward(e.heading,e.p.angle_to_point(e.home),2.4*delta)
	if e.move_mode == "charge" and e.p.distance_to(e.charge_end) < 2: enter_mode(game,e,"recoil")
	e.face = Vector2.from_angle(e.heading)
	var trail: PackedVector2Array = e.trail
	if trail.is_empty() or trail[trail.size()-1].distance_to(e.p) >= 6.0:
		trail.append(e.p)
		var keep: int = int((HEAD_GAP+SEGMENTS*SPACING+TAIL_GAP+80)/6.0)+8
		if trail.size() > keep: trail = trail.slice(trail.size()-keep)
		e.trail = trail
	place_body(e)
	advance_roam_attacks(boss,game,e,delta,angry)

# Segments sit at fixed arc lengths behind the head along its own path. Links
# not yet out of the breach hole stay underground there.
func place_body(e: Dictionary) -> void:
	var trail: PackedVector2Array = e.trail
	var points := PackedVector2Array([e.p])
	for i in range(trail.size()-1,-1,-1): points.append(trail[i])
	var segments: Array = []
	var walked := 0.0
	var index := 0
	var count: int = SEGMENTS+1
	for n in range(count):
		var s: float = HEAD_GAP+n*SPACING+(TAIL_GAP-SPACING if n == SEGMENTS else 0.0)
		var p: Vector2 = points[points.size()-1]
		var direction: Vector2 = e.face
		while index < points.size()-1:
			var a: Vector2 = points[index]
			var b: Vector2 = points[index+1]
			var length: float = a.distance_to(b)
			if walked+length >= s:
				p = a.lerp(b,(s-walked)/maxf(length,0.001))
				direction = b.direction_to(a) if length > 0.001 else direction
				break
			walked += length
			index += 1
		if index >= points.size()-1 and n > 0: direction = segments[-1].dir if not segments.is_empty() else direction
		var k: float = float(n)/SEGMENTS
		var out: float = clampf((e.traveled-s)/50.0,0.0,1.0)
		var wave: float = 10.0+6.0*sin(s*0.022-e.age*3.2)
		var z: float = lerpf(-40.0,wave,out) if out > 0 else -40.0
		var kind: String = "tail" if n == SEGMENTS else "body"
		segments.append({"p":p,"dir":direction,"radius":(19.0 if kind == "tail" else lerpf(BODY_RADIUS[0],BODY_RADIUS[1],k)),"z":z,"kind":kind})
	e.segments = segments
	var tail: Dictionary = segments[-1]
	e.tail = tail.p-tail.dir*24.0
	e.tail_z = tail.z
	e.head_z = 26.0

func advance_roam_attacks(boss, game, e: Dictionary, delta: float, angry: bool) -> void:
	var scale: float = e.attack_scale*(0.8 if angry else 1.0)
	# Head: three aimed needles, and now and then a large energy orb.
	e.aimed_cd -= delta
	if e.aimed_cd <= 0:
		var lead: float = 0.22 if e.expert and e.aimed_cycle%2 == 1 else 0.0
		for i in range(4 if angry else 3):
			e.volleys.append({"t":i*0.1,"kind":"aimed","speed":(255.0+25.0*e.mid),"lead":lead})
		e.aimed_cycle += 1
		e.aimed_cd = 1.7*scale
	e.orb_cd -= delta
	if e.orb_cd <= 0 and e.move_mode != "charge":
		var origin := muzzle(e)
		game.bullets.append({"p":origin,"v":Vector2.ZERO,"damage":1.0,"hostile":true,"life":8.0,
			"energy_orb":true,"orb_phase":"charge","orb_age":0.0,"orb_radius":18.0,
			"orb_flash":0.0,"orb_speed_scale":0.95+0.1*e.mid,"pressure":false})
		game.enemy_attack_cue("boss_orb_charge",origin,false)
		e.orb_cd = 7.0*scale
	# Body: telegraphed thin beams square to the hull, never swung around.
	e.beam_cd -= delta
	if e.beam_cd <= 0 and not e.move_mode in ["charge_warning","charge"]:
		var picks: Array = [4,9,13] if angry else [5,11]
		var shift: int = game.rng.randi_range(-1,1)
		for pick in picks:
			var index: int = clampi(pick+shift,1,SEGMENTS-2)
			var segment: Dictionary = e.segments[index]
			if segment.z < 0: continue
			var normal: Vector2 = segment.dir.orthogonal()
			if normal.dot(game.player-segment.p) < 0: normal = -normal
			var heading: Vector2 = normal.rotated(clampf(normal.angle_to(segment.p.direction_to(game.player)),-0.3,0.3))
			boss.add_laser(segment.p,game.attack_end(segment.p,heading,1800),0.95*e.attack_scale,0.55,e)
			boss.lasers[-1].merge({"mount":index,"heading":heading,"warning_total":0.95*e.attack_scale})
		game.enemy_attack_cue("hunter_lock",e.p,false)
		e.beam_cd = 6.0*scale
	# Body: a mechanical broadside that ripples from neck to tail.
	e.broadside_cd -= delta
	if e.broadside_cd <= 0:
		var spread: Array = [-0.12,0.12] if e.expert else [0.0]
		var start: int = e.broadside_cycle%2
		var k := 0
		for index in range(start,SEGMENTS,2):
			e.volleys.append({"t":k*0.07,"kind":"side","index":index,"speed":165.0+15.0*e.mid,"spread":spread,"cue":k%3 == 0})
			k += 1
		e.broadside_cycle += 1
		e.broadside_cd = 3.4*scale
	# Tail: an even radial burst that turns a little each time.
	e.tail_cd -= delta
	if e.tail_cd <= 0:
		var count: int = (24 if angry else 18)+roundi(4*e.mid)
		var base: float = e.tail_cycle*0.37
		for i in range(count): emit_field(game,e.tail,Vector2.from_angle(base+i*TAU/count),135.0+10.0*e.mid,1)
		game.enemy_attack_cue("halo_fire",e.tail)
		e.tail_cycle += 1
		e.tail_cd = 3.9*scale

# ---------------------------------------------------------------- update

func advance(boss, game, e: Dictionary, delta: float, _toward: Vector2) -> Vector2:
	e.age += delta
	e.cd = 1.0
	e.bite = maxf(0.0,e.bite-delta)
	if e.last_player != Vector2.INF and delta > 0:
		var velocity: Vector2 = ((game.player-e.last_player)/delta).limit_length(game.SPEED+game.move_bonus)
		e.player_velocity = e.player_velocity.lerp(velocity,1.0-exp(-8*delta))
	e.last_player = game.player
	e.still_time = e.still_time+delta if e.player_velocity.length() < 40 else 0.0
	if e.phase == 1 and e.hp <= e.hp_floor+0.001: begin_breach(boss,game,e)
	if e.phase == 1: advance_burrow(boss,game,e,delta)
	elif e.state in ["breach_dive","breach_wait"]: advance_breach(boss,game,e,delta)
	else: advance_roam(boss,game,e,delta)
	advance_volleys(game,e,delta)
	e.dir = e.face
	return Vector2.ZERO

func draw(game) -> void:
	Visual.draw(self,game)

func draw_depth(view, game, e: Dictionary, parts: Dictionary) -> void:
	Visual.draw_depth(self,view,game,e,parts)
