extends RefCounted
## Six glass-and-wire emitter vanes with stepped frames and circuit buses.
const Glyph = preload("res://scripts/glyph_meshes.gd")
const WING_SHAPE := [Vector2(120,-19),Vector2(148,-32),Vector2(180,-32),Vector2(202,-54),Vector2(275,-54),Vector2(306,-23),Vector2(306,8),Vector2(272,8),Vector2(247,30),Vector2(200,30),Vector2(180,42),Vector2(148,24),Vector2(120,19)]
const ARMOR_PANELS := [
	[Vector2(157,-21),Vector2(185,-21),Vector2(210,-44),Vector2(233,-44),Vector2(233,20),Vector2(197,20),Vector2(178,31),Vector2(157,15)],
	[Vector2(243,-44),Vector2(271,-44),Vector2(295,-20),Vector2(295,-3),Vector2(268,-3),Vector2(243,19)]]
const STEEL := Color("8197b1")

static func local_points(e: Dictionary, points: Array, angle: float, mirror: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in points: result.append(e.p+Vector2(p.x,p.y*mirror).rotated(angle))
	return result

static func wing_mesh(mirrored: bool) -> ArrayMesh:
	var outline: Array[Vector2] = []
	# World +Y points down; the 3D stage uses +Y up. Preserve the same hull
	# for the solid mesh, the 2D panel overlay and player contact collision.
	for p in WING_SHAPE: outline.append(Vector2(p.x,p.y if mirrored else -p.y))
	if not mirrored: outline.reverse()
	var surface := SurfaceTool.new()
	surface.append_from(Glyph.plate(outline),0,Transform3D.IDENTITY)
	for panel in ARMOR_PANELS:
		var plate: Array[Vector2] = []
		for p in panel: plate.append(Vector2(p.x,p.y if mirrored else -p.y))
		if not mirrored: plate.reverse()
		surface.append_from(Glyph.plate(plate),0,Transform3D(Basis.from_scale(Vector3(1,1,0.22)),Vector3(0,0,0.9)))
	return surface.commit()

static func draw(boss, game) -> void:
	for e in game.enemies:
		if not e.has("pattern_time") or e.hp <= 0 or not game.attack_open(e.p): continue
		var ink: Color = boss.INK
		var rage: bool = e.hp <= e.max_hp*0.5
		# Light glass faces retain the contact silhouette without a solid disk.
		if not game.depth_enabled:
			game.draw_circle(e.p,boss.BODY_RADIUS,Color("202239",0.28))
		for i in range(6):
			var polygon: PackedVector2Array = boss.wing_polygon(e,i)
			if not game.depth_enabled: game.draw_colored_polygon(polygon,Color("273347",0.26))
			polygon.append(polygon[0])
			game.draw_polyline(polygon,Color(STEEL,0.85),2,true)
			var angle: float = boss.wing_angle(e,i)
			var mirror: float = 1.0 if i%2 == 0 else -1.0
			var color: Color = boss.BLUE if i%2 == 0 else boss.ROSE
			for panel in ARMOR_PANELS:
				var plate := local_points(e,panel,angle,mirror)
				if not game.depth_enabled: game.draw_colored_polygon(plate,Color("46576d",0.18))
				plate.append(plate[0])
				game.draw_polyline(plate,Color(STEEL,0.5),1.4,true)
			var bus := local_points(e,[Vector2(126,0),Vector2(176,0),Vector2(176,-12),Vector2(220,-12),Vector2(220,-18),Vector2(268,-18)],angle,mirror)
			game.draw_polyline(bus,Color("0d1725",0.5),5,true)
			game.draw_polyline(bus,Color(color,0.82),2,true)
			# Parallel slots and short status bars read as machined surfaces.
			for slot in range(4):
				var vent := local_points(e,[Vector2(192+slot*8,5),Vector2(192+slot*8,16)],angle,mirror)
				game.draw_line(vent[0],vent[1],Color(STEEL,0.4),1,true)
			var hinge := local_points(e,[Vector2(140,-13),Vector2(157,-13),Vector2(157,13),Vector2(140,13)],angle,mirror)
			game.draw_colored_polygon(hinge,Color("172333"))
			hinge.append(hinge[0])
			game.draw_polyline(hinge,STEEL,1.5,true)
			var mouth: Vector2 = boss.mouth_position(e,i)
			var direction: Vector2 = boss.stream_heading(e,i)
			var flash: float = e.mouth_flash[i]/0.16
			var receiver := PackedVector2Array()
			for p in [Vector2(-20,-13),Vector2(-12,-21),Vector2(20,-21),Vector2(20,21),Vector2(-12,21),Vector2(-20,13)]: receiver.append(mouth+p.rotated(direction.angle()))
			game.draw_colored_polygon(receiver,Color("101b2b",0.55))
			receiver.append(receiver[0])
			game.draw_polyline(receiver,color,2,true)
			for side in [-1,1]:
				game.draw_line(mouth+direction*5+direction.orthogonal()*side*12,mouth+direction*26+direction.orthogonal()*side*12,STEEL,3,true)
			game.draw_line(mouth-direction*7,mouth+direction*(15+flash*6),color.lerp(Color.WHITE,flash*0.6),5,true)
			var root: Vector2 = boss.root_position(e,i)
			var socket := PackedVector2Array([root+Vector2(-10,-7).rotated(angle),root+Vector2(10,-7).rotated(angle),root+Vector2(10,7).rotated(angle),root+Vector2(-10,7).rotated(angle)])
			game.draw_colored_polygon(socket,Color("151c2a"))
			socket.append(socket[0])
			game.draw_polyline(socket,ink,1.5,true)
			game.draw_line(root-Vector2.from_angle(angle)*5,root+Vector2.from_angle(angle)*5,Color(ink,0.7),3+e.root_flash*7,true)
			# A separate, angular red port makes the aimed needle source explicit.
			var needle: Vector2 = boss.needle_position(e,i)
			var needle_dir := Vector2.from_angle(angle)
			var mount: Vector2 = e.p+Vector2(230,20*mirror).rotated(angle)
			game.draw_line(mount,needle,STEEL,5,true)
			var housing := PackedVector2Array()
			for p in [Vector2(-14,-10),Vector2(14,-10),Vector2(14,10),Vector2(-14,10)]: housing.append(needle+p.rotated(angle))
			game.draw_colored_polygon(housing,Color("182232"))
			housing.append(housing[0])
			game.draw_polyline(housing,STEEL,1.5,true)
			var charging := false
			for volley in e.needle_volleys:
				if volley.gun != i: continue
				needle_dir = volley.heading
				charging = true
				if volley.fired == 0:
					var progress: float = 1.0-clampf(volley.timer/volley.warning,0,1)
					game.draw_arc(needle,19-progress*7,0,TAU,16,Color("ff788e"),1.5,true)
					var end: Vector2 = game.attack_end(needle,needle_dir,330)
					game.draw_line(needle,end,Color(1,0.47,0.56,0.10+progress*0.12),1.5,true)
			var tip: Vector2 = needle+needle_dir*13
			var side: Vector2 = needle_dir.orthogonal()*6
			game.draw_colored_polygon(PackedVector2Array([tip,needle-needle_dir*10+side,needle-needle_dir*5,needle-needle_dir*10-side]),Color("ff788e") if charging else Color("804a60"))
		# The carapace edge is a real contact boundary, independent of core damage.
		game.draw_arc(e.p,boss.BODY_RADIUS,0,TAU,72,Color(ink,0.45),2,true)
		if not game.depth_enabled:
			game.draw_circle(e.p,73,Color("161e2b"))
			game.draw_circle(e.p,43,ink.darkened(0.25))
			game.draw_circle(e.p,23,Color("fff6e7"))
		for i in range(boss.COUNT):
			var plate: Dictionary = e.plates[i]
			var a: float = (i-0.46)*TAU/boss.COUNT
			var b: float = (i+0.46)*TAU/boss.COUNT
			if plate.hp > 0:
				var panel := PackedVector2Array([e.p+Vector2.from_angle(a)*108,e.p+Vector2.from_angle(b)*108,e.p+Vector2.from_angle(b)*84,e.p+Vector2.from_angle(a)*84])
				game.draw_colored_polygon(panel,Color("4c4249").lerp(ink.darkened(0.3),1-plate.hp/plate.max_hp))
				panel.append(panel[0])
				game.draw_polyline(panel,ink,2,true)
			else: game.draw_arc(e.p,boss.RADIUS,a,b,8,Color(ink,0.2),2,true)
		for beam in game.boss.lasers:
			if beam.owner != e or not beam.get("seraph",false): continue
			var mouth: Vector2 = e.p+beam.heading*82
			var power: float = 1.0 if beam.warning <= 0 else 1.0-beam.warning/boss.LASER_WARNING
			game.draw_circle(mouth,18+power*13,Color(ink,0.12+power*0.2))
			game.draw_arc(mouth,20,-PI,PI,32,Color(ink,0.7),2,true)
			if beam.warning <= 0: game.draw_line(mouth-beam.heading.orthogonal()*20,mouth+beam.heading.orthogonal()*20,Color("fff5e7"),4,true)
		for strike in e.evictions:
			if strike.timer > 0:
				game.draw_circle(strike.p,boss.EVICTION_RADIUS,Color(boss.ROSE,0.07))
				game.draw_arc(strike.p,boss.EVICTION_RADIUS,0,TAU,40,Color(boss.ROSE,0.6),2,true)
				var progress: float = clampf(1.0-strike.timer/1.5,0,1)
				var mote: Vector2 = strike.origin.lerp(strike.p,progress)+Vector2(0,-180*sin(progress*PI))
				game.draw_circle(mote,5,Color("fff3dc"))
				game.draw_circle(mote,10,Color(boss.ROSE,0.15))
			else:
				game.draw_circle(strike.p,boss.EVICTION_RADIUS,Color(boss.ROSE,0.25))
				game.draw_arc(strike.p,boss.EVICTION_RADIUS*(1.0-strike.timer),0,TAU,40,Color("ffe4dc"),4,true)
		if rage: game.draw_arc(e.p,66,e.age,e.age+PI*1.7,40,Color(boss.ROSE,0.8),2,true)

static func draw_depth(boss, view, _game, e: Dictionary, parts: Dictionary) -> void:
	parts.seraph_body.append(view.chaser_entry(e.p,Vector2.RIGHT,Vector3(boss.BODY_RADIUS,boss.BODY_RADIUS,26),Color("37465d"),12))
	for i in range(6):
		var angle: float = boss.wing_angle(e,i)
		var key: String = "seraph_wing_a" if i%2 == 0 else "seraph_wing_b"
		parts[key].append(view.chaser_entry(e.p,Vector2.from_angle(angle),Vector3(1,1,22),Color("5c718a"),20))
		var mouth: Vector2 = boss.mouth_position(e,i)
		var color: Color = boss.BLUE if i%2 == 0 else boss.ROSE
		parts.boss_armor.append(view.chaser_entry(mouth,boss.stream_heading(e,i),Vector3(24,22,11),color.darkened(0.35),35))
		var root: Vector2 = boss.root_position(e,i)
		parts.boss_core.append(view.chaser_entry(root,Vector2.from_angle(angle),Vector3(11,11,8),boss.INK,31))
	parts.boss_base.append(view.chaser_entry(e.p,Vector2.RIGHT,Vector3(77,77,23),Color("777180"),30))
	parts.boss_core.append(view.chaser_entry(e.p,Vector2.RIGHT,Vector3(44,44,25),boss.INK,48))
