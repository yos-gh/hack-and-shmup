extends Node2D

const TILE := 32.0
const SPEED := 245.0
const PLAYER_HIT_RADIUS := 5.0
# Enemy timing stays at floor-one values; only population and HP scale.
const ENEMY_MOVE_SPEED := 86.0
const ENEMY_BULLET_SPEED := 238.0
const ENEMY_SHOT_INTERVAL := 1.665
const ENEMY_BUCKET_SIZE := 64.0
const BULLET_HIT_RADIUS := 14.0
const IDLE_UPDATE_PHASES := 6
const KILL_TIME_BONUS := [0.1, 0.2, 0.3]
var enemy_buckets: Dictionary = {}
var patrol_elapsed: Dictionary = {}
var simulation_tick := 0
var goal_room := 0
var corridor_cells: Dictionary = {}
var room_links: Array[Vector2i] = []
var sound: Node
var audio_mode := 0
const SUB_NAMES := ["SCATTER", "SHOCKWAVE", "LANCE"]
const ENTRY_CLEARANCE := 96.0
var entrances: Dictionary = {}

const SHOCK_RADIUS := 165.0
const LANCE_RANGE := 520.0
const LANCE_WIDTH := 39.0
var initial_enemies: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var damage_labels: Array[Dictionary] = []
var room_shapes: Array[int] = []
var pending_respawn := false
var death_reason := ""
var timeout_banner := 0.0
var time_limit := 0.0
var time_left := 0.0
var route_seconds := 0.0
var floor_start_kills := 0
var floor_number := 1
var deaths := 0
var kills := 0
var cells: Dictionary = {}
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
var grace := 0.0
var flow_cd := 0.0
var sub_weapon := 0
var power := 1.0
var fire_rate := 1.0
var move_bonus := 0.0
var choosing := false
var paused := false
var title_screen := true
var best_cleared := 0
var hit_flash := 0.0
var hit_banner := 0.0
var fire_armed := false
var choices: Array[int] = []
var banner := 4.0
var rng := RandomNumberGenerator.new()
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
	rng.randomize()
	new_floor()

func tile(p: Vector2) -> Vector2i:
	return Vector2i(floor(p.x / TILE), floor(p.y / TILE))

func center(p: Vector2i) -> Vector2:
	return Vector2(p) * TILE + Vector2.ONE * TILE * 0.5

