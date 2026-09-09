extends Node2D

const Catalog = preload("res://scripts/combat_catalog.gd")

const Queries = preload("res://scripts/floor_queries.gd")

const TILE := 32.0
const SPEED := 245.0
const PLAYER_HIT_RADIUS := 5.0
# Enemy timing stays at floor-one values; only population and HP scale.
var ENEMY_MOVE_SPEED: float:
	get: return Catalog.ENEMIES[0].move_speed
var ENEMY_BULLET_SPEED: float:
	get: return Catalog.ENEMIES[1].bullet_speed
var ENEMY_SHOT_INTERVAL: float:
	get: return Catalog.ENEMIES[1].shot_interval
const ENEMY_BUCKET_SIZE := 64.0
const BULLET_HIT_RADIUS := 14.0
const IDLE_UPDATE_PHASES := 6
var KILL_TIME_BONUS: Array:
	get: return Catalog.ENEMIES.map(func(definition): return definition.time_bonus)
var enemy_buckets: Dictionary = {}
var patrol_elapsed: Dictionary = {}
var simulation_tick := 0
var goal_room := 0
var corridor_cells: Dictionary = {}
var room_links: Array[Vector2i] = []
var sound: Node
var audio_mode := 0
var SUB_NAMES: Array:
	get: return Catalog.WEAPONS.map(func(definition): return definition.title)
var SUB_COOLDOWNS: Array:
	get: return Catalog.WEAPONS.map(func(definition): return definition.cooldown)
const ENTRY_CLEARANCE := 96.0
var entrances: Dictionary = {}

var SHOCK_RADIUS: float:
	get: return Catalog.WEAPONS[1].reach
var LANCE_RANGE: float:
	get: return Catalog.WEAPONS[2].reach
var LANCE_WIDTH: float:
	get: return Catalog.WEAPONS[2].width
var initial_enemies: Array[Dictionary]:
	get: return session.floor_snapshot.enemies
	set(value): session.floor_snapshot.enemies = value
var effects: Array[Dictionary] = []
var damage_labels: Array[Dictionary] = []
var room_shapes: Array[int] = []
var pending_respawn: bool:
	get: return session.pending_respawn
	set(value): session.pending_respawn = value
var death_reason := ""
var timeout_banner := 0.0
var time_limit := 0.0
var time_left := 0.0
var route_seconds := 0.0
var floor_start_kills: int:
	get: return session.floor_snapshot.kills
	set(value): session.floor_snapshot.kills = value
var floor_number: int:
	get: return session.run.floor_number
	set(value): session.run.floor_number = value
var deaths: int:
	get: return session.run.deaths
	set(value): session.run.deaths = value
var kills: int:
	get: return session.run.kills
	set(value): session.run.kills = value
var cells: Dictionary = {}
var floor_revision := 0
var depth_view: Node
var depth_enabled := false
var view_comparison := false
var rooms: Array[Rect2i] = []
var discovered: Dictionary = {}
var enemies: Array[Dictionary] = []
var bullets: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var flow: Dictionary = {}
var player := Vector2.ZERO
var spawn_point := Vector2.ZERO
var stairs := Vector2.ZERO
var camera_pos := Vector2.ZERO
var main_cd := 0.0
var sub_cd := 0.0
var sub_cd_total := 0.0
var grace := 0.0
var flow_cd := 0.0
var sub_weapon: int:
	get: return session.run.sub_weapon
	set(value): session.run.sub_weapon = value
var power: float:
	get: return session.run.power
	set(value): session.run.power = value
var fire_rate: float:
	get: return session.run.fire_rate
	set(value): session.run.fire_rate = value
var move_bonus: float:
	get: return session.run.move_bonus
	set(value): session.run.move_bonus = value
var choosing: bool:
	get: return session.choosing
	set(value): session.choosing = value
var paused: bool:
	get: return session.paused
	set(value): session.paused = value
var title_screen: bool:
	get: return session.title_screen
	set(value): session.title_screen = value
var best_cleared: int:
	get: return session.best_cleared
	set(value): session.best_cleared = value
