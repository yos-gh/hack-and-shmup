extends Node

const Background = preload("res://scripts/background_style.gd")
const Glyph = preload("res://scripts/glyph_meshes.gd")

# Presentation-only orthographic XY scene: one world unit equals one screen pixel.
# +Z adds depth without moving the projected hit position. No 3D physics nodes.
var viewport := SubViewport.new()
var camera := Camera3D.new()
var stage := Node3D.new()
var batches: Dictionary = {}
var cached_floor := -1
var cached_discovery := 0
var active := true
var applied_pitch := -1.0
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
	for key in ["bg_shell","bg_core","bg_strut","bg_lower"]: make_batch(key,box)
	make_batch("floor", box)
	make_batch("contact", box)
	make_batch("wall_v", beveled_square(Vector2(0.4,1.0)))
	make_batch("wall_h", beveled_square(Vector2(1.0,0.4)))
	make_batch("square", Glyph.plate([Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)],0.22))
	make_batch("player_barrel", beveled_square())
	make_batch("chaser", Glyph.plate([Vector2(1,1),Vector2(-1,0.76),Vector2(-1,-0.76),Vector2(1,-1)],0.22))
	make_batch("sniper", sniper_mesh())
	make_batch("siege_base", Glyph.annulus(0.55,4))
	make_batch("siege_armor", beveled_square())
	make_batch("siege_barrel", beveled_square())
	make_batch("siege_core", beveled_square())
	make_batch("hunter_body", Glyph.chevron())
	make_batch("hunter_wing", beveled_square())
	make_batch("hunter_core", beveled_square())
	make_batch("hunter_drive", beveled_square())
	make_batch("ring", Glyph.annulus(5.0/12.0,48,true))
	make_batch("halo_ring", Glyph.annulus(24.0/29.0,64,true))
	var disk := CylinderMesh.new()
	disk.top_radius = 1.0
	disk.bottom_radius = 1.0
	disk.height = 1.0
	disk.radial_segments = 48
	make_batch("halo_base", disk)
	make_batch("halo_core", beveled_square())
	sync(get_parent())

func make_batch(key: String, mesh: Mesh) -> void:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.65
	material.metallic = 0.15
	if key in ["floor", "contact"]: material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var instance := MultiMeshInstance3D.new()
	instance.material_override = material
	if key in ["square","player_barrel","chaser"] or key.begins_with("siege_") or key.begins_with("hunter_") or key.begins_with("halo_"):
		var glyph_surface := ShaderMaterial.new()
		glyph_surface.shader = preload("res://scripts/glyph_surface.gdshader")
		instance.material_override = glyph_surface
	if key in ["ring", "sniper"]:
		var iris := ShaderMaterial.new()
		iris.shader = preload("res://scripts/triangular_iris.gdshader") if key == "sniper" else preload("res://scripts/sniper_iris.gdshader")
		instance.material_override = iris
	if key == "floor":
		var glass_floor := ShaderMaterial.new()
		glass_floor.shader = preload("res://scripts/background_floor.gdshader")
		instance.material_override = glass_floor
	if key in ["wall_v","wall_h"]: material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if key.begins_with("bg_"):
		var glass := ShaderMaterial.new()
		glass.shader = preload("res://scripts/background_glass.gdshader")
		instance.material_override = glass
	# Transparent batches sort as layers, not by their aggregate AABB center.
	# Camera pitch must never move glass flooring in front of combat glyphs.
	if key.begins_with("bg_"): instance.material_override.render_priority = -30
	elif key == "floor": instance.material_override.render_priority = -20
	elif key not in ["wall_v","wall_h","contact"]: instance.material_override.render_priority = 10
	instance.multimesh = MultiMesh.new()
	instance.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	instance.multimesh.use_colors = true
	instance.multimesh.use_custom_data = key in ["ring", "sniper"]
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

