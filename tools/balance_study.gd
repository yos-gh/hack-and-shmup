extends SceneTree
## Reproducible combat measurements. Protected fixtures are not human survival estimates.
const Balance = preload("res://scripts/combat_balance.gd")
const Catalog = preload("res://scripts/combat_catalog.gd")
const Generator = preload("res://scripts/floor_generator.gd")
const Settings = preload("res://scripts/floor_settings.gd")
var fixture = preload("res://tools/balance_fixture.gd").new()
var rows: Array = []
var options := {"depth":"0", "output":"res://docs/validation/high-floor", "mode":"boss", "frames":"2100", "scatter_distance":"120"}

func _initialize() -> void: call_deferred("run")

func write_json(name: String, value) -> void:
	var file := FileAccess.open(options.output + "/" + name, FileAccess.WRITE)
	file.store_string(JSON.stringify(value, "\t"))

func tables() -> void:
	var generator := Generator.new()
	var settings := Settings.new()
	var table: Array = []
	var rooms: Array = []
	for depth in [1,20,30,40,50,60,80,100,104]:
		var power: float = Balance.reference_power(depth)
		var rate: float = Balance.reference_rate(depth)
		var hp := {}
		for kind in Catalog.ENEMIES: hp[str(kind)] = Balance.mob_health(kind,depth)
		var sub: Array = []
		for weapon in range(3):
			var definition = Catalog.WEAPONS[weapon]
			sub.append({"weapon":weapon,"damage_per_hit":power*definition.damage,"cooldown_base":definition.cooldown,"cooldown_max_recharge":definition.cooldown/1.5,"hits_to_chaser":ceili(hp["0"]/(power*definition.damage))})
		table.append({"depth":depth,"hp":hp,"power":power,"rate":rate,"primary_dps":Balance.primary_dps(power,rate),"sub":sub})
		settings.depth = depth - 1 if depth % 5 == 0 else depth
		for seed_value in [7,93,19045]:
			var data = generator.generate(settings,seed_value)
			for room in range(data.rooms.size()):
				var counts := {"0":0,"1":0,"2":0,"4":0,"5":0}
				for enemy in data.enemies:
					if enemy.room == room: counts[str(enemy.kind)] += 1
				rooms.append({"reference_depth":depth,"actual_depth":settings.depth,"seed":seed_value,"room":room,"counts":counts})
	write_json("tables.json",table)
	write_json("rooms.json",rooms)

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		var pair := argument.trim_prefix("--").split("=",true,1)
		if pair.size() != 2 or not options.has(pair[0]): printerr("Invalid option: ",argument); quit(2); return
		options[pair[0]] = pair[1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(options.output))
	if options.mode == "tables": tables(); print("PASS: balance tables generated"); quit(); return
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.depth_view.set_process(false)
	var depths: Array = [5,15,30,50,80,100] if options.mode == "boss" else [29,31,39,49,59,79,99,104]
	if int(options.depth) > 0: depths = [int(options.depth)]
	for depth in depths:
		for build in ["standard","primary","sub"]:
			for variant in (range(3) if options.mode == "boss" else [-1]):
				for weapon in range(3):
					for protected in [true,false]:
						rows.append(fixture.measure(game,depth,build,variant,weapon,protected,int(options.frames),float(options.scatter_distance)))
		write_json("%s-%d.json" % [options.mode,depth], rows.filter(func(row): return row.depth == depth))
		print("MEASURED: ",options.mode," depth ",depth)
		await process_frame
	game.free()
	print("PASS: measurements recorded, including failures; human difficulty remains a playtest question")
	quit()
