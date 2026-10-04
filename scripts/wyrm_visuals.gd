extends RefCounted
## Abyss Wyrm: an armoured machine serpent. A wedge skull with swept horns, a
## crest and two jaw prongs reaching past the snout, a crystal weak point set
## in its crown, and a chain of octagonal drums with dorsal fins and raked side
## vanes, ending in a blade tail.
## Local +X is forward; heights are in pixels so the wire shader finds creases.
const BossFx = preload("res://scripts/boss_fx.gd")
const Citadel = preload("res://scripts/citadel_visuals.gd")
const STEEL := Color("8197b1")
const HEAD_TINT := Color("6d86a6")
const BODY_TINT := Color("566b88")
const VANE_TINT := Color("3b4c63")
const CRATER := Color("04070c")
const RUBBLE := Color("3a4658")
const SEGMENT_SCALE := 28.0

static func mirrored(points: Array, side: float) -> Array:
	var result := []
	for p in points: result.append(Vector2(p.x,p.y*side))
	return result

static func head_mesh() -> ArrayMesh:
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The skull falls toward a blunt snout; the jaw prongs reach past it with
	# an open throat between them.
	Citadel.slab(s,[Vector2(-54,0),Vector2(-42,-33),Vector2(10,-36),Vector2(50,-24),Vector2(66,-12),Vector2(66,12),Vector2(50,24),Vector2(10,36),Vector2(-42,33)],8,28,5,1.0,Vector2(0.12,0))
	Citadel.slab(s,Citadel.rect(-48,22,-5,5),26,40,2.5,1.0,Vector2(0.12,0))          # crest
	for side in [-1.0,1.0]:
		Citadel.slab(s,mirrored([Vector2(-20,8),Vector2(70,7),Vector2(98,10),Vector2(96,18),Vector2(60,28),Vector2(-20,30)],side),0,12,2.5)   # jaw prong
		Citadel.slab(s,mirrored([Vector2(4,18),Vector2(48,15),Vector2(52,25),Vector2(6,31)],side),22,33,2,1.0,Vector2(0.12,0))                # brow
		Citadel.slab(s,mirrored([Vector2(-8,25),Vector2(8,30),Vector2(-60,62),Vector2(-76,57)],side),16,28,2,1.0,Vector2(0.14,0))              # swept horn
		Citadel.slab(s,Citadel.rect(-34,-8,33,39) if side > 0 else Citadel.rect(-34,-8,-39,-33),10,18,1.5)                                    # cheek vent
	return s.commit()

# Flat, unlit pit floor; opaque, so links below the floor vanish into it.
static func pit_mesh() -> ArrayMesh:
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(18):
		var a := Vector2.from_angle(i*TAU/18)*(0.9+0.1*absf(sin(i*2.7)))
		var b := Vector2.from_angle((i+1)*TAU/18)*(0.9+0.1*absf(sin((i+1)*2.7)))
		for p in [Vector3.ZERO,Vector3(b.x,b.y,0),Vector3(a.x,a.y,0)]:
			s.set_normal(Vector3.BACK)
			s.set_color(Color.WHITE)
			s.add_vertex(p)
	return s.commit()

static func segment_mesh() -> ArrayMesh:
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	Citadel.slab(s,Citadel.octagon(24),0,16,4)                                   # armoured drum
	Citadel.slab(s,Citadel.rect(9,15,-27,27),2,18,2)                             # forward collar
	Citadel.slab(s,[Vector2(-14,-3),Vector2(10,-3),Vector2(16,0),Vector2(10,3),Vector2(-14,3)],16,30,2,1.0,Vector2(0.25,0))   # dorsal fin
	for side in [-1.0,1.0]:
		Citadel.slab(s,mirrored([Vector2(-2,21),Vector2(10,21),Vector2(-4,40),Vector2(-16,40)],side),3,11,1.5)   # raked vane
	return s.commit()

static func tail_mesh() -> ArrayMesh:
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	Citadel.slab(s,[Vector2(-24,-14),Vector2(16,-10),Vector2(58,0),Vector2(16,10),Vector2(-24,14)],0,14,3,1.0,Vector2(0.08,0))
	for side in [-1.0,1.0]:
		Citadel.slab(s,mirrored([Vector2(-20,10),Vector2(0,12),Vector2(-30,34),Vector2(-38,30)],side),2,10,1.5)
	Citadel.slab(s,Citadel.shifted(Citadel.octagon(9),Vector2(4,0)),13,20,2)     # emitter pod
	return s.commit()