func sniper_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Sample rays against an isosceles outline and a circular inner contour.
	# Include the exact three corners as well as regular circle samples.
	var corners := [Vector2(1.3,0),Vector2(-0.8,0.9),Vector2(-0.8,-0.9)]
	var angles: Array[float] = []
	for i in range(48): angles.append(TAU*i/48.0)
	for corner in corners:
		var angle: float = fposmod(corner.angle(),TAU)
		if not angles.has(angle): angles.append(angle)
	angles.sort()
	for i in range(angles.size()):
		var a := Vector2.from_angle(angles[i])
		var b := Vector2.from_angle(angles[(i+1)%angles.size()])
		var oa := sniper_outline(a,corners)
		var ob := sniper_outline(b,corners)
		var outer_a := Vector3(oa.x*0.94,oa.y*0.94,0.75+oa.x*0.22)
		var outer_b := Vector3(ob.x*0.94,ob.y*0.94,0.75+ob.x*0.22)
		var inner_a := Vector3(a.x*5.0/12.0,a.y*5.0/12.0,0.75+a.x*5.0/12.0*0.22)
		var inner_b := Vector3(b.x*5.0/12.0,b.y*5.0/12.0,0.75+b.x*5.0/12.0*0.22)
		for face in [[outer_a,outer_b,inner_b],[outer_a,inner_b,inner_a]]:
			for point in [face[0],face[2],face[1]]:
				surface.set_color(Color(0.82,0.86,0.91))
				surface.set_normal(Vector3(-0.22,0,1).normalized())
				surface.set_uv(Vector2(1 if Vector2(point.x,point.y).length() < 0.5 else 0,0))
				surface.add_vertex(point)
		var rim_a := Vector3(oa.x,oa.y,0.45+oa.x*0.22)
		var rim_b := Vector3(ob.x,ob.y,0.45+ob.x*0.22)
		surface.set_uv(Vector2.ZERO)
		surface.set_color(Color.WHITE)
		var bevel_normal := (rim_b-rim_a).cross(outer_a-rim_a).normalized()
		triangle(surface,rim_a,rim_b,outer_b,bevel_normal)
		triangle(surface,rim_a,outer_b,outer_a,bevel_normal)
		for contour in [[rim_a,rim_b,0.0],[inner_b,inner_a,1.0]]:
			var start: Vector3 = contour[0]
			var end: Vector3 = contour[1]
			var low_start := Vector3(start.x,start.y,0)
			var low_end := Vector3(end.x,end.y,0)
			surface.set_color(Color(0.35,0.48,0.58))
			surface.set_uv(Vector2(contour[2],0))
			var normal := (low_end-low_start).cross(end-low_start).normalized()
			triangle(surface, low_start, low_end, end, normal)
			triangle(surface, low_start, end, start, normal)
		for face in [[rim_a,inner_b,rim_b],[rim_a,inner_a,inner_b]]:
			for point in [face[0],face[2],face[1]]:
				surface.set_normal(Vector3.FORWARD)
				surface.set_color(Color(0.25,0.32,0.4))
				surface.set_uv(Vector2(1 if Vector2(point.x,point.y).length() < 0.5 else 0,0))
				surface.add_vertex(Vector3(point.x,point.y,0))
	return surface.commit()

func sniper_outline(direction: Vector2, corners: Array) -> Vector2:
	for i in range(corners.size()):
		var a: Vector2 = corners[i]
		var edge: Vector2 = corners[(i+1)%corners.size()]-a
		var denominator := direction.cross(edge)
		if absf(denominator) < 0.00001: continue
		var distance := a.cross(edge)/denominator
		var along := a.cross(direction)/denominator
		if distance > 0 and along >= -0.00001 and along <= 1.00001:
			return direction*distance
	return direction

func chaser_heading(game, enemy: Dictionary) -> Vector2:
	if not enemy.active: return enemy.dir
	var cell: Vector2i = game.tile(enemy.p)
	var target: Vector2 = game.player if cell == game.tile(game.player) else game.center(game.flow.get(cell, cell))
	var direction: Vector2 = target-enemy.p
	return direction.normalized() if direction.length_squared() > 0.001 else enemy.dir

