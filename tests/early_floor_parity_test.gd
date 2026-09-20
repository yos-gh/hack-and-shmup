extends SceneTree
## Baseline: generator/data/queries at 26808167aeefc865780d09b872fe821caf185d4e.
const Settings = preload("res://scripts/floor_settings.gd")
const FIXTURE = "res://tests/fixtures/early_floor_baseline.json"
func _initialize() -> void: call_deferred("run")
func digest(data) -> String:
	var bytes := var_to_bytes([data.cells,data.rooms,data.room_shapes,data.entrances,data.enemies,data.room_links,data.corridor_cells,data.spawn_point,data.stairs,data.goal_room,data.time_limit,data.rng.state])
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()
func run() -> void:
	var baseline: bool = "--baseline" in OS.get_cmdline_user_args()
	var generator = load("res://docs/validation/high-floor-baseline/generator.gd" if baseline else "res://scripts/floor_generator.gd").new()
	var expected: Dictionary = {} if baseline else JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var results := {}
	var settings := Settings.new()
	for depth in range(1,31):
		if depth % 5 == 0: continue
		settings.depth = depth
		for seed_value in [7,93,19045]:
			var key := "%d:%d" % [depth,seed_value]
			results[key] = digest(generator.generate(settings,seed_value))
			if not baseline and results[key] != expected.get(key, ""):
				push_error("FAIL: early floor changed: " + key)
				quit(1)
				return
	if baseline:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/fixtures"))
		FileAccess.open(FIXTURE,FileAccess.WRITE).store_string(JSON.stringify(results,"\t"))
	print("PASS: ", results.size(), " early floor layout/enemy/timer/RNG digests", " recorded" if baseline else " unchanged")
	quit()