var hit_flash := 0.0
var hit_banner := 0.0
var fire_armed: bool:
	get: return session.fire_armed
	set(value): session.fire_armed = value
var choices: Array[int]:
	get: return session.run.choices
	set(value): session.run.choices = value
var banner := 4.0
var rng := RandomNumberGenerator.new()
var effects_rng := RandomNumberGenerator.new()
# Development replay input. Empty uses the normal keyboard and mouse.
var replay_input: Dictionary = {}
var floor_generator = preload("res://scripts/floor_generator.gd").new()
var session = preload("res://scripts/game_session.gd").new()
var combat_events = preload("res://scripts/combat_events.gd").new()
var combat_feedback = preload("res://scripts/combat_feedback.gd").new()
var controls = preload("res://scripts/player_input.gd").new()
var world_view = preload("res://scripts/world_view.gd").new()
var hud = preload("res://scripts/game_hud.gd").new()
var font := ThemeDB.fallback_font
var boss = preload("res://scripts/boss.gd").new()
var boss_floor := false
var stairs_unlocked := true
var boss_max_hp := 0.0
var boss_variant := 0
var practice = preload("res://scripts/boss_practice.gd").new()

func _ready() -> void:
	sound = preload("res://scripts/sound.gd").new()
	add_child(sound)
	combat_feedback.bind_to(self)
	rng.randomize()
	effects_rng.randomize()
	new_floor()

func tile(p: Vector2) -> Vector2i:
	return Queries.tile(self,p)

func center(p: Vector2i) -> Vector2:
	return Queries.center(self,p)

func new_floor(boss_choice: int = -1) -> void:
	var settings = preload("res://scripts/floor_settings.gd").new()
	settings.depth = floor_number
	settings.move_bonus = move_bonus
	settings.power = power
	settings.fire_rate = fire_rate
	settings.boss_choice = boss_choice
	var generated = floor_generator.generate_from_state(settings,rng.state)
	floor_revision += 1
	cells = generated.cells
	rooms = generated.rooms
	room_shapes = generated.room_shapes
	entrances = generated.entrances
	enemies = generated.enemies
	room_links = generated.room_links
	corridor_cells = generated.corridor_cells
	flow = generated.flow
	spawn_point = generated.spawn_point
	stairs = generated.stairs
	goal_room = generated.goal_room
	boss_floor = generated.boss_floor
	if boss_floor:
		boss_variant = generated.boss_variant
		boss_max_hp = generated.boss_max_hp
	route_seconds = generated.route_seconds
	time_limit = generated.time_limit
	rng.state = generated.rng.state
	session.floor_snapshot.capture(self)
	restart_attempt()

func enemy_health(kind: int, depth: int) -> float:
	return Queries.enemy_health(self,kind,depth)

func enemy_touches_player(e: Dictionary) -> bool:
	if e.kind == 1: return e.p.distance_to(player) < PLAYER_HIT_RADIUS + 12.0
	var half_size := 12.0 if e.kind == 2 else 10.0
	var nearest: Vector2 = player.clamp(e.p-Vector2.ONE*half_size,e.p+Vector2.ONE*half_size)
	return nearest.distance_to(player) < PLAYER_HIT_RADIUS

func update_awareness(e: Dictionary, room_id: int, delta: float) -> void:
	if e.active:
		if e.charge <= 0 and e.get("stun", 0.0) <= 0: e.dir = e.p.direction_to(player)
		return
	if e.room == room_id: e.searching = true
	if not e.searching: return
	e.notice = maxf(0,e.notice-delta)
	var target_angle: float = e.p.angle_to_point(player)
	var angle: float = rotate_toward(e.dir.angle(),target_angle,e.turn_speed*delta)
	e.dir = Vector2.from_angle(angle)
	if e.notice <= 0 and absf(angle_difference(angle,target_angle)) < 0.2 and attack_reaches(e.p,player):
		e.active = true
		if e.kind in [1,2]: e.cd = maxf(e.cd,Catalog.ENEMIES[e.kind].activation_delay)

func entry_safe(p: Vector2, room_id: int) -> bool:
	return Queries.entry_safe(self,p,room_id)

