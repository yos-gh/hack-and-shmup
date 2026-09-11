extends SceneTree
const Scenario = preload("res://tools/dev_scenario.gd")
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: "+message)
		failures += 1

func background_only(game) -> void:
	game.depth_view.sync(game)
	for key in game.depth_view.batches:
		if not key.begins_with("bg_") and not key in ["floor","contact","wall_v","wall_h"]:
			game.depth_view.batches[key].visible_instance_count = 0

func run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Camera view test requires a display renderer")
		quit(2)
		return
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	Scenario.configure(game,"normal19",19045,1)
	game.set_depth_view(true)
	game.depth_view.set_process(false)
	DirAccess.make_dir_recursive_absolute("res://docs/validation/camera")
	for angle in [0.0,25.0,35.0]:
		game.set_view_pitch(angle)
		game.camera_pos = game.center(game.rooms[1].get_center())
		var target: Vector2 = game.view_origin()
		game.camera_pos = target
		background_only(game)
		for warmup in range(4):
			await process_frame
			await RenderingServer.frame_post_draw
		var first := PackedByteArray()
		var max_change := 0
		game.camera_pos = target+Vector2(0.04,0.04)
		var camera_origin := Vector3.ZERO
		for frame in range(20):
			game.camera_pos = game.camera_pos.lerp(target,1-exp(-12.0/60))
			background_only(game)
			if frame == 0: camera_origin = game.depth_view.camera.position
			else: check(game.depth_view.camera.position == camera_origin,"subpixel settling does not move the rendered camera")
			await process_frame
			await RenderingServer.frame_post_draw
			var pixels: PackedByteArray = game.depth_view.viewport.get_texture().get_image().get_data()
			if first.is_empty(): first = pixels
			for i in range(pixels.size()): max_change = maxi(max_change,absi(int(first[i])-int(pixels[i])))
		# Allow one quantization level of GPU blending roundoff, not moving edges.
		check(max_change <= 1,"stationary background has no visible edge shimmer at %d degrees" % angle)
		print("Pitch ",angle," settled-background max channel drift: ",max_change,"/255")
		for offset in [Vector2.ZERO,Vector2(240,160),Vector2(-330,-180)]:
			var point: Vector2 = target+offset
			var screen_point: Vector2 = game.world_to_screen(point)
			check(game.screen_to_world(screen_point).distance_to(point)<0.001,"cursor projection round trip")
			var rendered: Vector2 = game.depth_view.camera.unproject_position(game.depth_view.project_point(point))
			check(rendered.distance_to(screen_point)<0.08,"3D ground, bullets and 2D overlays share projection")
			game.replay_input = {"cursor":screen_point}
			check(game.controls.aim(game).dot(game.player.direction_to(point))>0.999,"mouse aims at the displayed world target")
		check(is_zero_approx(game.depth_view.camera.rotation.y) and is_zero_approx(game.depth_view.camera.rotation.z),"pitch introduces no yaw or roll")
		game.depth_view.sync(game)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/validation/camera/tilt-%d.png" % angle)
	for scenario in ["normal19","hunter15"]:
		var baseline := ""
		for angle in [0.0,25.0,35.0]:
			Scenario.configure(game,scenario,19045,1)
			game.set_view_pitch(angle)
			for frame in range(120):
				Scenario.input_frame(game,frame)
				game._physics_process(1.0/60)
				game.depth_view.sync(game)
			if angle == 0: baseline = Scenario.digest(game)
			else: check(Scenario.digest(game) == baseline,"pitch leaves combat/RNG unchanged: "+scenario)
	game.free()
	if failures == 0: print("PASS: stopped-camera stability, pitch projection, cursor aim, no yaw/roll and combat parity")
	quit(1 if failures else 0)
