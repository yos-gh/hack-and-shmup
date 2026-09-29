extends RefCounted
## Iron Citadel: an angular SF tank. Two long, exposed, tapered track wedges are
## joined by a dark X-braced truss frame. At the crossing stands the core
## housing, a little smaller than the shield ring: a collar ringed by sloped
## armour cheeks and diagonal buttresses whose tips break past the ring, with
## hydraulic rams and cooling ribs, carrying the seat of the core. Angular
## sponsons where the truss meets the tracks carry rotating twin-barrel heads.
## Local +X is the hull's heading, Y is lateral.
const BossFx = preload("res://scripts/boss_fx.gd")
const Triad = preload("res://scripts/triad_visuals.gd")
# Contact parts in hull space; each corner is a ground vertex of the 3D frame
# or chassis. One truss arm in its own frame (+X outward along the diagonal).
const ARM := [Vector2(50,-13),Vector2(172,-13),Vector2(172,13),Vector2(50,13)]
const ARM_START := 50.0
const ARM_END := 172.0
# Tapered track wedge: widest just behind the nose, narrowing to both ends.
const TRACK := [Vector2(-151,-14),Vector2(91,-20),Vector2(151,-12),Vector2(151,12),Vector2(91,20),Vector2(-151,14)]
const TRACK_Y := 128.0
const TRACK_TOP := 16.0
const TRACK_SLOPE := 0.02
# Angular sponson plate, pointing outward from the hull.
const SPONSON := [Vector2(-24,-17),Vector2(14,-24),Vector2(24,-14),Vector2(24,14),Vector2(14,24),Vector2(-24,17)]
const MOUNT_RADIUS := 24.0
const MOUNT := 140.0
const CLEATS := 9
# The housing mesh is authored from the ground; its instance origin sits at
# this height so the core and 2D overlays stay registered with its middle.
const HOUSING_LIFT := 14.0
const CHASSIS_TINT := Color("6a8299")
const FRAME_TINT := Color("2c3e50")
const HOUSING_TINT := Color("4a5e72")
const HAZARD := Color("ffb95e")
const LAMP := Color("ffe6c8")
const TOP := Color.WHITE
const CHAMFER := Color(0.78,0.84,0.9)
const WALL := Color(0.4,0.5,0.62)
const BASE := Color(0.25,0.32,0.4)

static func octagon(radius: float) -> Array:
	var points := []
	for i in range(8): points.append(Vector2.from_angle(PI/8+i*TAU/8)*radius)
	return points

static func hexagon(radius: float) -> Array:
	var points := []
	for i in range(6): points.append(Vector2.from_angle(i*TAU/6)*radius)
	return points

static func shifted(points: Array, offset: Vector2, angle: float = 0.0) -> Array:
	var result := []
	for p in points: result.append(p.rotated(angle)+offset)
	return result

static func rect(x0: float, x1: float, y0: float, y1: float) -> Array:
	return [Vector2(x0,y0),Vector2(x1,y0),Vector2(x1,y1),Vector2(x0,y1)]

# Offset a convex, consistently wound outline inward by `amount`.
static func inset(points: Array, amount: float) -> Array:
	var center := Vector2.ZERO
	for p in points: center += p
	center /= points.size()
	var lines := []
	for i in range(points.size()):
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i+1)%points.size()]
		var normal := (b-a).orthogonal().normalized()
		if normal.dot(center-a) < 0: normal = -normal
		lines.append([a+normal*amount,b-a])
	var result := []
	for i in range(points.size()):
		var previous: Array = lines[(i-1+points.size())%points.size()]
		var current: Array = lines[i]
		var hit = Geometry2D.line_intersects_line(previous[0],previous[1],current[0],current[1])
		result.append(hit if hit != null else current[0])
	return result

# Closed convex slab with a chamfered top edge. The top falls along `slope`
# (height lost per pixel); `tone` darkens secondary parts.
static func slab(s: SurfaceTool, outline: Array, z0: float, z1: float, chamfer: float, tone: float = 1.0, slope: Vector2 = Vector2.ZERO) -> void:
	var top := inset(outline,chamfer)
	var center := Vector2.ZERO
	for p in outline: center += p
	center /= outline.size()
	var high := func(p: Vector2) -> float: return z1-slope.dot(p)
	var lift := func(p: Vector2, z: float) -> Vector3: return Triad.lift(p.x,p.y,z)
	for i in range(outline.size()):
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i+1)%outline.size()]
		var ia: Vector2 = top[i]
		var ib: Vector2 = top[(i+1)%outline.size()]
		var edge_normal := (b-a).orthogonal().normalized()
		if edge_normal.dot((a+b)*0.5-center) < 0: edge_normal = -edge_normal
		var out := Triad.lift(edge_normal.x,edge_normal.y,0).normalized()
		var ca: Vector3 = lift.call(a,high.call(a)-chamfer)
		var cb: Vector3 = lift.call(b,high.call(b)-chamfer)
		Triad.quad(s,lift.call(a,z0),lift.call(b,z0),cb,ca,out,WALL*tone)
		Triad.quad(s,ca,cb,lift.call(ib,high.call(ib)),lift.call(ia,high.call(ia)),(out+Vector3.BACK).normalized(),CHAMFER*tone)
		Triad.oriented(s,lift.call(center,high.call(center)),lift.call(ia,high.call(ia)),lift.call(ib,high.call(ib)),Vector3.BACK,TOP*tone)
		Triad.oriented(s,lift.call(center,z0),lift.call(a,z0),lift.call(b,z0),Vector3.FORWARD,BASE)

