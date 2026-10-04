extends RefCounted
## Abyss Wyrm: the boss of every 25th floor. A huge mechanical serpent that
## first breaches the floor from telegraphed holes, crawls out over the floor
## and dives again, then tears free and prowls the arena. Only the core on its
## head takes damage, inside a ring of breakable plates; the armoured links
## stop shots. Each form holds about one boss's health.
const Balance = preload("res://scripts/combat_balance.gd")
const Visual = preload("res://scripts/wyrm_visuals.gd")
const INK := Color("8fc8ff")
const RAGE_INK := Color("ff6a88")
# The core and its plates share the warm hue of the other bosses' cores.
const CORE_INK := Color("ffcf73")
# Head: the core sits at the head's origin, ringed by shield plates. Like the
# Citadel's, the ring keeps its compass bearing while the head turns, so a hole
# shot in it stays on the player's side until the plate rebuilds.
const CORE := 34.0
const RING := 80.0
const SLOTS := 12
const REBUILD := 7.0
const MUZZLE := 200.0
const HEAD_Z := 40.0
const HEAD_HULL := [Vector2(-100,0),Vector2(-80,-72),Vector2(60,-86),Vector2(170,-60),Vector2(236,-40),Vector2(236,40),Vector2(170,60),Vector2(60,86),Vector2(-80,72)]
# Body: links sit at fixed path distances behind the head. A link within RAMP
# of a hole along the path is climbing out of it or sinking into it.
const SEGMENTS := 11
const HEAD_GAP := 150.0
const SPACING := 84.0
const TAIL_GAP := 96.0
const BODY_RADIUS := [70.0,40.0]
const JOINT_RADIUS := 46.0
const BODY_Z := 16.0
const RAMP := 110.0
const TURRETS := [1,3,5,7,9]
const TAIL_LINKS := 3
const TAIL_REACH := 250.0
const TAIL_MUZZLE := 100.0
# Holes, breaches and timing.
const HOLE_RADIUS := 120.0
const TAIL_HOLE_RADIUS := 86.0
const BREACH_RADIUS := 150.0
const UNDER_TIME := 1.4
const FIRST_UNDER_TIME := 1.8
const EMERGE_TIME := 0.55
const EMERGE_SPEED := 300.0
const DIVE_SPEED := 560.0
const MAX_OUT := 1000.0
const BREACH_WAIT := 1.7
const LASER_WARNING := 1.0
const CHASE_WARNING := 1.1
const CHASE_DURATION := 4.6
const HP_FACTOR := 3.75
# The second form's share of the first form's health; the HUD marks the split.
const SECOND_FORM := 1.15
# Bombardment: a mottled field of shells over the whole arena, in waves.
const SHELL_RADIUS := 100.0
const SHELL_CELL := 180.0
const SHELL_WARNING := 2.0
const SHELL_FOLLOW := 1.3
# The head rears and spits a column of slag at the ceiling before the shells fall.
const WINDUP := 1.2
# After the column the head sinks back before the chasing beam: a beat of rest.
const BEAM_GAP := 1.0
# How far the head rears up off the floor (drawn up the screen) to spit at the ceiling.
const REAR_LIFT := 170.0
# ...and how far it tips its snout up toward the ceiling (radians).
const REAR_PITCH := 1.48
# How high each of the first links rises with a rearing head, as a share of
# the head's lift: together they bend into one continuous raised neck.
const NECK_RISE := [0.86,0.66,0.45,0.26,0.1]
# Shock cage: a closed double ring of shots that shrinks onto the player. Only
# a Shockwave (which clears shots) or a gap behind cover gets through it.
const CAGE_WARNING := 0.9
const CAGE_RADIUS := 440.0
const CAGE_SPEED := 120.0
const CAGE_COUNT := 48
# 64×52 arena; pillars line the outer wall. The head keeps inside INNER of
# home, which holds no cover at all, so it cannot wedge itself on a pillar.
# Only a charge leaves that box, along a lane checked clear of walls and pillars.
const COVER_CELLS := [Vector2i(12,-22),Vector2i(31,-22),Vector2i(50,-22),Vector2i(12,20),Vector2i(31,20),Vector2i(50,20),
	Vector2i(4,-10),Vector2i(4,9),Vector2i(58,-10),Vector2i(58,9)]
const INNER := Vector2(660,470)
const HEAD_CLEAR := 120.0

func setup(data, e: Dictionary) -> void:
	var dps: float = Balance.primary_dps(data.power,data.fire_rate,data.physics_ticks)
	var low: float = clampf((data.floor_number-5)/20.0,0.0,1.0)
	var mid: float = clampf((data.floor_number-25)/25.0,0.0,1.0)
	var late: float = maxf(0.0,data.floor_number-50)
	e["low"] = low
	e["mid"] = mid
	e["expert"] = data.floor_number >= 50
	# Tier 0 at floor 25, 1 at 50, 2 at 75, 3 at 100: each step is clearly
	# tougher, fires more often, with faster shots and extra waves.
	var tier: float = clampf((data.floor_number-25)/25.0,0.0,3.0)
	e["tier"] = tier
	e["attack_scale"] = lerpf(1.35,1.0,low)/(1.0+0.12*tier)
	e["bullet_scale"] = 1.0+0.07*tier
	e["speed_scale"] = lerpf(0.8,1.0,low)*(1.0+0.06*tier)
	var combined_dps: float = dps+Balance.sub_dps(data.power,data.recharge,0,data.physics_ticks)*0.5
	e["phase_hp"] = combined_dps*HP_FACTOR*lerpf(0.6,1.0,low*low)*(1.0+0.3*tier)*(1.0+0.004*late)
	e["max_hp"] = e.phase_hp*(1.0+SECOND_FORM)
	e.hp = e.max_hp
	e["hp_floor"] = e.phase_hp*SECOND_FORM
	e["plates"] = []
	var plate_hp: float = dps*0.5*lerpf(0.55,1.0,low*low)*(1.0+0.003*late)
	for k in range(SLOTS): e.plates.append({"hp":plate_hp,"max_hp":plate_hp,"timer":0.0})
	var home: Vector2 = data.center(Vector2i(32,0))-Vector2(16,16)
	e["home"] = home
	e["phase"] = 1
	e["state"] = "under"
	e["state_time"] = FIRST_UNDER_TIME
	e["rise"] = 0
	e["pattern"] = "beam"
	e["head_hole"] = Vector2.INF
	e["tail_hole"] = Vector2.INF
	e["emerge_heading"] = PI
	e["tail_dir"] = Vector2.RIGHT
	e["tail_lift"] = 0.0
	e["exposed_time"] = 0.0
	e["beam_started"] = false
	e["crawl_side"] = 1.0
	e["trail"] = PackedVector2Array([home])
	e["lead"] = home
	e["hole"] = home
	e["traveled"] = 0.0
	e["dive_at"] = INF
	e["dive_point"] = home
	e["heading"] = PI
	e["face"] = Vector2.LEFT
	e["head_v"] = 0.0
	e["head_z"] = -80.0
	e["submerged"] = true
	e["segments"] = []
	e["tail"] = home
	e["tail_heading"] = Vector2.RIGHT
	e["tail_z"] = -80.0
	e["volleys"] = []
	e["shells"] = []
	e["launch_flash"] = 0.0
	e["windup"] = 0.0
	e["beam_gap"] = 0.0
	e["rear"] = 0.0
	# While the head rears, the core rides up with it out of reach.
	e["guarded"] = false
	e["barrage_queue"] = []
	e["shell_cells"] = []
	e["shell_grid"] = []
	e["shell_origin"] = Vector2.ZERO
	e["shell_previous"] = {}
	e["closing"] = []
	e["cages"] = []
	e["cage_cd"] = 6.0
	e["near_time"] = 0.0
	e["frenzy"] = false
	e["age"] = 0.0
	e["last_player"] = Vector2.INF
	e["player_velocity"] = Vector2.ZERO
	e["still_time"] = 0.0
	e["fan_cd"] = 0.0
	e["fan_cycle"] = 0
	e["missile_cd"] = 0.0
	e["turret_cd"] = 1.0
	e["broadside_cd"] = 1.0
	e["broadside_cycle"] = 0
	e["tail_cd"] = 1.0
	e["tail_cycle"] = 0
	# Second form.
	e["breach"] = home
	e["move_mode"] = "prowl"
	e["move_time"] = 0.0
	e["move_target"] = home
	e["move_side"] = 1.0
	e["charge_cd"] = 5.0
	e["charge_start"] = home
	e["charge_end"] = home
	e["charge_dir"] = Vector2.LEFT
	e["orb_cd"] = 3.0
	e["aimed_cd"] = 1.5
	e["aimed_cycle"] = 0
	e["beam_cd"] = 4.5
	e["barrage_cd"] = 8.0
	e["stuck_time"] = 0.0
	e["stuck_from"] = home
	e.p = home
	e.dir = Vector2.LEFT
	e.cd = 1.0

