extends RefCounted
## Presentation-only palette and lower structure; never consumes gameplay RNG.
const PAIRS := [
	[Color("528ba2"),Color("925bb0")],
	[Color("527eab"),Color("b48759")],
	[Color("8771aa"),Color("489d92")],
	[Color("799a7a"),Color("6c72b2")]
]

static func palette(game) -> Array:
	var pair: Array = PAIRS[posmod(hash(game.cells) ^ (game.floor_number*7919),PAIRS.size())]
	return [with_lightness(pair[0],0.62),with_lightness(pair[1],0.48)]

static func lightness(color: Color) -> float:
	# Oklab L, from Bjorn Ottosson's public-domain linear-sRGB conversion.
	# https://bottosson.github.io/posts/oklab/
	var c := color.srgb_to_linear()
	var l := pow(0.4122214708*c.r+0.5363325363*c.g+0.0514459929*c.b,1.0/3.0)
	var m := pow(0.2119034982*c.r+0.6806995451*c.g+0.1073969566*c.b,1.0/3.0)
	var v := pow(0.0883024619*c.r+0.2817188376*c.g+0.6299787005*c.b,1.0/3.0)
	return 0.2104542553*l+0.7936177850*m-0.0040720468*v

static func with_lightness(color: Color, target: float) -> Color:
	# Uniform linear scaling preserves Oklab hue; chroma scales with lightness.
	var gain := pow(target/maxf(lightness(color),0.0001),3.0)
	var c := color.srgb_to_linear()
	return Color(c.r*gain,c.g*gain,c.b*gain,color.a).linear_to_srgb()

static func sample_at(seed_value: int, cell: Vector2i, channel: int) -> float:
	# Integer avalanche avoids the straight bands produced by linear modulo patterns.
	var value: int = (cell.x*73856093 ^ cell.y*19349663 ^ seed_value ^ channel*83492791) & 0x7fffffff
	value = ((value ^ (value >> 16))*0x45d9f3b) & 0x7fffffff
	value = ((value ^ (value >> 16))*0x45d9f3b) & 0x7fffffff
	return float(value ^ (value >> 16))/2147483648.0

static func enclosed_solids(cells: Dictionary, solids: Dictionary) -> Array:
	var bounds := Rect2i(cells.keys()[0],Vector2i.ONE)
	for cell in cells: bounds = bounds.expand(cell)
	bounds = bounds.grow(1)
	var visited: Dictionary = {}
	var enclosed: Array = []
	for seed_cell in solids:
		if visited.has(seed_cell): continue
		var region: Array = [seed_cell]
		visited[seed_cell] = true
		var exterior := false
		var cursor := 0
		while cursor < region.size():
			var cell: Vector2i = region[cursor]
			cursor += 1
			for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
				var next: Vector2i = cell+direction
				if not bounds.has_point(next):
					exterior = true
					continue
				if cells.has(next) or visited.has(next): continue
				visited[next] = true
				region.append(next)
		if not exterior: enclosed.append_array(region)
	return enclosed

static func is_room_obstacle(game, cell: Vector2i) -> bool:
	# Corridor loops can enclose empty space; only actual room footprints get caps.
	for i in range(game.rooms.size()):
		var shape: int = game.room_shapes[i] if i < game.room_shapes.size() else 0
		if game.rooms[i].has_point(cell) and game.room_contains(cell,game.rooms[i],shape): return true
	return false

static func build(view, game, solids: Dictionary, colors: Array) -> void:
	var shells: Array = []
	var masks: Array = []
	var cores: Array = []
	var struts: Array = []
	var edges: Dictionary = {}
	var lower: Array = []
	var decor_seed: int = hash(game.cells) ^ (game.floor_number*7919)
	var outer: Color = colors[0]
	var inner: Color = colors[1]
	for cell in enclosed_solids(game.cells,solids):
		if not is_room_obstacle(game,cell): continue
		masks.append(view.entry(game.center(cell),Vector3(32,32,1),Color("080e17"),-0.25))
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
			shells.append(wall_entry(middle-tangent,middle+tangent,depth,translucent(outer if known else outer.darkened(0.48),0.13)))
			if direction.y != 0:
				add_edge(edges,middle-tangent,middle+tangent,-32,-32,translucent(outer if known else outer.darkened(0.48),0.55))
			var core := wall_entry(middle-tangent,middle+tangent,depth-32,translucent(inner if known else inner.darkened(0.5),0.20))
			core.transform.origin.z -= 32
			cores.append(core)
		# Only the playable inner boundary receives a clear line; depth is subdued.
		# Sparse deep supports avoid an equally weighted cube lattice.
		if sample_at(decor_seed,cell,2) < 0.2:
			for corner in [Vector2(-16,-16),Vector2(16,16)]:
				add_edge(edges,point+corner,point+corner,-32,-144,translucent(inner if solids[cell] else inner.darkened(0.5),0.12))
	for cell in game.cells:
		var known: bool = game.cells[cell] == -1 or game.discovered.has(game.cells[cell])
		var ink := inner if known else inner.darkened(0.5)
		var p: Vector2 = game.center(cell)
		# One aligned block per floor cell, no overlapping decks or floating prisms.
		var opacity := lerpf(0.10,0.46,sample_at(decor_seed,cell,1))
		lower.append(view.entry(p,Vector3(31.5,31.5,1),translucent(ink,opacity),-48))
		for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			if game.cells.has(cell+direction): continue
			var middle := p+Vector2(direction)*16
			var tangent := Vector2(-direction.y,direction.x)*16
			var side := wall_entry(middle-tangent,middle+tangent,32,translucent(ink,opacity))
			side.transform.origin.z -= 48
			lower.append(side)
	for edge in edges.values(): struts.append(edge)
	view.upload("wall_mask",masks)
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
