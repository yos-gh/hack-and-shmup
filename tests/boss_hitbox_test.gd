extends SceneTree
const Geometry = preload("res://scripts/boss_geometry.gd")
const Balance = preload("res://scripts/combat_balance.gd")
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: " + message)
		failures += 1
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.title_screen = false
	game.floor_number = 50
	for variant in range(3):
		game.new_floor(variant)
		game.discovered[1] = true
		var enemy: Dictionary = game.enemies[0]
		enemy.p = game.center(Vector2i(14,1))
		game.enemies.assign([enemy])
		game.player = enemy.p + Vector2(180,0)
		game.grace = 999.0
		game.rebuild_enemy_buckets()
		var radius: float = [39.0,67.2,58.0][variant]
		check(is_equal_approx(game.enemy_bullet_radius(enemy),radius), "body-wide radius for each variant")
		for angle in [0.0,PI/4,PI/2,PI,PI*1.5]:
			var direction := Vector2.from_angle(angle)
			check(game.bullet_target(enemy.p+direction*(radius-1)) == enemy, "body edges hit across bucket boundaries")
			check(game.bullet_target(enemy.p+direction*(radius+1)).is_empty(), "outside body misses")
		var initial_hp: float = enemy.hp
		game.emit_shot(enemy.p+Vector2(-radius-8,radius*0.6),Vector2.RIGHT,1050,1,false)
		for frame in range(4): game._physics_process(1.0/60)
		check(enemy.hp < initial_hp, "off-center MG projectile damages full body")
		game.player = enemy.p + Vector2(game.SHOCK_RADIUS+radius*0.5,0)
		game.sub_weapon = 1
		var before: float = enemy.hp
		game.fire_sub(Vector2.LEFT)
		check(enemy.hp < before, "shock hitting hull edge damages boss")
		game.depth_view.sync(game)
		var key: String = ["siege_base","hunter_body","halo_ring"][variant]
		var expected: float = [39.0,53.76,58.0][variant]
		check(is_equal_approx(game.depth_view.batches[key].get_instance_transform(0).basis.x.length(),expected), "render uses shared enlarged dimensions")
	for depth in [45,50]:
		var previous: float = Balance.boss_health(7,3.2,0.5,1,60,30)
		check(is_equal_approx(Balance.boss_health(7,3.2,0.5,1,60,depth),previous*0.75), "VECTOR 45/50 HP exactly 25 percent lower")
	check(Balance.hunter_depth_factor(30)==1.0 and Balance.hunter_depth_factor(31)<1.0, "HP easing starts smoothly after 30")
	# Active shields used to snap instantly; searching and active now share half-speed turning.
	var shield := {"kind":2,"p":Vector2.ZERO,"dir":Vector2.RIGHT,"turn_speed":2.0,"charge":0.0,"stun":0.0,"active":true,"room":1,"notice":1.0,"searching":true,"cd":2.0}
	game.player = Vector2(0,100)
	for active in [true,false]:
		shield.active = active
		shield.dir = Vector2.RIGHT
		game.update_awareness(shield,1,0.1)
		check(is_equal_approx(shield.dir.angle(),0.1), "shield turns at half authored rate in both states")
	shield.active = true
	shield.charge = 0.5
	var direction: Vector2 = shield.dir
	game.update_awareness(shield,1,0.1)
	check(shield.dir == direction, "charge heading remains locked")
	game.free()
	if failures == 0: print("PASS: full-body MG/area hits, bucket edges, model scale, VECTOR HP and half-speed shield turning")
	quit(1 if failures else 0)