func rage(e: Dictionary) -> bool:
	return e.hp <= e.phase_hp*(SECOND_FORM+0.5) if e.phase == 1 else e.hp <= e.phase_hp*SECOND_FORM*0.5

# The last stretch of the second form: one more step of pressure.
func frenzied(e: Dictionary) -> bool:
	return e.phase == 2 and e.state == "roam" and e.hp <= e.phase_hp*SECOND_FORM*0.25

func ink(e: Dictionary) -> Color:
	if frenzied(e): return RAGE_INK
	return INK.lerp(RAGE_INK,0.65) if rage(e) else INK

func core_ink(e: Dictionary) -> Color:
	return CORE_INK.lerp(RAGE_INK,0.35) if frenzied(e) else CORE_INK

# Where the head is drawn: lifted up the screen while it rears for the bombardment.
func head_lift(e: Dictionary) -> Vector2:
	return Vector2(0,-REAR_LIFT*e.get("rear",0.0))

# Where a point on the head's centre line (`along` ahead of the core) is drawn
# while the head rears: the snout tips up, so on screen it climbs above the
# head (0.47 world units per unit of height at the 25-degree view).
func head_point(e: Dictionary, along: float, side: float = 0.0) -> Vector2:
	var pitch: float = REAR_PITCH*e.get("rear",0.0)
	return e.p+head_lift(e)+e.face*along*cos(pitch)+e.face.orthogonal()*side+Vector2(0,-0.47*along*sin(pitch))

func rear_mouth(e: Dictionary) -> Vector2:
	return head_point(e,MUZZLE)

# The core seat on the crown, `height` above the head's origin, tipped back with
# a rearing head: [screen anchor, height above the floor, pitch].
func crown(e: Dictionary, height: float) -> Array:
	var pitch: float = REAR_PITCH*e.get("rear",0.0)
	var lift: Vector2 = head_lift(e)
	var anchor: Vector2 = e.p+lift-e.face*height*sin(pitch)+Vector2(0,0.47*height*(1.0-cos(pitch)))
	return [anchor,e.head_z-lift.y*0.5+height*cos(pitch),pitch]

func muzzle(e: Dictionary) -> Vector2:
	return e.p+e.face*MUZZLE

func tail_muzzle(e: Dictionary) -> Vector2:
	return e.tail+e.tail_heading*TAIL_MUZZLE

func body_length() -> float:
	return HEAD_GAP+(SEGMENTS-1)*SPACING+TAIL_GAP+RAMP

func inner(e: Dictionary) -> Rect2:
	return Rect2(e.home-INNER,INNER*2)

func mount_position(e: Dictionary, index: int) -> Vector2:
	for segment in e.segments:
		if segment.index == index: return segment.p
	return e.p

func segment_at(e: Dictionary, index: int) -> Dictionary:
	for segment in e.segments:
		if segment.index == index and segment.kind == "body" and segment.z >= 0: return segment
	return {}

# Every blocked tile touching the disc, as Citadel's chassis check does.
func clear_disc(game, point: Vector2, radius: float) -> bool:
	var low: Vector2i = game.tile(point-Vector2.ONE*radius)
	var high: Vector2i = game.tile(point+Vector2.ONE*radius)
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			var cell := Vector2i(x,y)
			if game.cells.has(cell): continue
			var corner: Vector2 = Vector2(cell)*game.TILE
			if point.distance_to(point.clamp(corner,corner+Vector2.ONE*game.TILE)) < radius: return false
	return true

# ---------------------------------------------------------------- contact and damage

func head_outline(e: Dictionary) -> PackedVector2Array:
	var outline := PackedVector2Array()
	var angle: float = e.face.angle()
	for p in HEAD_HULL: outline.append(e.p+p.rotated(angle))
	return outline

func touches(e: Dictionary, player: Vector2, radius: float) -> bool:
	# Open holes are deadly until they have filled back in.
	for pit in Visual.pits(self,e):
		if player.distance_to(pit[0]) < pit[1]*0.85+radius: return true
	if e.head_v >= 0.5 and e.p.distance_to(player) < 240+radius:
		var outline := head_outline(e)
		if Geometry2D.is_point_in_polygon(player,outline): return true
		for j in range(outline.size()):
			if Geometry2D.get_closest_point_to_segment(player,outline[j],outline[(j+1)%outline.size()]).distance_to(player) < radius: return true
	for segment in e.segments:
		if segment.z < 0: continue
		if segment.p.distance_to(player) < segment.radius+radius: return true
	return e.tail_z >= 0 and (e.tail+e.tail_heading*30).distance_to(player) < 42.0+radius

func plate_slot(_e: Dictionary, direction: Vector2) -> int:
	return posmod(roundi(direction.angle()/TAU*SLOTS),SLOTS)

func plate_position(e: Dictionary, k: int) -> Vector2:
	return e.p+Vector2.from_angle(k*TAU/SLOTS)*RING

func plate_up(e: Dictionary, k: int) -> bool:
	return e.plates[k].hp > 0

func damage_plate(game, e: Dictionary, k: int, damage: float) -> void:
	var plate: Dictionary = e.plates[k]
	plate.hp = maxf(0,plate.hp-damage)
	game.combat_events.enemy_hit.emit(plate_position(e,k),damage,true,false)
	if plate.hp == 0:
		plate.timer = REBUILD
		game.sound.play_sfx("armor_break")
		game.burst(plate_position(e,k),Color("63f5ce"),8)

# Plates first, then the armoured links; the core itself is left to the normal hit test.
func intercept_bullet(game, bullet: Dictionary) -> bool:
	for e in game.enemies:
		if not e.has("segments") or e.hp <= 0: continue
		if not e.submerged and not e.guarded:
			var offset: Vector2 = bullet.p-e.p
			if absf(offset.length()-RING) <= 12:
				var k := plate_slot(e,offset)
				if plate_up(e,k):
					damage_plate(game,e,k,bullet.damage)
					return true
		for segment in e.segments:
			if segment.z < 0: continue
			if bullet.p.distance_squared_to(segment.p) < segment.radius*segment.radius:
				game.combat_events.enemy_hit.emit(bullet.p,0.0,true,false)
				return true
	return false