func room_contains(p: Vector2i, r: Rect2i, shape: int) -> bool:
	return Queries.room_contains(self,p,r,shape)

func restart_attempt() -> void:
	session.restart_attempt(self)

func attack_open(p: Vector2) -> bool:
	var c := tile(p)
	return cells.has(c) and (cells[c] == -1 or discovered.has(cells[c]))

func attack_end(origin: Vector2, direction: Vector2, distance: float) -> Vector2:
	var end := origin
	for i in range(1, int(ceil(distance / 4.0)) + 1):
		var next := origin + direction * minf(i * 4.0, distance)
		if not attack_open(next): break
		end = next
	return end

func attack_reaches(origin: Vector2, target: Vector2) -> bool:
	return attack_end(origin, origin.direction_to(target), origin.distance_to(target)).distance_to(target) < 1.0

func fire_sub(aim: Vector2) -> void:
	var definition = Catalog.WEAPONS[sub_weapon]
	sound.play_sfx(definition.sound)
	sub_cd_total = definition.cooldown
	match sub_weapon:
		0:
			for i in range(definition.pellets): emit_shot(player, aim.rotated((i - (definition.pellets-1)*0.5) * definition.spread), definition.speed, power * definition.damage, false, definition.reach)
			sub_cd = sub_cd_total
		1:
			for e in enemies:
				if e.p.distance_to(player) <= SHOCK_RADIUS and attack_reaches(player, e.p):
					hurt_enemy(e, power * definition.damage, player.direction_to(e.p), definition.knockback)
			bullets = bullets.filter(func(b: Dictionary) -> bool: return not (b.hostile and b.p.distance_to(player) <= SHOCK_RADIUS and attack_reaches(player, b.p)))
			effects.append({"kind": 0, "p": player, "end": player, "life": 0.4})
			sub_cd = sub_cd_total
		2:
			var end := attack_end(player, aim, LANCE_RANGE)
			for e in enemies:
				var nearest := Geometry2D.get_closest_point_to_segment(e.p, player, end)
				if nearest.distance_to(e.p) <= LANCE_WIDTH * 0.5 + 12.5 and attack_reaches(player, e.p):
					hurt_enemy(e, power * definition.damage, aim, definition.knockback)
			effects.append({"kind": 1, "p": player, "end": end, "life": 0.28})
			sub_cd = sub_cd_total

func connect_rooms(a: int, b: int) -> void:
	Queries.connect_rooms(self,a,b)

func walkable(p: Vector2, radius: float = 10.0) -> bool:
	return Queries.walkable(self,p,radius)

func slide(p: Vector2, motion: Vector2, radius: float = 10.0) -> Vector2:
	var next := p
	if walkable(next + Vector2(motion.x, 0), radius): next.x += motion.x
	if walkable(next + Vector2(0, motion.y), radius): next.y += motion.y
	return next

func build_flow() -> void:
	Queries.build_flow(self)

func enemy_bucket(p: Vector2) -> Vector2i:
	return Vector2i(floor(p.x / ENEMY_BUCKET_SIZE), floor(p.y / ENEMY_BUCKET_SIZE))

func rebuild_enemy_buckets() -> void:
	enemy_buckets.clear()
	# Insert in enemy order, including every bucket touched by the hit radius.
	# A bullet needs one lookup; overlapping targets keep their original priority.
	for e in enemies:
		if e.hp <= 0: continue
		var lo := enemy_bucket(e.p - Vector2.ONE * BULLET_HIT_RADIUS)
		var hi := enemy_bucket(e.p + Vector2.ONE * BULLET_HIT_RADIUS)
		for y in range(lo.y, hi.y + 1):
			for x in range(lo.x, hi.x + 1):
				var key := Vector2i(x, y)
				if not enemy_buckets.has(key): enemy_buckets[key] = []
				enemy_buckets[key].append(e)

func bullet_target(p: Vector2) -> Dictionary:
	for e in enemy_buckets.get(enemy_bucket(p), []):
		if e.hp > 0 and p.distance_squared_to(e.p) < BULLET_HIT_RADIUS * BULLET_HIT_RADIUS and attack_open(e.p):
			return e
	return {}

