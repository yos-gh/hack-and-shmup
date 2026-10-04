extends RefCounted
## Abyss Wyrm: a huge armoured boring machine in the shape of a serpent. The
## head is a hexagonal hull carrying the core in a raised housing ringed by
## shield plates, with a visor bar, hydraulic clamp jaws around an emitter
## throat, shoulder plates, exhaust louvres and a sensor mast. Each link is an
## armoured drum with a saddle plate, side track pods and a joint flange;
## hydraulic rams join the links and gun turrets ride every other one. The
## tail ends in a blade with an emitter pod. Local +X is forward; heights are
## pixels so the wire shader finds real creases.
const BossFx = preload("res://scripts/boss_fx.gd")
const Citadel = preload("res://scripts/citadel_visuals.gd")
const STEEL := Color("8197b1")
const HEAD_TINT := Color("62788f")
const BODY_TINT := Color("53667d")
const RAM_TINT := Color("8a9cb0")
const TURRET_TINT := Color("6d7f95")
const CRATER := Color("04070c")
const RUBBLE := Color("3a4658")
const SHELL_INK := Color("ff6a88")
const LINK_RADIUS := 70.0 # the link mesh is authored at this radius

static func mirrored(points: Array, side: float) -> Array:
	var result := []
	for p in points: result.append(Vector2(p.x,p.y*side))
	return result

static func side_rect(x0: float, x1: float, y0: float, y1: float, side: float) -> Array:
	return Citadel.rect(x0,x1,y0,y1) if side > 0 else Citadel.rect(x0,x1,-y1,-y0)

static func head_mesh() -> ArrayMesh:
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Hexagonal armoured hull, falling slightly toward the front.
	Citadel.slab(s,[Vector2(-100,0),Vector2(-80,-70),Vector2(60,-84),Vector2(150,-52),Vector2(176,-26),Vector2(176,26),Vector2(150,52),Vector2(60,84),Vector2(-80,70)],10,44,8,1.0,Vector2(0.05,0))
	# Core housing on the crown: collar and seat around the weak point.
	Citadel.slab(s,Citadel.octagon(60),44,52,4)
	Citadel.slab(s,Citadel.octagon(44),52,56,2)
	# Visor bar across the brow, emitter block in the throat.
	Citadel.slab(s,Citadel.rect(112,146,-46,46),38,48,3)
	Citadel.slab(s,Citadel.rect(170,214,-16,16),12,30,3)
	for side in [-1.0,1.0]:
		# Clamp jaws reaching past the hull, with an open throat between them.
		Citadel.slab(s,mirrored([Vector2(120,26),Vector2(200,20),Vector2(240,32),Vector2(234,54),Vector2(176,66),Vector2(120,64)],side),4,28,4)
		Citadel.slab(s,side_rect(70,150,54,64,side),30,40,2)                                             # hydraulic ram
		Citadel.slab(s,mirrored([Vector2(-70,72),Vector2(40,84),Vector2(52,104),Vector2(-60,100)],side),20,38,3)   # shoulder plate
	for k in range(3): Citadel.slab(s,Citadel.rect(-92+k*18,-80+k*18,-44,44),44,50,1.5)                   # exhaust louvres
	Citadel.slab(s,Citadel.rect(-118,-96,-12,12),30,62,3)                                                 # sensor mast
	return s.commit()

static func segment_mesh() -> ArrayMesh:
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	Citadel.slab(s,Citadel.octagon(56),0,34,7)                                   # armoured drum
	Citadel.slab(s,Citadel.rect(-30,30,-46,46),34,44,4)                          # saddle plate
	Citadel.slab(s,Citadel.rect(40,52,-60,60),4,38,3)                            # joint flange
	for side in [-1.0,1.0]: Citadel.slab(s,side_rect(-44,44,52,72,side),0,20,3)  # track pods
	for k in range(3): Citadel.slab(s,Citadel.rect(-22+k*16,-14+k*16,-28,28),44,48,1.5)   # vent ribs
	return s.commit()

static func tail_mesh() -> ArrayMesh:
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	Citadel.slab(s,[Vector2(-50,-30),Vector2(30,-22),Vector2(116,0),Vector2(30,22),Vector2(-50,30)],0,26,5,1.0,Vector2(0.08,0))
	Citadel.slab(s,Citadel.shifted(Citadel.octagon(18),Vector2(4,0)),26,40,3)    # emitter pod
	for side in [-1.0,1.0]:
		Citadel.slab(s,mirrored([Vector2(-40,22),Vector2(0,26),Vector2(-50,64),Vector2(-70,58)],side),4,18,2)   # stabiliser vane
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