func block_damage(game, e: Dictionary, damage: float, direction: Vector2) -> bool:
	if e.guarded: return true
	var k := plate_slot(e,-direction)
	if not plate_up(e,k): return false
	damage_plate(game,e,k,damage)
	return true

func shock(game, e: Dictionary, damage: float) -> void:
	if e.submerged or e.guarded: return
	var incoming: Vector2 = game.player.direction_to(e.p)
	var exposed: bool = not plate_up(e,plate_slot(e,-incoming))
	for k in range(SLOTS):
		if not plate_up(e,k): continue
		var point := plate_position(e,k)
		if (point-e.p).dot(game.player-e.p) <= 0: continue
		if game.player.distance_to(point) <= game.SHOCK_RADIUS+12 and game.attack_reaches(game.player,point): damage_plate(game,e,k,damage)
	if exposed and game.player.distance_to(e.p) <= game.SHOCK_RADIUS+CORE and game.attack_reaches(game.player,e.p):
		game.hurt_enemy(e,damage,incoming,0,true)

func lance(game, e: Dictionary, rays: Array, direction: Vector2, damage: float) -> void:
	if e.submerged or e.guarded: return
	var touched := {}
	var core_hit := false
	# Like the Citadel: every lane resolves against the pre-shot plates, so one
	# lance cannot break a plate and reach the core through the new hole.
	for ray in rays:
		var along: float = (e.p-ray.p).dot(direction)
		var start: float = maxf(0,along-RING-16)
		var finish: float = minf(ray.p.distance_to(ray.end),along+RING+16)
		var distance := start
		while distance <= finish:
			var point: Vector2 = game.LanceTrace.lane_point(ray,direction,distance)
			var offset: Vector2 = point-e.p
			if absf(offset.length()-RING) <= 12:
				var k := plate_slot(e,offset)
				if plate_up(e,k):
					touched[k] = true
					break
			if offset.length() <= CORE:
				core_hit = true
				break
			distance += 4
	for k in touched: damage_plate(game,e,k,damage)
	if core_hit: game.hurt_enemy(e,damage,direction,0,true)

func on_destroyed(game, e: Dictionary) -> void:
	for segment in e.segments:
		if segment.z >= 0: game.burst(segment.p,ink(e),8)

# ---------------------------------------------------------------- the path the body follows

func reset_path(e: Dictionary, origin: Vector2, heading: float) -> void:
	e.trail = PackedVector2Array([origin])
	e.lead = origin
	e.hole = origin
	e.traveled = 0.0
	e.dive_at = INF
	e.dive_point = origin
	e.heading = heading
	e.face = Vector2.from_angle(heading)

func advance_lead(e: Dictionary, step: Vector2) -> void:
	if step == Vector2.ZERO: return
	e.lead += step
	e.traveled += step.length()
	var trail: PackedVector2Array = e.trail
	if trail[trail.size()-1].distance_to(e.lead) >= 8.0:
		trail.append(e.lead)
		var keep: int = int((HEAD_GAP+SEGMENTS*SPACING+TAIL_GAP+160)/8.0)
		if trail.size() > keep: trail = trail.slice(trail.size()-keep)
		e.trail = trail

# The head plunges a ramp's length ahead; the body follows it down.
func begin_dive(e: Dictionary) -> void:
	e.dive_at = e.traveled+RAMP
	e.dive_point = e.lead+Vector2.from_angle(e.heading)*RAMP

func out_of_ground(e: Dictionary, position: float) -> float:
	return clampf(minf(position,e.dive_at-position)/RAMP,0.0,1.0)

static func smooth(t: float) -> float:
	return t*t*(3.0-2.0*t)

func place_body(e: Dictionary, with_tail: bool) -> void:
	var trail: PackedVector2Array = e.trail
	var points := PackedVector2Array([e.lead])
	for i in range(trail.size()-1,-1,-1): points.append(trail[i])
	var segments: Array = []
	var walked := 0.0
	var index := 0
	var count: int = SEGMENTS+(1 if with_tail else 0)
	for n in range(count):
		var s: float = HEAD_GAP+n*SPACING+(TAIL_GAP-SPACING if n == SEGMENTS else 0.0)
		var at: float = e.traveled-s
		var v := out_of_ground(e,at)
		var p: Vector2 = e.hole if at < 0 else e.dive_point
		var direction: Vector2 = Vector2.from_angle(e.heading)
		if v > 0:
			while index < points.size()-1:
				var a: Vector2 = points[index]
				var b: Vector2 = points[index+1]
				var length: float = a.distance_to(b)
				if walked+length >= s:
					p = a.lerp(b,(s-walked)/maxf(length,0.001))
					if length > 0.001: direction = b.direction_to(a)
					break
				walked += length
				index += 1
			if index >= points.size()-1: p = points[points.size()-1]
		var radius: float = JOINT_RADIUS if n == SEGMENTS else lerpf(BODY_RADIUS[0],BODY_RADIUS[1],float(n)/(SEGMENTS-1))
		var z: float = lerpf(-80.0,BODY_Z+8.0*sin(s*0.012-e.age*2.6),smooth(v)) if v > 0 else -80.0
		segments.append({"p":p,"dir":direction,"radius":radius,"z":z,"kind":"joint" if n == SEGMENTS else "body","index":n})
	e.segments = segments
	e.head_v = out_of_ground(e,e.traveled)
	e.head_z = lerpf(-80.0,HEAD_Z,smooth(e.head_v))
	e.p = e.lead if e.traveled <= e.dive_at else e.dive_point
	e.submerged = e.head_v < 0.35
	if with_tail:
		var joint: Dictionary = segments[-1]
		e.tail = joint.p-joint.dir*(joint.radius+24)
		e.tail_heading = -joint.dir
		e.tail_z = joint.z

# First form only: the tail rises from its own hole and sways.
func pose_tail(e: Dictionary) -> void:
	var lift: float = smooth(e.tail_lift)
	var sway: float = sin(e.age*1.7)*0.4
	var outward: Vector2 = e.tail_dir.rotated(sway)
	var tip: Vector2 = e.tail_hole+outward*TAIL_REACH*lift
	for i in range(TAIL_LINKS):
		var k: float = float(i)/TAIL_LINKS
		var p: Vector2 = e.tail_hole.lerp(tip,k)+outward.orthogonal()*sin(k*PI)*22*lift
		var z: float = lerpf(-80.0,BODY_Z+6.0*k,lift) if e.tail_lift > 0.12 else -80.0
		e.segments.append({"p":p,"dir":-outward,"radius":lerpf(54.0,42.0,k),"z":z,"kind":"tail_link","index":-1-i})
	e.tail = tip
	e.tail_heading = outward
	e.tail_z = lerpf(-80.0,BODY_Z+10.0,lift) if e.tail_lift > 0.12 else -80.0

func dive_complete(e: Dictionary) -> bool:
	if e.traveled <= e.dive_at: return false
	for segment in e.segments:
		if segment.kind != "tail_link" and segment.z > -60: return false
	return true

func steer(e: Dictionary, desired: float, turn_rate: float, delta: float) -> void:
	# Look ahead; a heading that would leave the open middle turns home instead.
	if not inner(e).has_point(e.lead+Vector2.from_angle(e.heading)*260): desired = e.lead.angle_to_point(e.home)
	e.heading = rotate_toward(e.heading,desired,turn_rate*delta)

