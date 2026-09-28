extends "res://scripts/boss_fortress.gd"
## Six wing mouths write slow, mirrored ribbons around a shielded laser iris.
const Visual = preload("res://scripts/seraph_visuals.gd")
const INK := Color("f7dab0")
const BLUE := Color("8abaff")
const ROSE := Color("ff91b1")
const BODY_RADIUS := 144.0
const LASER_WARNING := 1.15
const LASER_DURATION := 9.0
const COVER_CELLS := [Vector2i(8,-10),Vector2i(8,9),Vector2i(30,-10),Vector2i(30,9)]
const EVICTION_RADIUS := 65.0
const MOTIF_SECONDS := 6.0

func setup(data, e: Dictionary) -> void:
	var dps: float = Balance.primary_dps(data.power,data.fire_rate,data.physics_ticks)
	var low: float = clampf((data.floor_number-5)/20.0,0.0,1.0)
	var mid: float = clampf((data.floor_number-25)/25.0,0.0,1.0)
	var late: float = maxf(0.0,data.floor_number-50)
	e["low"] = low
	e["mid"] = mid
	# Include a conservative three-pellet Scatter contribution. Practice invests
	# in recharge as well as primary fire; primary-only HP underestimated it.
	var combined_dps: float = dps+Balance.sub_dps(data.power,data.recharge,0,data.physics_ticks)*0.5
	e["max_hp"] = combined_dps*14.0*lerpf(0.60,1.0,low*low)*(1.0+0.004*late)
	e.hp = e.max_hp
	e["plates"] = []
	for i in range(COUNT):
		var hp: float = dps*0.20*lerpf(0.7,1.0,low)*(1.0+0.003*late)
		e.plates.append({"hp":hp,"max_hp":hp,"timer":0.0})
	e["home"] = e.p
	e["age"] = 0.0
	e["pattern_time"] = 0.0
	e["motif"] = 0
	e["stream_cd"] = 1.3
	e["bloom_cycle"] = -1
	e["mouth_flash"] = [0.0,0.0,0.0,0.0,0.0,0.0]
	e["root_flash"] = 0.0
	e["needle_cd"] = 1.8
	e["needle_cycle"] = 0
	e["needle_volleys"] = []
	e["last_player"] = Vector2.ZERO
	e["player_velocity"] = Vector2.ZERO
	e["laser_cd"] = 3.0
	e["evictions"] = []
	e["eviction_cd"] = 7.0
	e["cover_points"] = []
	for cell in COVER_CELLS: e.cover_points.append(data.center(cell)+Vector2(16,16))
	e.dir = Vector2.LEFT
	e.cd = 0.5

func wing_angle(e: Dictionary, index: int) -> float:
	return index*TAU/6.0+e.age*0.035+0.08*sin(e.age*0.4)+0.045*sin(e.age*0.85+index*PI/3)

