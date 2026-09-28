extends RefCounted
## Deterministic wire fragments: decorative snapshots, no simulation RNG or actors.
const RAYS := 48

static func prepare(game, pulse: Dictionary) -> void:
	var reach := PackedFloat32Array()
	for i in range(RAYS):
		var tip: Vector2 = game.attack_end(pulse.p,Vector2.from_angle(i*TAU/RAYS),pulse.radius)
		reach.append(maxf(0,pulse.p.distance_to(tip)-14))
	pulse["reach"] = reach

static func draw(game, pulse: Dictionary) -> void:
	var age: float = pulse.duration-pulse.life
	var origin: Vector2 = pulse.p
	var color: Color = pulse.color
	var reach: PackedFloat32Array = pulse.reach
	# Two offset polygon waves break into short edges rather than solid discs.
	for wave in range(2):
		var phase := clampf((age-wave*0.13)/0.78,0,1)
		if phase <= 0 or phase >= 1: continue
		var expansion := 1-pow(1-phase,3)
		var ink := Color(color.lerp(Color.WHITE,0.35),(1-phase)*0.8)
		for i in range(RAYS):
			if (i+wave)%4 == 3: continue
			var next := (i+1)%RAYS
			var a := origin+Vector2.from_angle(i*TAU/RAYS)*minf(reach[i],pulse.radius*expansion)
			var b := origin+Vector2.from_angle(next*TAU/RAYS)*minf(reach[next],pulse.radius*expansion)
			game.draw_line(a,b,Color(ink,ink.a*0.13),7,true)
			game.draw_line(a,b,ink,1.6,true)
	# Unequal triangular shards and open struts suggest a disintegrating cage.
	for i in range(24):
		var phase := clampf((age-0.025*(i%4))/ (0.95+0.09*(i%4)),0,1)
		if phase <= 0 or phase >= 1: continue
		var axis := Vector2.from_angle(i*TAU/24)
		var travel := (24+(150+float((i*37)%90))*(1-pow(1-phase,2)))
		var center := origin+axis*minf(reach[i*2],travel)
		var spin := i*1.71+phase*(2.4 if i%2 == 0 else -3.1)
		var size := (7+float((i*7)%13))*(1-phase*0.6)
		var edge := Vector2.from_angle(spin)*size
		var side := edge.orthogonal()*0.48
		var ink := Color(color.lerp(Color.WHITE,0.25),pow(1-phase,1.3)*0.95)
		var points := PackedVector2Array([center+edge,center-edge*0.7+side,center-edge*0.45-side])
		if i%3 != 0: points.append(points[0])
		game.draw_polyline(points,ink,1.7,true)
		game.draw_line(center-axis*minf(22,travel*0.15),center,Color(ink,ink.a*0.25),1,true)
	# A single local flash decays quickly; no full-screen strobe or control pause.
	var flash := maxf(0,1-age/0.24)
	if flash > 0:
		var radius := 16+56*(1-flash)
		var diamond := PackedVector2Array([origin+Vector2.UP*radius,origin+Vector2.RIGHT*radius,origin+Vector2.DOWN*radius,origin+Vector2.LEFT*radius,origin+Vector2.UP*radius])
		game.draw_colored_polygon(diamond,Color(color,flash*0.16))
		game.draw_polyline(diamond,Color(Color.WHITE,flash),2.5,true)
		for i in range(8):
			var axis := Vector2.from_angle(i*TAU/8)
			var tip := origin+axis*minf(reach[i*6],radius*(2.1 if i%2 == 0 else 1.2))
			game.draw_line(origin+axis*6,tip,Color(Color.WHITE,flash*flash),2,true)