func crawl(e: Dictionary, target: Vector2, speed: float, turn_rate: float, delta: float) -> void:
	steer(e,e.lead.angle_to_point(target)+0.4*sin(e.age*1.3),turn_rate,delta)
	if e.phase == 1 and e.traveled >= MAX_OUT: speed = 0.0
	var step: Vector2 = Vector2.from_angle(e.heading)*speed*delta
	if inner(e).has_point(e.lead+step): advance_lead(e,step)
	else: e.heading = rotate_toward(e.heading,e.lead.angle_to_point(e.home),2.0*delta)
	e.face = Vector2.from_angle(e.heading)

# ---------------------------------------------------------------- shots

# Shot speeds scale with the floor tier of the wyrm being updated.
var shot_scale := 1.0

func emit_field(game, origin: Vector2, direction: Vector2, speed: float, tone: int) -> void:
	game.emit_shot(origin,direction,speed*shot_scale,1,true,1500)
	game.bullets[-1].merge({"pattern":"radial","field":true,"pressure":false,"tone":tone})

func emit_needle(game, origin: Vector2, direction: Vector2, speed: float) -> void:
	game.emit_shot(origin,direction,speed*shot_scale,1,true,1500)
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
	var count: int = (9 if e.expert else 7)+(2 if rage(e) else 0)
	for i in range(count):
		emit_needle(game,origin,aim.rotated((i-(count-1)*0.5)*0.13),215.0+20.0*e.mid)
	e.fan_cycle += 1
	game.enemy_attack_cue("siege_fire",origin)

func fire_missiles(game, e: Dictionary) -> void:
	var origin := tail_muzzle(e)
	var aim: Vector2 = origin.direction_to(game.player)
	for side in ([-1.0,0.0,1.0] if not rage(e) else [-1.0,-0.4,0.4,1.0]):
		game.emit_shot(origin,aim.rotated(side*0.6),165.0,1,true,1500)
		game.bullets[-1].merge({"guided":true,"pressure":false,"homing_time":2.4,"turn_rate":1.6,"pattern":"missile"})
	game.enemy_attack_cue("siege_fire",origin)

func fire_tail_burst(game, e: Dictionary, count: int) -> void:
	var base: float = e.tail_cycle*0.37
	for i in range(count): emit_field(game,tail_muzzle(e),Vector2.from_angle(base+i*TAU/count),140.0+10.0*e.mid,1)
	game.enemy_attack_cue("halo_fire",tail_muzzle(e))
	e.tail_cycle += 1

# Gun turrets on every other link: a short aimed burst after a visible charge.
func fire_turrets(e: Dictionary, shots: int) -> void:
	var k := 0
	for segment in e.segments:
		if not segment.index in TURRETS or segment.kind != "body" or segment.z < 0: continue
		for i in range(shots):
			e.volleys.append({"t":0.45+k*0.2+i*0.12,"kind":"turret","index":segment.index,"lead":0.25 if e.expert and i%2 == 1 else 0.0})
		k += 1

# A mechanical ripple from neck to tail, square to each link.
func fire_broadside(e: Dictionary) -> void:
	var spread: Array = [-0.16,0.0,0.16] if e.expert else [-0.1,0.1]
	var k := 0
	for segment in e.segments:
		if segment.kind != "body" or segment.z < 0: continue
		e.volleys.append({"t":k*0.06,"kind":"side","index":segment.index,"speed":165.0+15.0*e.mid,"spread":spread,"cue":k%3 == 0})
		k += 1
	e.broadside_cycle += 1

func start_head_beam(boss, game, e: Dictionary, chase: bool) -> void:
	# Both beams start along the head's own heading, so the neck never snaps.
	var heading: Vector2 = e.face
	if chase: game.enemy_attack_cue("hunter_lock",e.p,false)
	else: game.enemy_attack_cue("triad_charge",e.p,false)
	var warning: float = CHASE_WARNING if chase else LASER_WARNING
	var duration: float = CHASE_DURATION if chase else beam_duration(e)
	var turn: float = ((0.28+0.04*e.tier)*(1.1 if rage(e) else 1.0)) if chase else ((0.31+0.06*e.tier)*(1.2 if rage(e) else 1.0))
	var origin: Vector2 = e.p+heading*MUZZLE
	boss.lasers.append({"owner":e,"a":origin,"b":game.attack_end(origin,heading,1800),"heading":heading,
		"warning":warning,"warning_total":warning,"duration":duration,"peak_duration":duration,"triad":true,"chase":chase,
		"turn_rate":turn,"width":46.0 if chase else 110.0,"muzzle":MUZZLE,"hue":Color("ffb3c4") if chase else Color("bfe2ff"),"charge_radius":34.0,
		# While charging, the beam swings onto the player before it locks and fires.
		"pre_track":0.3 if chase else 0.8})

func end_lasers(boss, e: Dictionary) -> void:
	for beam in boss.lasers:
		if beam.owner == e: beam.duration = 0

func head_beam(boss, e: Dictionary) -> Dictionary:
	for beam in boss.lasers:
		if beam.owner == e and beam.get("triad",false) and beam.duration > 0: return beam
	return {}

# The bombardment: the head rears and spits a column of slag at the ceiling,
# then burning chunks fall over the whole arena, a cell at a time, each one
# marked on the ground first. Every wave leaves the player's row or column
# open (alternating), so there is always a lane to run along, and later waves
# fall mostly where the last wave left open ground.
func plan_barrage(game, e: Dictionary) -> void:
	var room: Rect2i = game.rooms[1]
	var area := Rect2(Vector2(room.position)*game.TILE,Vector2(room.size)*game.TILE)
	var columns: int = int(area.size.x/SHELL_CELL)
	var rows: int = int(area.size.y/SHELL_CELL)
	var origin: Vector2 = area.position+(area.size-Vector2(columns,rows)*SHELL_CELL)*0.5
	e.shell_cells = []
	e.shell_grid = []
	for y in range(rows):
		for x in range(columns):
			var cell: Vector2 = origin+(Vector2(x,y)+Vector2(0.5,0.5))*SHELL_CELL
			if not game.walkable(cell,20): continue
			e.shell_cells.append(cell)
			e.shell_grid.append(Vector2i(x,y))
	e.shell_origin = origin
	e.shell_previous = {}
	var waves: int = mini(4,2+mini(int(e.tier),2)+(1 if rage(e) or frenzied(e) else 0))
	e.barrage_queue = []
	var at: float = WINDUP
	for wave in range(waves):
		e.barrage_queue.append({"t":at,"wave":wave,"warn":SHELL_WARNING if wave == 0 else SHELL_FOLLOW})
		at += SHELL_WARNING if wave == 0 else SHELL_FOLLOW
	e.windup = WINDUP
	game.enemy_attack_cue("boss_orb_charge",e.p,false)

func plan_wave(game, e: Dictionary, wave: int, warn: float) -> void:
	var cells: Array = e.shell_cells
	var grid: Array = e.shell_grid
	var previous: Dictionary = e.shell_previous
	var here := Vector2i(((game.player-e.shell_origin)/SHELL_CELL).floor())
	var hit := {}
	for i in range(cells.size()):
		var chance: float = 0.4 if wave == 0 else (0.1 if previous.has(i) else 0.55)
		if game.rng.randf() >= chance: continue
		# The running lane through the player: their row, then their column.
		if wave%2 == 0 and grid[i].y == here.y: continue
		if wave%2 == 1 and grid[i].x == here.x: continue
		hit[i] = true
	for i in hit:
		var jitter := Vector2(game.rng.randf_range(-24,24),game.rng.randf_range(-24,24))
		e.shells.append({"p":cells[i]+jitter,"r":SHELL_RADIUS,"impact":warn,"warn":warn,"fired":false,"wave":wave,"spin":game.rng.randf_range(-4,4)})
	e.shell_previous = hit
	if wave > 0: game.enemy_attack_cue("boss_mark",game.player,false)

