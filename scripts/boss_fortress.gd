extends RefCounted

const Balance = preload("res://scripts/combat_balance.gd")
const RADIUS := 96.0
const COUNT := 12
const REBUILD := 8.0
const CORE := 48.0
const PATTERNS := ["radial","fan","laser","missile","fan","slam","radial","laser","fan","missile","slam","radial"]
const EXPERT_PATTERNS := ["radial","crossfire","laser","missile","weave","slam","fan","scissor","radial","crossfire","missile","weave","slam","laser"]
var motion = preload("res://scripts/fortress_motion.gd").new()
const BossFx = preload("res://scripts/boss_fx.gd")
const CitadelVisual = preload("res://scripts/citadel_visuals.gd")
const SHIELD_INK := Color("ffb07a")

func setup(data, e: Dictionary) -> void:
	var dps: float = Balance.primary_dps(data.power,data.fire_rate,data.physics_ticks)
	var low: float = clampf((data.floor_number-5)/20.0,0.0,1.0)
	var mid: float = clampf((data.floor_number-25)/25.0,0.0,1.0)
	var late: float = maxf(0.0,data.floor_number-50)
	# DPS tracks the current build. After floor 50 the extra factor gives
	# durability a modest edge over that same player's continuing growth.
	e["low"] = low
	e["mid"] = mid
	e["speed_scale"] = lerpf(0.68,1.0,low)*(1.0+0.001*late)
	e["attack_scale"] = lerpf(1.35,1.0,low)/(1.0+0.0015*late)
	e["bullet_scale"] = lerpf(0.82,1.0,low)*(1.0+0.0008*late)
	e.hp = dps*11.0*lerpf(0.65,1.0,low*low)*(1.0+0.004*late)
	e["max_hp"] = e.hp
	e["plates"] = []
	for i in range(COUNT): e.plates.append({"hp":dps*0.65*lerpf(0.55,1.0,low*low)*(1.0+0.003*late),"max_hp":dps*0.65*lerpf(0.55,1.0,low*low)*(1.0+0.003*late),"timer":0.0})
	e["step"] = 0
	e["slam"] = []
	e["home"] = data.center(Vector2i(24,1))
	e["expert"] = data.floor_number >= 50
	e["heading"] = -PI/2
	e["tread"] = 0.0
	e["machine_cd"] = 0.4
	e["machine_cycle"] = 0
	e["pattern"] = "radial"
	e.dir = Vector2.UP
	e.cd = 0.65
	motion.setup(e)

func touches(e: Dictionary, player: Vector2, radius: float) -> bool:
	if e.p.distance_to(player) < 108+radius: return true
	# Hull, separate track belts and sponson rings match the 3D chassis
	# footprint; the recess ahead of the glacis stays traversable.
	for polygon in CitadelVisual.contact_parts(e):
		if Geometry2D.is_point_in_polygon(player,polygon): return true
		for j in range(polygon.size()):
			if Geometry2D.get_closest_point_to_segment(player,polygon[j],polygon[(j+1)%polygon.size()]).distance_to(player) < radius: return true
	for gun in range(4):
		if player.distance_to(gun_position(e,gun)) < CitadelVisual.MOUNT_RADIUS+radius: return true
	return false

func plate_position(e: Dictionary, i: int) -> Vector2:
	return e.p+Vector2.from_angle(i*TAU/COUNT)*RADIUS

func damage_plate(game, e: Dictionary, i: int, damage: float) -> void:
	var plate: Dictionary = e.plates[i]
	plate.hp = maxf(0,plate.hp-damage)
	game.combat_events.enemy_hit.emit(plate_position(e,i),damage,true,false)
	if plate.hp == 0:
		plate.timer = REBUILD
		game.sound.play_sfx("armor_break")
		game.burst(plate_position(e,i),Color("63f5ce"),8)

