extends "res://scripts/boss_fortress.gd"
## A solid east wall with sliding fan, gatling and seeker emplacements.
const PATTERN_ORDER := ["radial","fan","direct","missile","radial","guided","fan","orb","direct","missile","radial","fan"]
const TURRET_REBUILD := 7.0
const ARM_OFFSETS := [Vector2(-105,-570),Vector2(-125,-350),Vector2(-90,-170),Vector2(-105,170),Vector2(-125,350),Vector2(-90,570),Vector2(-125,-455),Vector2(-125,455)]
const MISSILE_PORT_Y := 245.0

func missile_port(e: Dictionary, target: Vector2) -> Vector2:
	return e.p+Vector2(-28,-MISSILE_PORT_Y if target.y < e.p.y else MISSILE_PORT_Y)

func missile_visual_position(missile: Dictionary) -> Vector2:
	var progress: float = clampf(1.0-missile.time/missile.warning,0.0,1.0)
	if progress < 0.28:
		return missile.source.lerp(Vector2(missile.source.x,missile.sky_y),progress/0.28)
	return Vector2(missile.p.x,lerpf(missile.sky_y,missile.p.y,clampf((progress-0.58)/0.42,0.0,1.0)))

func setup(data, e: Dictionary) -> void:
	var dps: float = Balance.primary_dps(data.power,data.fire_rate,data.physics_ticks)
	var low: float = clampf((data.floor_number-5)/20.0,0.0,1.0)
	var mid: float = clampf((data.floor_number-25)/25.0,0.0,1.0)
	var late: float = maxf(0.0,data.floor_number-50)
	e["low"] = low
	e["mid"] = mid
	e["expert"] = data.floor_number >= 50
	e["age"] = 0.0
	e["step"] = 0
	e["pattern"] = "radial"
	e["max_hp"] = dps*10.5*lerpf(0.65,1.0,low*low)*(1.0+0.004*late)
	e.hp = e.max_hp
	e["plates"] = []
	for i in range(COUNT):
		var hp: float = dps*0.62*lerpf(0.55,1.0,low*low)*(1.0+0.003*late)
		e.plates.append({"hp":hp,"max_hp":hp,"timer":0.0})
	e["turrets"] = []
	for i in range(8 if e.expert else 6):
		var hp: float = dps*0.55
		e.turrets.append({"hp":hp,"max_hp":hp,"timer":0.0,"role":i%3})
	e["salvo_cd"] = 0.45
	e["turret_cursor"] = 0
	e["slam"] = []
	e["bullet_scale"] = lerpf(0.82,1.0,low)*(1.0+0.0008*late)
	e["attack_scale"] = lerpf(1.35,1.0,low)/(1.0+0.0015*late)
	e["home"] = e.p
	e.dir = Vector2.LEFT
	e.cd = 0.55

func touches(e: Dictionary, player: Vector2, radius: float) -> bool:
	# The backdrop is scenery; the shielded core alone is the contact hazard.
	return e.p.distance_to(player) < CORE+radius

func gun_position(e: Dictionary, gun: int) -> Vector2:
	var offset: Vector2 = ARM_OFFSETS[gun]
	var phase: float = e.age*(0.95+gun*0.11)+gun*1.7
	return e.p+offset+Vector2(sin(phase)*18,cos(phase*0.83)*24)

func arm_joints(e: Dictionary, gun: int) -> PackedVector2Array:
	var offset: Vector2 = ARM_OFFSETS[gun]
	var phase: float = e.age*(0.95+gun*0.11)+gun*1.7
	var socket: Vector2 = e.p+Vector2(32,offset.y)
	var elbow: Vector2 = e.p+Vector2(-43+sin(phase*0.7)*17,offset.y+cos(phase*0.83)*37)
	return PackedVector2Array([socket,elbow,gun_position(e,gun)])

func active_guns(e: Dictionary, role: int = -1) -> Array[int]:
	var result: Array[int] = []
	for i in range(e.turrets.size()):
		if e.turrets[i].hp > 0 and (role < 0 or e.turrets[i].role == role): result.append(i)
	return result