func advance_shells(boss, game, e: Dictionary, delta: float) -> void:
	e.rear = 0.0
	if e.windup > 0:
		e.windup -= delta
		e.rear = smooth(clampf(1.0-e.windup/WINDUP,0,1))
		if e.windup <= 0:
			# The reared head spits the slag column at the ceiling.
			e.launch_flash = 0.8
			e.beam_gap = BEAM_GAP
			e.rear = 1.0
			game.presentation.kick(0.6)
			game.presentation.ripple(e.p,2.0)
			game.enemy_attack_cue("wyrm_plume",e.p,false)
	elif e.beam_gap > 0:
		# Hold the pose a moment, lower the head, then the chasing beam.
		e.beam_gap -= delta
		e.rear = smooth(clampf(e.beam_gap/BEAM_GAP*1.6,0,1))
		if e.beam_gap <= 0: start_head_beam(boss,game,e,true)
	for item in e.barrage_queue:
		item.t -= delta
		if item.t <= 0: plan_wave(game,e,item.wave,item.warn)
	e.barrage_queue = e.barrage_queue.filter(func(item: Dictionary) -> bool: return item.t > 0)
	var landed := Vector2.INF
	for shell in e.shells:
		shell.impact -= delta
		if shell.impact > 0 or shell.fired: continue
		shell.fired = true
		game.burst(shell.p,Color("ff9a5c"),3)
		if landed == Vector2.INF or shell.p.distance_to(game.player) < landed.distance_to(game.player): landed = shell.p
		# Shells arc over cover; only open ground between the marks is safe.
		if game.player.distance_to(shell.p) < shell.r+game.PLAYER_HIT_RADIUS: game.die()
	if landed != Vector2.INF:
		game.enemy_attack_cue("wyrm_slag",landed,false)
		game.presentation.ripple(landed,1.2)
	e.shells = e.shells.filter(func(s: Dictionary) -> bool: return s.impact > -0.3)

# The shock cage: a warned double ring around the player that shrinks onto them.
func start_cage(game, e: Dictionary) -> void:
	e.cages.append({"p":game.player,"t":CAGE_WARNING,"fired":false})
	game.enemy_attack_cue("wyrm_cage",game.player,false)

func advance_cages(game, e: Dictionary, delta: float) -> void:
	for cage in e.cages:
		cage.t -= delta
		if cage.t > 0 or cage.fired: continue
		cage.fired = true
		var count: int = CAGE_COUNT+4*int(e.tier)
		var rings: int = 3 if e.tier >= 2 or frenzied(e) else 2
		for ring in range(rings):
			var radius: float = CAGE_RADIUS+ring*34.0
			for i in range(count):
				var angle: float = (i+0.5*ring)*TAU/count
				var origin: Vector2 = cage.p+Vector2.from_angle(angle)*radius
				game.emit_shot(origin,-Vector2.from_angle(angle),CAGE_SPEED*shot_scale,1,true,radius+260)
				game.bullets[-1].merge({"pattern":"radial","field":true,"pressure":false,"tone":2})
		game.enemy_attack_cue("halo_fire",cage.p)
	e.cages = e.cages.filter(func(c: Dictionary) -> bool: return not c.fired)

func advance_closing(e: Dictionary, delta: float) -> void:
	for pit in e.closing: pit.t -= delta
	e.closing = e.closing.filter(func(pit: Dictionary) -> bool: return pit.t > 0)

# Open holes fill back in over a second and a half instead of vanishing.
func close_pits(game, e: Dictionary, pits: Array) -> void:
	for pit in pits:
		e.closing.append({"p":pit[0],"r":pit[1],"t":1.5,"total":1.5})
		game.burst(pit[0],Color("8197b1"),6)

func advance_volleys(game, e: Dictionary, delta: float) -> void:
	for volley in e.volleys:
		volley.t -= delta
		if volley.t > 0: continue
		match volley.kind:
			"ring":
				if e.submerged: continue
				fire_ring(game,muzzle(e),volley.count,volley.speed,volley.gaps,volley.gap,volley.base,0)
				game.enemy_attack_cue("halo_fire",muzzle(e))
			"side":
				var segment := segment_at(e,volley.index)
				if segment.is_empty(): continue
				var normal: Vector2 = segment.dir.orthogonal()
				for side in [-1.0,1.0]:
					for spread in volley.spread:
						emit_field(game,segment.p+normal*side*segment.radius,(normal*side).rotated(spread),volley.speed,1 if segment.index%2 == 1 else 0)
				if volley.cue: game.enemy_attack_cue("pearl_fire",segment.p,false)
			"turret":
				var segment := segment_at(e,volley.index)
				if segment.is_empty(): continue
				var aim: Vector2 = segment.p.direction_to(game.player+e.player_velocity*volley.lead)
				emit_needle(game,segment.p+aim*44,aim,235.0+20.0*e.mid)
				game.enemy_attack_cue("siege_fire",segment.p)
			"aimed":
				if e.submerged: continue
				var origin := muzzle(e)
				emit_needle(game,origin,origin.direction_to(game.player+e.player_velocity*volley.lead),volley.speed)
				game.enemy_attack_cue("sniper_fire",origin,false)
	e.volleys = e.volleys.filter(func(v: Dictionary) -> bool: return v.t > 0)

# ---------------------------------------------------------------- first form: burrowing

func pick_holes(game, e: Dictionary) -> void:
	e.pattern = ["beam","rings","barrage"][e.rise%3]
	var player: Vector2 = game.player
	var box := inner(e).grow(-120)
	var best := Vector2.INF
	var best_tail := Vector2.INF
	var best_score := -INF
	for attempt in range(60):
		var head: Vector2 = Vector2(game.rng.randf_range(box.position.x,box.end.x),game.rng.randf_range(box.position.y,box.end.y))
		if e.pattern == "barrage": head = e.home+Vector2.from_angle(game.rng.randf_range(0,TAU))*game.rng.randf_range(0,240)
		var tail: Vector2 = head+Vector2.from_angle(game.rng.randf_range(0,TAU))*game.rng.randf_range(520,900)
		if not inner(e).grow(60).has_point(tail) or not clear_disc(game,tail,TAIL_HOLE_RADIUS+60): continue
		var score: float = minf(head.distance_to(player),520.0)+minf(tail.distance_to(player),320.0)*0.6
		if e.head_hole != Vector2.INF: score += minf(head.distance_to(e.head_hole),400.0)*0.4
		if head.distance_to(player) < 380 or tail.distance_to(player) < 260: score -= 1000
		if score > best_score:
			best_score = score
			best = head
			best_tail = tail
	if best == Vector2.INF:
		best = e.home
		best_tail = e.home+Vector2(620,0)
	e.head_hole = best
	e.tail_hole = best_tail
	# Rise at an angle to the player, never straight at them, and stay in the middle.
	var heading: float = best.angle_to_point(player)+(0.7 if game.rng.randf() < 0.5 else -0.7)
	if not inner(e).has_point(best+Vector2.from_angle(heading)*300): heading = best.angle_to_point(e.home)
	e.emerge_heading = heading
	e.tail_dir = best.direction_to(best_tail)
	e.p = best