# Open holes as [centre, radius, fade]; shared by the 2D rim and the 3D pit.
static func pits(boss, e: Dictionary) -> Array:
	var result: Array = []
	if e.phase == 1 or e.state == "breach_dive":
		if e.state in ["emerge","exposed","dive","breach_dive"]:
			result.append([e.hole,boss.HOLE_RADIUS,1.0])
			if e.dive_at < INF: result.append([e.dive_point,boss.HOLE_RADIUS*0.9,1.0])
		if e.tail_lift > 0 and e.tail_hole != Vector2.INF: result.append([e.tail_hole,boss.TAIL_HOLE_RADIUS,1.0])
	elif e.state == "roam":
		var fade: float = clampf(1.0-(e.traveled-boss.body_length())/400.0,0,1)
		if fade > 0: result.append([e.hole,boss.BREACH_RADIUS*0.8,fade])
	return result

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
	game.draw_polyline(rim,Color(ink,0.45*fade),2.0,true)
	game.draw_arc(center,radius*0.62,0,TAU,32,Color(ink,0.12*fade),6,true)
	for i in range(9):
		var axis := Vector2.from_angle(i*TAU/9+center.x*0.01)
		game.draw_line(center+axis*radius*0.95,center+axis*radius*(1.25+0.15*sin(i*1.7)),Color(STEEL,0.4*fade),1.4,true)

# Ground warning before a breach: a cracking target and the way the head will rise.
static func draw_omen(game, center: Vector2, radius: float, progress: float, ink: Color, clock: float, direction: Vector2 = Vector2.ZERO, reach: float = 0.0) -> void:
	BossFx.target_mark(game,center,radius,progress,ink,clock)
	for i in range(11):
		var axis := Vector2.from_angle(i*TAU/11+center.y*0.01)
		var length: float = radius*(0.4+0.9*progress)*(0.7+0.3*sin(i*2.3))
		game.draw_line(center+axis*radius*0.2,center+axis*length,Color(ink,0.25+0.5*progress),1.6,true)
	if reach > 0 and not direction.is_zero_approx():
		var tip: Vector2 = center+direction*(radius+reach)
		BossFx.dashed(game,center+direction*radius,tip,Color(ink,0.6*progress+0.2),clock,14,10,2)
		var side := direction.orthogonal()*14
		game.draw_polyline(PackedVector2Array([tip-direction*18+side,tip,tip-direction*18-side]),Color(ink,0.5+0.5*progress),2.5,true)

static func draw_shells(game, e: Dictionary, clock: float) -> void:
	for shell in e.shells:
		if shell.fired:
			BossFx.impact(game,shell.p,shell.r,-shell.impact,SHELL_INK,0.3)
			continue
		if shell.impact > shell.warn: continue
		var progress: float = clampf(1.0-shell.impact/shell.warn,0,1)
		var urgent: bool = progress > 0.75 and fmod(clock,0.12) < 0.06
		game.draw_circle(shell.p,shell.r,Color(SHELL_INK,0.05+0.10*progress+(0.07 if urgent else 0.0)))
		game.draw_arc(shell.p,shell.r,0,TAU,40,Color(SHELL_INK,0.75),1.6,true)
		game.draw_arc(shell.p,shell.r*(1.0-progress),0,TAU,32,Color(BossFx.WHITE_HOT,0.25+0.5*progress),1.5,true)
		for axis in [Vector2.RIGHT,Vector2.DOWN]: game.draw_line(shell.p-axis*10,shell.p+axis*10,Color(SHELL_INK,0.8),1.4,true)
		if progress > 0.7:
			# The shell drops into its mark.
			var fall: float = (progress-0.7)/0.3
			var head: Vector2 = shell.p+Vector2(0,-460*(1.0-fall))
			game.draw_line(head+Vector2(0,-46),head,Color(SHELL_INK.lerp(Color.WHITE,0.4),0.85),3,true)
			BossFx.glow(game,head,12,Color(SHELL_INK,0.6))

static func draw_charge_lane(boss, game, e: Dictionary) -> void:
	var direction: Vector2 = e.charge_dir
	var half: float = 100.0
	var side: Vector2 = direction.orthogonal()*half
	var ink := Color("ff496a")
	var clock: float = game.presentation.clock
	var blink: float = 0.75+0.25*sin(clock*18.0)
	var start: Vector2 = e.charge_start
	var end: Vector2 = e.charge_end+direction*240
	game.draw_colored_polygon(PackedVector2Array([start-side,end-side,end+side,start+side]),Color(1,0.2,0.3,0.07*blink+0.03))
	for sign_value in [-1,1]:
		game.draw_line(start+side*sign_value,end+side*sign_value,Color(ink,0.25),8,true)
		game.draw_line(start+side*sign_value,end+side*sign_value,Color(ink,blink),2.5,true)
	var length: float = start.distance_to(end)
	var distance: float = 120.0+fmod(clock*300.0,110.0)
	while distance < length:
		var point: Vector2 = start+direction*distance
		var fade: float = clampf(minf(distance-120.0,length-distance)/80.0,0,1)
		game.draw_polyline(PackedVector2Array([point-direction*26-direction.orthogonal()*30,point,point-direction*26+direction.orthogonal()*30]),Color(ink,fade),3.5,true)
		distance += 110.0