func new_floor(boss_choice: int = -1) -> void:
	cells.clear()
	rooms.clear()
	room_shapes.clear()
	entrances.clear()
	effects.clear()
	damage_labels.clear()
	discovered.clear()
	enemies.clear()
	bullets.clear()
	particles.clear()
	room_links.clear()
	corridor_cells.clear()
	boss_floor = floor_number % 5 == 0
	if boss_floor:
		boss_variant = rng.randi_range(0,2) if boss_choice < 0 else clampi(boss_choice,0,2)
		boss.build(self)
		return
	# Scatter larger rooms without overlap, then connect a spanning tree and loops.
	var target_count := rng.randi_range(7, 10)
	for attempt in range(600):
		if rooms.size() >= target_count: break
		var r := Rect2i(rng.randi_range(-52, 52), rng.randi_range(-44, 44), rng.randi_range(18, 25), rng.randi_range(16, 22))
		var overlaps := false
		for other in rooms:
			if r.grow(5).intersects(other): overlaps = true; break
		if overlaps: continue
		rooms.append(r)
		var shape := rng.randi_range(0, 4)
		room_shapes.append(shape)
		for cy in range(r.position.y, r.end.y):
			for cx in range(r.position.x, r.end.x):
				if room_contains(Vector2i(cx,cy),r,shape): cells[Vector2i(cx,cy)] = rooms.size() - 1
	var connected: Array[int] = [0]
	while connected.size() < rooms.size():
		var best := Vector2i(-1,-1)
		var best_distance := INF
		for a in connected:
			for b in range(rooms.size()):
				if b in connected: continue
				var distance := Vector2(rooms[a].get_center()).distance_squared_to(Vector2(rooms[b].get_center()))
				if distance < best_distance: best_distance = distance; best = Vector2i(a,b)
		connect_rooms(best.x,best.y)
		room_links.append(best)
		connected.append(best.y)
	for extra in range(2):
		var a := rng.randi_range(0,rooms.size()-1)
		var b := rng.randi_range(0,rooms.size()-1)
		if a != b and not Vector2i(a,b) in room_links and not Vector2i(b,a) in room_links:
			connect_rooms(a,b)
			room_links.append(Vector2i(a,b))
	for i in range(rooms.size()):
		var r := rooms[i]
		var c := r.get_center()
		var obstacle_candidates: Array[Vector2i] = []
		for cell in cells:
			if cells[cell] == i and not corridor_cells.has(cell) and absi(cell.x-c.x)>2 and absi(cell.y-c.y)>2:
				obstacle_candidates.append(cell)
		for n in range(mini(18,obstacle_candidates.size())):
			var pick := rng.randi_range(0,obstacle_candidates.size()-1)
			cells.erase(obstacle_candidates[pick])
			obstacle_candidates.remove_at(pick)
	spawn_point = center(rooms[0].get_center())
	player = spawn_point
	build_flow()
	# Remove isolated pockets left by obstacles, before choosing enemy positions.
	for c in cells.keys():
		if not flow.has(c): cells.erase(c)
	goal_room = 1
	var longest := 0
	for i in range(1,rooms.size()):
		var cursor := rooms[i].get_center()
		var distance := 0
		while cursor != tile(spawn_point) and flow.has(cursor):
			cursor = flow[cursor]
			distance += 1
		if distance > longest: longest = distance; goal_room = i
	stairs = center(rooms[goal_room].get_center())
	for i in range(1,rooms.size()):
		entrances[i] = []
		for cell in cells:
			if cells[cell] != i: continue
			for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				if cells.has(cell+d) and cells[cell+d] != i:
					entrances[i].append(center(cell))
					break
		var candidates: Array[Vector2i] = []
		for cell in cells:
			if cells[cell] == i and entry_safe(center(cell),i): candidates.append(cell)
		for n in range(mini(18+floor_number*4,85)):
			if candidates.is_empty(): break
			var candidate_index := rng.randi_range(0,candidates.size()-1)
			var p := candidates[candidate_index]
			candidates.remove_at(candidate_index)
			var kind := 0
			if n % 7 == 0: kind = 1
			elif n % 11 == 0: kind = 2
			enemies.append({"p":center(p), "kind":kind, "hp":enemy_health(kind, floor_number),
				"room":i, "active":false, "searching":false, "notice":rng.randf_range(0.35,0.85), "turn_speed":rng.randf_range(1.8,3.8),
				"cd":rng.randf_range(0.25,0.65), "charge":0.0, "stun":0.0, "dir":Vector2.from_angle(rng.randf()*TAU), "push":Vector2.ZERO})
	initial_enemies = enemies.duplicate(true)
	floor_start_kills = kills
	player = spawn_point
	build_flow()
	var cursor := tile(stairs)
	var steps := 0
	while cursor != tile(spawn_point) and flow.has(cursor):
		cursor = flow[cursor]
		steps += 1
	# Budget follows the actual navigable shortest route and current movement speed.
	route_seconds = steps * TILE / (SPEED + move_bonus)
	time_limit = (route_seconds * 1.35 + 2.0) * 1.5
	restart_attempt()

func enemy_health(kind: int, depth: int) -> float:
	if kind == 2: return 1.0
	# Preserve floor-one HP and interpolate to the requested floor-15 targets.
	return lerpf(2.3, 4.0, (depth - 1) / 14.0) if kind == 0 else 1.0 + (depth - 1) / 14.0

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
		if e.kind in [1,2]: e.cd = maxf(e.cd,0.55)

func entry_safe(p: Vector2, room_id: int) -> bool:
	if cells.get(tile(p), -1) != room_id: return false
	for entrance in entrances.get(room_id, []):
		if p.distance_to(entrance) < ENTRY_CLEARANCE: return false
	return walkable(p)

func room_contains(p: Vector2i, r: Rect2i, shape: int) -> bool:
	var local := p - r.position
	var mid := r.get_center() - r.position
	var dx := absi(local.x - mid.x)
	var dy := absi(local.y - mid.y)
	match shape:
		1: return local.x <= mid.x + 1 or local.y >= mid.y - 1 # L
		2: return dx <= 4 or dy <= 4 # cross
		3: return float(dx) / (r.size.x * 0.5) + float(dy) / (r.size.y * 0.5) < 1.35 # bevelled
		4: return dy <= 3 or local.x < 6 or local.x >= r.size.x - 6 # two chambers
	return true