func begin_emerge(game, e: Dictionary) -> void:
	e.state = "emerge"
	e.state_time = EMERGE_TIME
	reset_path(e,e.head_hole,e.emerge_heading)
	game.enemy_attack_cue("wyrm_breach",e.head_hole)
	game.burst(e.head_hole,INK,16)
	game.burst(e.tail_hole,INK,10)
	# The floor grid buckles outward as the hull breaks through, like a Shockwave.
	game.presentation.ripple(e.head_hole,2.6)
	game.presentation.ripple(e.tail_hole,1.6)
	game.presentation.kick(0.45)
	for hole in [[e.head_hole,HOLE_RADIUS],[e.tail_hole,TAIL_HOLE_RADIUS]]:
		if game.player.distance_to(hole[0]) < hole[1]+game.PLAYER_HIT_RADIUS: game.die()

func beam_duration(e: Dictionary) -> float:
	return 4.0+0.8*e.mid+(0.6 if rage(e) else 0.0)

func begin_exposed(e: Dictionary) -> void:
	e.state = "exposed"
	e.exposed_time = 0.0
	e.beam_started = false
	e.crawl_side = -e.crawl_side
	match e.pattern:
		"beam":
			e.fan_cd = 0.5
			e.turret_cd = 0.8
			e.state_time = 1.2+LASER_WARNING+beam_duration(e)+0.6
		"rings":
			# Ring after ring with three escape lanes that drift sideways, so the
			# player keeps running with the gap.
			var waves: int = (8 if rage(e) else 7)+int(e.tier)
			var drift: float = (0.21+0.04*e.mid)*(1.0 if (e.rise/3)%2 == 0 else -1.0)
			var base: float = e.face.angle()+PI/3
			var gap: float = deg_to_rad(lerpf(52.0,44.0,e.low)-8.0*e.mid)
			for wave in range(waves):
				e.volleys.append({"t":0.5+wave*0.6*e.attack_scale,"kind":"ring","count":64+roundi(8*e.mid),"speed":155.0+15.0*e.mid,"gaps":3,"gap":gap,"base":base+wave*drift})
			e.missile_cd = 0.6
			e.broadside_cd = 0.9
			e.state_time = 0.5+waves*0.6*e.attack_scale+0.8
		"barrage":
			e.tail_cd = 0.8
			e.turret_cd = 1.5
			e.state_time = 1.4+WINDUP+BEAM_GAP+CHASE_WARNING+CHASE_DURATION+0.5

func advance_burrow(boss, game, e: Dictionary, delta: float) -> void:
	if e.head_hole == Vector2.INF: pick_holes(game,e)
	e.state_time -= delta
	var angry := rage(e)
	match e.state:
		"under":
			e.tail_lift = 0.0
			e.segments = []
			e.head_v = 0.0
			e.head_z = -80.0
			e.tail_z = -80.0
			e.submerged = true
			e.p = e.head_hole
			if e.state_time <= 0: begin_emerge(game,e)
			return
		"emerge":
			e.tail_lift = clampf(1.0-e.state_time/EMERGE_TIME,0,1)
			advance_lead(e,Vector2.from_angle(e.heading)*EMERGE_SPEED*e.speed_scale*delta)
			if e.state_time <= 0: begin_exposed(e)
		"exposed":
			e.tail_lift = 1.0
			e.exposed_time += delta
			var beam := head_beam(boss,e)
			match e.pattern:
				"beam":
					if not e.beam_started and e.exposed_time >= 1.2:
						start_head_beam(boss,game,e,false)
						e.beam_started = true
					elif beam.is_empty():
						var away: Vector2 = game.player+game.player.direction_to(e.lead)*520
						crawl(e,away,150.0*e.speed_scale,1.0,delta)
					else:
						# Creep along the beam while it fires; the body keeps sliding out.
						var step: Vector2 = Vector2.from_angle(e.heading)*40.0*delta
						if e.traveled < MAX_OUT and inner(e).has_point(e.lead+step): advance_lead(e,step)
					e.fan_cd -= delta
					if e.fan_cd <= 0:
						fire_fan(game,e)
						e.fan_cd = (0.7 if angry else 0.85)*e.attack_scale
					e.turret_cd -= delta
					if e.turret_cd <= 0:
						fire_turrets(e,3 if angry else 2)
						e.turret_cd = 2.0*e.attack_scale
				"rings":
					var around: Vector2 = game.player+game.player.direction_to(e.lead).rotated(e.crawl_side*0.8)*400
					crawl(e,around,170.0*e.speed_scale,1.1,delta)
					e.missile_cd -= delta
					if e.missile_cd <= 0:
						fire_missiles(game,e)
						e.missile_cd = (1.15 if angry else 1.4)*e.attack_scale
					e.broadside_cd -= delta
					if e.broadside_cd <= 0:
						fire_broadside(e)
						e.broadside_cd = (1.5 if angry else 1.9)*e.attack_scale
				"barrage":
					if e.exposed_time < 1.4: crawl(e,e.home,160.0*e.speed_scale,1.2,delta)
					elif not e.beam_started:
						plan_barrage(game,e)
						e.beam_started = true
					e.tail_cd -= delta
					if e.tail_cd <= 0:
						fire_tail_burst(game,e,(26 if angry else 22)+roundi(4*e.mid))
						e.tail_cd = 1.6*e.attack_scale
					e.turret_cd -= delta
					if e.turret_cd <= 0:
						fire_turrets(e,2)
						e.turret_cd = 3.0*e.attack_scale
			beam = head_beam(boss,e)
			if not beam.is_empty():
				# The head holds still and turns with its beam, never faster than a neck can.
				e.face = Vector2.from_angle(rotate_toward(e.face.angle(),beam.heading.angle(),2.4*delta))
				e.heading = e.face.angle()
			if e.state_time <= 0:
				e.state = "dive"
				end_lasers(boss,e)
				begin_dive(e)
				game.presentation.ripple(e.dive_point,1.8)
		"dive":
			e.tail_lift = maxf(0.0,e.tail_lift-delta/0.6)
			advance_lead(e,Vector2.from_angle(e.heading)*DIVE_SPEED*delta)
	place_body(e,false)
	pose_tail(e)
	if e.state == "dive" and dive_complete(e) and e.tail_lift <= 0:
		close_pits(game,e,[[e.hole,HOLE_RADIUS],[e.dive_point,HOLE_RADIUS*0.9],[e.tail_hole,TAIL_HOLE_RADIUS]])
		e.state = "under"
		e.state_time = UNDER_TIME*e.attack_scale
		e.rise += 1
		pick_holes(game,e)
		game.enemy_attack_cue("wyrm_rumble",e.head_hole,false)
		game.presentation.ripple(e.head_hole,0.7)

# ---------------------------------------------------------------- transition

func begin_breach(boss, game, e: Dictionary) -> void:
	e.phase = 2
	e.hp_floor = e.hp
	e.volleys.clear()
	e.shells.clear()
	e.barrage_queue.clear()
	e.cages.clear()
	e.windup = 0.0
	e.beam_gap = 0.0
	e.rear = 0.0
	end_lasers(boss,e)
	# The beast drops every shot in flight as it tears loose; a clean start.
	for b in game.bullets:
		if b.hostile:
			game.burst(b.p,INK,1)
			b.life = 0
	e.breach = e.home
	if e.state in ["emerge","exposed"]:
		begin_dive(e)
		e.state = "breach_dive"
	elif e.state == "dive": e.state = "breach_dive"
	else:
		e.state = "breach_wait"
		e.state_time = BREACH_WAIT
		game.enemy_attack_cue("wyrm_rumble",e.breach,false)
	game.enemy_attack_cue("boss_release",e.p)