func turret_burst(boss, e: Dictionary, gun: int, rage: bool, delay: float = 0.12) -> void:
	match int(e.turrets[gun].role):
		0: salvo(boss,e,gun,delay,5+roundi(2*e.mid)+int(rage)*2,0.145,225,"fan")
		1:
			for round_index in range(3+roundi(2*e.mid)+int(rage)):
				salvo(boss,e,gun,delay+round_index*0.10*e.attack_scale,1,0,290,"direct")
		2:
			salvo(boss,e,gun,delay,2+roundi(2*e.mid)+int(rage),0.16,165,"guided")
			boss.salvos[-1]["guided"] = true

func intercept_bullet(game, bullet: Dictionary) -> bool:
	for e in game.enemies:
		if not e.has("turrets") or e.hp <= 0: continue
		for i in range(e.turrets.size()):
			var turret: Dictionary = e.turrets[i]
			if turret.hp <= 0 or bullet.p.distance_to(gun_position(e,i)) > 23: continue
			turret.hp = maxf(0.0,turret.hp-bullet.damage)
			game.combat_events.enemy_hit.emit(gun_position(e,i),bullet.damage,true,false)
			if turret.hp == 0:
				turret.timer = TURRET_REBUILD
				game.burst(gun_position(e,i),Color("e0a5fa"),10)
			return true
	return super.intercept_bullet(game,bullet)

func salvo(boss, e: Dictionary, gun: int, delay: float, count: int, spacing: float, speed: float, pattern_name: String, aim: Vector2 = Vector2.ZERO) -> void:
	if gun >= 0 and e.turrets[gun].hp <= 0: return
	boss.queue_aimed(e,delay,count,spacing,speed)
	var shot: Dictionary = boss.salvos[-1]
	shot["pattern"] = pattern_name
	if gun >= 0: shot["gun"] = gun
	else: shot["origin"] = e.p
	shot["aim"] = aim

func radial(boss, e: Dictionary, rage: bool) -> void:
	var count := 24+roundi(8*e.low)+roundi(8*e.mid)+int(rage)*8
	var gap_degrees: float = lerpf(52.0,36.0,e.low)-12.0*e.mid
	for wave in range(2 if e.low >= 0.5 else 1):
		var offsets := PackedFloat32Array()
		var rotation: float = e.step*0.27+wave*0.14
		for i in range(count): offsets.append(radial_angle(i,count,gap_degrees)+rotation)
		boss.salvos.append({"owner":e,"delay":0.18+wave*0.3,"offsets":offsets,"speed":165.0+20*wave,"aim":Vector2.RIGHT,"origin":e.p,"pattern":"radial"})

func pattern(boss, game, e: Dictionary, name: String, rage: bool) -> void:
	if name == "radial": radial(boss,e,rage)
	elif name == "fan":
		var guns: Array[int] = active_guns(e,0)
		for wave in range(2+int(rage)):
			for gun in guns: salvo(boss,e,gun,0.18+wave*0.31,5+roundi(2*e.low)+roundi(2*e.mid),0.15,220+wave*15,"fan")
	elif name == "direct":
		for gun in active_guns(e,1):
			for round_index in range(4+roundi(2*e.mid)+int(rage)):
				salvo(boss,e,gun,0.16+round_index*0.12+gun*0.05,1,0,295,"direct")
	elif name == "guided":
		for gun in active_guns(e,2):
			for wave in range(1+int(rage)+roundi(e.mid)):
				salvo(boss,e,gun,0.18+wave*0.34,2+roundi(2*e.mid),0.17,155,"guided")
				boss.salvos[-1]["guided"] = true
	elif name == "orb":
		launch_orb(game,e)
	elif name == "missile":
		launch_missile(game,e,rage)

func launch_orb(game, e: Dictionary) -> void:
	# Hold a growing charge over the core, then launch a large accelerating shot.
	game.bullets.append({"p":e.p,"v":Vector2.ZERO,"damage":1.0,"hostile":true,"life":8.0,
		"energy_orb":true,"orb_phase":"charge","orb_age":0.0,"orb_radius":18.0,
		"orb_flash":0.0,"orb_speed_scale":e.bullet_scale,"pressure":false})
	game.enemy_attack_cue("halo_fire",e.p)

func orb_absorbs_area(game, center: Vector2, radius: float) -> bool:
	for bullet in game.bullets:
		if bullet.get("energy_orb",false) and bullet.life > 0 and bullet.p.distance_to(center) < bullet.orb_radius+radius:
			bullet.orb_flash = 0.15
			return true
	return false

