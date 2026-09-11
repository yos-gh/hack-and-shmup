extends RefCounted
## Presentation-only palette and lower structure; never consumes gameplay RNG.
const PAIRS := [
	[Color("51848b"),Color("806388")],
	[Color("57758f"),Color("9b805c")],
	[Color("796788"),Color("538b83")],
	[Color("6f8471"),Color("626e98")]
]

static func palette(game) -> Array:
	return PAIRS[posmod(hash(game.cells) ^ (game.floor_number*7919),PAIRS.size())]

static func build(view, game, solids: Dictionary, colors: Array) -> void:
	var shells: Array = []
	var caps: Array = []
	var cores: Array = []
	var struts: Array = []
	var edges: Dictionary = {}
	var lower: Array = []
	var outer: Color = colors[0]
	var inner: Color = colors[1]
	for cell in solids:
		if not solids[cell]: continue
		var point: Vector2 = game.center(cell)
		# A hollow glass column, with a second colored layer deep inside it.
		var depth := 96.0
		caps.append(view.entry(point,Vector3(32,32,0.1),outer.darkened(0.78),-0.15))
		shells.append(view.entry(point,Vector3(31.5,31.5,depth),translucent(outer,0.13),-depth*0.5))
		cores.append(view.entry(point,Vector3(26,26,depth*0.62),translucent(inner,0.20),-depth*0.63))
		for corner in [Vector2(-16,-16),Vector2(16,-16),Vector2(16,16),Vector2(-16,16)]:
			add_edge(edges,point+corner,point+corner,0,-32,translucent(outer.lightened(0.06),0.70))
			add_edge(edges,point+corner,point+corner,-32,-depth,translucent(outer,0.22))
		for level in [0.0,-32.0,-64.0,-depth]:
			var ink := translucent(outer.lightened(0.18),0.85) if level == 0 else translucent(outer,0.22)
			if level <= -64: ink = translucent(inner,0.27)
			for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
				# The playable boundary already owns these top edges.
				if level == 0 and game.cells.has(cell+direction): continue
				var middle: Vector2 = point+Vector2(direction)*16
				var tangent := Vector2(-direction.y,direction.x)*16
				var edge_ink := translucent(outer.lightened(0.06),0.70) if level == -32 and direction == Vector2i.DOWN else ink
				add_edge(edges,middle-tangent,middle+tangent,level,level,edge_ink)
	for cell in game.cells:
		if game.cells[cell] != -1 and not game.discovered.has(game.cells[cell]): continue
		var p: Vector2 = game.center(cell)
		var panel := Vector2i(floori(cell.x/4.0),floori(cell.y/4.0))
		# Discontinuous suspended decks form broad quiet masses under the glass.
		# Their layout is decorative and cannot reveal another playable room.
		var pattern := posmod(panel.x*13+panel.y*7,5)
		if pattern < 3:
			var depth := 68.0+pattern*24.0
			lower.append(view.entry(p,Vector3(31.5,31.5,22),translucent(inner,0.14),-depth))
			if posmod(cell.x,4) == 0:
				lower.append(view.entry(p+Vector2(-15,0),Vector3(0.65,32,0.5),translucent(outer,0.23),-depth+11))
			if posmod(cell.y,4) == 0:
				lower.append(view.entry(p+Vector2(0,-15),Vector3(32,0.65,0.5),translucent(outer,0.23),-depth+11))
		if posmod(cell.x,4) == 1 or posmod(cell.y,4) == 1:
			var horizontal: bool = posmod(cell.y,4) == 1
			var size := Vector3(32,3,5) if horizontal else Vector3(3,32,5)
			lower.append(view.entry(p,size,translucent(outer,0.18),-46))
	for edge in edges.values(): struts.append(edge)
	view.upload("bg_cap",caps)
	view.upload("bg_shell",shells)
	view.upload("bg_core",cores)
	view.upload("bg_strut",struts)
	view.upload("bg_lower",lower)

static func translucent(color: Color, opacity: float) -> Color:
	return Color(color.r,color.g,color.b,opacity)

static func add_edge(edges: Dictionary, a: Vector2, b: Vector2, za: float, zb: float, color: Color) -> void:
	var start := Vector3(a.x,-a.y,za)
	var end := Vector3(b.x,-b.y,zb)
	if start > end:
		var swap := start
		start = end
		end = swap
	var key := [start,end]
	if not edges.has(key): edges[key] = line_entry(start,end,color)
	elif color.a > edges[key].color.a: edges[key].color = color

static func line_entry(a: Vector3, b: Vector3, color: Color) -> Dictionary:
	var axis := b-a
	var up := Vector3.RIGHT if absf(axis.normalized().dot(Vector3.BACK)) > 0.99 else Vector3.BACK
	var side := up.cross(axis).normalized()
	return {"transform":Transform3D(Basis(axis,side,axis.normalized().cross(side)),(a+b)*0.5),"color":color,"warning":0.0}

static func line_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex in [Vector3(-0.5,-1,0),Vector3(0.5,-1,0),Vector3(0.5,1,0),Vector3(-0.5,-1,0),Vector3(0.5,1,0),Vector3(-0.5,1,0)]:
		surface.add_vertex(vertex)
	return surface.commit()