func cycle_audio() -> void:
	audio_mode = (audio_mode + 1) % 3
	sound.set_audio_mode(audio_mode)
	queue_redraw()

func audio_button_rect() -> Rect2:
	return Rect2(get_viewport_rect().size.x-390,22,172,42)

func start_run() -> void:
	session.start_run(self)

func return_to_title() -> void:
	session.return_to_title(self)

func _unhandled_input(event: InputEvent) -> void:
	controls.handle_event(self,event)

func upgrade(index: int) -> void:
	apply_upgrade(choices[index])
	floor_number += 1
	new_floor()

func apply_upgrade(kind: int) -> void:
	session.run.apply_upgrade(kind)

func shield_velocity(e: Dictionary, delta: float, toward: Vector2) -> Vector2:
	if e.get("stun", 0.0) > 0:
		e.stun = maxf(0.0, e.stun - delta)
		return Vector2.ZERO
	if e.charge > 0:
		e.charge = maxf(0.0, e.charge - delta)
		var velocity: Vector2 = e.dir * Catalog.ENEMIES[2].charge_speed
		var hit_wall := not walkable(e.p + velocity * delta)
		if e.charge <= 0 or hit_wall:
			if hit_wall: e.cd = Catalog.ENEMIES[2].wall_recovery
			e.charge = 0.0
			e.stun = Catalog.ENEMIES[2].stun_duration
			return Vector2.ZERO
		return velocity
	if e.cd <= 0:
		e.dir = toward
		e.charge = Catalog.ENEMIES[2].charge_duration
		e.cd = Catalog.ENEMIES[2].charge_recovery
	return Vector2.ZERO

func emit_shot(p: Vector2, direction: Vector2, speed: float, damage: float, hostile: bool, distance: float = 10000.0) -> void:
	bullets.append({"p": p, "v": direction * speed, "damage": damage, "hostile": hostile, "life": distance / speed})

func burst(p: Vector2, color: Color, count: int = 8) -> void:
	for i in range(count):
		particles.append({"p": p, "v": Vector2.from_angle(effects_rng.randf() * TAU) * effects_rng.randf_range(30, 180), "life": 0.35, "color": color})

func hurt_enemy(e: Dictionary, damage: float, direction: Vector2, knockback: float = 180.0) -> void:
	if e.hp <= 0: return
	if e.kind != 3: e.push += direction * knockback
	if e.kind == 2 and direction.dot(e.dir) < -0.35:
		combat_events.enemy_hit.emit(e.p,0.0,true,false)
		return
	e.hp -= damage
	var killed: bool = e.hp <= 0
	if killed and not boss_floor and e.kind < 3:
		time_left += Catalog.ENEMIES[e.kind].time_bonus
	combat_events.enemy_hit.emit(e.p,damage,false,killed)


func die(reason: String = "HIT") -> void:
	session.die(self, reason)