func orb_absorbs_lance(game, rays: Array) -> bool:
	for bullet in game.bullets:
		if not bullet.get("energy_orb",false) or bullet.life <= 0: continue
		for ray in rays:
			var point: Vector2 = Geometry2D.get_closest_point_to_segment(bullet.p,ray.p,ray.end)
			if point.distance_to(bullet.p) <= bullet.orb_radius+ray.width*0.5:
				bullet.orb_flash = 0.15
				return true
	return false

func launch_missile(game, e: Dictionary, rage: bool) -> void:
	var target: Vector2 = game.player
	for side in range(1+int(rage)+roundi(e.mid)):
		var offset: Vector2 = Vector2(0,(side-(int(rage)+roundi(e.mid))*0.5)*145)
		var point: Vector2 = target+offset
		if not game.walkable(point,34): point = target
		var flight_time: float = 1.05*e.attack_scale+side*0.13
		var source: Vector2 = missile_port(e,point)
		var sky_y: float = minf(game.screen_to_world(Vector2(0,-48)).y,minf(point.y,source.y)-240)
		e.slam.append({"p":point,"source":source,"sky_y":sky_y,"radius":56.0+8.0*e.mid,"time":flight_time,"warning":flight_time,"fired":false})

func advance(boss, game, e: Dictionary, delta: float, _toward: Vector2) -> Vector2:
	e.age += delta
	for plate in e.plates:
		if plate.hp > 0: continue
		plate.timer = maxf(0.0,plate.timer-delta)
		if plate.timer == 0: plate.hp = plate.max_hp
	for turret in e.turrets:
		if turret.hp > 0: continue
		turret.timer = maxf(0.0,turret.timer-delta)
		if turret.timer == 0: turret.hp = turret.max_hp
	for missile in e.slam:
		missile.time -= delta
		if missile.time <= 0 and not missile.fired:
			missile.fired = true
			game.enemy_attack_cue("siege_fire",missile.p)
			game.burst(missile.p,Color("e8a8fa"),15)
			# Falling ordnance ignores horizontal cover so a pillar is not permanent safety.
			if game.player.distance_to(missile.p) < missile.radius+game.PLAYER_HIT_RADIUS: game.die()
	e.slam = e.slam.filter(func(m): return m.time > -0.22)
	var rage: bool = e.hp <= e.max_hp*0.5
	e.salvo_cd -= delta
	if e.salvo_cd <= 0:
		var active: Array[int] = active_guns(e)
		if not active.is_empty():
			var gun: int = active[e.turret_cursor%active.size()]
			turret_burst(boss,e,gun,rage)
			e.turret_cursor += 1
		e.salvo_cd = (0.68 if rage else 0.84)*e.attack_scale
	if e.cd <= 0:
		e.pattern = PATTERN_ORDER[e.step%PATTERN_ORDER.size()]
		pattern(boss,game,e,e.pattern,rage)
		e.step += 1
		e.cd = lerpf(0.95,0.76,e.mid)*e.attack_scale
	return Vector2.ZERO