func restart_attempt() -> void:
	boss.reset()
	stairs_unlocked = not boss_floor
	enemies = initial_enemies.duplicate(true)
	enemy_buckets.clear()
	patrol_elapsed.clear()
	simulation_tick = 0
	bullets.clear()
	particles.clear()
	effects.clear()
	damage_labels.clear()
	discovered.clear()
	discovered[0] = true
	player = spawn_point
	camera_pos = player
	kills = floor_start_kills
	main_cd = 0.0
	sub_cd = 0.0
	grace = 1.0
	flow_cd = 0.0
	pending_respawn = false
	time_left = time_limit
	banner = 3.0
	choosing = false

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
	sound.play_sfx(["scatter","shock","lance"][sub_weapon])
	match sub_weapon:
		0:
			for i in range(13): emit_shot(player, aim.rotated((i - 6) * 0.075), 850, power * 2.5, false, 320)
			sub_cd = 1.1
		1:
			for e in enemies:
				if e.p.distance_to(player) <= SHOCK_RADIUS and attack_reaches(player, e.p):
					hurt_enemy(e, power * 3, player.direction_to(e.p), 650.0)
			bullets = bullets.filter(func(b: Dictionary) -> bool: return not (b.hostile and b.p.distance_to(player) <= SHOCK_RADIUS and attack_reaches(player, b.p)))
			effects.append({"kind": 0, "p": player, "end": player, "life": 0.4})
			sub_cd = 2.0
		2:
			var end := attack_end(player, aim, LANCE_RANGE)
			for e in enemies:
				var nearest := Geometry2D.get_closest_point_to_segment(e.p, player, end)
				if nearest.distance_to(e.p) <= LANCE_WIDTH * 0.5 + 12.5 and attack_reaches(player, e.p):
					hurt_enemy(e, power * 9, aim, 260.0)
			effects.append({"kind": 1, "p": player, "end": end, "life": 0.28})
			sub_cd = 1.7

func connect_rooms(a: int, b: int) -> void:
	var p := rooms[a].get_center()
	var goal := rooms[b].get_center()
	while p != goal:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				corridor_cells[p + Vector2i(dx,dy)] = true
				if not cells.has(p + Vector2i(dx, dy)):
					cells[p + Vector2i(dx, dy)] = -1
		if p.x != goal.x: p.x += 1 if goal.x > p.x else -1
		else: p.y += 1 if goal.y > p.y else -1

func walkable(p: Vector2, radius: float = 10.0) -> bool:
	for offset in [Vector2(-radius,-radius), Vector2(radius,-radius), Vector2(-radius,radius), Vector2(radius,radius)]:
		if not cells.has(tile(p + offset)): return false
	return true

func slide(p: Vector2, motion: Vector2, radius: float = 10.0) -> Vector2:
	var next := p
	if walkable(next + Vector2(motion.x, 0), radius): next.x += motion.x
	if walkable(next + Vector2(0, motion.y), radius): next.y += motion.y
	return next

func build_flow() -> void:
	flow.clear()
	var start := tile(player)
	flow[start] = start
	var queue: Array[Vector2i] = [start]
	var index := 0
	while index < queue.size():
		var c := queue[index]
		index += 1
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if cells.has(n) and not flow.has(n):
				flow[n] = c
				queue.append(n)

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
	practice.active = false
	practice.selecting = false
	floor_number = 1
	kills = 0
	deaths = 0
	power = 1.0
	fire_rate = 1.0
	move_bonus = 0.0
	sub_weapon = 0
	title_screen = false
	paused = false
	fire_armed = false
	timeout_banner = 0
	hit_banner = 0
	hit_flash = 0
	sound.set_paused(false)
	new_floor()

func return_to_title() -> void:
	practice.active = false
	practice.selecting = false
	title_screen = true
	paused = false
	choosing = false
	pending_respawn = false
	sound.set_paused(false)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if practice.selecting:
		practice.input(self,event)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			cycle_audio()
			return
		if title_screen:
			if event.keycode in [KEY_ENTER, KEY_SPACE]: start_run()
			elif event.keycode == KEY_B: practice.open(self)
			elif event.keycode == KEY_ESCAPE and not OS.has_feature("web"): get_tree().quit()
			return
		if practice.active and event.keycode == KEY_B:
			practice.open(self)
			return
		if practice.active and event.keycode == KEY_R:
			restart_attempt()
			return
		if event.keycode == KEY_ESCAPE:
			if paused: return_to_title()
			else: paused = true
			return
		if paused: return
		if event.keycode == KEY_Q: sub_weapon = (sub_weapon + 2) % 3
		if event.keycode == KEY_E: sub_weapon = (sub_weapon + 1) % 3
		if choosing and event.keycode >= KEY_1 and event.keycode <= KEY_3:
			upgrade(event.keycode - KEY_1)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
			if title_screen:
				if audio_button_rect().has_point(event.position):
					if event.button_index == MOUSE_BUTTON_LEFT: cycle_audio()
				elif fullscreen_button_rect().has_point(event.position):
					if event.button_index == MOUSE_BUTTON_LEFT: toggle_fullscreen()
				else: start_run()
				return
			if paused:
				paused = false
				fire_armed = false
				sound.set_paused(false)
				return
		if title_screen or paused: return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: sub_weapon = (sub_weapon + 1) % 3
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: sub_weapon = (sub_weapon + 2) % 3
		if choosing and event.button_index == MOUSE_BUTTON_LEFT:
			var s := get_viewport_rect().size
			for i in range(3):
				if upgrade_card_rect(s, i).has_point(event.position):
					fire_armed = false
					upgrade(i)
					return