func boss_part(enemy: Dictionary, facing: Vector2, offset: Vector2, size: Vector3, color: Color, height: float) -> Dictionary:
	var factor := 1.3 if get_parent().boss_variant == 0 else 1.12
	return chaser_entry(enemy.p+(offset*factor).rotated(facing.angle()),facing,Vector3(size.x*factor,size.y*factor,size.z),color,height)

func sync_other_bosses(game) -> void:
	var parts := {"siege_base":[],"siege_armor":[],"siege_barrel":[],"siege_core":[],"hunter_body":[],"hunter_wing":[],"hunter_core":[],"hunter_drive":[]}
	if game.boss_floor and game.boss_variant != 2:
		for enemy in game.enemies:
			if enemy.kind != 3 or enemy.hp <= 0 or not game.attack_open(enemy.p): continue
			var warning: float = game.attack_warning(enemy)
			var facing: Vector2 = enemy.p.direction_to(game.player) if enemy.active else enemy.dir
			if game.boss_variant == 0:
				var flash: float = game.boss.shot_flash(game,enemy.p)
				var ink: Color = game.boss.COLORS[0].lerp(Color("fff5ff"),flash*0.8)
				# Stationary diamond footing, independent of the swivelling turret.
				parts.siege_base.append(boss_part(enemy,Vector2.RIGHT,Vector2.ZERO,Vector3(20,20,5),ink,2))
				for side in [-1,1]:
					parts.siege_armor.append(boss_part(enemy,facing,Vector2(-3,side*10),Vector3(6,3,5),ink.darkened(0.22),4))
					parts.siege_barrel.append(boss_part(enemy,facing,Vector2(11-warning*3-flash*4,side*4),Vector3(7,2,4),ink.lerp(Color("fff0fc"),warning),6))
				parts.siege_core.append(boss_part(enemy,facing,Vector2.ZERO,Vector3(8-warning*3,7-warning*3,5),ink.lerp(Color.WHITE,warning),5))
			else:
				var laser_charge := 0.0
				var firing := false
				for beam in game.boss.lasers:
					if beam.owner != enemy: continue
					# Aim at the locked central beam, not a player moving across it.
					if laser_charge == 0 and not firing: facing = beam.a.direction_to(beam.b)
					laser_charge = maxf(laser_charge,clampf(1-beam.warning/0.8,0,1))
					firing = firing or beam.warning <= 0
				# Multi-beam patterns are symmetric: use their average direction.
				var beam_aim := Vector2.ZERO
				for beam in game.boss.lasers:
					if beam.owner == enemy: beam_aim += beam.a.direction_to(beam.b)
				if not beam_aim.is_zero_approx(): facing = beam_aim.normalized()
				var ink: Color = game.boss.COLORS[1]
				parts.hunter_body.append(boss_part(enemy,facing,Vector2.ZERO,Vector3(24,18,3),ink.darkened(0.65),1))
				parts.hunter_body.append(boss_part(enemy,facing,Vector2.ZERO,Vector3(22,16,5),ink.darkened(0.18),3))
				for side in [-1,1]:
					parts.hunter_wing.append(boss_part(enemy,facing,Vector2(-9,side*(9-laser_charge*2)),Vector3(5,2,4),ink.lerp(Color("e3fcff"),laser_charge*0.6),6))
					var drive: float = 2.0 if laser_charge > 0 and not firing else 5.0
					parts.hunter_drive.append(boss_part(enemy,facing,Vector2(-18,side*9),Vector3(drive,2,2),ink.darkened(0.35 if drive == 2 else 0),3))
				var extent := 7.0-4.0*maxf(laser_charge,warning)
				parts.hunter_core.append(boss_part(enemy,facing,Vector2.ZERO,Vector3(extent,1.8,4),ink.lerp(Color.WHITE,maxf(laser_charge,warning)),7))
	for key in parts: upload(key,parts[key])

func chaser_entry(point: Vector2, heading: Vector2, scale_value: Vector3, color: Color, height: float) -> Dictionary:
	var value := entry(point, scale_value, color, height)
	value.transform.basis = Basis(Vector3.BACK, -heading.angle()) * Basis.from_scale(scale_value)
	return value