func _physics_process(delta: float) -> void:
	sound.set_paused(paused)
	if title_screen or paused or choosing:
		queue_redraw()
		return
	if pending_respawn:
		restart_attempt()
		queue_redraw()
		return
	hit_flash = maxf(0,hit_flash-delta)
	hit_banner = maxf(0,hit_banner-delta)
	var primary: bool = controls.primary(self)
	var secondary: bool = controls.secondary(self)
	if not primary and not secondary: fire_armed = true
	timeout_banner = maxf(0, timeout_banner - delta)
	if not boss_floor:
		time_left = maxf(0, time_left - delta)
		sound.update_time_warning(time_left)
		if time_left <= 0:
			die("TIME UP")
			return
	for entry in damage_labels:
		entry.life -= delta
		entry.p.y -= 34.0 * delta
	damage_labels = damage_labels.filter(func(entry: Dictionary) -> bool: return entry.life > 0)
	for effect in effects: effect.life -= delta
	effects = effects.filter(func(effect: Dictionary) -> bool: return effect.life > 0)
	main_cd -= delta
	sub_cd = maxf(0, sub_cd - delta)
	grace = maxf(0, grace - delta)
	banner -= delta
	var movement: Vector2 = controls.movement(self)
	player = slide(player, movement.normalized() * (SPEED + move_bonus) * delta, PLAYER_HIT_RADIUS)
	camera_pos = camera_pos.lerp(player, 1.0 - exp(-12 * delta))
	var room_id: int = cells.get(tile(player), -1)
	if room_id >= 0: discovered[room_id] = true
	var aim: Vector2 = controls.aim(self)
	if fire_armed and primary and main_cd <= 0:
		emit_shot(player, aim.rotated(rng.randf_range(-Catalog.PRIMARY.spread, Catalog.PRIMARY.spread)), Catalog.PRIMARY.speed, power*Catalog.PRIMARY.damage, false, Catalog.PRIMARY.reach)
		sound.play_sfx(Catalog.PRIMARY.sound)
		main_cd = Catalog.PRIMARY.cooldown / fire_rate
	if fire_armed and secondary and sub_cd <= 0:
		fire_sub(aim)
	flow_cd -= delta
	if flow_cd <= 0 and flow.get(tile(player), Vector2i(-999999, -999999)) != tile(player):
		build_flow()
		flow_cd = 0.22
	simulation_tick += 1
	for i in range(1, rooms.size()):
		patrol_elapsed[i] = patrol_elapsed.get(i, 0.0) + delta
	for e in enemies:
		if e.hp <= 0: continue
		var enemy_delta := delta
		# Unseen patrols run at 10 Hz, staggered by room. Entered rooms and
		# pursuing enemies retain full-rate reactions, motion and collisions.
		if not e.active and not e.searching and not discovered.has(e.room) and e.push == Vector2.ZERO:
			if (simulation_tick + e.room) % IDLE_UPDATE_PHASES != 0: continue
			enemy_delta = patrol_elapsed.get(e.room, delta)
		update_awareness(e, room_id, delta)
		if e.active: e.cd -= delta
		var toward: Vector2 = (player - e.p).normalized()
		var velocity := Vector2.ZERO
		if e.active:
			if e.kind == 1:
				if e.cd <= 0:
					emit_shot(e.p, toward, ENEMY_BULLET_SPEED, 1, true)
					e.cd = ENEMY_SHOT_INTERVAL
			elif e.kind == 2:
				velocity = shield_velocity(e, delta, toward)
			elif e.kind == 3:
				velocity = boss.enemy_velocity(self,e,delta,toward)
			else:
				var c := tile(e.p)
				var target: Vector2 = player if c == tile(player) else center(flow.get(c, c))
				velocity = (target - e.p).normalized() * ENEMY_MOVE_SPEED
		elif not e.searching and e.kind != 3:
			velocity = e.dir * Catalog.ENEMIES[e.kind].patrol_speed
		var next_position := slide(e.p, (velocity + e.push) * enemy_delta)
		# Unalerted patrols must not drift back into the entrance buffer.
		if e.active or entry_safe(next_position, e.room): e.p = next_position
		e.push = e.push.move_toward(Vector2.ZERO, 600 * delta)
		if enemy_touches_player(e):
			die()
			if pending_respawn: return
	for i in range(1, rooms.size()):
		if discovered.has(i) or (simulation_tick + i) % IDLE_UPDATE_PHASES == 0:
			patrol_elapsed[i] = 0.0
	enemies.append_array(boss.pending_summons)
	boss.pending_summons.clear()
	rebuild_enemy_buckets()
	for b in bullets:
		b.life -= delta
		if b.get("homing_time",0.0) > 0:
			var heading: float = rotate_toward(b.v.angle(),b.p.angle_to_point(player)+b.get("homing_offset",0.0),b.get("turn_rate",1.1)*minf(delta,b.homing_time))
			b.v = Vector2.from_angle(heading)*b.v.length()
			b.homing_time = maxf(0.0,b.homing_time-delta)
		var travel: Vector2 = b.v * delta
		var steps := maxi(1, int(ceil(travel.length() / 7)))
		for step in range(steps):
			b.p += travel / steps
			if not attack_open(b.p): b.life = 0; break
			if b.hostile:
				if b.p.distance_to(player) < PLAYER_HIT_RADIUS + 2.0:
					die()
					if pending_respawn: return
					b.life = 0
					break
			else:
				var target := bullet_target(b.p)
				if not target.is_empty():
					hurt_enemy(target, b.damage, b.v.normalized())
					b.life = 0
			if b.life <= 0: break
	bullets = bullets.filter(func(b: Dictionary) -> bool: return b.life > 0)
	for e in enemies:
		if e.hp <= 0: kills += 1; burst(e.p, Color("ff647c"), 12)
	enemies = enemies.filter(func(e: Dictionary) -> bool: return e.hp > 0)
	if boss_floor and not stairs_unlocked and boss.remaining(self) == 0:
		stairs_unlocked = true
		enemies.clear()
		boss.reset()
		bullets = bullets.filter(func(b: Dictionary) -> bool: return not b.hostile)
		banner = 3.0
	if boss_floor:
		boss.advance_attacks(self,delta)
		if pending_respawn: return
	for p in particles:
		p.life -= delta
		p.p += p.v * delta
	particles = particles.filter(func(p: Dictionary) -> bool: return p.life > 0)
	if stairs_unlocked and player.distance_to(stairs) < 24:
		if practice.active:
			practice.open(self)
			return
		choices.assign([0, 1, 2, 3])
		choices.shuffle()
		choices.resize(3)
		sound.play_sfx("clear")
		best_cleared = maxi(best_cleared, floor_number)
		choosing = true
	queue_redraw()