func upgrade(index: int) -> void:
	apply_upgrade(choices[index])
	floor_number += 1
	new_floor()

func apply_upgrade(kind: int) -> void:
	match kind:
		0: power += 0.35
		1: fire_rate += 0.2
		2: move_bonus += 20.0
		3: power += 0.2; move_bonus += 10.0

func shield_velocity(e: Dictionary, delta: float, toward: Vector2) -> Vector2:
	if e.get("stun", 0.0) > 0:
		e.stun = maxf(0.0, e.stun - delta)
		return Vector2.ZERO
	if e.charge > 0:
		e.charge = maxf(0.0, e.charge - delta)
		var velocity: Vector2 = e.dir * 410
		var hit_wall := not walkable(e.p + velocity * delta)
		if e.charge <= 0 or hit_wall:
			if hit_wall: e.cd = 1.2
			e.charge = 0.0
			e.stun = 1.0
			return Vector2.ZERO
		return velocity
	if e.cd <= 0:
		e.dir = toward
		e.charge = 1.8
		e.cd = 2.7
	return Vector2.ZERO

func emit_shot(p: Vector2, direction: Vector2, speed: float, damage: float, hostile: bool, distance: float = 10000.0) -> void:
	bullets.append({"p": p, "v": direction * speed, "damage": damage, "hostile": hostile, "life": distance / speed})

func burst(p: Vector2, color: Color, count: int = 8) -> void:
	for i in range(count):
		particles.append({"p": p, "v": Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(30, 180), "life": 0.35, "color": color})

func hurt_enemy(e: Dictionary, damage: float, direction: Vector2, knockback: float = 180.0) -> void:
	if e.hp <= 0: return
	if e.kind != 3: e.push += direction * knockback
	if e.kind == 2 and direction.dot(e.dir) < -0.35:
		sound.play_sfx("shield")
		burst(e.p, Color.SKY_BLUE, 3)
		return
	if e.hp <= 0: return
	var offset := Vector2((damage_labels.size() % 3 - 1) * 13, -18)
	damage_labels.append({"p": e.p + offset, "damage": damage, "life": 0.65})
	if damage_labels.size() > 96: damage_labels.pop_front()
	e.hp -= damage
	if e.hp <= 0:
		if not boss_floor and e.kind < 3: time_left += KILL_TIME_BONUS[e.kind]
		sound.play_sfx("kill")
	burst(e.p, Color("ff647c"), 3)

func die(reason: String = "HIT") -> void:
	if pending_respawn or (grace > 0 and reason != "TIME UP"): return
	deaths += 1
	sound.play_sfx("timeout" if reason == "TIME UP" else "death")
	if reason == "TIME UP": timeout_banner = 1.0
	else:
		hit_flash = 0.25
		hit_banner = 0.8
	death_reason = reason
	pending_respawn = true
	queue_redraw()

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
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT): fire_armed = true
	timeout_banner = maxf(0, timeout_banner - delta)
	if not boss_floor:
		time_left = maxf(0, time_left - delta)
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
	var movement := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	player = slide(player, movement.normalized() * (SPEED + move_bonus) * delta, PLAYER_HIT_RADIUS)
	camera_pos = camera_pos.lerp(player, 1.0 - exp(-12 * delta))
	var room_id: int = cells.get(tile(player), -1)
	if room_id >= 0: discovered[room_id] = true
	var aim := (get_global_mouse_position() - get_viewport_rect().size * 0.5 + camera_pos - player).normalized()
	if fire_armed and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and main_cd <= 0:
		emit_shot(player, aim.rotated(rng.randf_range(-0.025, 0.025)), 1050, power, false)
		sound.play_sfx("shot")
		main_cd = 0.09 / fire_rate
	if fire_armed and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and sub_cd <= 0:
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
			velocity = e.dir * 18
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

