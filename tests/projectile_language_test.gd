extends SceneTree
const Fixture = preload("res://tools/balance_fixture.gd")
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: "+message)
		failures += 1
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.depth_view.set_process(false)
	for variant in range(3):
		Fixture.new().configure(game,25,"standard",variant,0)
		var e: Dictionary = game.enemies[0]
		for pattern in ["radial","weave","fan","direct"]:
			game.bullets.clear()
			game.boss.emit_salvo(game,{"owner":e,"aim":Vector2.LEFT,"offsets":PackedFloat32Array([-0.1,0,0.1]),"speed":165.0,"pattern":pattern})
			for b in game.bullets:
				check(game.Catalog.projectile_shape(b) == ("pearl" if pattern in ["radial","weave"] else "needle"),"shape follows the firing role across bosses, not speed")
				check(is_equal_approx(b.v.length(),165.0) and b.damage == 1 and b.hostile,"presentation classification preserves projectile mechanics")
		game.bullets.clear()
		game.boss.emit_salvo(game,{"owner":e,"aim":Vector2.LEFT,"offsets":PackedFloat32Array([0]),"speed":165.0,"guided":true})
		check(game.Catalog.projectile_shape(game.bullets[0]) == "seeker","shared guided volleys retain the finned shape")
	game.free()
	if failures == 0: print("PASS: shared projectile language preserves attack behavior")
	quit(1 if failures else 0)
