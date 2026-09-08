extends Node

# Presentation-only orthographic XY scene: one world unit equals one screen pixel.
# +Z adds depth without moving the projected hit position. No 3D physics nodes.
var viewport := SubViewport.new()
var camera := Camera3D.new()
var stage := Node3D.new()
var batches: Dictionary = {}
var cached_floor := -1
var cached_discovery := 0
var active := true
var max_sync_ms := 0.0
var last_rebuild_ms := 0.0

func _ready() -> void:
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)
	viewport.add_child(stage)
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = 0.1
	camera.far = 3000.0
	camera.current = true
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("080e17")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b3c8df")
	environment.environment.ambient_light_energy = 0.65
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-25, -35, 0)
	light.light_energy = 1.0
	light.shadow_enabled = false
	stage.add_child(light)
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	make_batch("floor", box)
	make_batch("contact", box)
	make_batch("wall_v", beveled_square(Vector2(0.4,1.0)))
	make_batch("wall_h", beveled_square(Vector2(1.0,0.4)))
	make_batch("square", beveled_square())
	var ring := TorusMesh.new()
	ring.inner_radius = 5.0/12.0
	ring.outer_radius = 1.0
	ring.rings = 16
	ring.ring_segments = 8
	make_batch("ring", ring)
	sync(get_parent())

func make_batch(key: String, mesh: Mesh) -> void:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.65
	material.metallic = 0.15
	if key in ["floor", "contact"]: material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var instance := MultiMeshInstance3D.new()
	instance.material_override = material
	if key == "ring":
		var iris := ShaderMaterial.new()
		iris.shader = preload("res://scripts/sniper_iris.gdshader")
		instance.material_override = iris
	instance.multimesh = MultiMesh.new()
	instance.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	instance.multimesh.use_colors = true
	instance.multimesh.use_custom_data = key == "ring"
	instance.multimesh.mesh = mesh
	stage.add_child(instance)
	batches[key] = instance.multimesh

func beveled_square(top_ratio: Vector2 = Vector2(0.73,0.73)) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [Vector2(-1,-1), Vector2(1,-1), Vector2(1,1), Vector2(-1,1)]
	for i in range(4):
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i+1)%4]
		var top_a := Vector3(a.x*top_ratio.x, a.y*top_ratio.y, 1)
		var top_b := Vector3(b.x*top_ratio.x, b.y*top_ratio.y, 1)
		triangle(surface, Vector3(0,0,1), top_a, top_b, Vector3.BACK)
		var low_a := Vector3(a.x, a.y, 0)
		var low_b := Vector3(b.x, b.y, 0)
		var normal := Vector3(a.x+b.x, a.y+b.y, 0.8).normalized()
		triangle(surface, low_a, low_b, top_b, normal)
		triangle(surface, low_a, top_b, top_a, normal)
	return surface.commit()

func triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	# Godot front faces use clockwise winding; normals point toward the camera.
	for point in [a,c,b]:
		surface.set_normal(normal)
		surface.add_vertex(point)

func project_point(point: Vector2, height: float = 0.0) -> Vector3:
	return Vector3(point.x, -point.y, height)

func entry(point: Vector2, scale_value: Vector3, color: Color, height: float = 0.0, ring: bool = false, warning: float = 0.0) -> Dictionary:
	var basis := Basis(Vector3.RIGHT, PI/2) if ring else Basis.IDENTITY
	return {"transform": Transform3D(basis.scaled(scale_value), project_point(point, height)), "color": color, "warning": warning}

func upload(key: String, entries: Array) -> void:
	var mesh: MultiMesh = batches[key]
	if mesh.instance_count < entries.size():
		mesh.instance_count = maxi(entries.size(), mesh.instance_count*2)
	mesh.visible_instance_count = entries.size()
	for i in range(entries.size()):
		mesh.set_instance_transform(i, entries[i].transform)
		mesh.set_instance_color(i, entries[i].color)
		if mesh.use_custom_data: mesh.set_instance_custom_data(i, Color(entries[i].warning, 0, 0, 0))

func set_active(value: bool) -> void:
	active = value
	set_process(value)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if value else SubViewport.UPDATE_DISABLED
	if value: sync(get_parent())