func wing_polygon(e: Dictionary, index: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var mirror: float = 1.0 if index%2 == 0 else -1.0
	for p in Visual.WING_SHAPE:
		points.append(e.p+Vector2(p.x,p.y*mirror).rotated(wing_angle(e,index)))
	return points

func mouth_position(e: Dictionary, index: int) -> Vector2:
	return e.p+Vector2(268,-18 if index%2 == 0 else 18).rotated(wing_angle(e,index))

func root_position(e: Dictionary, index: int) -> Vector2:
	return e.p+Vector2.from_angle(wing_angle(e,index)+PI/6)*147

func stream_heading(e: Dictionary, index: int) -> Vector2:
	var inward: float = (e.p-mouth_position(e,index)).angle()
	var handed: float = -1.0 if e.motif == 2 or (e.motif == 1 and index%2 == 1) else 1.0
	var phase: float = e.pattern_time*0.95+(index%2)*0.6
	if e.motif == 1: phase += (index%3)*TAU/3
	# Grazing trajectories repeatedly sweep the core's approaches before opening
	# into broad ribbons outside. They never sample the player's position.
	return Vector2.from_angle(inward+handed*(0.78+0.13*sin(phase)))

func touches(e: Dictionary, player: Vector2, radius: float) -> bool:
	if e.p.distance_to(player) < BODY_RADIUS+radius: return true
	if e.p.distance_to(player) > 328+radius: return false
	for index in range(6):
		var polygon := wing_polygon(e,index)
		if Geometry2D.is_point_in_polygon(player,polygon): return true
		for j in range(polygon.size()):
			if Geometry2D.get_closest_point_to_segment(player,polygon[j],polygon[(j+1)%polygon.size()]).distance_to(player) < radius: return true
	return false

func emit_pearl(game, origin: Vector2, direction: Vector2, speed: float, tone: int, pattern: String) -> void:
	game.emit_shot(origin,direction,speed,1,true,1100)
	game.bullets[-1].merge({"seraph":true,"field":true,"tone":tone,"pattern":pattern,"source":origin})

func stream_open(e: Dictionary, index: int) -> bool:
	# Alternating banks hand off the openings instead of all six falling silent.
	var offset: float = (index%2)*1.8 if e.low >= 0.5 else 0.0
	return fmod(e.pattern_time+offset,3.6) < lerpf(2.15,2.55,e.low)

func fire_streams(game, e: Dictionary, use_phrase: bool = false) -> void:
	var count: int = 2 if e.low < 0.45 else 3
	var spacing: float = 0.055+0.008*e.mid
	for index in range(6):
		if use_phrase and not stream_open(e,index): continue
		var origin := mouth_position(e,index)
		var heading := stream_heading(e,index)
		for j in range(count):
			emit_pearl(game,origin,heading.rotated((j-(count-1)*0.5)*spacing),112+9*e.mid,index%2,"ribbon")
		e.mouth_flash[index] = 0.16

func fire_bloom(game, e: Dictionary) -> void:
	# Root organs open a second, outward petal. Its broad empty sectors are
	# phase-locked to the wing pattern instead of closing at random.
	var count: int = 5 if e.low < 0.45 else 7
	for index in range(6):
		if index%2 != posmod(e.bloom_cycle,2): continue
		var origin := root_position(e,index)
		var heading: Vector2 = Vector2.from_angle(wing_angle(e,index)+PI/6+0.42*sin(e.pattern_time*0.85))
		for j in range(count):
			emit_pearl(game,origin,heading.rotated((j-(count-1)*0.5)*(0.09+0.02*e.mid)),96+8*e.mid,index%2,"petal")
	e.root_flash = 0.4

func needle_position(e: Dictionary, index: int) -> Vector2:
	return e.p+Vector2(241,43 if index%2 == 0 else -43).rotated(wing_angle(e,index))

func prepare_needles(game, e: Dictionary, rage: bool) -> void:
	var closest := 0
	for i in range(1,6):
		if needle_position(e,i).distance_squared_to(game.player) < needle_position(e,closest).distance_squared_to(game.player): closest = i
	var count: int = 2 if e.mid >= 0.4 else 1
	for bank in range(count):
		var index: int = (closest+bank*(1 if e.needle_cycle%2 == 0 else 5))%6
		# Alternate a direct lane with a lane ahead of the current movement.
		# The target locks before the warning, and never tracks during the burst.
		var lead: float = (0.55+0.25*e.mid) if (bank == 1 or e.needle_cycle%2 == 1) else 0.0
		var target: Vector2 = game.player+(e.player_velocity*lead).limit_length(190)
		var origin := needle_position(e,index)
		e.needle_volleys.append({"gun":index,"target":target,"heading":origin.direction_to(target),
			"timer":lerpf(0.95,0.7,e.low)+bank*0.28,"warning":lerpf(0.95,0.7,e.low)+bank*0.28,
			"left":3+int(e.mid >= 0.8)+int(rage),"fired":0})
	e.needle_cycle += 1

func advance_needles(game, e: Dictionary, delta: float, rage: bool) -> void:
	e.needle_cd -= delta
	if e.needle_cd <= 0:
		prepare_needles(game,e,rage)
		e.needle_cd = (lerpf(3.8,2.9,e.low)-0.45*e.mid)*(0.86 if rage else 1.0)
	for volley in e.needle_volleys:
		volley.timer -= delta
		if volley.timer > 0 or volley.left <= 0: continue
		var origin := needle_position(e,volley.gun)
		# A narrow rake grows outward from the locked lane; it does not chase
		# every dodge. At high floors the delayed second gun forms a pincer.
		var rake: float = (volley.fired-1)*0.045*(1 if volley.gun%2 == 0 else -1)
		for side in ([-1,1] if e.mid >= 0.8 else [0]):
			game.emit_shot(origin,volley.heading.rotated(rake+side*0.075),lerpf(185,230,e.low)+25*e.mid,1,true,1100)
			game.bullets[-1].merge({"pressure":true,"pattern":"seraph_aimed","source":origin})
		volley.left -= 1
		volley.fired += 1
		volley.timer += 0.14
	e.needle_volleys = e.needle_volleys.filter(func(v: Dictionary) -> bool: return v.left > 0)

func laser_duration(rage: bool) -> float:
	return LASER_DURATION+(1.0 if rage else 0.0)

func start_laser(boss, game, e: Dictionary, rage: bool) -> void:
	game.enemy_attack_cue("seraph_charge",e.p,false)
	var heading: Vector2 = e.p.direction_to(game.player)
	if heading.is_zero_approx(): heading = Vector2.LEFT
	var origin: Vector2 = e.p+heading*82
	var duration: float = laser_duration(rage)
	boss.lasers.append({"owner":e,"a":origin,"b":game.attack_end(origin,heading,1600),"heading":heading,
		"warning":LASER_WARNING,"duration":duration,"peak_duration":duration,"seraph":true,
		"turn_rate":(0.29+0.075*e.mid)*(1.24 if rage else 1.0),"width":100.0})

func near_cover(e: Dictionary, player: Vector2) -> bool:
	for point in e.cover_points:
		if point.distance_to(player) < 112: return true
	return false

func advance(boss, game, e: Dictionary, delta: float, _toward: Vector2) -> Vector2:
	e.age += delta
	if e.last_player != Vector2.ZERO:
		var velocity: Vector2 = ((game.player-e.last_player)/maxf(delta,0.0001)).limit_length(game.SPEED+game.move_bonus)
		e.player_velocity = e.player_velocity.lerp(velocity,1.0-exp(-8*delta))
	e.last_player = game.player
	var rage: bool = e.hp <= e.max_hp*0.5
	e.pattern_time += delta*(1.12 if rage else 1.0)
	var motif: int = int(e.pattern_time/MOTIF_SECONDS)%3
	if motif != e.motif:
		e.motif = motif
		e.stream_cd = 0.8 # the mouths turn before reversing the weave
	for plate in e.plates:
		if plate.hp > 0: continue
		plate.timer = maxf(0.0,plate.timer-delta)
		if plate.timer == 0: plate.hp = plate.max_hp
	for i in range(6): e.mouth_flash[i] = maxf(0,e.mouth_flash[i]-delta)
	e.root_flash = maxf(0,e.root_flash-delta)
	e.stream_cd -= delta
	if e.stream_cd <= 0:
		fire_streams(game,e,true)
		e.stream_cd = lerpf(0.27,0.215,e.low)-0.015*e.mid
	# Alternating petals have a separate period from the ribbons, so openings
	# migrate instead of leaving the same wide sector clear every cycle.
	var cycle: int = int(maxf(0,e.pattern_time-1.4)/2.6)
	if e.pattern_time >= 1.4 and cycle != e.bloom_cycle:
		e.bloom_cycle = cycle
		fire_bloom(game,e)
	advance_needles(game,e,delta,rage)
	e.laser_cd -= delta
	if e.laser_cd <= 0:
		start_laser(boss,game,e,rage)
		e.laser_cd = LASER_WARNING+laser_duration(rage)+1.5
	# The core iris sends a visible arcing mote only to occupied cover.
	e.eviction_cd -= delta
	if e.eviction_cd <= 0:
		if near_cover(e,game.player):
			e.evictions.append({"p":game.player,"origin":e.p,"timer":1.5})
			game.enemy_attack_cue("boss_mark",game.player,false)
			e.eviction_cd = 8.0
		else: e.eviction_cd = 0.8
	for strike in e.evictions:
		strike.timer -= delta
		if strike.timer <= 0 and strike.timer+delta > 0:
			game.enemy_attack_cue("boss_release",strike.p,false)
			if strike.p.distance_to(game.player) < EVICTION_RADIUS: game.die()
	e.evictions = e.evictions.filter(func(s: Dictionary) -> bool: return s.timer > -0.32)
	var destination: Vector2 = e.home+Vector2(sin(e.age*0.27)*38,cos(e.age*0.31)*34)
	return (destination-e.p).limit_length(28*delta)/maxf(delta,0.0001)

func draw(game) -> void:
	Visual.draw(self,game)

func draw_depth(view, game, e: Dictionary, parts: Dictionary) -> void:
	Visual.draw_depth(self,view,game,e,parts)