func draw(game) -> void:
	for e in game.enemies:
		if not e.has("turrets") or e.hp <= 0 or not game.attack_open(e.p): continue
		var ink := Color("e0a5fa") if e.hp > e.max_hp*0.5 else Color("ff718c")
		if not game.depth_enabled:
			var wall := Rect2(e.p+Vector2(20,-680),Vector2(230,1360))
			game.draw_rect(wall,Color("293244"))
			game.draw_rect(wall,ink.darkened(0.48),false,4)
			game.draw_line(e.p+Vector2(20,-680),e.p+Vector2(20,680),ink.darkened(0.12),6,true)
			for row in range(13):
				var level: float = -600+row*100
				var socket: Vector2 = e.p+Vector2(44,level)
				game.draw_rect(Rect2(socket-Vector2(22,15),Vector2(44,30)),Color("101827"))
				game.draw_rect(Rect2(socket-Vector2(22,15),Vector2(44,30)),ink.darkened(0.42),false,2)
				game.draw_line(e.p+Vector2(80,level+50),e.p+Vector2(230,level+50),Color("536276"),2,true)
			game.draw_rect(Rect2(e.p+Vector2(-8,-65),Vector2(116,130)),Color("172534"))
			game.draw_rect(Rect2(e.p+Vector2(-8,-65),Vector2(116,130)),ink.darkened(0.15),false,3)
			game.draw_circle(e.p,CORE,ink.darkened(0.45))
			game.draw_circle(e.p,CORE*0.68,ink)
			for side in [-1,1]:
				var port: Vector2 = e.p+Vector2(-28,side*MISSILE_PORT_Y)
				var launching: bool = e.slam.any(func(m): return not m.fired and absf(m.source.y-port.y) < 1.0 and m.time > m.warning-0.18)
				game.draw_rect(Rect2(port+Vector2(0,-22),Vector2(62,44)),Color("263246"))
				game.draw_rect(Rect2(port+Vector2(0,-22),Vector2(62,44)),ink.darkened(0.5),false,2)
				game.draw_circle(port,15,Color("57416b") if launching else Color("0e1929"))
				game.draw_arc(port,15,0,TAU,24,ink if launching else ink.darkened(0.3),2,true)
		for i in range(e.turrets.size()):
			var pos: Vector2 = gun_position(e,i)
			var role: int = e.turrets[i].role
			var joints: PackedVector2Array = arm_joints(e,i)
			var role_ink: Color = [Color("ffaacb"),Color("ffd18a"),Color("9fc7ff")][role]
			if not game.depth_enabled:
				for segment in range(2):
					game.draw_line(joints[segment],joints[segment+1],Color("39475a"),14,true)
					game.draw_line(joints[segment],joints[segment+1],role_ink.darkened(0.5),4,true)
				for joint in range(2):
					game.draw_circle(joints[joint],9,Color("273547"))
					game.draw_arc(joints[joint],9,0,TAU,18,role_ink.darkened(0.2),2,true)
			if e.turrets[i].hp > 0:
				if role == 0:
					game.draw_colored_polygon(PackedVector2Array([pos+Vector2(-24,-19),pos+Vector2(19,-25),pos+Vector2(28,0),pos+Vector2(19,25),pos+Vector2(-24,19)]),Color("293244"))
					game.draw_arc(pos,25,-PI*0.7,PI*0.7,22,role_ink,3,true)
					for spread in [-1,0,1]: game.draw_line(pos,pos+pos.direction_to(game.player).rotated(spread*0.22)*34,role_ink,3,true)
				elif role == 1:
					game.draw_rect(Rect2(pos-Vector2(22,19),Vector2(44,38)),Color("293244"))
					game.draw_rect(Rect2(pos-Vector2(22,19),Vector2(44,38)),role_ink,false,3)
					for side in [-1,0,1]: game.draw_line(pos+Vector2(0,side*7),pos+pos.direction_to(game.player)*37+Vector2(0,side*7),role_ink,3,true)
				else:
					game.draw_circle(pos,23,Color("293244"))
					game.draw_arc(pos,23,0,TAU,24,role_ink,3,true)
					for dot in range(3): game.draw_circle(pos+Vector2.from_angle(dot*TAU/3+e.age)*12,3,role_ink)
			else: game.draw_arc(pos,23,0,TAU,24,Color(role_ink,0.22),2,true)
		for i in range(COUNT):
			var plate: Dictionary = e.plates[i]
			var a: float = (i-0.47)*TAU/COUNT
			var b: float = (i+0.47)*TAU/COUNT
			if plate.hp > 0:
				var panel := PackedVector2Array([e.p+Vector2.from_angle(a)*108,e.p+Vector2.from_angle(b)*108,e.p+Vector2.from_angle(b)*84,e.p+Vector2.from_angle(a)*84])
				game.draw_colored_polygon(panel,Color("483452").lerp(ink.darkened(0.4),1-plate.hp/plate.max_hp))
				panel.append(panel[0])
				game.draw_polyline(panel,Color("d6aafa"),2,true)
			else: game.draw_arc(e.p,RADIUS,a,b,8,Color(0.8,0.6,1.0,0.35),2,true)
		for missile in e.slam:
			if missile.fired:
				var impact: float = clampf(-missile.time/0.22,0.0,1.0)
				game.draw_circle(missile.p,missile.radius,Color(0.85,0.5,1.0,0.55*(1-impact)))
				game.draw_arc(missile.p,lerpf(missile.radius*0.75,missile.radius*1.25,impact),0,TAU,40,Color(1.0,0.9,1.0,1-impact),5,true)
			else:
				var warning_color := Color(0.75,0.55,0.95,0.42)
				game.draw_circle(missile.p,missile.radius,Color(0.65,0.38,0.9,0.08))
				game.draw_arc(missile.p,missile.radius,0,TAU,40,warning_color,1.5,true)
				game.draw_arc(missile.p,missile.radius*clampf(1-missile.time/missile.warning,0,1),0,TAU,40,Color(0.9,0.75,1.0,0.5),1.5,true)
				var progress: float = clampf(1.0-missile.time/missile.warning,0.0,1.0)
				if progress < 0.28 or progress >= 0.58:
					var projectile: Vector2 = missile_visual_position(missile)
					var direction := Vector2.UP if progress < 0.28 else Vector2.DOWN
					game.draw_line(projectile-direction*24,projectile,Color(0.87,0.63,1.0,0.35),4,true)
					game.draw_circle(projectile,11,Color("4f365e"))
					game.draw_circle(projectile,7,Color("c48add"))
					game.draw_circle(projectile+direction*3,3,Color("fff0ff"))