func _process(_delta: float) -> void:
	if not active: return
	var game = get_parent()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED if game.title_screen else SubViewport.UPDATE_ALWAYS
	if not game.title_screen: sync(game)

func sync(game) -> void:
	var started := Time.get_ticks_usec()
	var screen: Vector2 = game.get_viewport_rect().size
	viewport.size = Vector2i(screen)
	camera.size = screen.y
	camera.position = project_point(game.camera_pos, 1500)
	var discovery: int = hash(game.discovered)
	if cached_floor != game.floor_revision or cached_discovery != discovery:
		rebuild_floor(game)
		cached_floor = game.floor_revision
		cached_discovery = discovery
	var squares: Array = []
	var rings: Array = []
	var bounds := Rect2(game.camera_pos-screen*0.5-Vector2(48,48), screen+Vector2(96,96))
	for enemy in game.enemies:
		if enemy.kind >= 3 or enemy.hp <= 0 or not bounds.has_point(enemy.p) or not game.attack_open(enemy.p): continue
		var warning: float = game.attack_warning(enemy)
		if enemy.kind == 1:
			rings.append(entry(enemy.p, Vector3(12,12,7), Color("ffb95e").lerp(Color("fff4dd"), warning), 7, true, warning))
		else:
			var radius: float = 10.0 if enemy.kind == 0 else 12.0-warning*2.0
			var color := Color("f3637a") if enemy.kind == 0 else Color("ad8fff").lerp(Color("fff4dd"), warning)
			# A quiet chassis and raised inset plate retain the original footprint.
			squares.append(entry(enemy.p, Vector3(radius,radius,2), color.darkened(0.65), 1))
			squares.append(entry(enemy.p, Vector3(radius*0.88,radius*0.88,5), color, 4))
	if game.grace <= 0 or fmod(game.grace, 0.16) < 0.1:
		rings.append(entry(game.player, Vector3(12,12,7), Color("63f5ce"), 7, true))
	upload("square", squares)
	upload("ring", rings)
	game.queue_redraw()
	max_sync_ms = maxf(max_sync_ms, (Time.get_ticks_usec()-started)/1000.0)

func rebuild_floor(game) -> void:
	var started := Time.get_ticks_usec()
	var floors: Array = []
	var contacts: Array = []
	var vertical_walls: Array = []
	var horizontal_walls: Array = []
	for cell in game.cells:
		var known: bool = game.cells[cell] == -1 or game.discovered.has(game.cells[cell])
		var p: Vector2 = game.center(cell)
		# Nearly continuous floor; only a quiet seam every four cells.
		var shade := Color("182432") if known else Color("0c1420")
		var panel := Vector2i(floori(cell.x/4.0), floori(cell.y/4.0))
		# Coordinate-derived variation cannot consume simulation or effects RNG.
		shade = shade.lightened(posmod(panel.x*17+panel.y*31,4)*0.003) if known else shade
		var seam_x := 0.7 if posmod(cell.x,4) == 0 else 0.0
		var seam_y := 0.7 if posmod(cell.y,4) == 0 else 0.0
		floors.append(entry(p+Vector2(seam_x,seam_y)*0.5, Vector3(32-seam_x,32-seam_y,2), shade, -2))
		for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			if game.cells.has(cell+direction): continue
			var wall_center: Vector2 = p+Vector2(direction)*18
			var contact_size := Vector3(5,32,0.1) if direction.x != 0 else Vector3(32,5,0.1)
			contacts.append(entry(p+Vector2(direction)*13.5, contact_size, Color("101b28") if known else Color("0a111b"), -0.8))
			var size_value := Vector3(2,16,8) if direction.x != 0 else Vector3(16,2,8)
			var target: Array = vertical_walls if direction.x != 0 else horizontal_walls
			target.append(entry(wall_center, size_value, Color("426477") if known else Color("172736"), -1))
	upload("floor", floors)
	upload("contact", contacts)
	upload("wall_v", vertical_walls)
	upload("wall_h", horizontal_walls)
	last_rebuild_ms = (Time.get_ticks_usec()-started)/1000.0