# Shield plates around the core; the ring keeps its bearing as the head turns.
static func draw_shields(boss, game, e: Dictionary, ink: Color) -> void:
	var inner: float = boss.RING-12.0
	var outer: float = boss.RING+12.0
	for k in range(boss.SLOTS):
		var plate: Dictionary = e.plates[k]
		var a: float = (k-0.44)*TAU/boss.SLOTS
		var b: float = (k+0.44)*TAU/boss.SLOTS
		if plate.hp > 0:
			var health: float = clampf(plate.hp/plate.max_hp,0,1)
			var tone := ink.lerp(BossFx.DANGER,1.0-health)
			var panel := BossFx.arc_band(e.p,a,b,inner,outer)
			game.draw_colored_polygon(panel,Color(tone.darkened(0.6),0.66))
			panel.append(panel[0])
			game.draw_polyline(panel,Color(tone,0.95),1.8,true)
			game.draw_arc(e.p,outer-4,a+0.05,b-0.05,6,Color(tone.lightened(0.35),0.55),1,true)
		else:
			var refill: float = clampf(1.0-plate.timer/maxf(boss.REBUILD,0.001),0,1)
			var ghost := BossFx.arc_band(e.p,a,b,inner,outer)
			ghost.append(ghost[0])
			game.draw_polyline(ghost,Color(ink,0.16),1,true)
			game.draw_arc(e.p,outer,a,lerpf(a,b,refill),8,Color(ink,0.6),2,true)

static func draw(boss, game) -> void:
	var clock: float = game.presentation.clock
	for e in game.enemies:
		if not e.has("segments") or e.hp <= 0: continue
		var ink: Color = boss.ink(e)
		var angry: bool = boss.rage(e)
		if e.phase == 1 and e.state == "under" and e.head_hole != Vector2.INF:
			var total: float = boss.UNDER_TIME*e.attack_scale if e.rise > 0 else boss.FIRST_UNDER_TIME
			var progress: float = clampf(1.0-e.state_time/total,0,1)
			draw_omen(game,e.head_hole,boss.HOLE_RADIUS,progress,ink,clock,Vector2.from_angle(e.emerge_heading),260)
			draw_omen(game,e.tail_hole,boss.TAIL_HOLE_RADIUS,progress,ink,clock)
		elif e.state == "breach_wait":
			draw_omen(game,e.breach,boss.BREACH_RADIUS,clampf(1.0-e.state_time/boss.BREACH_WAIT,0,1),ink,clock)
		for pit in pits(boss,e): draw_crater(game,pit[0],pit[1],ink,pit[2])
		if e.state == "roam" and e.move_mode in ["charge_warning","charge"]: draw_charge_lane(boss,game,e)
		if not game.depth_enabled:
			for segment in e.segments:
				if segment.z < 0: continue
				game.draw_circle(segment.p,segment.radius,Color("3b4c63"))
				game.draw_arc(segment.p,segment.radius,0,TAU,32,Color(STEEL,0.8),1.5,true)
			if e.head_v >= 0.5:
				var hull: PackedVector2Array = boss.head_outline(e)
				game.draw_colored_polygon(hull,Color("4d6380"))
				hull.append(hull[0])
				game.draw_polyline(hull,Color(STEEL),1.5,true)
			if e.tail_z >= 0: game.draw_circle(e.tail+e.tail_heading*30,42,Color("3b4c63"))
		# Spine lamps: a pulse runs down the body; turrets glow as they charge.
		for segment in e.segments:
			if segment.z < 0: continue
			var pulse: float = 0.5+0.5*sin(clock*(7.0 if angry else 4.0)-segment.index*0.7)
			BossFx.glow(game,segment.p,12+pulse*10,Color(ink,0.10+0.22*pulse))
		for volley in e.volleys:
			if volley.kind != "turret" or volley.t > 0.45: continue
			var segment: Dictionary = boss.segment_at(e,volley.index)
			if not segment.is_empty(): BossFx.charge(game,segment.p,1.0-volley.t/0.45,ink,30)
		for beam in game.boss.lasers:
			if beam.owner != e or not beam.has("mount") or beam.warning <= 0: continue
			BossFx.charge(game,beam.a,1.0-beam.warning/beam.warning_total,ink,40)
		if e.launch_flash > 0:
			# Shells leave the turrets for the sky.
			var k: float = e.launch_flash/0.7
			for segment in e.segments:
				if not segment.index in boss.TURRETS or segment.z < 0: continue
				var top: Vector2 = segment.p+Vector2(0,-520*(1.0-k))
				game.draw_line(segment.p,top,Color(SHELL_INK,0.5*k),4,true)
				BossFx.glow(game,top,16,Color(SHELL_INK,0.7*k))
		if e.tail_z >= 0: BossFx.glow(game,boss.tail_muzzle(e),16,Color(ink,0.4))
		draw_shells(game,e,clock)
		if e.submerged: continue
		# The weak point: the core and its plates. Visor lamps and the throat
		# brighten while the head is charging a beam.
		draw_shields(boss,game,e,ink)
		BossFx.energy_core(game,e.p,22,ink,clock,angry)
		var face: Vector2 = e.face
		var heat: float = 0.0
		for beam in game.boss.lasers:
			if beam.owner == e and beam.get("triad",false): heat = 1.0 if beam.warning <= 0 else 1.0-beam.warning/beam.warning_total
		for k in range(5):
			var lamp: Vector2 = e.p+face*130+face.orthogonal()*(-36+k*18)
			BossFx.glow(game,lamp,8+heat*6,Color(ink.lerp(Color.WHITE,0.3),0.45+0.4*heat))
			game.draw_circle(lamp,2.2,Color(BossFx.WHITE_HOT,0.8))
		BossFx.glow(game,e.p+face*196,16+heat*22,Color(ink,0.3+0.5*heat))

