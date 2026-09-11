extends SceneTree
const Scenario = preload("res://tools/dev_scenario.gd")
const Background = preload("res://scripts/background_style.gd")
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: "+message)
		failures += 1

func run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Background edge test requires a display renderer")
		quit(2)
		return
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	check(game.view_pitch_degrees == 25,"adopted pitch defaults to 25 degrees")
	Scenario.configure(game,"normal19",19045,1)
	game.set_depth_view(true)
	var view = game.depth_view
	view.set_process(false)
	var unique: Dictionary = {}
	var edges: MultiMesh = view.batches.bg_strut
	for index in range(edges.visible_instance_count):
		var transform := edges.get_instance_transform(index)
		var key := [transform*Vector3(-0.5,0,0),transform*Vector3(0.5,0,0)]
		check(key[0].z <= -32 and key[1].z <= -32,"decorative cube edges never outline the roof or upper wall")
		check(not unique.has(key),"each shared cube edge is emitted once")
		unique[key] = true
	for key in view.batches: view.batches[key].visible_instance_count = 0
	var target: Vector2 = game.view_origin()
	view.upload("bg_strut",[Background.line_entry(view.project_point(target-Vector2(40,0)),view.project_point(target+Vector2(40,0)),Color.WHITE)])
	for warmup in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	var baseline: Vector3 = view.camera.position
	var energy: Array[float] = []
	for phase in range(16):
		# Sweep one pixel continuously; do not let camera quantization hide aliasing.
		view.camera.position = baseline+Vector3(0,-phase/16.0/cos(deg_to_rad(25)),0)
		await process_frame
		await RenderingServer.frame_post_draw
		var frame: Image = view.viewport.get_texture().get_image()
		var center := Vector2i(frame.get_size()/2)
		var background := frame.get_pixel(0,0).r
		var total := 0.0
		for y in range(-5,6): total += frame.get_pixelv(center+Vector2i(0,y)).r-background
		energy.append(total)
	var minimum: float = energy.min()
	var maximum: float = energy.max()
	print("One-pixel edge sweep integrated brightness: ",minimum,"..",maximum)
	check(minimum>0.2 and maximum/minimum<1.06,"edge brightness/width stays stable through subpixel motion")
	view.camera.position = baseline
	view.batches.bg_strut.visible_instance_count = 0
	view.upload("bg_shell",[view.entry(target,Vector3(32,32,96),Color(0.32,0.52,0.55,0.13),-48)])
	await process_frame
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = view.viewport.get_texture().get_image()
	var front: Vector2 = view.camera.unproject_position(view.project_point(target+Vector2(0,16),-16))
	print("Front sample ",front," color ",frame.get_pixelv(Vector2i(front))," background ",frame.get_pixel(0,0))
	check(frame.get_pixelv(Vector2i(front)).get_luminance()>frame.get_pixel(0,0).get_luminance()+0.03,"near-facing cube wall renders below the top at 25 degrees")
	var below: Vector2 = view.camera.unproject_position(view.project_point(target+Vector2(0,16),-64))
	var wall_light := frame.get_pixelv(Vector2i(front)).get_luminance()-frame.get_pixel(0,0).get_luminance()
	var support_light := frame.get_pixelv(Vector2i(below)).get_luminance()-frame.get_pixel(0,0).get_luminance()
	check(wall_light>support_light*3.0,"near wall is distinct from the transparent lower support")
	# The next cube's roof must hide the preceding cube's near face.
	view.upload("bg_cap",[view.entry(target+Vector2(0,32),Vector3(32,32,0.1),Color(0.08,0.12,0.14),-0.15)])
	for wait_frame in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	var covered: Image = view.viewport.get_texture().get_image()
	view.batches.bg_shell.visible_instance_count = 0
	for wait_frame in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	var roof_only: Image = view.viewport.get_texture().get_image()
	check(covered.get_pixelv(Vector2i(front)).is_equal_approx(roof_only.get_pixelv(Vector2i(front))),"roof occludes the rear cube face")
	DirAccess.make_dir_recursive_absolute("res://docs/validation/edges")
	frame.save_png("res://docs/validation/edges/front-face.png")
	game.free()
	if failures == 0: print("PASS: shared edges, subpixel line coverage and visible near cube face")
	quit(1 if failures else 0)