# Crater rim: a jagged ring that never changes between frames.
static func crater(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(18):
		var jag: float = 0.86+0.14*absf(sin(i*2.7+center.x*0.013+center.y*0.007))
		points.append(center+Vector2.from_angle(i*TAU/18)*radius*jag)
	return points

static func draw_crater(game, center: Vector2, radius: float, ink: Color, fade: float = 1.0) -> void:
	var rim := crater(center,radius)
	if not game.depth_enabled: game.draw_colored_polygon(rim,Color(CRATER,0.82*fade))
	rim.append(rim[0])
	game.draw_polyline(rim,Color(ink,0.45*fade),1.6,true)
	game.draw_arc(center,radius*0.62,0,TAU,32,Color(ink,0.12*fade),5,true)
	for i in range(7):
		var axis := Vector2.from_angle(i*TAU/7+center.x*0.01)
		game.draw_line(center+axis*radius*0.95,center+axis*radius*(1.25+0.15*sin(i*1.7)),Color(STEEL,0.4*fade),1.2,true)

# Ground warning before a breach: a cracking target and the direction the head will rise.
static func draw_omen(game, center: Vector2, radius: float, progress: float, ink: Color, clock: float, direction: Vector2 = Vector2.ZERO, reach: float = 0.0) -> void:
	BossFx.target_mark(game,center,radius,progress,ink,clock)
	for i in range(9):
		var axis := Vector2.from_angle(i*TAU/9+center.y*0.01)
		var length: float = radius*(0.4+0.9*progress)*(0.7+0.3*sin(i*2.3))
		game.draw_line(center+axis*radius*0.2,center+axis*length,Color(ink,0.25+0.5*progress),1.4,true)
	if reach > 0 and not direction.is_zero_approx():
		var tip: Vector2 = center+direction*(radius+reach*0.6)
		BossFx.dashed(game,center+direction*radius,tip,Color(ink,0.6*progress+0.2),clock)
		var side := direction.orthogonal()*9
		game.draw_polyline(PackedVector2Array([tip-direction*12+side,tip,tip-direction*12-side]),Color(ink,0.5+0.5*progress),2,true)

static func draw(boss, game) -> void:
	var clock: float = game.presentation.clock
	for e in game.enemies:
		if not e.has("segments") or e.hp <= 0: continue
		var ink: Color = boss.ink(e)
		var angry: bool = boss.rage(e)
		if e.phase == 1 or e.state == "breach_dive":
			if e.head_hole != Vector2.INF:
				if e.state == "under":
					var total: float = boss.UNDER_TIME*e.attack_scale if e.rise > 0 else boss.FIRST_UNDER_TIME
					var progress: float = clampf(1.0-e.state_time/total,0,1)
					draw_omen(game,e.head_hole,boss.HOLE_RADIUS,progress,ink,clock,e.emerge_dir,boss.NECK_REACH)
					draw_omen(game,e.tail_hole,boss.TAIL_HOLE_RADIUS,progress,ink,clock)
				else:
					draw_crater(game,e.head_hole,boss.HOLE_RADIUS,ink)
					draw_crater(game,e.tail_hole,boss.TAIL_HOLE_RADIUS,ink)
		elif e.state == "breach_wait":
			draw_omen(game,e.breach,boss.BREACH_RADIUS,clampf(1.0-e.state_time/boss.BREACH_WAIT,0,1),ink,clock)
		else:
			var fade: float = clampf(1.0-(e.traveled-boss.SEGMENTS*boss.SPACING)/400.0,0,1)
			if fade > 0: draw_crater(game,e.breach,boss.BREACH_RADIUS*0.8,ink,fade)
			if e.move_mode in ["charge_warning","charge"]: draw_charge_lane(boss,game,e)
		if not game.depth_enabled:
			for segment in e.segments:
				if segment.z < 0: continue
				game.draw_circle(segment.p,segment.radius,Color("3b4c63"))
				game.draw_arc(segment.p,segment.radius,0,TAU,24,Color(STEEL,0.8),1.5,true)
			if not e.submerged:
				game.draw_circle(e.p,boss.HEAD_RADIUS,Color("4d6380"))
				game.draw_line(e.p,e.p+e.face*boss.MUZZLE,Color(STEEL),8,true)
		# Spine lamps: a pulse runs from the head down the body.
		for i in range(e.segments.size()):
			var segment: Dictionary = e.segments[i]
			if segment.z < 0: continue
			var pulse: float = 0.5+0.5*sin(clock*(7.0 if angry else 4.0)-i*0.7)
			BossFx.glow(game,segment.p,8+pulse*6,Color(ink,0.10+0.22*pulse))
		if e.tail_z >= 0:
			BossFx.glow(game,e.tail,12,Color(ink,0.35))
		for beam in game.boss.lasers:
			if beam.owner != e or not beam.has("mount") or beam.warning <= 0: continue
			BossFx.charge(game,beam.a,1.0-beam.warning/beam.warning_total,ink,30)
		if e.submerged: continue
		# The crown crystal is the weak point; the eyes flare while the head is charging.
		var face: Vector2 = e.face
		BossFx.energy_core(game,e.p-face*8,17,ink,clock,angry)
		var heat: float = 0.0
		for beam in game.boss.lasers:
			if beam.owner == e and beam.get("triad",false): heat = 1.0 if beam.warning <= 0 else 1.0-beam.warning/beam.warning_total
		for side in [-1.0,1.0]:
			var eye: Vector2 = e.p+face*40+face.orthogonal()*side*20
			BossFx.glow(game,eye,10+heat*10,Color(ink.lerp(Color.WHITE,0.4),0.55+0.4*heat))
			game.draw_line(eye-face*7,eye+face*6+face.orthogonal()*side*3,Color("fff6ea"),2,true)
		# Throat light between the jaw prongs.
		BossFx.glow(game,e.p+face*76,10+heat*16,Color(ink,0.3+0.5*heat))

static func draw_charge_lane(boss, game, e: Dictionary) -> void:
	var direction: Vector2 = e.charge_dir
	var half: float = boss.HEAD_RADIUS+18
	var side: Vector2 = direction.orthogonal()*half
	var ink := Color("ff496a")
	var clock: float = game.presentation.clock
	var blink: float = 0.75+0.25*sin(clock*18.0)
	var start: Vector2 = e.charge_start
	var end: Vector2 = e.charge_end+direction*half
	game.draw_colored_polygon(PackedVector2Array([start-side,end-side,end+side,start+side]),Color(1,0.2,0.3,0.07*blink+0.03))
	for sign_value in [-1,1]:
		game.draw_line(start+side*sign_value,end+side*sign_value,Color(ink,0.25),7,true)
		game.draw_line(start+side*sign_value,end+side*sign_value,Color(ink,blink),2,true)
	var length: float = start.distance_to(end)
	var distance: float = 70.0+fmod(clock*260.0,90.0)
	while distance < length:
		var point: Vector2 = start+direction*distance
		var fade: float = clampf(minf(distance-70.0,length-distance)/60.0,0,1)
		game.draw_polyline(PackedVector2Array([point-direction*18-direction.orthogonal()*16,point,point-direction*18+direction.orthogonal()*16]),Color(ink,fade),3,true)
		distance += 90.0

static func draw_depth(boss, view, _game, e: Dictionary, parts: Dictionary) -> void:
	var ink: Color = boss.ink(e)
	# Rubble kicked up around open holes.
	var holes: Array = []
	if e.phase == 1 or e.state == "breach_dive":
		if e.state != "under" and e.head_hole != Vector2.INF: holes = [[e.head_hole,boss.HOLE_RADIUS],[e.tail_hole,boss.TAIL_HOLE_RADIUS]]
	elif e.state == "roam" and e.traveled < boss.SEGMENTS*boss.SPACING+400: holes = [[e.breach,boss.BREACH_RADIUS*0.8]]
	for hole in holes:
		var center: Vector2 = hole[0]
		parts.pit.append(view.entry(center,Vector3(hole[1],hole[1],1),CRATER,0.2))
		for i in range(8):
			var angle: float = i*TAU/8+absf(sin(center.x*0.11+i))*0.4
			var size: float = 7.0+4.0*absf(sin(i*1.9+center.y*0.05))
			parts.boss_armor.append(view.weight(view.chaser_entry(center+Vector2.from_angle(angle)*hole[1]*1.02,Vector2.from_angle(angle+0.6),Vector3(size,size*0.7,4),RUBBLE,0),0.6))
	var count: int = e.segments.size()
	for i in range(count):
		var segment: Dictionary = e.segments[i]
		if segment.z < -26: continue
		var scale: float = segment.radius/SEGMENT_SCALE
		var tint := BODY_TINT.lerp(ink,0.08) if i%2 == 0 else BODY_TINT.darkened(0.08)
		parts.wyrm_segment.append(view.weight(view.chaser_entry(segment.p,segment.dir,Vector3(scale,scale,scale),tint,segment.z),0.8))
	if e.tail_z > -26 and count > 0:
		var last: Dictionary = e.segments[count-1]
		var heading: Vector2 = last.p.direction_to(e.tail)
		if heading.is_zero_approx(): heading = -last.dir
		parts.wyrm_tail.append(view.weight(view.chaser_entry(e.tail-heading*18,heading,Vector3.ONE,BODY_TINT,e.tail_z),0.85))
		parts.boss_core.append(view.chaser_entry(e.tail+heading*4,heading,Vector3(6,6,5),ink,e.tail_z+14))
	if e.head_z > -30:
		parts.wyrm_head.append(view.chaser_entry(e.p,e.face,Vector3.ONE,HEAD_TINT.lerp(ink,0.12),e.head_z))
		parts.boss_core.append(view.chaser_entry(e.p-e.face*8,e.face,Vector3(15,15,10),ink,e.head_z+30))