func advance_breach(boss, game, e: Dictionary, delta: float) -> void:
	if e.state == "breach_dive":
		e.tail_lift = maxf(0.0,e.tail_lift-delta/0.6)
		advance_lead(e,Vector2.from_angle(e.heading)*DIVE_SPEED*delta)
		place_body(e,false)
		pose_tail(e)
		if dive_complete(e) and e.tail_lift <= 0:
			close_pits(game,e,[[e.hole,HOLE_RADIUS],[e.dive_point,HOLE_RADIUS*0.9],[e.tail_hole,TAIL_HOLE_RADIUS]])
			e.state = "breach_wait"
			e.state_time = BREACH_WAIT
			game.enemy_attack_cue("wyrm_rumble",e.breach,false)
		return
	e.state_time -= delta
	e.p = e.breach
	e.submerged = true
	e.segments = []
	e.head_v = 0.0
	e.head_z = -80.0
	e.tail_z = -80.0
	if e.state_time > 0: return
	# Burst out at the centre, heading away from the player.
	if game.player.distance_to(e.breach) < BREACH_RADIUS+game.PLAYER_HIT_RADIUS: game.die()
	game.burst(e.breach,INK,24)
	game.enemy_attack_cue("wyrm_breach",e.breach)
	game.presentation.ripple(e.breach,3.0)
	game.presentation.kick(0.7)
	e.state = "roam"
	e.hp_floor = 0.0
	reset_path(e,e.breach,game.player.angle_to_point(e.breach))
	enter_mode(boss,game,e,"prowl")
	e.barrage_cd = 8.0
	place_body(e,true)

# ---------------------------------------------------------------- second form: prowling

func enter_mode(boss, game, e: Dictionary, mode: String) -> void:
	e.move_mode = mode
	match mode:
		"prowl":
			var box := inner(e).grow(-60)
			var target: Vector2 = e.home
			for attempt in range(16):
				target = Vector2(game.rng.randf_range(box.position.x,box.end.x),game.rng.randf_range(box.position.y,box.end.y))
				if target.distance_to(e.lead) > 420 and target.distance_to(game.player) > 300: break
			e.move_target = target
			e.move_time = game.rng.randf_range(2.6,3.6)
		"stalk":
			e.move_side = -e.move_side
			e.move_time = game.rng.randf_range(2.4,3.2)
		"evade":
			e.move_target = (e.lead+game.player.direction_to(e.lead)*460).clamp(inner(e).position,inner(e).end)
			e.move_time = 1.6
		"charge_warning":
			var aim: Vector2 = game.player+e.player_velocity*0.3*e.mid
			e.charge_dir = e.lead.direction_to(aim)
			if e.charge_dir.is_zero_approx(): e.charge_dir = Vector2.from_angle(e.heading)
			e.charge_start = e.lead
			e.charge_end = e.lead
			for distance in range(16,roundi(900+160*e.mid)+1,16):
				var next: Vector2 = e.lead+e.charge_dir*distance
				# The snout reaches ahead of the core; keep all of it off cover.
				if not clear_disc(game,next+e.charge_dir*100,HEAD_CLEAR) or not clear_disc(game,next,HEAD_CLEAR): break
				e.charge_end = next
			if e.lead.distance_to(e.charge_end) < 260:
				enter_mode(boss,game,e,"prowl")
				return
			e.move_time = maxf(1.1*e.attack_scale,absf(angle_difference(e.heading,e.charge_dir.angle()))/2.2+0.4)*(0.88 if rage(e) else 1.0)
			game.enemy_attack_cue("boss_mark",e.p,false)
			end_lasers(boss,e)
		"charge":
			e.move_time = e.lead.distance_to(e.charge_end)/charge_speed(e)+0.1
			game.enemy_attack_cue("boss_release",e.p)
		"recoil":
			e.move_time = 0.7
			e.charge_cd = (5.0 if rage(e) else 6.5)*e.attack_scale
		"barrage":
			end_lasers(boss,e)
			plan_barrage(game,e)
			e.move_time = WINDUP+BEAM_GAP+CHASE_WARNING+CHASE_DURATION+0.4
			e.barrage_cd = (10.0 if frenzied(e) else (14.0 if rage(e) else 17.0))*e.attack_scale

func charge_speed(e: Dictionary) -> float:
	return (520.0+60.0*e.mid)*e.speed_scale

func next_mode(boss, game, e: Dictionary) -> void:
	match e.move_mode:
		"charge_warning": enter_mode(boss,game,e,"charge")
		"charge": enter_mode(boss,game,e,"recoil")
		"recoil":
			if inner(e).has_point(e.lead): enter_mode(boss,game,e,"prowl")
			else: e.move_time = 0.3
		_:
			if e.charge_cd <= 0 and e.lead.distance_to(game.player) > 340: enter_mode(boss,game,e,"charge_warning")
			elif e.still_time > 1.6 or (e.move_mode == "prowl" and game.rng.randf() < 0.55): enter_mode(boss,game,e,"stalk")
			else: enter_mode(boss,game,e,"prowl")

func advance_roam(boss, game, e: Dictionary, delta: float) -> void:
	var angry := rage(e)
	e.move_time -= delta
	e.charge_cd -= delta
	e.barrage_cd -= delta
	if e.move_mode in ["prowl","stalk","evade"]:
		if e.barrage_cd <= 0: enter_mode(boss,game,e,"barrage")
		elif e.move_mode != "evade" and e.lead.distance_to(game.player) < 300: enter_mode(boss,game,e,"evade")
	if e.move_time <= 0: next_mode(boss,game,e)
	var beams_busy := false
	for beam in boss.lasers:
		if beam.owner == e and beam.has("mount") and beam.duration > 0: beams_busy = true
	var speed: float = ((175.0 if angry else 150.0)+20.0*e.mid)*e.speed_scale*(1.2 if frenzied(e) else 1.0)
	if beams_busy: speed = minf(speed,70.0)
	match e.move_mode:
		"prowl", "evade":
			crawl(e,e.move_target,speed,0.95,delta)
			if e.lead.distance_to(e.move_target) < 90: e.move_time = minf(e.move_time,0.2)
		"stalk":
			var to_player: Vector2 = e.lead.direction_to(game.player)
			var target: Vector2 = (game.player+to_player.orthogonal()*e.move_side*420-to_player*80).clamp(inner(e).position,inner(e).end)
			crawl(e,target,speed,1.0,delta)
		"charge_warning":
			e.heading = rotate_toward(e.heading,e.charge_dir.angle(),2.2*delta)
			e.face = Vector2.from_angle(e.heading)
		"charge":
			advance_lead(e,e.charge_dir*minf(charge_speed(e)*delta,e.lead.distance_to(e.charge_end)))
			e.heading = e.charge_dir.angle()
			e.face = e.charge_dir
			if e.lead.distance_to(e.charge_end) < 2: enter_mode(boss,game,e,"recoil")
		"recoil":
			# Turn in place toward the middle, then crawl back along open ground.
			var home_angle: float = e.lead.angle_to_point(e.home)
			e.heading = rotate_toward(e.heading,home_angle,1.6*delta)
			if absf(angle_difference(e.heading,home_angle)) < 0.4:
				var step: Vector2 = Vector2.from_angle(e.heading)*90.0*delta
				if inner(e).has_point(e.lead+step) or clear_disc(game,e.lead+step+Vector2.from_angle(e.heading)*100,HEAD_CLEAR): advance_lead(e,step)
			e.face = Vector2.from_angle(e.heading)
		"barrage":
			var beam := head_beam(boss,e)
			if not beam.is_empty():
				e.face = Vector2.from_angle(rotate_toward(e.face.angle(),beam.heading.angle(),2.4*delta))
				e.heading = e.face.angle()
	# A last guard: a head that has not moved for a while goes back to the middle.
	e.stuck_time += delta
	if e.stuck_time >= 1.5:
		if e.move_mode in ["prowl","stalk","evade"] and e.lead.distance_to(e.stuck_from) < 30: enter_mode(boss,game,e,"recoil")
		e.stuck_time = 0.0
		e.stuck_from = e.lead
	place_body(e,true)
	if not e.get("breach_closed",false) and e.traveled > body_length()+60:
		e["breach_closed"] = true
		close_pits(game,e,[[e.hole,BREACH_RADIUS*0.8]])
	advance_roam_attacks(boss,game,e,delta,angry)