func label_at(p: Vector2, value: String, size: int = 18, color: Color = Color.WHITE) -> void:
	hud.label_at(self, p, value, size, color)

func attack_warning(e: Dictionary) -> float:
	if not e.active or e.charge > 0 or e.get("stun",0.0) > 0 or e.kind == 0: return 0.0
	if e.kind == 3: return boss.warning(e)
	var duration: float = Catalog.ENEMIES[e.kind].warning_duration
	return clampf(1.0-e.cd/duration,0.0,1.0)

func _draw() -> void:
	var screen := get_viewport_rect().size
	if title_screen:
		hud.draw_title(self, screen)
		return
	world_view.draw(self, screen)
	hud.draw(self, screen)

func set_depth_view(enabled: bool) -> void:
	if enabled and depth_view == null:
		depth_view = preload("res://scripts/depth_view.gd").new()
		add_child(depth_view)
	depth_enabled = enabled
	if depth_view != null: depth_view.set_active(enabled)
	queue_redraw()



func menu_origin_y(screen: Vector2, is_pause: bool) -> float:
	var top := -30.0 - font.get_ascent(28) if is_pause else -130.0 - font.get_ascent(24)
	return (screen.y - top - 275.0) * 0.5

func upgrade_card_rect(screen: Vector2, index: int) -> Rect2:
	return Rect2(screen.x / 2 - 450 + index * 310, menu_origin_y(screen, false) - 40, 290, 150)

func player_stats() -> Array[Dictionary]:
	return [
		{"name":"DAMAGE", "value":"%.2fx" % power, "detail":"+%.0f%%" % ((power - 1.0) * 100.0)},
		{"name":"FIRE RATE", "value":"%.2fx" % fire_rate, "detail":"+%.0f%%" % ((fire_rate - 1.0) * 100.0)},
		{"name":"MOVE SPEED", "value":"%.0f" % (SPEED + move_bonus), "detail":"+%.0f" % move_bonus}
	]

func centered_title_label(screen: Vector2, y: float, value: String, size: int, color: Color = Color.WHITE) -> void:
	hud.centered_title_label(self, screen, y, value, size, color)

func fullscreen_button_rect() -> Rect2:
	return Rect2(get_viewport_rect().size.x-202,22,180,42)

func toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode in [DisplayServer.WINDOW_MODE_FULLSCREEN,DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN] else DisplayServer.WINDOW_MODE_FULLSCREEN)
	queue_redraw()