func draw_depth(view, _game, e: Dictionary, parts: Dictionary) -> void:
	var ink := Color("e0a5fa") if e.hp > e.max_hp*0.5 else Color("ff718c")
	for side in [35,225]:
		parts.siege_armor.append(view.chaser_entry(e.p+Vector2(side,0),Vector2.RIGHT,Vector3(12,660,17),Color("596477"),30))
	for row in range(13):
		var level: float = -600+row*100
		var segment: Vector2 = e.p+Vector2(130,level)
		parts.siege_base.append(view.chaser_entry(segment,Vector2.RIGHT,Vector3(110,51,24),Color("344052"),16))
		parts.siege_armor.append(view.chaser_entry(e.p+Vector2(25,level),Vector2.RIGHT,Vector3(16,27,15),ink.darkened(0.45),32))
	parts.siege_armor.append(view.chaser_entry(e.p+Vector2(18,0),Vector2.RIGHT,Vector3(55,65,20),ink.darkened(0.48),29))
	for side in [-1,1]:
		var port: Vector2 = e.p+Vector2(-28,side*MISSILE_PORT_Y)
		parts.siege_base.append(view.chaser_entry(port+Vector2(28,0),Vector2.RIGHT,Vector3(38,26,20),Color("354155"),22))
		parts.siege_armor.append(view.chaser_entry(port,Vector2.LEFT,Vector3(17,19,13),ink.darkened(0.42),30))
	for i in range(e.turrets.size()):
		var pos: Vector2 = gun_position(e,i)
		var joints: PackedVector2Array = arm_joints(e,i)
		var role: int = e.turrets[i].role
		var role_ink: Color = [Color("ffaacb"),Color("ffd18a"),Color("9fc7ff")][role]
		var color: Color = role_ink if e.turrets[i].hp > 0 else role_ink.darkened(0.7)
		for segment in range(2):
			var from_point: Vector2 = joints[segment]
			var to_point: Vector2 = joints[segment+1]
			var axis: Vector2 = from_point.direction_to(to_point)
			parts.siege_barrel.append(view.chaser_entry((from_point+to_point)*0.5,axis,Vector3(from_point.distance_to(to_point)*0.5,7,7),Color("5e6c80"),24))
		parts.siege_armor.append(view.chaser_entry(joints[1],Vector2.RIGHT,Vector3(11,11,10),color.darkened(0.35),31))
		parts.siege_armor.append(view.chaser_entry(pos,Vector2.RIGHT,Vector3(25 if role == 0 else 20,24 if role == 0 else 18,15),color,27))
		if e.turrets[i].hp > 0:
			var direction: Vector2 = pos.direction_to(_game.player)
			for barrel in range(3 if role != 2 else 1):
				parts.siege_barrel.append(view.chaser_entry(pos+direction*27+direction.orthogonal()*(barrel-1)*7,direction,Vector3(24,3,4),color,35))
	parts.siege_core.append(view.chaser_entry(e.p,Vector2.RIGHT,Vector3(45,45,18),ink,34))