func draw_radial_fill(origin: Vector2, outline: PackedVector2Array, color: Color) -> void:
	for i in range(outline.size() - 1):
		if absf((outline[i] - origin).cross(outline[i + 1] - origin)) > 0.01:
			draw_colored_polygon(PackedVector2Array([origin, outline[i], outline[i + 1]]), color)

func label_at(p: Vector2, value: String, size: int = 18, color: Color = Color.WHITE) -> void:
	draw_string(font, p, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func attack_warning(e: Dictionary) -> float:
	if not e.active or e.charge > 0 or e.get("stun",0.0) > 0 or e.kind == 0: return 0.0
	if e.kind == 3: return boss.warning(e)
	var duration := 0.45 if e.kind == 1 else (0.55 if e.kind == 2 else 0.6)
	return clampf(1.0-e.cd/duration,0.0,1.0)

func _draw() -> void:
	var screen := get_viewport_rect().size
	if title_screen:
		draw_title(screen)
		return
	var offset := screen * 0.5 - camera_pos
	draw_set_transform(offset)
	var view := Rect2(-offset - Vector2(32,32), screen + Vector2(64,64))
	for c in cells:
		var p := Vector2(c) * TILE
		if not view.has_point(p): continue
		var id: int = cells[c]
		var visible := id == -1 or discovered.has(id)
		var color := Color("182735") if visible else Color("0b121c")
		draw_rect(Rect2(p + Vector2.ONE, Vector2.ONE * 30), color)
		for d in [Vector2i.UP, Vector2i.LEFT, Vector2i.DOWN, Vector2i.RIGHT]:
			if not cells.has(c + d):
				var edge := p + Vector2(16,16) + Vector2(d) * 16
				var side := Vector2(-d.y, d.x) * 16
				draw_line(edge - side, edge + side, Color("354858") if visible else Color("16202d"), 3)
	if stairs_unlocked and discovered.has(goal_room):
		draw_rect(Rect2(stairs - Vector2(23,23), Vector2(46,46)), Color("24493c"))
		for i in range(4): draw_line(stairs + Vector2(-16 + i * 4, -12 + i * 8), stairs + Vector2(16, -12 + i * 8), Color("65ffcf"), 3)
		label_at(stairs + Vector2(-30,-34), "DESCEND", 13, Color("65ffcf"))
	boss.draw_lasers(self)
	boss.draw_options(self)
	for e in enemies:
		if cells.get(tile(e.p), -1) >= 0 and not discovered.has(cells[tile(e.p)]): continue
		var p: Vector2 = e.p
		var warning := attack_warning(e)
		if not e.active:
			draw_line(p + e.dir * 13, p + e.dir * 23, Color("ffb95e") if e.searching else Color("8194aa"), 2)
		if e.kind == 0:
			draw_rect(Rect2(p - Vector2(10,10), Vector2(20,20)), Color("f3637a"))
		elif e.kind == 1:
			draw_circle(p, 12, Color("ffb95e").lerp(Color("fff4dd"),warning))
			draw_circle(p, lerpf(5.0,1.5,warning), Color("342338"))
		elif e.kind == 2:
			var extent := 12.0 - warning*2.0
			draw_rect(Rect2(p - Vector2.ONE*extent, Vector2.ONE*extent*2), Color("ad8fff").lerp(Color("fff4dd"),warning))
			var dir: Vector2 = e.dir
			var side := dir.orthogonal() * 15
			draw_line(p + dir * 16 - side, p + dir * 16 + side, Color("c7eaff"), 4)
		else:
			var ink: Color = boss.COLORS[boss_variant]
			if boss_variant == 0:
				draw_colored_polygon(PackedVector2Array([p+Vector2(-20,0),p+Vector2(0,-20),p+Vector2(20,0),p+Vector2(0,20)]),ink.darkened(0.55))
			elif boss_variant == 1:
				var angle: float = e.dir.angle()
				draw_colored_polygon(PackedVector2Array([p+Vector2(-24,-18).rotated(angle),p+Vector2(24,0).rotated(angle),p+Vector2(-24,18).rotated(angle)]),ink.darkened(0.35))
			else:
				draw_circle(p,24,ink.darkened(0.55))
				draw_arc(p,29,0,TAU,32,ink,2)
			var extent := lerpf(12.0,7.0,warning)
			draw_rect(Rect2(p-Vector2.ONE*extent,Vector2.ONE*extent*2),ink.lerp(Color.WHITE,warning))
	for b in bullets:
		if cells.get(tile(b.p), -1) >= 0 and not discovered.has(cells[tile(b.p)]): continue
		var bullet_ink := Color("ff788e") if b.get("pressure",false) else (Color("d996ed") if b.get("guided",false) else Color("ffb95e"))
		draw_line(b.p, b.p - b.v.normalized() * 12, bullet_ink if b.hostile else Color("b2fff0"), 4 if b.hostile else 2)
	var preview_aim := (get_global_mouse_position() - offset - player).normalized()
	var preview_alpha := 0.18 if sub_cd <= 0 else 0.06
	if sub_weapon == 0:
		var fan := PackedVector2Array([player])
		for i in range(25): fan.append(attack_end(player, preview_aim.rotated((i / 24.0 - 0.5) * 0.9), 320.0))
		fan.append(player)
		draw_radial_fill(player, fan, Color(1,0.75,0.4,preview_alpha * 0.4))
		draw_polyline(fan,Color(1,0.75,0.4,preview_alpha * 2),1)
	elif sub_weapon == 2:
		var end := attack_end(player, preview_aim, LANCE_RANGE)
		draw_line(player,end,Color(0.78,0.94,1,preview_alpha),LANCE_WIDTH)
		var side := preview_aim.orthogonal()*LANCE_WIDTH*0.5
		draw_line(end-side,end+side,Color(0.78,0.94,1,preview_alpha*2),2)
	if sub_weapon == 1:
		var outline := PackedVector2Array()
		for i in range(97): outline.append(attack_end(player, Vector2.from_angle(i * TAU / 96), SHOCK_RADIUS))
		draw_radial_fill(player, outline, Color(0.3, 1, 0.85, 0.035))
		draw_polyline(outline, Color(0.3, 1, 0.85, 0.3 if sub_cd <= 0 else 0.08), 1)
	for effect in effects:
		if effect.kind == 0:
			var outline := PackedVector2Array()
			var progress: float = 1.0 - effect.life / 0.4
			for i in range(97): outline.append(attack_end(effect.p, Vector2.from_angle(i * TAU / 96), SHOCK_RADIUS * minf(1, progress * 3)))
			draw_radial_fill(effect.p, outline, Color(0.3, 1, 0.85, effect.life * 0.4))
			draw_polyline(outline, Color(0.4, 1, 0.9, effect.life / 0.4), 5)
		else:
			var direction: Vector2 = effect.p.direction_to(effect.end)
			var length: float = effect.p.distance_to(effect.end)
			var tip_size := minf(18.0, length * 0.4)
			var neck: Vector2 = effect.end - direction * tip_size
			var side := direction.orthogonal()
			var ink := Color(0.78, 0.94, 1.0, 0.55 * minf(1.0, effect.life / 0.09))
			if length > 1.0:
				draw_line(effect.p, neck, ink, LANCE_WIDTH)
				draw_colored_polygon(PackedVector2Array([effect.end, neck + side * LANCE_WIDTH * 0.65, neck - side * LANCE_WIDTH * 0.65]), ink)
	for p in particles: draw_rect(Rect2(p.p, Vector2(3,3)), Color(p.color, p.life / 0.35))
	for entry in damage_labels:
		var number := str(int(round(entry.damage))) if is_equal_approx(entry.damage, round(entry.damage)) else "%.1f" % entry.damage
		var alpha := minf(1.0, entry.life / 0.2)
		label_at(entry.p + Vector2(1,1), number, 17, Color(0.02,0.03,0.05,alpha))
		label_at(entry.p, number, 17, Color(1.0,0.95,0.75,alpha))
	if grace <= 0 or fmod(grace, 0.16) < 0.1:
		draw_circle(player, 12, Color("63f5ce"))
		draw_circle(player, PLAYER_HIT_RADIUS, Color("13252f"))
	var aim := (get_global_mouse_position() - offset - player).normalized()
	draw_line(player + aim * 8, player + aim * 23, Color.WHITE, 5)
	if grace > 0: draw_arc(player, 21, 0, TAU, 32, Color("63f5ce"), 1)
	if not boss_floor and time_left <= 5.0:
		draw_arc(player,29,-PI/2,-PI/2+TAU*clampf(time_left/5,0.001,1),48,Color(1,0.28,0.34,0.8),3)
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(0,0,screen.x,76), Color("0b111c"))
	label_at(Vector2(26,32), "DEPTH  %02d" % floor_number, 23)
	label_at(Vector2(26,56), "KILLS %d   /   RETRIES %d" % [kills, deaths], 13, Color("8194aa"))
	label_at(Vector2(650,31), "RMB  /  " + SUB_NAMES[sub_weapon], 20, Color("ffb95e"))
	label_at(Vector2(650,56), "READY" if sub_cd <= 0 else "RECHARGING  %.1fs" % sub_cd, 13, Color("8194aa"))
	if boss_floor:
		label_at(Vector2(930,31), "CORE %d / 6" % boss.remaining(self) if boss_variant == 0 else "BOSS", 23, boss.COLORS[boss_variant])
		label_at(Vector2(930,56), "NO TIME LIMIT", 12, Color("8194aa"))
		draw_rect(Rect2(0,76,screen.x*boss.health(self)/maxf(boss_max_hp,1),3),boss.COLORS[boss_variant])
	else:
		label_at(Vector2(930,31), "%04.1f s" % time_left, 25, Color("ff647c") if time_left < 5 else Color("63f5ce"))
		label_at(Vector2(930,56), "TO DESCEND", 12, Color("8194aa"))
		draw_rect(Rect2(0,76,screen.x * clampf(time_left / maxf(time_limit, 0.01),0,1),3), Color("ff647c") if time_left < 5 else Color("63f5ce"))
	# Spatial overview reflects the actual irregular graph, including the goal bearing.
	var bounds := Rect2(Vector2(rooms[0].position),Vector2(rooms[0].size))
	for r in rooms: bounds = bounds.merge(Rect2(Vector2(r.position),Vector2(r.size)))
	var map_scale := minf(130.0/bounds.size.x,52.0/bounds.size.y)
	var map_origin := Vector2(screen.x-145,10)
	for link in room_links:
		var a := map_origin + (Vector2(rooms[link.x].get_center())-bounds.position)*map_scale
		var b := map_origin + (Vector2(rooms[link.y].get_center())-bounds.position)*map_scale
		draw_line(a,b,Color("354858"),1)
	for i in range(rooms.size()):
		var mp := map_origin + (Vector2(rooms[i].position)-bounds.position)*map_scale
		draw_rect(Rect2(mp,Vector2(rooms[i].size)*map_scale),Color("63f5ce") if cells.get(tile(player),-1)==i else (Color("354858") if discovered.has(i) else Color("171f2b")))
		if i == goal_room and stairs_unlocked: draw_circle(mp+Vector2(rooms[i].size)*map_scale*0.5,2,Color("ffb95e"))
	draw_rect(Rect2(0,screen.y - 40,screen.x,40), Color("0b111c"))
	label_at(Vector2(26,screen.y - 15), "WASD  MOVE     LMB  MACHINE GUN     RMB  SUB WEAPON     Q/E / WHEEL  SWITCH     ESC  PAUSE     M  AUDIO", 13, Color("a4b3c6"))
	if practice.active: label_at(Vector2(screen.x-240,screen.y-15),"PRACTICE / R RETRY / B SELECT",12,Color("63f5ce"))
	if banner > 0:
		centered_title_label(screen,110,("BOSS DEFEATED / DESCEND" if stairs_unlocked else boss.NAMES[boss_variant]) if boss_floor else "FIND THE STAIRS. KEEP DESCENDING.",18,Color("63f5ce"))
	if hit_flash > 0:
		draw_rect(Rect2(Vector2.ZERO,screen),Color(1,0.25,0.3,hit_flash*0.35))
		draw_rect(Rect2(Vector2(4,4),screen-Vector2(8,8)),Color(1,0.3,0.35,hit_flash*2),false,6)
	if hit_banner > 0:
		label_at(Vector2(screen.x/2-105,145),"HIT / RETRY",26,Color(1,0.5,0.5,minf(1,hit_banner*3)))
	if timeout_banner > 0:
		label_at(Vector2(screen.x / 2 - 145,145),"TIME UP / RETRY",26,Color(1,0.3,0.35,minf(1,timeout_banner*3)))
	var mouse := get_global_mouse_position()
	draw_arc(mouse, 8, 0, TAU, 16, Color("63f5ce"), 1)
	if paused or choosing:
		draw_rect(Rect2(Vector2.ZERO, screen), Color(0.02,0.03,0.06,0.93))
		var menu_y := menu_origin_y(screen, paused)
		if paused:
			centered_title_label(screen,menu_y-30,"PAUSED",28)
			centered_title_label(screen,menu_y+20,"CLICK TO RESUME",22,Color("63f5ce"))
			centered_title_label(screen,menu_y+58,"ESC / RETURN TO TITLE",18,Color("8194aa"))
		else:
			centered_title_label(screen,menu_y - 130, "FLOOR CLEARED / CHOOSE AN UPGRADE", 24, Color("63f5ce"))
			centered_title_label(screen,menu_y - 90, "CLICK A CARD OR PRESS 1 / 2 / 3", 16, Color("8194aa"))
			var names := ["HEAVY ROUNDS", "OVERCLOCK", "QUICKSTEP", "HUNTER"]
			var descriptions := ["+35% base weapon damage", "+20% base firing speed", "+20 movement speed", "+20% damage / +10 speed"]
			for i in range(3):
				var p := upgrade_card_rect(screen, i).position
				draw_rect(Rect2(p,Vector2(290,150)),Color("182735"))
				draw_rect(Rect2(p,Vector2(290,150)),Color("63f5ce"),false,2)
				label_at(p + Vector2(18,32), "0%d / %s" % [i + 1, names[choices[i]]], 20)
				label_at(p + Vector2(18,86), descriptions[choices[i]], 15, Color("a4b3c6"))
		draw_player_stats(screen, menu_y + 155)



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