# Slab whose top falls linearly from `inner` height at radius r0 to `outer`
# at r1 along `angle`, so armour plates lean outward from the housing.
static func leaning(s: SurfaceTool, outline: Array, angle: float, z0: float, r0: float, inner: float, r1: float, outer: float, chamfer: float) -> void:
	var fall := (inner-outer)/(r1-r0)
	slab(s,shifted(outline,Vector2.ZERO,angle),z0,inner+fall*r0,chamfer,1.0,Vector2.from_angle(angle)*fall)

static func track_half_width(x: float) -> float:
	if x < 91: return lerpf(14,20,(x+151)/242.0)
	return lerpf(20,12,(x-91)/60.0)

static func sponson_angle(gun: int) -> float:
	return gun*PI/2+PI/4

static func chassis_mesh() -> ArrayMesh:
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0,1.0]:
		slab(s,shifted(TRACK,Vector2(0,TRACK_Y*side)),0,TRACK_TOP,3,1.0,Vector2(TRACK_SLOPE,0))
	for gun in range(4):
		var angle := sponson_angle(gun)
		slab(s,shifted(SPONSON,Vector2.from_angle(angle)*MOUNT,angle),TRACK_TOP-2,TRACK_TOP+6,3)
	return s.commit()

# X-braced truss: twin rails per arm with cross braces and a track shoe.
static func frame_mesh() -> ArrayMesh:
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	for gun in range(4):
		var angle := sponson_angle(gun)
		for side in [-1.0,1.0]:
			slab(s,shifted(rect(ARM_START,ARM_END,8,13) if side > 0 else rect(ARM_START,ARM_END,-13,-8),Vector2.ZERO,angle),0,9,2)
		var along := ARM_START+12
		while along < ARM_END-20:
			slab(s,shifted(rect(along,along+4,-8,8),Vector2.ZERO,angle),2,7,1)
			along += 18
		slab(s,shifted(rect(ARM_END-22,ARM_END,-8,8),Vector2.ZERO,angle),0,11,2)   # track shoe
	return s.commit()

# Core housing, authored from the ground and lowered by HOUSING_LIFT.
static func housing_mesh() -> ArrayMesh:
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	var l := HOUSING_LIFT
	slab(s,octagon(64),6-l,14-l,3)                          # load collar on the truss
	for gun in range(4):
		var axis := gun*PI/2
		# Sloped armour cheek between buttresses, with cooling ribs.
		leaning(s,[Vector2(52,-24),Vector2(90,-18),Vector2(90,18),Vector2(52,24)],axis,6-l,52,20-l,90,11-l,2.5)
		if gun%2 == 1:
			for y in [-10.0,0.0,10.0]:
				leaning(s,rect(58,86,y-1.5,y+1.5),axis,16-l,58,22-l,86,14-l,0.6)
	# Prow sensor block and rear exhaust louvres on their cheeks.
	leaning(s,[Vector2(78,-9),Vector2(98,-4),Vector2(98,4),Vector2(78,9)],0,12-l,78,18-l,98,14-l,1.5)
	for k in range(3):
		leaning(s,rect(64+k*8,68+k*8,-14,14),PI,16-l,64,21-l,90,14-l,0.8)
	slab(s,octagon(46),14-l,22-l,3)                        # core seat
	slab(s,octagon(33),22-l,26-l,2)
	return s.commit()

static func gun_mesh() -> ArrayMesh:
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	slab(s,hexagon(17),0,3,1)                               # traverse collar
	slab(s,[Vector2(-16,-14),Vector2(8,-14),Vector2(16,-8),Vector2(16,8),Vector2(8,14),Vector2(-16,14)],3,13,3)
	slab(s,rect(-14,-5,-6,6),13,16,1)                       # sight block
	for side in [-1.0,1.0]:
		slab(s,rect(16,42,3,8) if side > 0 else rect(16,42,-8,-3),6,10,1)
		slab(s,rect(40,47,2,9) if side > 0 else rect(40,47,-9,-2),5,11,1.5)   # muzzle brake
	return s.commit()

# Diagonal buttresses and their hydraulic rams continue the truss into the
# housing; they share its dark tint. Lowered by HOUSING_LIFT like the housing.
static func brace_mesh() -> ArrayMesh:
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	var l := HOUSING_LIFT
	for gun in range(4):
		var diagonal := sponson_angle(gun)
		# Tall at the collar, raked down to a tip past the ring.
		leaning(s,[Vector2(40,-13),Vector2(102,-8),Vector2(113,0),Vector2(102,8),Vector2(40,13)],diagonal,4-l,40,24-l,113,11-l,2.5)
		for side in [-1.0,1.0]:
			slab(s,shifted(rect(52,90,15,19) if side > 0 else rect(52,90,-19,-15),Vector2.ZERO,diagonal),8-l,12-l,1)
			slab(s,shifted(rect(86,96,12,17) if side > 0 else rect(86,96,-17,-12),Vector2.ZERO,diagonal),7-l,13-l,1)
	return s.commit()

