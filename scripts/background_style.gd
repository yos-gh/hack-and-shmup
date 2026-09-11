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
	var cores: Array = []
	var struts: Array = []
	var lower: Array = []
	var outer: Color = colors[0]
	var inner: Color = colors[1]
	for cell in solids:
		if not solids[cell]: continue
		var point: Vector2 = game.center(cell)
		var tint := outer.darkened(0.30)
		tint.a = 0.24
		shells.append(view.entry(point,Vector3(31,31,36),tint,-18))
		cores.append(view.entry(point,Vector3(20,20,18),inner.darkened(0.55),-16))
		# Four recessed posts reveal depth through the quiet outer shell.
		for corner in [Vector2(-13,-13),Vector2(13,-13),Vector2(13,13),Vector2(-13,13)]:
			struts.append(view.entry(point+corner,Vector3(0.75,0.75,32),outer.darkened(0.40),-16))
		for direction in [Vector2i.UP,Vector2i.RIGHT]:
			var size := Vector3(28,0.75,0.5) if direction.y else Vector3(0.75,28,0.5)
			struts.append(view.entry(point+Vector2(direction)*13, size,inner.darkened(0.45),-31))
	for cell in game.cells:
		if game.cells[cell] != -1 and not game.discovered.has(game.cells[cell]): continue
		# Sparse service trays, not another generated dungeon or playable floor.
		if posmod(cell.x,4) != 1 and posmod(cell.y,4) != 1: continue
		var p: Vector2 = game.center(cell)
		var horizontal: bool = posmod(cell.y,4) == 1
		var size := Vector3(31,7,4) if horizontal else Vector3(7,31,4)
		lower.append(view.entry(p,size,inner.darkened(0.68),-42))
		var rail := Vector3(31,0.8,0.5) if horizontal else Vector3(0.8,31,0.5)
		lower.append(view.entry(p,rail,outer.darkened(0.50),-39))
	view.upload("bg_shell",shells)
	view.upload("bg_core",cores)
	view.upload("bg_strut",struts)
	view.upload("bg_lower",lower)