func advance_roam_attacks(boss, game, e: Dictionary, delta: float, angry: bool) -> void:
	var frenzy := frenzied(e)
	if frenzy and not e.frenzy:
		# Into the last stretch: a roar, and everything comes faster.
		e.frenzy = true
		game.enemy_attack_cue("wyrm_breach",e.p)
		game.presentation.ripple(e.p,2.4)
		game.presentation.kick(0.5)
		e.cage_cd = minf(e.cage_cd,1.5)
		e.barrage_cd = minf(e.barrage_cd,6.0)
	var scale: float = e.attack_scale*(0.8 if angry else 1.0)*(0.75 if frenzy else 1.0)
	var busy: bool = e.move_mode == "barrage"
	e.cage_cd -= delta
	if e.cage_cd <= 0 and not busy and not e.move_mode in ["charge_warning","charge"]:
		start_cage(game,e)
		e.cage_cd = (7.0 if frenzy else 11.0)*e.attack_scale
	if not busy:
		# Head: a burst of aimed needles, and now and then a large energy orb.
		e.aimed_cd -= delta
		if e.aimed_cd <= 0:
			var lead: float = 0.22 if e.expert and e.aimed_cycle%2 == 1 else 0.0
			for i in range(6 if angry else 5):
				e.volleys.append({"t":i*0.09,"kind":"aimed","speed":265.0+25.0*e.mid,"lead":lead})
			e.aimed_cycle += 1
			e.aimed_cd = 1.5*scale
		e.orb_cd -= delta
		if e.orb_cd <= 0 and not e.move_mode in ["charge_warning","charge"]:
			var origin := muzzle(e)
			game.bullets.append({"p":origin,"v":Vector2.ZERO,"damage":1.0,"hostile":true,"life":8.0,
				"energy_orb":true,"orb_phase":"charge","orb_age":0.0,"orb_radius":18.0,
				"orb_flash":0.0,"orb_speed_scale":0.95+0.1*e.mid,"pressure":false})
			game.enemy_attack_cue("boss_orb_charge",origin,false)
			e.orb_cd = 6.5*scale
		# Body: telegraphed thin beams square to the hull, never swung around.
		e.beam_cd -= delta
		if e.beam_cd <= 0 and not e.move_mode in ["charge_warning","charge"]:
			for index in ([1,4,7,10] if angry else [2,5,8]):
				var segment := segment_at(e,index)
				if segment.is_empty(): continue
				var normal: Vector2 = segment.dir.orthogonal()
				if normal.dot(game.player-segment.p) < 0: normal = -normal
				var heading: Vector2 = normal.rotated(clampf(normal.angle_to(segment.p.direction_to(game.player)),-0.3,0.3))
				boss.add_laser(segment.p,game.attack_end(segment.p,heading,1800),0.95*e.attack_scale,0.55,e)
				boss.lasers[-1].merge({"mount":index,"heading":heading,"warning_total":0.95*e.attack_scale,"width":10.0})
			game.enemy_attack_cue("hunter_lock",e.p,false)
			e.beam_cd = 5.5*scale
		# Body: a broadside ripple from neck to tail.
		e.broadside_cd -= delta
		if e.broadside_cd <= 0:
			fire_broadside(e)
			e.broadside_cd = 2.8*scale
	e.turret_cd -= delta
	if e.turret_cd <= 0:
		fire_turrets(e,3 if angry else 2)
		e.turret_cd = (3.4 if busy else 2.4)*scale
	# Tail: an even radial burst that turns a little each time.
	e.tail_cd -= delta
	if e.tail_cd <= 0 and e.tail_z >= 0:
		fire_tail_burst(game,e,(32 if angry else 26)+roundi(4*e.mid))
		e.tail_cd = 3.2*scale

# ---------------------------------------------------------------- update

func advance(boss, game, e: Dictionary, delta: float, _toward: Vector2) -> Vector2:
	e.age += delta
	e.cd = 1.0
	shot_scale = e.bullet_scale
	e.launch_flash = maxf(0.0,e.launch_flash-delta)
	advance_closing(e,delta)
	# Crowding the head in the first form calls the shock cage down on the player.
	if e.phase == 1:
		e.cage_cd -= delta
		var close: bool = not e.submerged and game.player.distance_to(e.p) < 340
		e.near_time = e.near_time+delta if close else maxf(0.0,e.near_time-delta*0.5)
		# It also comes on its own while the head is out, so there is no
		# stretch of the fight spent only shooting.
		if (e.near_time > 1.2 or e.state == "exposed") and not e.submerged and e.cage_cd <= 0:
			start_cage(game,e)
			e.cage_cd = (8.0 if e.near_time > 1.2 else 11.0)*e.attack_scale
			e.near_time = 0.0
	if e.last_player != Vector2.INF and delta > 0:
		var velocity: Vector2 = ((game.player-e.last_player)/delta).limit_length(game.SPEED+game.move_bonus)
		e.player_velocity = e.player_velocity.lerp(velocity,1.0-exp(-8*delta))
	e.last_player = game.player
	e.still_time = e.still_time+delta if e.player_velocity.length() < 40 else 0.0
	for plate in e.plates:
		if plate.hp > 0: continue
		plate.timer = maxf(0.0,plate.timer-delta)
		if plate.timer == 0: plate.hp = plate.max_hp
	if e.phase == 1 and e.hp <= e.hp_floor+0.001: begin_breach(boss,game,e)
	if e.phase == 1: advance_burrow(boss,game,e,delta)
	elif e.state in ["breach_dive","breach_wait"]: advance_breach(boss,game,e,delta)
	else: advance_roam(boss,game,e,delta)
	advance_volleys(game,e,delta)
	advance_shells(boss,game,e,delta)
	advance_cages(game,e,delta)
	e.guarded = e.rear > 0.0
	e.dir = e.face
	return Vector2.ZERO

# Development only: jump to the second form (F9 in debug builds, --form=2 in the study tools).
func skip_form(game) -> void:
	for e in game.enemies:
		if e.has("segments") and e.phase == 1: e.hp = minf(e.hp,e.hp_floor)

func draw(game) -> void:
	Visual.draw(self,game)

func draw_depth(view, game, e: Dictionary, parts: Dictionary) -> void:
	Visual.draw_depth(self,view,game,e,parts)