func intercept_bullet(game, bullet: Dictionary) -> bool:
	for e in game.enemies:
		if not e.has("plates") or e.hp <= 0: continue
		var offset: Vector2 = bullet.p-e.p
		if absf(offset.length()-RADIUS) > 12: continue
		var i := posmod(roundi(offset.angle()/TAU*COUNT),COUNT)
		if e.plates[i].hp > 0:
			damage_plate(game,e,i,bullet.damage)
			return true
	return false

func block_damage(game, e: Dictionary, damage: float, direction: Vector2) -> bool:
	# Sub-weapons and direct damage use the incoming side, never bypass armor.
	var i := posmod(roundi((-direction).angle()/TAU*COUNT),COUNT)
	if e.plates[i].hp <= 0: return false
	damage_plate(game,e,i,damage)
	return true

func shock(game, e: Dictionary, damage: float) -> void:
	var incoming: Vector2 = game.player.direction_to(e.p)
	var front := posmod(roundi((-incoming).angle()/TAU*COUNT),COUNT)
	var exposed: bool = e.plates[front].hp <= 0
	for i in range(COUNT):
		var point := plate_position(e,i)
		# Only the facing side can be reached by the expanding wave.
		if (point-e.p).dot(game.player-e.p) <= 0: continue
		if e.plates[i].hp > 0 and game.player.distance_to(point) <= game.SHOCK_RADIUS+12 and game.attack_reaches(game.player,point):
			damage_plate(game,e,i,damage)
	if exposed and game.player.distance_to(e.p) <= game.SHOCK_RADIUS+CORE and game.attack_reaches(game.player,e.p):
		game.hurt_enemy(e,damage,incoming,0,true)

func lance(game, e: Dictionary, rays: Array, direction: Vector2, damage: float) -> void:
	var touched := {}
	var core_hit := false
	# All lanes resolve against the pre-shot shield state. A single lance cannot
	# break a panel and damage the core through that newly opened hole.
	for ray in rays:
		var along: float = (e.p-ray.p).dot(direction)
		var start: float = maxf(0,along-RADIUS-16)
		var finish: float = minf(ray.p.distance_to(ray.end),along+RADIUS+16)
		var distance := start
		while distance <= finish:
			var point: Vector2 = game.LanceTrace.lane_point(ray,direction,distance)
			var offset: Vector2 = point-e.p
			if absf(offset.length()-RADIUS) <= 12:
				var i := posmod(roundi(offset.angle()/TAU*COUNT),COUNT)
				if e.plates[i].hp > 0:
					touched[i] = true
					break
			if offset.length() <= CORE:
				core_hit = true
				break
			distance += 4
	for i in touched: damage_plate(game,e,i,damage)
	if core_hit: game.hurt_enemy(e,damage,direction,0,true)

func gun_position(e: Dictionary, gun: int) -> Vector2:
	return e.p+Vector2.from_angle(gun*PI/2+PI/4+e.heading)*140

func gun_direction(game, e: Dictionary, gun: int) -> Vector2:
	for beam in game.boss.lasers:
		if beam.owner == e and beam.get("gun",-1) == gun: return beam.heading
	return gun_position(e,gun).direction_to(game.player)

func drive(game, e: Dictionary, delta: float, rage: bool) -> Vector2:
	return motion.advance(game,e,delta,rage)

func radial_angle(index: int, count: int, gap_degrees: float) -> float:
	var sector := index%4
	var local_index := index/4
	var local_count := (count-1-sector)/4+1
	var half_lobe := (PI/2-deg_to_rad(gap_degrees))*0.5
	return sector*PI/2+lerpf(-half_lobe,half_lobe,float(local_index)/maxi(local_count-1,1))

func queue_gun(boss, e: Dictionary, gun: int, delay: float, count: int, spread: float, speed: float, aim: Vector2, pattern: String) -> Dictionary:
	boss.queue_aimed(e,delay,count,spread,speed)
	var salvo: Dictionary = boss.salvos[-1]
	salvo.merge({"gun":gun,"aim":aim,"pattern":pattern},true)
	return salvo

