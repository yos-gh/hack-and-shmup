extends RefCounted
## Presentation-only palette and lower structure; never consumes gameplay RNG.
const PAIRS := [
	[Color("528ba2"),Color("925bb0")],
	[Color("527eab"),Color("b48759")],
	[Color("8771aa"),Color("489d92")],
	[Color("799a7a"),Color("6c72b2")]
]

static func palette(game) -> Array:
	return PAIRS[posmod(hash(game.cells) ^ (game.floor_number*7919),PAIRS.size())]

static func build(view, game, solids: Dictionary, colors: Array) -> void:
	var shells: Array = []
	var cores: Array = []
	var struts: Array = []
	var edges: Dictionary = {}
	var lower: Array = []
	var outer: Color = colors[0]
	var inner: Color = colors[1]
	for cell in solids:
		var point: Vector2 = game.center(cell)
		# The contour carries open glass curtains with a second color at depth.
		var depth := 96.0
		# Open curtains descend from the playable contour: no roof or outer box.
		for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var neighbor: Vector2i = cell+direction
			if not game.cells.has(neighbor): continue
			var known: bool = game.cells[neighbor] == -1 or game.discovered.has(game.cells[neighbor])
			var middle := point+Vector2(direction)*16
			var tangent := Vector2(-direction.y,direction.x)*16
			shells.append(wall_entry(middle-tangent,middle+tangent,depth,translucent(outer,0.13) if known else Color(0.24,0.34,0.44,0.09)))
			if not known: continue
			var core := wall_entry(middle-tangent,middle+tangent,depth-32,translucent(inner,0.20))
			core.transform.origin.z -= 32
			cores.append(core)
		if not solids[cell]: continue
		# Only the playable inner boundary receives a clear line; depth is subdued.
		# Sparse deep supports avoid an equally weighted cube lattice.
		if posmod(cell.x*7+cell.y*11,5) == 0:
			for corner in [Vector2(-16,-16),Vector2(16,16)]:
				add_edge(edges,point+corner,point+corner,-32,-144,translucent(inner,0.12))
	for cell in game.cells:
		if game.cells[cell] != -1 and not game.discovered.has(game.cells[cell]): continue
		var p: Vector2 = game.center(cell)
		# World-fixed decorative masses, unrelated to hidden room contents.
		var panel := Vector2i(floori(cell.x/3.0),floori(cell.y/3.0))
		var pattern := posmod(panel.x*13+panel.y*7,7)
		if pattern < 4:
			var depth := 64.0+pattern*24.0
			lower.append(view.entry(p,Vector3(32,32,1),translucent(inner,0.30),-depth+22))
			for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
				var neighbor: Vector2i = cell+direction
				var other_panel := Vector2i(floori(neighbor.x/3.0),floori(neighbor.y/3.0))
				var same_deck := posmod(other_panel.x*13+other_panel.y*7,7) == pattern
				if game.cells.has(neighbor) and (game.cells[neighbor] == -1 or game.discovered.has(game.cells[neighbor])) and same_deck: continue
				var middle := p+Vector2(direction)*16
				var tangent := Vector2(-direction.y,direction.x)*16
				var side := wall_entry(middle-tangent,middle+tangent,44,translucent(inner,0.30))
				side.transform.origin.z -= depth-22
				lower.append(side)
		# Occasional tall, inset prisms provide a different spatial scale.
		if posmod(cell.x*17+cell.y*31,19) == 0:
			lower.append(view.entry(p,Vector3(23,23,1),translucent(inner,0.33),-52))
			for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
				var middle := p+Vector2(direction)*11.5
				var tangent := Vector2(-direction.y,direction.x)*11.5
				var side := wall_entry(middle-tangent,middle+tangent,96,translucent(inner,0.33))
				side.transform.origin.z -= 52
				lower.append(side)
	for edge in edges.values(): struts.append(edge)
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

static func wall_entry(a: Vector2, b: Vector2, depth: float, color: Color) -> Dictionary:
	var start := Vector3(a.x,-a.y,0)
	var end := Vector3(b.x,-b.y,0)
	var along := end-start
	var down := Vector3(0,0,-depth)
	return {"transform":Transform3D(Basis(along,down,along.cross(down).normalized()),(start+end+down)*0.5),"color":color,"warning":0.0}

static func wall_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in [Vector3(-0.5,-0.5,0),Vector3(0.5,0.5,0),Vector3(0.5,-0.5,0),Vector3(-0.5,-0.5,0),Vector3(-0.5,0.5,0),Vector3(0.5,0.5,0)]:
		surface.set_normal(Vector3.BACK)
		surface.add_vertex(p)
	return surface.commit()
