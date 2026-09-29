extends RefCounted
## Triad Battery: three clamped lattice gantries around the core, each carrying a
## guide rail on which two turret carriages slide. Twin-barrel heads aim along
## the stream they fire; needle pods ride the rail between them.
const Glyph = preload("res://scripts/glyph_meshes.gd")
const BossFx = preload("res://scripts/boss_fx.gd")
const TURRET_RADIUS := 292.0
const MUZZLE := 24.0
const NEEDLE_ALONG := 0.3
# Contact parts in gantry space: +X outward along the gantry, Y along the rail.
const GANTRY_HULL := [
	[Vector2(108,-38),Vector2(154,-38),Vector2(154,38),Vector2(108,38)],
	[Vector2(154,-28),Vector2(228,-28),Vector2(228,28),Vector2(154,28)],
	[Vector2(226,-36),Vector2(280,-36),Vector2(280,36),Vector2(226,36)],
	[Vector2(236,-198),Vector2(270,-198),Vector2(270,198),Vector2(236,198)],
	[Vector2(270,-118),Vector2(288,-118),Vector2(288,118),Vector2(270,118)],
	[Vector2(230,184),Vector2(276,184),Vector2(276,204),Vector2(230,204)],
	[Vector2(230,-204),Vector2(276,-204),Vector2(276,-184),Vector2(230,-184)]]
const CARRIAGE_HULL := [Vector2(-26,-26),Vector2(26,-26),Vector2(26,26),Vector2(-26,26)]
const REACH := 346.0
const STEEL := Color("8197b1")
const HAZARD := Color("ffb95e")
const TOP := Color.WHITE
const CHAMFER := Color(0.78,0.84,0.9)
const WALL := Color(0.4,0.5,0.62)
const BASE := Color(0.25,0.32,0.4)

static func lift(x: float, y: float, z: float) -> Vector3:
	# World +Y points down; the 3D stage uses +Y up.
	return Vector3(x,-y,z)

# Emit a triangle whose visible face points along `outward`.
static func oriented(s: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3, tint: Color) -> void:
	if (b-a).cross(c-a).dot(outward) < 0:
		var swap := b
		b = c
		c = swap
	Glyph.face(s,a,b,c,tint)

static func quad(s: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3, tint: Color) -> void:
	oriented(s,a,b,c,outward,tint)
	oriented(s,a,c,d,outward,tint)

# Closed machined block with a chamfered top edge. Heights are in pixels so the
# wire shader finds real creases.
static func block(s: SurfaceTool, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, chamfer: float) -> void:
	var zc := z1-chamfer
	var low := [Vector2(x0,y0),Vector2(x1,y0),Vector2(x1,y1),Vector2(x0,y1)]
	var inset := [Vector2(x0+chamfer,y0+chamfer),Vector2(x1-chamfer,y0+chamfer),Vector2(x1-chamfer,y1-chamfer),Vector2(x0+chamfer,y1-chamfer)]
	var center := Vector2((x0+x1)*0.5,(y0+y1)*0.5)
	for i in range(4):
		var a: Vector2 = low[i]
		var b: Vector2 = low[(i+1)%4]
		var ia: Vector2 = inset[i]
		var ib: Vector2 = inset[(i+1)%4]
		var mid: Vector2 = (a+b)*0.5-center
		var out := lift(mid.x,mid.y,0).normalized()
		quad(s,lift(a.x,a.y,z0),lift(b.x,b.y,z0),lift(b.x,b.y,zc),lift(a.x,a.y,zc),out,WALL)
		quad(s,lift(a.x,a.y,zc),lift(b.x,b.y,zc),lift(ib.x,ib.y,z1),lift(ia.x,ia.y,z1),(out+Vector3.BACK).normalized(),CHAMFER)
	quad(s,lift(inset[0].x,inset[0].y,z1),lift(inset[1].x,inset[1].y,z1),lift(inset[2].x,inset[2].y,z1),lift(inset[3].x,inset[3].y,z1),Vector3.BACK,TOP)
	quad(s,lift(x0,y0,z0),lift(x1,y0,z0),lift(x1,y1,z0),lift(x0,y1,z0),Vector3.FORWARD,BASE)

static func gantry_mesh() -> ArrayMesh:
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	block(s,108,154,-38,38,0,44,7)       # hull clamp
	block(s,120,146,-30,30,44,52,3)      # clamp cap
	block(s,154,228,-28,-15,0,24,3)      # lattice rails
	block(s,154,228,15,28,0,24,3)
	for x in [170.0,192.0,214.0]:
		block(s,x-4,x+4,-15,15,8,18,1)     # rungs
	block(s,226,280,-36,36,0,36,6)       # rail junction
	block(s,236,270,-198,198,0,20,4)     # rail beam
	block(s,248,258,-190,190,20,26,1)    # guide rail
	block(s,270,288,-118,118,0,30,7)     # outboard armour bulwark
	block(s,230,276,184,204,0,36,5)      # end stops
	block(s,230,276,-204,-184,0,36,5)
	return s.commit()

