extends SceneTree
## Capture actual runtime meshes in three orthographic views, at a shared scale.
var sheet: SubViewport
const Scenario = preload("res://tools/dev_scenario.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_view_pitch(0)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	Scenario.configure(game,"normal19",19045,1)
	game.set_depth_view(true)
	game.depth_view.set_process(false)
	var view = game.depth_view
	sheet = view.viewport
	var models: Array = []
	for kind in [-1,0,1,2]:
		if kind == -1:
			game.grace = 0
			game.replay_input = {"aim":Vector2.RIGHT}
			view.sync(game)
			models.append(copy_parts(view,["ring","player_barrel"],game.player))
		else:
			var enemy: Dictionary = game.enemies.filter(func(e): return e.kind == kind)[0]
			enemy.active = false
			enemy.dir = Vector2.RIGHT
			enemy.cd = 2.5
			game.discovered[enemy.room] = true
			game.camera_pos = enemy.p
			# Only the selected normal enemy contributes to its batch.
			for other in game.enemies: other.hp = 1 if other == enemy else 0
			view.sync(game)
			models.append(copy_parts(view,[["chaser"],["sniper"],["square"]][kind],enemy.p))
	for scenario in ["siege5","hunter15","halo45"]:
		Scenario.configure(game,scenario,19045,1)
		var enemy: Dictionary = game.enemies[0]
		for other in game.enemies: other.hp = 1 if other == enemy else 0
		enemy.active = false
		enemy.dir = Vector2.RIGHT
		enemy.cd = 2.5
		view.sync(game)
		var keys: Array = []
		var prefix: String = {"siege5":"siege_","hunter15":"hunter_","halo45":"halo_"}[scenario]
		for key in view.batches:
			if key.begins_with(prefix): keys.append(key)
		models.append(copy_parts(view,keys,enemy.p))
		if scenario == "halo45":
			game.boss.deploy_options(game,enemy,0)
			var option: Dictionary = game.boss.options[0]
			for other in game.boss.options: other.life = 1 if other == option else 0
			view.sync(game)
			models.append(copy_parts(view,keys,option.p,1))
	for child in view.stage.get_children():
		if child is MultiMeshInstance3D: child.visible = false
	view.viewport.size = Vector2i(1440,840)
	view.camera.size = 840
	view.camera.position = Vector3(720,-420,1500)
	game.hide()
	var names := ["PLAYER","CHASER","SNIPER","SHIELD","SIEGE","VECTOR","HALO","OPTION"]
	for column in range(models.size()):
		label(names[column],Vector2(20+column*180,24))
		for row in range(3):
			var group := Node3D.new()
			view.stage.add_child(group)
			group.position = Vector3(90+column*180,-(155+row*245),0)
			group.basis = [Basis.IDENTITY,Basis(Vector3.BACK,Vector3.RIGHT,Vector3.UP),Basis(Vector3.RIGHT,Vector3.FORWARD,Vector3.UP)][row].scaled(Vector3.ONE*2.2)
			for source in models[column]: group.add_child(source.duplicate())
	for row in range(3): label(["TOP","FRONT (+X)","SIDE (-Y)"][row],Vector2(16,75+row*245))
	label("Runtime geometry / shared 2.2x scale / idle state / +X forward",Vector2(20,804))
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://docs/captures/prototype")
	view.viewport.get_texture().get_image().save_png("res://docs/captures/prototype/glyph-models.png")
	for model in models:
		for part in model: part.free()
	game.free()
	print("PASS: captured runtime glyph models in three orthographic views")
	quit()

func copy_parts(view, keys: Array, origin: Vector2, skip: int = 0) -> Array:
	var result: Array = []
	for key in keys:
		var batch: MultiMesh = view.batches[key]
		var material: Material
		for child in view.stage.get_children():
			if child is MultiMeshInstance3D and child.multimesh == batch: material = child.material_override
		for index in range(skip,batch.visible_instance_count):
			var part := MultiMeshInstance3D.new()
			part.material_override = material
			part.multimesh = MultiMesh.new()
			part.multimesh.transform_format = MultiMesh.TRANSFORM_3D
			part.multimesh.use_colors = true
			part.multimesh.mesh = batch.mesh
			part.multimesh.instance_count = 1
			var transform := batch.get_instance_transform(index)
			transform.origin -= Vector3(origin.x,-origin.y,0)
			part.multimesh.set_instance_transform(0,transform)
			part.multimesh.set_instance_color(0,batch.get_instance_color(index))
			result.append(part)
	return result

func label(value: String, position: Vector2) -> void:
	var text := Label.new()
	text.text = value
	text.position = position
	text.add_theme_font_size_override("font_size",16)
	sheet.add_child(text)