func draw_player_stats(screen: Vector2, y: float) -> void:
	centered_title_label(screen, y, "CURRENT STATS", 15, Color("8194aa"))
	var stats := player_stats()
	for i in range(stats.size()):
		var x := screen.x * 0.5 + (i - 1) * 250.0
		var item: Dictionary = stats[i]
		draw_rect(Rect2(x - 115, y + 15, 230, 105), Color("182735"))
		var column := Vector2(x * 2.0, screen.y)
		centered_title_label(column, y + 40, item.name, 15, Color("8194aa"))
		centered_title_label(column, y + 73, item.value, 25, Color("63f5ce"))
		centered_title_label(column, y + 101, item.detail, 15, Color("a4b3c6"))

func centered_title_label(screen: Vector2, y: float, value: String, size: int, color: Color = Color.WHITE) -> void:
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	label_at(Vector2((screen.x - width) * 0.5, y), value, size, color)

func fullscreen_button_rect() -> Rect2:
	return Rect2(get_viewport_rect().size.x-202,22,180,42)

func toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode in [DisplayServer.WINDOW_MODE_FULLSCREEN,DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN] else DisplayServer.WINDOW_MODE_FULLSCREEN)
	queue_redraw()

func draw_title(screen: Vector2) -> void:
	if practice.selecting:
		practice.draw(self,screen)
		return
	draw_rect(Rect2(Vector2.ZERO,screen),Color("0b111c"))
	var audio_button := audio_button_rect()
	draw_rect(audio_button,Color("182735"))
	draw_rect(audio_button,Color("63f5ce"),false,1)
	var audio_caption: String = ["AUDIO: ALL","AUDIO: SE ONLY","AUDIO: OFF"][audio_mode]
	var audio_width := font.get_string_size(audio_caption,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
	label_at(Vector2(audio_button.get_center().x-audio_width/2,audio_button.position.y+27),audio_caption,14,Color("63f5ce"))
	var button := fullscreen_button_rect()
	draw_rect(button,Color("182735"))
	draw_rect(button,Color("63f5ce"),false,1)
	var fullscreen := DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN,DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	var caption := "WINDOWED" if fullscreen else "FULLSCREEN"
	var caption_width := font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
	label_at(Vector2(button.get_center().x-caption_width/2,button.position.y+27),caption,16,Color("63f5ce"))
	var origin := screen * 0.5
	for i in range(6):
		var width := 210.0 + i*62
		draw_rect(Rect2(origin-Vector2(width/2,260-i*14),Vector2(width,24)),Color(0.15,0.32,0.34,0.2),false,1)
	centered_title_label(screen,origin.y+-90,"HACK / SHMUP",54,Color("63f5ce"))
	centered_title_label(screen,origin.y+-50,"ENDLESS DESCENT / PROTOTYPE",18,Color("8194aa"))
	centered_title_label(screen,origin.y+35,"DEEPEST CLEARED  %02d" % best_cleared,24,Color("ffb95e"))
	centered_title_label(screen,origin.y+105,"CLICK OR ENTER TO DESCEND",22)
	centered_title_label(screen,origin.y+148,"WASD MOVE / MOUSE AIM / Q & E WEAPONS",14,Color("8194aa"))
	centered_title_label(screen,origin.y+176,"M AUDIO / RECORD LASTS UNTIL YOU QUIT",14,Color("8194aa"))
	if not OS.has_feature("web"):
		centered_title_label(screen,origin.y+232,"ESC / QUIT",14,Color("8194aa"))
	centered_title_label(screen,origin.y+204,"B / BOSS PRACTICE",14,Color("63f5ce"))