static func draw_depth(boss, view, game, e: Dictionary, parts: Dictionary) -> void:
	var ink: Color = boss.ink(e)
	for pit in pits(boss,e):
		var center: Vector2 = pit[0]
		var radius: float = pit[1]
		parts.pit.append(view.entry(center,Vector3(radius,radius,1),CRATER,0.2))
		for i in range(10):
			var angle: float = i*TAU/10+absf(sin(center.x*0.11+i))*0.4
			var size: float = 12.0+7.0*absf(sin(i*1.9+center.y*0.05))
			parts.boss_armor.append(view.weight(view.chaser_entry(center+Vector2.from_angle(angle)*radius*1.02,Vector2.from_angle(angle+0.6),Vector3(size,size*0.7,6),RUBBLE,0),0.6))
	var previous: Dictionary = {}
	for segment in e.segments:
		if segment.z < -40:
			previous = {}
			continue
		var scale: float = segment.radius/LINK_RADIUS
		var tint := BODY_TINT.lerp(ink,0.08) if segment.index%2 == 0 else BODY_TINT.darkened(0.08)
		parts.wyrm_segment.append(view.weight(view.chaser_entry(segment.p,segment.dir,Vector3(scale,scale,scale),tint,segment.z),0.8))
		if segment.kind == "body" and segment.index in boss.TURRETS and segment.z > -10:
			var aim: Vector2 = segment.p.direction_to(game.player)
			parts.citadel_gun.append(view.weight(view.chaser_entry(segment.p,aim,Vector3(1.5,1.5,1.5),TURRET_TINT.lerp(ink,0.15),segment.z+44*scale),0.9))
		# Hydraulic rams across each joint of the chain.
		if not previous.is_empty() and segment.kind in ["body","joint"] and previous.kind == "body":
			var axis: Vector2 = segment.p.direction_to(previous.p)
			for side in [-1.0,1.0]:
				var a: Vector2 = segment.p+axis.orthogonal()*side*segment.radius*0.62
				var b: Vector2 = previous.p+axis.orthogonal()*side*minf(previous.radius,segment.radius)*0.62
				parts.boss_barrel.append(view.weight(view.chaser_entry((a+b)*0.5,a.direction_to(b),Vector3(a.distance_to(b)*0.5,5,6),RAM_TINT,(segment.z+previous.z)*0.5+20),0.6))
		previous = segment
	if e.tail_z > -40:
		parts.wyrm_tail.append(view.weight(view.chaser_entry(e.tail,e.tail_heading,Vector3.ONE,BODY_TINT,e.tail_z),0.85))
		parts.boss_core.append(view.chaser_entry(e.tail+e.tail_heading*4,e.tail_heading,Vector3(10,10,8),ink,e.tail_z+40))
	if e.head_z > -40:
		parts.wyrm_head.append(view.weight(view.chaser_entry(e.p,e.face,Vector3.ONE,HEAD_TINT.lerp(ink,0.1),e.head_z),0.9))
		parts.boss_core.append(view.chaser_entry(e.p,e.face,Vector3(24,24,14),ink,e.head_z+56))