static func carriage_mesh() -> ArrayMesh:
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	block(s,-26,26,-24,24,16,34,5)       # sled
	block(s,-26,-18,-26,26,0,16,2)       # skirts hugging the beam
	block(s,18,26,-26,26,0,16,2)
	return s.commit()

static func draw(boss, game) -> void:
	for e in game.enemies:
		if not e.has("pattern_time") or e.hp <= 0 or not game.attack_open(e.p): continue
		var ink: Color = boss.INK
		var rage: bool = e.hp <= e.max_hp*0.5
		var clock: float = game.presentation.clock
		if not game.depth_enabled:
			game.draw_circle(e.p,boss.BODY_RADIUS,Color("202239",0.28))
		# Faint contact outlines under the raised structure.
		for polygon in boss.hull_parts(e):
			if not game.depth_enabled: game.draw_colored_polygon(polygon,Color("273347",0.3))
			polygon.append(polygon[0])
			game.draw_polyline(polygon,Color(STEEL,0.28),1.0,true)
		for pair in range(3):
			var angle: float = boss.gantry_angle(e,pair)
			# Guide-rail light and hazard striping on the end stops.
			var rail_a: Vector2 = e.p+Vector2(253,-190).rotated(angle)
			var rail_b: Vector2 = e.p+Vector2(253,190).rotated(angle)
			game.draw_line(rail_a,rail_b,Color(ink,0.22),1.2,true)
			var runner: float = fmod(clock*0.6+pair*0.33,1.0)
			BossFx.glow(game,rail_a.lerp(rail_b,runner),10,Color(ink,0.5*sin(runner*PI)))
			for side in [-1.0,1.0]:
				for k in range(3):
					var a: Vector2 = e.p+Vector2(234+k*14,188*side).rotated(angle)
					var b: Vector2 = e.p+Vector2(244+k*14,200*side).rotated(angle)
					game.draw_line(a,b,Color(HAZARD,0.7),2,true)
		for i in range(6):
			var color: Color = boss.BLUE if i%2 == 0 else boss.ROSE
			var flash: float = e.mouth_flash[i]/0.16
			var mouth: Vector2 = boss.mouth_position(e,i)
			var pivot: Vector2 = boss.turret_pivot(e,i)
			var heading: Vector2 = boss.stream_heading(e,i)
			# Muzzle: flare on each burst, a status lamp on the turret head.
			BossFx.glow(game,mouth,10+flash*22,Color(color,0.35+flash*0.55))
			if flash > 0:
				for side in [-1.0,1.0]:
					var flare: Vector2 = mouth+heading*(6+flash*10)+heading.orthogonal()*side*6
					game.draw_line(mouth,flare,Color(color.lerp(Color.WHITE,0.6),flash),2,true)
			game.draw_circle(pivot-heading*8,2.5,Color(color,0.9))
			var root: Vector2 = boss.root_position(e,i)
			var root_angle: float = boss.carriage_angle(e,i)+PI/6
			var hatch := PackedVector2Array()
			for p in [Vector2(-8,-11),Vector2(8,-11),Vector2(8,11),Vector2(-8,11)]: hatch.append(root+p.rotated(root_angle))
			game.draw_colored_polygon(hatch,Color("151c2a"))
			hatch.append(hatch[0])
			game.draw_polyline(hatch,ink,1.5,true)
			game.draw_line(root-Vector2.from_angle(root_angle+PI/2)*6,root+Vector2.from_angle(root_angle+PI/2)*6,Color(ink,0.7),2+e.root_flash*6,true)
			# Needle pod on the rail: the aimed-shot source.
			var needle: Vector2 = boss.needle_position(e,i)
			var needle_dir := Vector2.from_angle(boss.carriage_angle(e,i))
			var charging := false
			for volley in e.needle_volleys:
				if volley.gun != i: continue
				needle_dir = volley.heading
				charging = true
				if volley.fired == 0:
					var progress: float = 1.0-clampf(volley.timer/volley.warning,0,1)
					BossFx.glow(game,needle,10+progress*14,Color("ff788e",0.3+progress*0.5))
					game.draw_arc(needle,19-progress*7,0,TAU,16,Color("ff788e"),1.5,true)
					var end: Vector2 = game.attack_end(needle,needle_dir,330)
					game.draw_line(needle,end,Color(1,0.47,0.56,0.10+progress*0.12),1.5,true)
			var tip: Vector2 = needle+needle_dir*13
			var side_offset: Vector2 = needle_dir.orthogonal()*6
			game.draw_colored_polygon(PackedVector2Array([tip,needle-needle_dir*10+side_offset,needle-needle_dir*5,needle-needle_dir*10-side_offset]),Color("ff788e") if charging else Color("804a60"))
		# The carapace edge is a real contact boundary, independent of core damage.
		game.draw_arc(e.p,boss.BODY_RADIUS,0,TAU,72,Color(ink,0.45),2,true)
		if not game.depth_enabled:
			game.draw_circle(e.p,73,Color("161e2b"))
			game.draw_circle(e.p,43,ink.darkened(0.25))
			game.draw_circle(e.p,23,Color("fff6e7"))
		BossFx.shield_ring(game,e,boss.COUNT,ink,boss.REBUILD)
		BossFx.energy_core(game,e.p,34,ink,clock,rage)
		if e.root_flash > 0:
			for i in range(6): BossFx.glow(game,boss.root_position(e,i),30,Color(ink,e.root_flash/0.4*0.6))
		for beam in game.boss.lasers:
			if beam.owner != e or not beam.get("triad",false): continue
			var mouth: Vector2 = e.p+beam.heading*82
			var power: float = 1.0 if beam.warning <= 0 else 1.0-beam.warning/boss.LASER_WARNING
			# Iris aperture: petals open as the beam charges.
			var aperture: float = lerpf(20.0,34.0,power)
			for k in range(6):
				var start: float = beam.heading.angle()+k*TAU/6+clock*(0.6 if beam.warning > 0 else 2.2)
				game.draw_arc(mouth,aperture,start,start+0.7,8,Color(ink,0.5+0.4*power),2,true)
			if beam.warning <= 0: game.draw_line(mouth-beam.heading.orthogonal()*22,mouth+beam.heading.orthogonal()*22,Color("fff5e7"),3,true)
		for strike in e.evictions:
			if strike.timer > 0:
				var progress: float = clampf(1.0-strike.timer/1.5,0,1)
				BossFx.target_mark(game,strike.p,boss.EVICTION_RADIUS,progress,boss.ROSE,clock)
				# The mote arcs from the iris; a short comet tail traces its path.
				for k in range(6):
					var t: float = maxf(0,progress-k*0.025)
					var trail: Vector2 = strike.origin.lerp(strike.p,t)+Vector2(0,-180*sin(t*PI))
					game.draw_circle(trail,5.0-k*0.7,Color(boss.ROSE,0.5-k*0.08))
				var mote: Vector2 = strike.origin.lerp(strike.p,progress)+Vector2(0,-180*sin(progress*PI))
				BossFx.glow(game,mote,22,Color(boss.ROSE,0.7))
				game.draw_circle(mote,4,Color("fff3dc"))
			else:
				BossFx.impact(game,strike.p,boss.EVICTION_RADIUS,-strike.timer,boss.ROSE,0.32)