func machine_gun(boss, game, e: Dictionary, rage: bool) -> void:
	# A streaming burst re-aims each round. Keep moving to lead it off target.
	var gun: int = [0,2,1,3][e.machine_cycle%4]
	for i in range((7+roundi(3*e.low)) if rage else (5+roundi(3*e.low))):
		var salvo := queue_gun(boss,e,gun,0.25+i*0.10*e.attack_scale,1,0,285,Vector2.ZERO,"machine")
		if e.expert and e.machine_cycle%2 == 1: salvo["lead"] = 0.22
	if e.expert:
		# Opposite turret arrives after the direct stream and leads the dodge.
		for i in range(7 if rage else 6):
			var intercept := queue_gun(boss,e,(gun+2)%4,0.48+i*0.12,1,0,320,Vector2.ZERO,"intercept")
			intercept["lead"] = 0.34
	e.machine_cycle += 1
	e.machine_cd = (0.95 if rage else 1.15)*e.attack_scale

func pattern(boss, game, e: Dictionary, name: String, rage: bool) -> void:
	var cycle: int = e.step/(EXPERT_PATTERNS.size() if e.expert else PATTERNS.size())
	if name == "radial":
		# Four lobes with 36-degree escape corridors, rotating between waves.
		# Their angle is locked for each pair; it never follows the player.
		var rotation: float = (cycle*0.37+(e.step%3)*0.19)
		for wave in range(2 if e.low >= 0.5 else 1):
			var offsets := PackedFloat32Array()
			var count := (30+roundi(10*e.low)) if rage else (20+roundi(8*e.low))
			for i in range(count): offsets.append(radial_angle(i,count,lerpf(54.0,36.0,e.low)-16.0*e.mid)+rotation+wave*(0.20 if e.expert else 0.10))
			boss.salvos.append({"owner":e,"delay":0.22+wave*0.36,"offsets":offsets,"speed":155.0+wave*35,"aim":Vector2.RIGHT,"pattern":"radial"})
	elif name == "weave":
		# Successive six-spoke volleys rotate; there is no stationary safe ray.
		for wave in range(6 if rage else 5):
			var offsets := PackedFloat32Array()
			for spoke in range(6): offsets.append(spoke*TAU/6+wave*0.14*(1 if cycle%2 == 0 else -1)+e.step*0.27)
			boss.salvos.append({"owner":e,"delay":0.25+wave*0.16,"offsets":offsets,"speed":205.0,"aim":Vector2.RIGHT,"pattern":"weave"})
	elif name == "crossfire":
		for wave in range(3 if rage else 2):
			for gun in [0,2]:
				var aim := gun_position(e,gun).direction_to(game.player+e.player_velocity*0.2).rotated((0.22 if gun == 0 else -0.22)*(1-wave))
				queue_gun(boss,e,gun,0.3+wave*0.27,5,0.09,245,aim,"crossfire")
	elif name == "scissor":
		game.enemy_attack_cue("hunter_lock",e.p,false)
		for gun in [1,3]:
			var origin := gun_position(e,gun)
			var side: float = 1.0 if gun == 1 else -1.0
			var heading := origin.direction_to(game.player).rotated(side*0.48)
			boss.add_laser(origin,game.attack_end(origin,heading,1800),0.95,0.8,e)
			boss.lasers[-1].merge({"gun":gun,"heading":heading,"sweep":-side*0.32})
	elif name == "fan":
		# Opposite cannons alternate wide fans; later fans close the first gaps.
		for wave in range((2+int(rage)) if e.low >= 0.5 else (1+int(rage))):
			var gun: int = (e.step+wave*2)%4
			var aim := gun_position(e,gun).direction_to(game.player).rotated((wave-0.5)*0.13)
			queue_gun(boss,e,gun,0.22+wave*0.26,(7+roundi(2*e.low)) if rage else (5+roundi(2*e.low)),0.15,215+wave*15,aim,"fan")
	elif name == "missile":
		for wave in range((3 if rage else 2) if e.low >= 0.5 else (2 if rage else 1)):
			for gun in [1,3]:
				var aim := gun_position(e,gun).direction_to(game.player).rotated(-0.5 if gun == 1 else 0.5)
				var salvo := queue_gun(boss,e,gun,0.3+wave*0.3,1,0,165,aim,"missile")
				salvo["guided"] = true
	elif name == "laser":
		game.enemy_attack_cue("hunter_lock",e.p,false)
		for gun in ([0,2,3] if rage else [0,2]):
			var origin := gun_position(e,gun)
			var heading := origin.direction_to(game.player).rotated(-0.15 if gun == 0 else 0.15)
			boss.add_laser(origin,game.attack_end(origin,heading,1800),0.9*e.attack_scale,0.55,e)
			boss.lasers[-1].merge({"gun":gun,"heading":heading})
	elif name == "slam":
		game.enemy_attack_cue("boss_mark",game.player,false)
		# The core lobs a hammer over cover; the target stays fixed while the tank drives on.
		e.slam.append({"p":game.player,"source":e.p,"radius":lerpf(58.0,68.0,e.low),"time":0.95*e.attack_scale,"warning":0.95*e.attack_scale,"fired":false})
		if rage:
			var side: Vector2 = e.p.direction_to(game.player).orthogonal()*145
			e.slam.append({"p":game.player+side,"source":e.p,"radius":lerpf(58.0,68.0,e.low),"time":1.25*e.attack_scale,"warning":1.25*e.attack_scale,"fired":false})

