extends RefCounted
## Cached floor silhouette with a continuous player position.
var cached_cells: Dictionary = {}
var bounds := Rect2i()
var texture: ImageTexture
var discovery_hash := -1
var active_room := -2

func prepare(game) -> void:
	var changed := not is_same(cached_cells,game.cells)
	if changed:
		cached_cells = game.cells
		bounds = Rect2i(game.cells.keys()[0],Vector2i.ONE)
		for cell in game.cells: bounds = bounds.merge(Rect2i(cell,Vector2i.ONE))
	var room: int = game.cells.get(game.tile(game.player),-1)
	var discovered: int = game.discovered.hash()
	if not changed and room == active_room and discovered == discovery_hash: return
	active_room = room
	discovery_hash = discovered
	var pixels := Image.create(bounds.size.x*3,bounds.size.y*3,false,Image.FORMAT_RGBA8)
	pixels.fill(Color.TRANSPARENT)
	for cell in game.cells:
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
	game.draw_rect(panel,Color("101c28"))
	game.draw_line(panel.position,panel.position+Vector2(panel.size.x,0),Color("3a5968"),1)
	game.hud.label_at(game,panel.position+Vector2(7,12),"PASSAGE" if active_room < 0 else "ROOM %02d" % (active_room+1),10,Color("a9c3ce"))
	var rect := projection(panel)
	game.draw_texture_rect(texture,rect,false)
	if game.stairs_unlocked:
		var goal := locate(game,game.stairs,rect)
		game.draw_circle(goal,4,Color("101c28"))
		preload("res://scripts/visual_icons.gd").draw_icon(game,"descend",goal,3,Color("ffb95e"))
	var player := locate(game,game.player,rect)
	game.draw_circle(player,4.5,Color("090f18"))
	game.draw_arc(player,4,0,TAU,20,Color("63f5ce"),1.3,true)
	game.draw_circle(player,2,Color.WHITE)
