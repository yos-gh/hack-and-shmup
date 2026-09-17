extends RefCounted

const Catalog = preload("res://scripts/combat_catalog.gd")
const Glyph = preload("res://scripts/glyph_meshes.gd")
const Behavior = preload("res://scripts/mob_behavior.gd")
const FLANK_INK := Color("ff946f")
const WARP_INK := Color("ee8fd5")
const WARP_PREVIEW_ALPHA := 0.4

static func outlines(kind: int) -> Array:
	if kind == Catalog.Enemy.FLANKER:
		return [[Vector2(-1,-0.9),Vector2(1,-0.65),Vector2(0.15,-0.1),Vector2(-0.8,-0.25)], [Vector2(-0.8,0.25),Vector2(0.15,0.1),Vector2(1,0.65),Vector2(-1,0.9)]]
	var result := []
	for i in range(4):
		var part: Array[Vector2] = []
		for p in [Vector2(-0.7,-1),Vector2(0.7,-1),Vector2(0.7,-0.62),Vector2(-0.7,-0.62)]:
			part.append(p.rotated(i*PI/2))
		result.append(part)
	return result

static func mesh(kind: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part in outlines(kind):
		var points: Array[Vector2] = []
		points.assign(part)
		Glyph.prism(surface,points,0.12 if kind == Catalog.Enemy.FLANKER else 0.0)
	return surface.commit()

static func ink(kind: int) -> Color:
	return FLANK_INK if kind == Catalog.Enemy.FLANKER else WARP_INK

static func draw_body(game, enemy: Dictionary) -> void:
	var color := ink(enemy.kind)
	for part in outlines(enemy.kind):
		var points := PackedVector2Array()
		for p in part: points.append(enemy.p+(p*12).rotated(enemy.dir.angle()))
		game.draw_colored_polygon(points,Color(color,0.3))
		points.append(points[0])
		game.draw_polyline(points,color,1.8,true)
	game.draw_circle(enemy.p,2.6,color.lightened(0.3))

static func draw_warning(game, enemy: Dictionary) -> void:
	if enemy.kind != Catalog.Enemy.INTERCEPTOR or enemy.hp <= 0: return
	if enemy.get("warp_warning",0.0) > 0:
		var target: Vector2 = enemy.warp_target
		var progress: float = 1.0-enemy.warp_warning/Behavior.WARP_WARNING
		var preview_ink := Color(WARP_INK,WARP_PREVIEW_ALPHA)
		game.draw_rect(Rect2(target-Vector2.ONE*18,Vector2.ONE*36),Color(Color("080e17"),0.12))
		game.draw_rect(Rect2(target-Vector2.ONE*18,Vector2.ONE*36),preview_ink,false,2)
		game.draw_arc(target,24,-PI/2,-PI/2+TAU*maxf(progress,0.01),32,preview_ink,2,true)
		game.draw_line(target-Vector2(7,0),target+Vector2(7,0),preview_ink,2)
		game.draw_line(target-Vector2(0,7),target+Vector2(0,7),preview_ink,2)
	elif enemy.get("arrival",0.0) > 0:
		game.draw_arc(enemy.p,19,0,TAU,24,Color(WARP_INK,enemy.arrival/0.6),2,true)