func advance(boss, game, e: Dictionary, delta: float, _toward: Vector2) -> Vector2:
	for plate in e.plates:
		if plate.hp > 0: continue
		plate.timer = maxf(0,plate.timer-delta)
		if plate.timer == 0: plate.hp = plate.max_hp
	for slam in e.slam:
		slam.time -= delta
		if slam.time <= 0 and not slam.fired:
			slam.fired = true
			game.burst(slam.p,Color("ff9470"),18)
			game.enemy_attack_cue("siege_fire",slam.p)
			# Lobbed over cover, so hiding behind a pillar is not permanent safety.
			if game.player.distance_to(slam.p) < slam.radius+game.PLAYER_HIT_RADIUS: game.die()
	e.slam = e.slam.filter(func(s): return s.time > -0.22)
	var rage: bool = e.hp <= e.max_hp*0.5
	e.machine_cd -= delta
	if e.machine_cd <= 0: machine_gun(boss,game,e,rage)
	if e.cd <= 0:
		var sequence: Array = EXPERT_PATTERNS if e.expert else PATTERNS
		e.pattern = sequence[e.step%sequence.size()]
		if e.move_mode in ["ram_warning","ram"] and e.pattern in ["laser","scissor"]: e.pattern = "fan"
		pattern(boss,game,e,e.pattern,rage)
		e.step += 1
		# No recovery state. The next pattern starts before existing fire ends.
		e.cd = lerpf(0.72 if rage else 0.95,0.64 if rage else 0.82,e.mid)*e.attack_scale
	return drive(game,e,delta,rage)