static func draw_depth(boss, view, _game, e: Dictionary, parts: Dictionary) -> void:
	parts.triad_body.append(view.weight(view.chaser_entry(e.p,Vector2.RIGHT,Vector3(boss.BODY_RADIUS,boss.BODY_RADIUS,26),Color("37465d"),12),0.7))
	for pair in range(3):
		parts.triad_gantry.append(view.weight(view.chaser_entry(e.p,Vector2.from_angle(boss.gantry_angle(e,pair)),Vector3.ONE,Color("5b6b84"),4),0.85))
	for i in range(6):
		var color: Color = boss.BLUE if i%2 == 0 else boss.ROSE
		var pivot: Vector2 = boss.turret_pivot(e,i)
		var heading: Vector2 = boss.stream_heading(e,i)
		var rail := Vector2.from_angle(boss.gantry_angle(e,i >> 1))
		parts.triad_carriage.append(view.weight(view.chaser_entry(pivot,rail,Vector3.ONE,Color("5b6b84").lerp(color,0.25),4),0.9))
		# Rotating twin-barrel head aimed along the stream it writes.
		parts.boss_armor.append(view.chaser_entry(pivot,heading,Vector3(20,17,12),color.darkened(0.3),40))
		for side in [-1.0,1.0]:
			parts.boss_barrel.append(view.weight(view.chaser_entry(pivot+heading*16+heading.orthogonal()*side*6.5,heading,Vector3(15,3,3.4),color.darkened(0.1),50),0.85))
		parts.boss_core.append(view.chaser_entry(boss.mouth_position(e,i),heading,Vector3(5,5,5),color,52))
		parts.boss_armor.append(view.weight(view.chaser_entry(boss.needle_position(e,i),rail,Vector3(10,8,8),Color("ff788e").darkened(0.4),24),0.8))
		parts.boss_core.append(view.chaser_entry(boss.root_position(e,i),Vector2.from_angle(boss.carriage_angle(e,i)+PI/6),Vector3(8,11,6),boss.INK,31))
	parts.boss_base.append(view.weight(view.chaser_entry(e.p,Vector2.RIGHT,Vector3(77,77,23),Color("777180"),30),0.8))
	parts.boss_core.append(view.chaser_entry(e.p,Vector2.RIGHT,Vector3(44,44,25),boss.INK,48))
