extends RefCounted
## Closed, faceted glyph solids. Local +X is forward; +Z is thickness.
## Face tint suggests colored glass without transparency sorting in crowds.

static func face(s: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, tint: Color) -> void:
	var normal := (b-a).cross(c-a).normalized()
	for p in [a,c,b]:
		s.set_normal(normal)
		s.set_color(tint)
		s.add_vertex(p)

static func quad(s: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, tint: Color) -> void:
	face(s,a,b,c,tint)
	face(s,a,c,d,tint)

static func prism(s: SurfaceTool, outline: Array[Vector2], slope: float = 0.0) -> void:
	var center := Vector2.ZERO
	for p in outline: center += p
	center /= outline.size()
	for i in range(outline.size()):
		var a := outline[i]
		var b := outline[(i+1)%outline.size()]
		var inset_a := center+(a-center)*0.83
		var inset_b := center+(b-center)*0.83
		var la := Vector3(a.x,a.y,0)
		var lb := Vector3(b.x,b.y,0)
		var ma := Vector3(a.x,a.y,0.65+slope*a.x)
		var mb := Vector3(b.x,b.y,0.65+slope*b.x)
		var ta := Vector3(inset_a.x,inset_a.y,1+slope*inset_a.x)
		var tb := Vector3(inset_b.x,inset_b.y,1+slope*inset_b.x)
		face(s,Vector3(center.x,center.y,1+slope*center.x),ta,tb,Color(0.82,0.86,0.91))
		quad(s,ma,mb,tb,ta,Color.WHITE)
		quad(s,la,lb,mb,ma,Color(0.35,0.48,0.58))
		face(s,Vector3(center.x,center.y,0),lb,la,Color(0.25,0.32,0.4))

static func plate(outline: Array[Vector2], slope: float = 0.0) -> ArrayMesh:
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	prism(s,outline,slope)
	return s.commit()

static func chevron() -> ArrayMesh:
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Two independent wings leave a real center slit, including in side views.
	prism(s,[Vector2(1,0.12),Vector2(-0.18,1),Vector2(-0.9,0.8),Vector2(0.18,0.12)],0.15)
	prism(s,[Vector2(0.18,-0.12),Vector2(-0.9,-0.8),Vector2(-0.18,-1),Vector2(1,-0.12)],0.15)
	return s.commit()

static func annulus(inner: float, segments: int = 48, torus_axes: bool = false) -> ArrayMesh:
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bevel := minf(0.065,(1-inner)*0.22)
	# Closed cross section: lower face, outer wall, bevel, face, inner bevel/wall.
	var section := [Vector2(inner,0),Vector2(1,0),Vector2(1,0.55),Vector2(1-bevel,1),Vector2(inner+bevel,1),Vector2(inner,0.55)]
	for i in range(segments):
		var a := Vector2.from_angle(TAU*i/segments)
		var b := Vector2.from_angle(TAU*(i+1)/segments)
		for j in range(section.size()):
			var p: Vector2 = section[j]
			var q: Vector2 = section[(j+1)%section.size()]
			var tint := Color(0.82,0.86,0.91) if j == 3 else Color.WHITE
			if j in [0,1,5]: tint = Color(0.35,0.48,0.58)
			var points: Array[Vector3] = [Vector3(a.x*p.x,a.y*p.x,p.y),Vector3(b.x*p.x,b.y*p.x,p.y),Vector3(b.x*q.x,b.y*q.x,q.y),Vector3(a.x*q.x,a.y*q.x,q.y)]
			if torus_axes:
				for k in range(4): points[k] = Basis(Vector3.RIGHT,-PI/2)*points[k]
			quad(s,points[0],points[1],points[2],points[3],tint)
	return s.commit()

static func boss_core() -> ArrayMesh:
	# A recessed octagonal seat and raised crystal share one static mesh.
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outline: Array[Vector2] = [Vector2(1,0.65),Vector2(0.65,1),Vector2(-0.65,1),Vector2(-1,0.65),Vector2(-1,-0.65),Vector2(-0.65,-1),Vector2(0.65,-1),Vector2(1,-0.65)]
	for i in range(outline.size()):
		var a := outline[i]
		var b := outline[(i+1)%outline.size()]
		var lower_a := Vector3(a.x,a.y,0)
		var lower_b := Vector3(b.x,b.y,0)
		var rim_a := Vector3(a.x,a.y,0.35)
		var rim_b := Vector3(b.x,b.y,0.35)
		var top_a := Vector3(a.x*0.65,a.y*0.65,1)
		var top_b := Vector3(b.x*0.65,b.y*0.65,1)
		quad(s,lower_a,lower_b,rim_b,rim_a,Color(0.25,0.36,0.43))
		quad(s,rim_a,rim_b,top_b,top_a,Color(0.65,0.76,0.82) if i%2 == 0 else Color.WHITE)
		face(s,Vector3(0,0,1),top_a,top_b,Color(0.9,0.94,1))
		face(s,Vector3.ZERO,lower_b,lower_a,Color(0.25,0.32,0.4))
	return s.commit()
