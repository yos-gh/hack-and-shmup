extends RefCounted
## Shared field-bullet batches, also used by Halo, Citadel and Bastion patterns.
const Catalog = preload("res://scripts/combat_catalog.gd")
const TONES := [Color("8abaff"),Color("ff91b1"),Color("ffb95e")]
const RIM := Color("101323")
const CENTER := Color("fff7ed")
const SEGMENTS := 32
var batches: Array[MultiMesh] = []
var visible_counts := PackedInt32Array([0,0,0])

func pearl_mesh(tone: Color) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in [[7.0,4.7,RIM],[4.7,1.8,tone],[1.8,0.0,CENTER]]:
		for i in range(SEGMENTS):
			var a := Vector2.from_angle(i*TAU/SEGMENTS)
			var b := Vector2.from_angle((i+1)*TAU/SEGMENTS)
			for point in [a*ring[0],b*ring[0],a*ring[1],a*ring[1],b*ring[0],b*ring[1]]:
				surface.set_color(ring[2])
				surface.add_vertex(Vector3(point.x,point.y,0))
	return surface.commit()

func prepare() -> void:
	if not batches.is_empty(): return
	for tone in TONES:
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_2D
		batch.mesh = pearl_mesh(tone)
		batch.instance_count = 1024
		batch.visible_instance_count = 0
		batches.append(batch)

func sync(game, view: Rect2) -> void:
	prepare()
	visible_counts.fill(0)
	# Only presentation is culled. Off-screen bullets keep their normal motion,
	# wall collision, lifetime and shockwave interaction in the game simulation.
	for bullet in game.bullets:
		if not bullet.get("field",false) or not view.has_point(bullet.p): continue
		if Catalog.projectile_shape(bullet) != "pearl": continue
		var room: int = game.cells.get(game.tile(bullet.p),-1)
		if room >= 0 and not game.discovered.has(room): continue
		var tone: int = clampi(bullet.get("tone",2),0,TONES.size()-1)
		var index: int = visible_counts[tone]
		var batch: MultiMesh = batches[tone]
		if index >= batch.instance_count:
			# Expanding a MultiMesh clears its transforms, so grow before uploading.
			batch.instance_count = maxi(game.bullets.size(),batch.instance_count*2)
			sync(game,view)
			return
		batch.set_instance_transform_2d(index,Transform2D(0,bullet.p))
		visible_counts[tone] += 1
	for tone in range(TONES.size()): batches[tone].visible_instance_count = visible_counts[tone]

func draw(game, view: Rect2) -> void:
	sync(game,view)
	for tone in range(TONES.size()):
		if visible_counts[tone] > 0: game.draw_multimesh(batches[tone],null)
