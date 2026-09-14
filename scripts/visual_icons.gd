extends RefCounted
const WEAPONS = ["scatter","shock","lance"]
const UPGRADES = ["damage","rate","move","hybrid"]
static func draw_wordmark(canvas: CanvasItem, center: Vector2, width: float) -> void:
	var glyphs := {
		"H":[[Vector2(0,0),Vector2(0,1)],[Vector2(1,0),Vector2(1,1)],[Vector2(0,0.5),Vector2(1,0.5)]],
		"A":[[Vector2(0,1),Vector2(0,0.2),Vector2(0.2,0),Vector2(0.8,0),Vector2(1,0.2),Vector2(1,1)],[Vector2(0,0.55),Vector2(1,0.55)]],
		"C":[[Vector2(1,0),Vector2(0.2,0),Vector2(0,0.2),Vector2(0,0.8),Vector2(0.2,1),Vector2(1,1)]],
		"K":[[Vector2(0,0),Vector2(0,1)],[Vector2(1,0),Vector2(0.2,0.5),Vector2(1,1)]],
		"/":[[Vector2(0,1),Vector2(1,0)]],
		"S":[[Vector2(1,0),Vector2(0.2,0),Vector2(0,0.2),Vector2(0,0.5),Vector2(1,0.5),Vector2(1,0.8),Vector2(0.8,1),Vector2(0,1)]],
		"M":[[Vector2(0,1),Vector2(0,0),Vector2(0.5,0.45),Vector2(1,0),Vector2(1,1)]],
		"U":[[Vector2(0,0),Vector2(0,0.8),Vector2(0.2,1),Vector2(0.8,1),Vector2(1,0.8),Vector2(1,0)]],
		"P":[[Vector2(0,1),Vector2(0,0),Vector2(0.8,0),Vector2(1,0.2),Vector2(1,0.5),Vector2(0,0.5)]]}
	var unit := width/14.2
	var index := 0
	for letter in "HACK/SHMUP":
		for stroke in glyphs[letter]:
			var points := PackedVector2Array()
			for p in stroke: points.append(center+Vector2(-width*0.5+index*unit*1.45+p.x*unit,(p.y-0.5)*unit*1.6))
			canvas.draw_polyline(points,Color(0.22,0.8,0.68,0.12),7,true)
			canvas.draw_polyline(points,Color("b7ffe9") if letter!="/" else Color("63f5ce"),2.4,true)
		index += 1
static func draw_icon(canvas: CanvasItem, kind: String, center: Vector2, radius: float, ink: Color) -> void:
	var paths: Array = []
	match kind:
		"scatter": paths = [[Vector2(-1,0),Vector2(1,-0.65)],[Vector2(-1,0),Vector2(1,0)],[Vector2(-1,0),Vector2(1,0.65)]]
		"shock":
			canvas.draw_arc(center,radius,0,TAU,32,ink,1.5,true)
			canvas.draw_arc(center,radius*0.55,PI*0.1,PI*1.6,24,ink,1.5,true)
			canvas.draw_circle(center,radius*0.15,ink)
		"lance": paths = [[Vector2(-1,0),Vector2(1,0)],[Vector2(0.35,-0.45),Vector2(1,0),Vector2(0.35,0.45)]]
		"descend": paths = [[Vector2(-0.65,-0.8),Vector2(0, -0.2),Vector2(0.65,-0.8)],[Vector2(-0.65,0),Vector2(0,0.6),Vector2(0.65,0)],[Vector2(-0.75,1),Vector2(0.75,1)]]
		"damage": paths = [[Vector2(-0.65,0.8),Vector2(-0.65,-0.35),Vector2(0,-1),Vector2(0.65,-0.35),Vector2(0.65,0.8),Vector2(-0.65,0.8)],[Vector2(-0.65,0.3),Vector2(0.65,0.3)]]
		"rate": paths = [[Vector2(-0.75,-0.8),Vector2(-0.15,0),Vector2(-0.75,0.8)],[Vector2(0.1,-0.8),Vector2(0.7,0),Vector2(0.1,0.8)]]
		"move": paths = [[Vector2(-0.9,0.65),Vector2(-0.1,-0.65),Vector2(0.5,-0.65),Vector2(0.1,0.2),Vector2(0.9,0.2)],[Vector2(-0.8,0.9),Vector2(0.7,0.9)]]
		"hybrid": paths = [[Vector2(0,-1),Vector2(0.8,0),Vector2(0,1),Vector2(-0.8,0),Vector2(0,-1)],[Vector2(-0.4,0),Vector2(0.4,0)],[Vector2(0,-0.4),Vector2(0,0.4)]]
		"mouse": paths = [[Vector2(-0.55,0.8),Vector2(-0.55,-0.6),Vector2(0,-0.9),Vector2(0.55,-0.6),Vector2(0.55,0.8),Vector2(-0.55,0.8)],[Vector2(0,-0.8),Vector2(0,-0.15)]]
		"keys": paths = [[Vector2(-1,0.8),Vector2(-1,0),Vector2(-0.35,0),Vector2(-0.35,-0.8),Vector2(0.35,-0.8),Vector2(0.35,0),Vector2(1,0),Vector2(1,0.8),Vector2(-1,0.8)]]
	for path in paths:
		var points := PackedVector2Array()
		for p in path: points.append(center+p*radius)
		canvas.draw_polyline(points,ink,1.6,true)
