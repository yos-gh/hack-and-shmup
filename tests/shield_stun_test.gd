extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: " + message)
		failures += 1
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var e: Dictionary = game.enemies[0].duplicate(true)
	e.kind = 2
	e.active = true
	e.p = game.spawn_point
	e.dir = Vector2.RIGHT
	e.charge = 0.01
	e.cd = 0.0
	check(game.shield_velocity(e,0.02,Vector2.UP) == Vector2.ZERO and e.stun == 1.0, "charge completion enters one-second stun")
	game.player = e.p + Vector2.UP * 100
	for i in range(10):
		game.update_awareness(e, e.room, 0.09)
		check(e.dir == Vector2.RIGHT, "shield direction frozen throughout stun")
		check(game.shield_velocity(e,0.09,Vector2.UP) == Vector2.ZERO and e.charge == 0, "no new charge during stun")
	game.shield_velocity(e,0.11,Vector2.UP)
	game.update_awareness(e,e.room,0.01)
	check(e.dir == Vector2.UP, "rotation resumes after stun expires")
	e.p = Vector2(-99999,-99999)
	e.charge = 1.0
	e.stun = 0.0
	game.shield_velocity(e,0.016,Vector2.UP)
	check(e.stun == 1.0 and e.charge == 0 and e.cd == 1.2, "wall ends charge with stun and normal cooldown")
	game.initial_enemies[0].stun = 0.0
	game.enemies[0].stun = 0.8
	game.restart_attempt()
	check(game.enemies[0].stun == 0, "retry resets stun")
	game.title_screen = false
	game.choosing = true
	game.choices.assign([0,1,2])
	var before: float = game.fire_rate
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = game.upgrade_card_rect(game.get_viewport_rect().size,1).get_center()
	game._unhandled_input(click)
	check(game.fire_rate > before and not game.choosing, "centered card hit area selects correct upgrade")
	print("PASS: charge-end and wall stun, frozen shield, recovery, retry and centered card click")
	game.free()
	quit(1 if failures else 0)
