extends RefCounted
## Cached floor silhouette with a continuous player position.
var cached_cells: Dictionary = {}
var bounds := Rect2i()
var texture: ImageTexture
var discovery_hash := -1
var active_room := -2
var explored: Dictionary = {}
var observed_cells: Dictionary = {}
var last_tile := Vector2i(2147483647,2147483647)
var exploration_version := 0
var rendered_version := -1
var overview := PackedVector2Array()

func reset(game) -> void:
	explored.clear()
	observed_cells = game.cells
	last_tile = Vector2i(2147483647,2147483647)
	exploration_version += 1
	observe(game)

func observe(game) -> void:
	if not is_same(observed_cells,game.cells):
		reset(game)
		return
	var tile: Vector2i = game.tile(game.player)
	if tile == last_tile: return
	last_tile = tile
	var room: int = game.cells.get(tile,-2)
	var seen := {tile:0}
	var queue: Array[Vector2i] = [tile]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if game.cells.get(cell,-2) == -1 and not explored.has(cell):
			explored[cell] = true
			exploration_version += 1
		if seen[cell] >= 2: continue
		for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i = cell+d
			var id: int = game.cells.get(next,-2)
			if seen.has(next) or (id != -1 and id != room): continue
			seen[next] = seen[cell]+1
			queue.append(next)

func detailed(game, cell: Vector2i) -> bool:
	var id: int = game.cells.get(cell,-2)
	return explored.has(cell) if id == -1 else id >= 0 and game.discovered.has(id)

func prepare(game) -> void:
	var changed := not is_same(cached_cells,game.cells)
	if changed:
		cached_cells = game.cells
		bounds = Rect2i(game.cells.keys()[0],Vector2i.ONE)
		for cell in game.cells: bounds = bounds.merge(Rect2i(cell,Vector2i.ONE))
		# Only a coarse envelope: no room boundaries, obstacles or connections.
		var points := PackedVector2Array()
		for room_rect in game.rooms:
			var center: Vector2 = Vector2(room_rect.get_center()).snapped(Vector2(12,12))
			for corner in [Vector2(-6,-6),Vector2(6,-6),Vector2(6,6),Vector2(-6,6)]:
				points.append((center+corner).clamp(Vector2(bounds.position),Vector2(bounds.end)))
		overview = Geometry2D.convex_hull(points)
	var room: int = game.cells.get(game.tile(game.player),-1)
	var discovered: int = game.discovered.hash()
	if not changed and room == active_room and discovered == discovery_hash and rendered_version == exploration_version: return
	active_room = room
	discovery_hash = discovered
	rendered_version = exploration_version
	var pixels := Image.create(bounds.size.x*3,bounds.size.y*3,false,Image.FORMAT_RGBA8)
	pixels.fill(Color.TRANSPARENT)
	for cell in game.cells:
		if not detailed(game,cell): continue
		var id: int = game.cells[cell]
		var ink := Color("718c9d") if id == -1 else Color("334351")
		if id >= 0 and game.discovered.has(id): ink = Color("637d91")
		if id >= 0 and id == active_room: ink = Color("279b91")
		var rect := Rect2i((cell-bounds.position)*3,Vector2i(3,3))
		pixels.fill_rect(rect,ink)
		if id >= 0 and id == active_room:
			for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				if game.cells.get(cell+d,-2) == id: continue
				var edge := rect
				if d.x != 0:
					edge.size.x = 1
					if d.x > 0: edge.position.x += 2
				else:
					edge.size.y = 1
					if d.y > 0: edge.position.y += 2
				pixels.fill_rect(edge,Color("70dfca"))
	texture = ImageTexture.create_from_image(pixels)

func projection(panel: Rect2) -> Rect2:
	var area := Rect2(panel.position+Vector2(8,18),panel.size-Vector2(16,24))
	var scale: float = minf(area.size.x/bounds.size.x,area.size.y/bounds.size.y)
	var size := Vector2(bounds.size)*scale
	return Rect2(area.get_center()-size*0.5,size)

func locate(game, point: Vector2, rect: Rect2) -> Vector2:
	return rect.position+(point/game.TILE-Vector2(bounds.position))*rect.size/Vector2(bounds.size)

func draw(game, panel: Rect2) -> void:
	prepare(game)
	var Hud = game.hud
	var plate: PackedVector2Array = Hud.chamfer(panel,10)
	game.draw_colored_polygon(plate,Color(0.03,0.07,0.1,0.82))
	game.draw_polyline(Hud.closed(plate),Color(0.3,0.62,0.66,0.45),1,true)
	# Corner brackets frame the scanner.
	var ink := Color(0.39,0.96,0.81,0.8)
	for corner in [[Vector2(panel.end.x,panel.position.y),Vector2(-1,1)],[Vector2(panel.position.x,panel.end.y),Vector2(1,-1)]]:
		var at: Vector2 = corner[0]
		var sign_value: Vector2 = corner[1]
		game.draw_line(at,at+Vector2(sign_value.x*14,0),ink,2)
		game.draw_line(at,at+Vector2(0,sign_value.y*14),ink,2)
	var sweep: float = fmod(game.presentation.clock*0.6,1.0)
	game.draw_line(Vector2(panel.position.x+6,panel.position.y+18+sweep*(panel.size.y-24)),Vector2(panel.end.x-6,panel.position.y+18+sweep*(panel.size.y-24)),Color(0.39,0.96,0.81,0.12),2)
	game.hud.label_at(game,panel.position+Vector2(12,13),"PASSAGE" if active_room < 0 else "ROOM %02d" % (active_room+1),10,Color("bfe8e4"))
	var rect := projection(panel)
	var envelope := PackedVector2Array()
	for p in overview: envelope.append(rect.position+(p-Vector2(bounds.position))*rect.size/Vector2(bounds.size))
	if envelope.size()>=3: game.draw_colored_polygon(envelope,Color("1d2b3759"))
	game.draw_texture_rect(texture,rect,false)
	var goal := locate(game,game.stairs,rect)
	game.draw_circle(goal,4,Color("101c28"))
	preload("res://scripts/visual_icons.gd").draw_icon(game,"descend",goal,3,Color("ffb95e") if game.stairs_unlocked else Color("8b7965"))
	var player := locate(game,game.player,rect)
	game.world_view.glow(game,player,12,Color(0.39,0.96,0.81,0.5))
	game.draw_circle(player,4.5,Color("090f18"))
	game.draw_arc(player,4,0,TAU,20,Color("63f5ce"),1.3,true)
	game.draw_circle(player,2,Color.WHITE)