func project_point(point: Vector2, height: float = 0.0) -> Vector3:
	return Vector3(point.x, -point.y, height)

func entry(point: Vector2, scale_value: Vector3, color: Color, height: float = 0.0, ring: bool = false, warning: float = 0.0) -> Dictionary:
	var basis := Basis(Vector3.RIGHT, PI/2) if ring else Basis.IDENTITY
	var origin := project_point(point,height)
	# Keep raised actor origins over their tactical anchors; mesh thickness remains 3D.
	origin.y -= tan(deg_to_rad(get_parent().view_pitch_degrees))*maxf(height,0.0)
	return {"transform": Transform3D(basis.scaled(scale_value), origin), "color": color, "warning": warning}

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
	var pitch := deg_to_rad(game.view_pitch_degrees)
	camera.rotation = Vector3(pitch,0,0)
	camera.position = project_point(game.view_origin())+Vector3(0,-sin(pitch),cos(pitch))*1500
	if applied_pitch != game.view_pitch_degrees:
		applied_pitch = game.view_pitch_degrees
		for child in stage.get_children():
			if child is MultiMeshInstance3D and child.multimesh in [batches.bg_shell,batches.bg_core,batches.bg_strut,batches.bg_lower]:
				child.material_override.set_shader_parameter("depth_slant",Vector2(0.45,-0.30) if pitch == 0 else Vector2.ZERO)
	var discovery: int = hash(game.discovered)
	if cached_floor != game.floor_revision or cached_discovery != discovery:
		rebuild_floor(game)
		cached_floor = game.floor_revision
		cached_discovery = discovery
	var squares: Array = []
	var rings: Array = []
	var chasers: Array = []
	var snipers: Array = []
	var world_screen: Vector2 = screen/game.view_scale()
	var bounds := Rect2(game.view_origin()-world_screen*0.5-Vector2(64,64), world_screen+Vector2(128,128))
	for enemy in game.enemies:
		if enemy.kind >= 3 or enemy.hp <= 0 or not bounds.has_point(enemy.p) or not game.attack_open(enemy.p): continue
		var warning: float = game.attack_warning(enemy)
		if enemy.kind == 1:
			var facing: Vector2 = (game.player-enemy.p).normalized() if enemy.active else enemy.dir
			var shell := chaser_entry(enemy.p, facing, Vector3(10.8,10.8,7), Color("ffb95e").lerp(Color("fff4dd"), maxf(warning,game.boss.shot_flash(game,enemy.p))), 3)
			shell.warning = warning
			snipers.append(shell)
		elif enemy.kind == 0:
			var heading := chaser_heading(game, enemy)
			chasers.append(chaser_entry(enemy.p, heading, Vector3(11,11,2), Color("582536"), 1))
			chasers.append(chaser_entry(enemy.p, heading, Vector3(10.56,10.56,5), Color("f3637a"), 3))
		else:
			var radius: float = 12.0-warning*2.0
			var color := Color("ad8fff").lerp(Color("fff4dd"), warning)
			# A quiet chassis and raised inset plate retain the original footprint.
			squares.append(chaser_entry(enemy.p, enemy.dir, Vector3(radius,radius,2), color.darkened(0.65), 1))
			squares.append(chaser_entry(enemy.p, enemy.dir, Vector3(radius*0.88,radius*0.88,5), color, 4))
	var barrels: Array = []
	if game.grace <= 0 or fmod(game.grace, 0.16) < 0.1:
		rings.append(entry(game.player, Vector3(12,12,7), Color("63f5ce"), 7, true))
		var aim: Vector2 = game.controls.aim(game)
		for side in [-1.0,1.0]:
			barrels.append(chaser_entry(game.player+aim*14+aim.orthogonal()*side*3.5,aim,Vector3(5,1.25,2),Color("3ba88f"),7))
	upload("player_barrel", barrels)
	upload("square", squares)
	upload("chaser", chasers)
	upload("sniper", snipers)
	upload("ring", rings)
	sync_halo(game)
	sync_other_bosses(game)
	game.queue_redraw()
	max_sync_ms = maxf(max_sync_ms, (Time.get_ticks_usec()-started)/1000.0)