static func contact_parts(e: Dictionary) -> Array[PackedVector2Array]:
	var parts: Array[PackedVector2Array] = []
	var shapes := [shifted(TRACK,Vector2(0,-TRACK_Y)),shifted(TRACK,Vector2(0,TRACK_Y))]
	for gun in range(4): shapes.append(shifted(ARM,Vector2.ZERO,sponson_angle(gun)))
	for shape in shapes:
		var polygon := PackedVector2Array()
		for p in shape: polygon.append(e.p+p.rotated(e.heading))
		parts.append(polygon)
	return parts

static func draw(fortress, game, e: Dictionary, ink: Color) -> void:
	var hull := Transform2D(e.heading,e.p)
	var clock: float = game.presentation.clock
	if not game.depth_enabled:
		var parts := contact_parts(e)
		for arm in parts.slice(2): game.draw_colored_polygon(arm,Color("24323f"))
		game.draw_colored_polygon(hull*PackedVector2Array(octagon(64)),Color("33495b"))
		for track in parts.slice(0,2): game.draw_colored_polygon(track,Color("556777"))
		for gun in range(4):
			var point: Vector2 = fortress.gun_position(e,gun)
			game.draw_circle(point,MOUNT_RADIUS,ink.darkened(0.4))
			game.draw_line(point,point+fortress.gun_direction(game,e,gun)*45,ink,10,true)
		game.draw_circle(e.p,fortress.CORE,ink)
	# Faint contact outlines under the raised tracks.
	for polygon in contact_parts(e).slice(0,2):
		polygon.append(polygon[0])
		game.draw_polyline(polygon,Color(Triad.STEEL,0.26),1.0,true)
	# Hazard striping across each track nose.
	for side in [-1.0,1.0]:
		for k in range(3):
			var x := 126.0+k*7
			var w: float = track_half_width(x)-3
			game.draw_line(hull*Vector2(x,side*TRACK_Y-w),hull*Vector2(x+6,side*TRACK_Y+w),Color(HAZARD,0.7),2,true)
	# Headlamps beside the prow sensor: steady when cruising, a hot red flare
	# while lining up a ram.
	var ramming: bool = e.get("move_mode","") in ["ram_warning","ram"]
	var lamp := Color("ff496a") if ramming else LAMP
	var flare := (0.75+0.25*sin(clock*18.0)) if ramming else 0.55
	for side in [-1.0,1.0]:
		var a: Vector2 = hull*Vector2(96,side*7)
		var b: Vector2 = hull*Vector2(86,side*16)
		BossFx.glow(game,a.lerp(b,0.5),12+flare*10,Color(lamp,0.22*flare+0.1))
		game.draw_line(a,b,Color(lamp,0.6+0.4*flare),2,true)
	# Exhaust louvres breathe with the engine; the ink tint follows rage.
	var breath: float = 0.5+0.5*sin(clock*5.0)
	BossFx.glow(game,hull*Vector2(-92,0),12+breath*8,Color(ink,0.18+0.2*breath))

static func draw_depth(fortress, view, game, e: Dictionary, parts: Dictionary, ink: Color) -> void:
	var facing := Vector2.from_angle(e.heading)
	parts.citadel_frame.append(view.weight(view.chaser_entry(e.p,facing,Vector3.ONE,FRAME_TINT,1),0.45))
	parts.citadel_brace.append(view.weight(view.chaser_entry(e.p,facing,Vector3.ONE,FRAME_TINT.lightened(0.06),HOUSING_LIFT),0.55))
	parts.citadel_chassis.append(view.weight(view.chaser_entry(e.p,facing,Vector3.ONE,CHASSIS_TINT,2),0.85))
	parts.citadel_keep.append(view.weight(view.chaser_entry(e.p,facing,Vector3.ONE,HOUSING_TINT.lerp(ink,0.1),HOUSING_LIFT),0.75))
	for side in [-1,1]:
		# Cleats ride the sloped top and follow the track's taper.
		for tread in range(CLEATS):
			var along: float = -CLEATS*16+fposmod(tread*32+e.tread,CLEATS*32)
			var top: float = TRACK_TOP-TRACK_SLOPE*along
			parts.boss_barrel.append(view.weight(view.boss_part(e,facing,Vector2(along,side*TRACK_Y),Vector3(4,track_half_width(along)+1,2),Color("7894ad"),2+top),0.5))
	for gun in range(4):
		var heading: Vector2 = fortress.gun_direction(game,e,gun)
		parts.citadel_gun.append(view.chaser_entry(fortress.gun_position(e,gun),heading,Vector3.ONE,ink.darkened(0.25),2+TRACK_TOP+6))
	parts.boss_core.append(view.chaser_entry(e.p,facing,Vector3(30,30,12),ink,26))
