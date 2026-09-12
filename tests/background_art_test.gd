extends SceneTree
const Background = preload("res://scripts/background_style.gd")
const Scenario = preload("res://tools/dev_scenario.gd")
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: "+message)
		failures += 1

func rendered(view) -> Image:
	for i in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	return view.viewport.get_texture().get_image()

func background_only(view) -> void:
	for key in view.batches:
		if not key.begins_with("bg_") and not key in ["floor","contact","wall_mask","wall_v","wall_h"]:
			view.batches[key].visible_instance_count = 0

func run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Background art test requires a display renderer")
		quit(2)
		return
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	Scenario.configure(game,"normal19",19045,1)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.set_depth_view(true)
	var view = game.depth_view
	var masks: MultiMesh = view.batches.wall_mask
	for i in range(masks.visible_instance_count):
		var point := masks.get_instance_transform(i).origin
		var inside_room := false
		for room in game.rooms: inside_room = inside_room or room.has_point(game.tile(Vector2(point.x,-point.y)))
		check(inside_room,"occlusion excludes spaces enclosed by corridor loops")
	var blocks: MultiMesh = view.batches.bg_lower
	var top_count := 0
	var opacities: Dictionary = {}
	for i in range(blocks.visible_instance_count):
		var part := blocks.get_instance_transform(i)
		if absf(part.basis.y.z)>0.1: continue
		top_count += 1
		check(is_equal_approx(part.basis.x.length(),31.5) and is_equal_approx(part.origin.z,-48),"floor blocks share size and level")
		opacities[snappedf(blocks.get_instance_color(i).a,0.01)] = true
	check(top_count == game.cells.size(),"one lower block per floor cell, no overlapping decorative layers")
	check(opacities.size()>12,"block transparency varies across the floor")
	for pair in Background.PAIRS:
		for target_l in [0.19,0.48,0.62]:
			for color in pair:
				check(absf(Background.lightness(Background.with_lightness(color,target_l))-target_l)<0.001,"perceptual lightness is consistent across hues")

	view.set_process(false)
	DirAccess.make_dir_recursive_absolute("res://docs/validation/art")
	# Choose an actual undiscovered room's exposed near edge.
	var target := Vector2i.ZERO
	var found := false
	for cell in game.cells:
		if game.cells[cell] < 0 or game.discovered.has(game.cells[cell]): continue
		if game.cells.has(cell+Vector2i.DOWN): continue
		if not found or cell.y>target.y:
			target = cell
			found = true
	check(found,"fixture has an undiscovered front edge")
	game.camera_pos = game.center(target)
	view.sync(game)
	background_only(view)
	var state := var_to_bytes([Scenario.digest(game),game.effects_rng.state,game.discovered])
	var hidden: Image = await rendered(view)
	hidden.save_png("res://docs/validation/art/hidden-room.png")
	var sample: Vector2 = view.camera.unproject_position(view.project_point(game.center(target)+Vector2(0,16),-16))
	var count: int = view.batches.bg_shell.visible_instance_count
	view.batches.bg_shell.visible_instance_count = 0
	var absent: Image = await rendered(view)
	var delta := hidden.get_pixelv(Vector2i(sample)).get_luminance()-absent.get_pixelv(Vector2i(sample)).get_luminance()
	print("Undiscovered near-side luminance contribution: ",delta)
	check(delta>0.01,"undiscovered near-facing wall contributes visible pixels")
	var lower_count: int = view.batches.bg_lower.visible_instance_count
	view.batches.bg_shell.visible_instance_count = count
	view.batches.bg_lower.visible_instance_count = 0
	var no_decor: Image = await rendered(view)
	check(hidden.get_data() != no_decor.get_data(),"hidden room retains visible decorative depth")
	view.batches.bg_lower.visible_instance_count = lower_count
	var layout: Array = []
	for i in range(lower_count): layout.append(view.batches.bg_lower.get_instance_transform(i))
	view.batches.bg_shell.visible_instance_count = count
	check(state == var_to_bytes([Scenario.digest(game),game.effects_rng.state,game.discovered]),"rendering hidden sides reveals no room or simulation state")
	game.discovered[game.cells[target]] = true
	view.sync(game)
	background_only(view)
	check(view.batches.bg_lower.visible_instance_count == lower_count,"discovery does not add or reroll decorative prisms")
	for i in range(lower_count): check(view.batches.bg_lower.get_instance_transform(i) == layout[i],"discovery preserves decorative positions and sizes")
	var known: Image = await rendered(view)
	known.save_png("res://docs/validation/art/discovered-room.png")
	check(known.get_pixelv(Vector2i(sample)).get_luminance()>hidden.get_pixelv(Vector2i(sample)).get_luminance()+0.01,"discovered wall is distinctly brighter than the hidden wall")
	# An integer camera translation must translate every depth layer as one image.
	game.camera_pos = game.center(game.rooms[1].get_center())
	view.sync(game)
	background_only(view)
	var baseline: Image = await rendered(view)
	baseline.save_png("res://docs/validation/art/room.png")
	var origin: Vector2 = game.camera_pos
	for offset in [Vector2(16,0),Vector2(0,16.0/cos(deg_to_rad(25))),Vector2(-16,-16.0/cos(deg_to_rad(25)))]:
		game.camera_pos = origin+offset
		view.sync(game)
		background_only(view)
		var moved: Image = await rendered(view)
		var shift := Vector2i(offset*game.view_scale())
		var maximum := 0.0
		var changed := 0
		var samples := 0
		for y in range(64,baseline.get_height()-64,3):
			for x in range(64,baseline.get_width()-64,3):
				var a := baseline.get_pixel(x+shift.x,y+shift.y)
				var b := moved.get_pixel(x,y)
				var difference: float = maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
				maximum = maxf(maximum,difference)
				if difference>2.0/255: changed += 1
				samples += 1
		print("Translated background ",shift," max difference ",maximum*255,"/255; changed samples ",changed,"/",samples)
		check(maximum<=8.0/255 and changed<float(samples)*0.001,"camera motion translates glass without swimming, deformation or sorting pops")
	print("Background rebuild ms: ",view.last_rebuild_ms)
	game.free()
	if failures == 0: print("PASS: hidden front walls, discovery hierarchy and coherent moving glass layers")
	quit(1 if failures else 0)