func sync_halo(game) -> void:
	var shells: Array = []
	var bases: Array = []
	var cores: Array = []
	if game.boss_floor and game.boss_variant == 2:
		var ink: Color = game.boss.COLORS[2]
		for enemy in game.enemies:
			if enemy.kind != 3 or enemy.hp <= 0 or not game.attack_open(enemy.p): continue
			var warning: float = game.attack_warning(enemy)
			var extent := lerpf(12.0,7.0,warning)
			bases.append(entry(enemy.p,Vector3(24,24,4),ink.darkened(0.75),3,true))
			shells.append(entry(enemy.p,Vector3(29,29,12),ink,7,true))
			cores.append(entry(enemy.p,Vector3(extent,extent,6),ink.lerp(Color.WHITE,maxf(warning,game.boss.shot_flash(game,enemy.p))),7))
		for option in game.boss.options:
			if option.life <= 0 or option.owner.hp <= 0 or not game.attack_open(option.p): continue
			var charge: float = game.boss.option_warning(option)
			var extent := 5.0-charge*2.0
			var color := ink.lerp(Color("fff5e2"),maxf(charge,game.boss.shot_flash(game,option.p)))
			bases.append(entry(option.p,Vector3(10,10,3),Color("263847"),3,true))
			shells.append(entry(option.p,Vector3(11,11,7),color,5,true))
			cores.append(entry(option.p,Vector3(extent,extent,4),color,6))
	# Upload empty lists as well, so defeat, retry and floor changes leave no ghosts.
	upload("halo_ring",shells)
	upload("halo_base",bases)
	upload("halo_core",cores)

func rebuild_floor(game) -> void:
	var started := Time.get_ticks_usec()
	var floors: Array = []
	var contacts: Array = []
	var vertical_walls: Array = []
	var horizontal_walls: Array = []
	var pillars: Dictionary = {}
	var palette := Background.palette(game)
	var outer: Color = palette[0]
	for cell in game.cells:
		var known: bool = game.cells[cell] == -1 or game.discovered.has(game.cells[cell])
		var p: Vector2 = game.center(cell)
		# Nearly continuous floor; only a quiet seam every four cells.
		var shade := Color("101923").lerp(outer,0.12) if known else Color("0c1420")
		shade.a = 0.56 if known else 1.0
		var panel := Vector2i(floori(cell.x/4.0), floori(cell.y/4.0))
		# Coordinate-derived variation cannot consume simulation or effects RNG.
		shade = shade.lightened(posmod(panel.x*17+panel.y*31,4)*0.003) if known else shade
		var seam_x := 0.7 if posmod(cell.x,4) == 0 else 0.0
		var seam_y := 0.7 if posmod(cell.y,4) == 0 else 0.0
		floors.append(entry(p+Vector2(seam_x,seam_y)*0.5, Vector3(32-seam_x,32-seam_y,2), shade, -2))
		for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			if game.cells.has(cell+direction): continue
			var solid: Vector2i = cell+direction
			pillars[solid] = known or pillars.get(solid,false)
			var wall_center: Vector2 = p+Vector2(direction)*16.65
			var contact_size := Vector3(2,32,0.1) if direction.x != 0 else Vector3(32,2,0.1)
			contacts.append(entry(p+Vector2(direction)*15, contact_size, Color("101b28") if known else Color("0a111b"), -0.8))
			var size_value := Vector3(0.6,16,0.5) if direction.x != 0 else Vector3(16,0.6,0.5)
			var target: Array = vertical_walls if direction.x != 0 else horizontal_walls
			target.append(entry(wall_center, size_value, outer.lightened(0.13) if known else Color("172736"), 0))
	Background.build(self,game,pillars,palette)
	upload("floor", floors)
	upload("contact", contacts)
	upload("wall_v", vertical_walls)
	upload("wall_h", horizontal_walls)
	last_rebuild_ms = (Time.get_ticks_usec()-started)/1000.0