func draw(game) -> void:
	for e in game.enemies:
		if not e.has("plates") or e.hp <= 0 or not game.attack_open(e.p): continue
		var ink := Color("ff9470") if e.hp > e.max_hp*0.5 else Color("ff496a")
		motion.draw(game,e)
		CitadelVisual.draw(self,game,e,ink)
		var clock: float = game.presentation.clock
		var rage: bool = e.hp <= e.max_hp*0.5
		BossFx.shield_ring(game,e,COUNT,SHIELD_INK,REBUILD)
		BossFx.energy_core(game,e.p,CORE*0.5,ink,clock,rage)
		for gun in range(4):
			var origin := gun_position(e,gun)
			var progress := -1.0
			for salvo in game.boss.salvos:
				if salvo.owner == e and salvo.get("gun",-1) == gun and salvo.delay <= 0.6:
					progress = maxf(progress,1.0-salvo.delay/0.6)
			if progress >= 0: BossFx.charge(game,origin,progress,ink)
		for beam in game.boss.lasers:
			if beam.owner != e or not beam.has("sweep") or beam.warning <= 0: continue
			# Sweep direction: a chevron trail along the arc the beam will travel.
			var angle: float = beam.heading.angle()
			var end_angle: float = angle+beam.sweep*0.8
			game.draw_arc(beam.a,90,angle,end_angle,18,Color(ink,0.7),1.6,true)
			for k in range(3):
				var t: float = fmod(clock*1.5+k/3.0,1.0)
				var at: float = lerpf(angle,end_angle,t)
				var tip: Vector2 = beam.a+Vector2.from_angle(at)*90
				var tangent := Vector2.from_angle(at).orthogonal()*signf(beam.sweep)
				game.draw_polyline(PackedVector2Array([tip-tangent*9+tangent.orthogonal()*6,tip,tip-tangent*9-tangent.orthogonal()*6]),Color(ink,0.9*sin(t*PI)),2,true)
		for slam in e.slam:
			if slam.fired:
				BossFx.impact(game,slam.p,slam.radius,-slam.time,ink)
				continue
			var progress: float = clampf(1-slam.time/slam.warning,0,1)
			BossFx.target_mark(game,slam.p,slam.radius,progress,ink,clock)
			# Launch: the core flashes and puffs smoke as the hammer leaves it.
			if progress < 0.22:
				var kick: float = 1-progress/0.22
				BossFx.glow(game,slam.source,30+kick*26,Color(ink.lerp(Color.WHITE,0.4),0.8*kick))
				game.draw_arc(slam.source,CORE*0.5+progress*160,0,TAU,32,Color(0.75,0.78,0.85,0.5*kick),2,true)
			# Faint arc for the rest of the flight, then the hammer itself, swelling with height.
			var trail := PackedVector2Array()
			for k in range(13): trail.append(hammer_arc(slam,lerpf(progress,1,k/12.0)))
			for k in range(0,12,2): game.draw_line(trail[k],trail[k+1],Color(ink,0.35),1.5,true)
			var hammer: Vector2 = hammer_arc(slam,progress)
			var lift: float = 4*progress*(1-progress)
			game.draw_circle(slam.p,lerpf(16,34,progress),Color(0,0,0,0.12+0.25*progress))
			for k in range(3):
				var behind: Vector2 = hammer_arc(slam,maxf(0,progress-0.035*(k+1)))
				game.draw_circle(behind,6-k*1.5,Color(ink,0.35-k*0.1))
			var spin := Transform2D(progress*TAU*1.25,Vector2.ONE*(1+0.45*lift),0,hammer)
			var head := spin*PackedVector2Array([Vector2(-26,-12),Vector2(-18,-20),Vector2(18,-20),Vector2(26,-12),Vector2(26,12),Vector2(18,20),Vector2(-18,20),Vector2(-26,12)])
			BossFx.glow(game,hammer,22+lift*12,Color(ink,0.3+progress*0.35))
			game.draw_colored_polygon(head,Color(ink.darkened(0.65),0.9))
			head.append(head[0])
			game.draw_polyline(head,ink,2,true)
			game.draw_line(spin*Vector2(-18,6),spin*Vector2(18,6),Color(ink,0.6),1.2,true)

# Ballistic path from the launching core to the target, high enough to clear cover.
func hammer_arc(slam: Dictionary, t: float) -> Vector2:
	var apex: float = maxf(150,slam.source.distance_to(slam.p)*0.45)
	return slam.source.lerp(slam.p,t)+Vector2(0,-4*apex*t*(1-t))

func draw_depth(view, game, e: Dictionary, parts: Dictionary) -> void:
	var ink := Color("ff9470") if e.hp > e.max_hp*0.5 else Color("ff496a")
	CitadelVisual.draw_depth(self,view,game,e,parts,ink)
