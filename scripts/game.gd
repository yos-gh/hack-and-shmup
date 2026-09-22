extends Node2D

const Catalog = preload("res://scripts/combat_catalog.gd")
const BossGeometry = preload("res://scripts/boss_geometry.gd")
const SHIELD_TURN_SCALE := 0.5

const LanceTrace = preload("res://scripts/lance_trace.gd")

const Queries = preload("res://scripts/floor_queries.gd")

const TILE := 32.0
const SPEED := 245.0
const PLAYER_HIT_RADIUS := 5.0
# Enemy timing stays at floor-one values; only population and HP scale.
var ENEMY_MOVE_SPEED: float:
	get: return Catalog.ENEMIES[Catalog.Enemy.CHASER].move_speed
var ENEMY_BULLET_SPEED: float:
	get: return Catalog.ENEMIES[Catalog.Enemy.SNIPER].bullet_speed
var ENEMY_SHOT_INTERVAL: float:
	get: return Catalog.ENEMIES[Catalog.Enemy.SNIPER].shot_interval
const ENEMY_BUCKET_SIZE := 64.0
const BULLET_HIT_RADIUS := 14.0
const IDLE_UPDATE_PHASES := 6
var KILL_TIME_BONUS: Array:
	get: return Catalog.ENEMIES.values().map(func(definition): return definition.time_bonus)
var enemy_buckets: Dictionary = {}
var patrol_elapsed: Dictionary = {}
var simulation_tick := 0
var goal_room := 0
var corridor_cells: Dictionary = {}
var room_links: Array[Vector2i] = []
var sound: Node
var audio_mode := 1
var menus: CanvasLayer
var SUB_NAMES: Array:
	get: return Catalog.WEAPONS.map(func(definition): return definition.title)
var SUB_COOLDOWNS: Array:
	get: return [session.run.sub_cooldown(0),session.run.sub_cooldown(1),session.run.sub_cooldown(2)]
const ENTRY_CLEARANCE := 96.0
var entrances: Dictionary = {}

var SHOCK_RADIUS: float:
	get: return session.run.sub_reach(1)
var LANCE_WIDTH: float:
	get: return session.run.lance_width()
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
var view_pitch_degrees := 25.0
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
var mobs = preload("res://scripts/mob_behavior.gd").new()
var controls = preload("res://scripts/player_input.gd").new()
var world_view = preload("res://scripts/world_view.gd").new()
var hud = preload("res://scripts/game_hud.gd").new()
var font: Font = preload("res://assets/fonts/Rajdhani-SemiBold.ttf")
var body_font: Font = preload("res://assets/fonts/Barlow-Regular.ttf")
var presentation = preload("res://scripts/presentation.gd").new()
var boss = preload("res://scripts/boss.gd").new()
var boss_floor := false
var stairs_unlocked := true
var boss_max_hp := 0.0
var boss_variant := 0
var practice = preload("res://scripts/boss_practice.gd").new()

func _ready() -> void:
	Input.joy_connection_changed.connect(controls.joy_connection_changed.bind(self))
	sound = preload("res://scripts/sound.gd").new()
	add_child(sound)
	combat_events.enemy_hit.connect(sound.hear_hit)
	menus = preload("res://scripts/game_menus.gd").new()
	add_child(menus)
	menus.setup(self)
	combat_feedback.bind_to(self)
	presentation.bind_to(self)
	rng.randomize()
	effects_rng.randomize()
	new_floor()
	set_depth_view(true)

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
	settings.recharge = session.run.recharge
	settings.physics_ticks = float(Engine.physics_ticks_per_second)
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
	if e.get("arrival",0.0) > 0: return false
	if e.kind == Catalog.Enemy.BOSS and boss_variant == 3:
		return boss.fortress.touches(e,player,PLAYER_HIT_RADIUS)
	if e.kind == Catalog.Enemy.BOSS and boss_variant == 4:
		return boss.bastion.touches(e,player,PLAYER_HIT_RADIUS)
	if e.kind == Catalog.Enemy.SNIPER: return e.p.distance_to(player) < PLAYER_HIT_RADIUS + 12.0
	var half_size := 12.0 if e.kind == Catalog.Enemy.SHIELD else 10.0
	var nearest: Vector2 = player.clamp(e.p-Vector2.ONE*half_size,e.p+Vector2.ONE*half_size)
	return nearest.distance_to(player) < PLAYER_HIT_RADIUS

func update_awareness(e: Dictionary, room_id: int, delta: float) -> void:
	if e.active:
		if e.charge <= 0 and e.get("stun", 0.0) <= 0:
			if e.kind == Catalog.Enemy.SHIELD:
				e.dir = Vector2.from_angle(rotate_toward(e.dir.angle(),e.p.angle_to_point(player),e.turn_speed*SHIELD_TURN_SCALE*delta))
			else: e.dir = e.p.direction_to(player)
		return
	if e.room == room_id: e.searching = true
	if not e.searching: return
	e.notice = maxf(0,e.notice-delta)
	# An interceptor remembers entry even if the player exits before eye contact.
	if e.kind == Catalog.Enemy.INTERCEPTOR and e.notice <= 0 and room_id != e.room:
		e.active = true
		return
	var target_angle: float = e.p.angle_to_point(player)
	var turn_scale: float = SHIELD_TURN_SCALE if e.kind == Catalog.Enemy.SHIELD else 1.0
	var angle: float = rotate_toward(e.dir.angle(),target_angle,e.turn_speed*turn_scale*delta)
	e.dir = Vector2.from_angle(angle)
	if e.notice <= 0 and absf(angle_difference(angle,target_angle)) < 0.2 and attack_reaches(e.p,player):
		e.active = true
		if e.kind in [Catalog.Enemy.SNIPER,Catalog.Enemy.SHIELD]: e.cd = maxf(e.cd,Catalog.ENEMIES[e.kind].activation_delay)

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
	combat_events.weapon_fired.emit(player,aim,sub_weapon)
	sub_cd_total = session.run.sub_cooldown(sub_weapon)
	match sub_weapon:
		0:
			var muzzle: Array[Vector2] = []
			for i in range(definition.pellets):
				var direction := aim.rotated((i - (definition.pellets-1)*0.5) * definition.spread)
				emit_shot(player,direction,definition.speed,power*definition.damage,false,session.run.sub_reach(sub_weapon))
				bullets[-1]["scatter_visual"] = true
				if i % 3 == 0: muzzle.append(attack_end(player,direction,26))
			effects.append({"kind":3,"p":player,"tips":muzzle,"life":0.08})
			sub_cd = sub_cd_total
		1:
			for e in enemies:
				if e.has("plates"):
					if boss_variant == 4 and boss.bastion.orb_absorbs_area(self,player,SHOCK_RADIUS): continue
					(boss.bastion if boss_variant == 4 else boss.fortress).shock(self,e,power*definition.damage)
					continue
				var body_radius: float = enemy_bullet_radius(e) if e.kind == Catalog.Enemy.BOSS else 0.0
				if e.p.distance_to(player) <= SHOCK_RADIUS + body_radius and attack_reaches(player, e.p):
					hurt_enemy(e, power * definition.damage, player.direction_to(e.p), definition.knockback)
			bullets = bullets.filter(func(b: Dictionary) -> bool: return not (b.hostile and not b.get("energy_orb",false) and b.p.distance_to(player) <= SHOCK_RADIUS and attack_reaches(player, b.p)))
			effects.append({"kind": 0, "p": player, "end": player, "life": 0.4})
			sub_cd = sub_cd_total
		2:
			var direction := aim.normalized()
			var rays := LanceTrace.lanes(self,player,direction)
			for e in enemies:
				if e.has("plates"):
					if boss_variant == 4 and boss.bastion.orb_absorbs_lance(self,rays): continue
					(boss.bastion if boss_variant == 4 else boss.fortress).lance(self,e,rays,direction,power*definition.damage)
					continue
				if LanceTrace.hits(self,e,rays,direction):
					hurt_enemy(e,power*definition.damage,direction,definition.knockback)
			effects.append({"kind":1,"p":player,"rays":rays,"life":0.28})
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

func enemy_bullet_radius(e: Dictionary) -> float:
	return BossGeometry.hit_radius(boss_variant) if e.get("kind",0) == Catalog.Enemy.BOSS else BULLET_HIT_RADIUS

func rebuild_enemy_buckets() -> void:
	enemy_buckets.clear()
	# Insert in enemy order, including every bucket touched by the hit radius.
	# A bullet needs one lookup; overlapping targets keep their original priority.
	for e in enemies:
		if e.hp <= 0: continue
		var radius := enemy_bullet_radius(e)
		var lo := enemy_bucket(e.p - Vector2.ONE * radius)
		var hi := enemy_bucket(e.p + Vector2.ONE * radius)
		for y in range(lo.y, hi.y + 1):
			for x in range(lo.x, hi.x + 1):
				var key := Vector2i(x, y)
				if not enemy_buckets.has(key): enemy_buckets[key] = []
				enemy_buckets[key].append(e)

func bullet_target(p: Vector2) -> Dictionary:
	for e in enemy_buckets.get(enemy_bucket(p), []):
		if e.hp > 0 and p.distance_squared_to(e.p) < pow(enemy_bullet_radius(e),2) and attack_open(e.p):
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

func _notification(what: int) -> void:
	if what != NOTIFICATION_APPLICATION_FOCUS_OUT: return
	if not is_node_ready(): return
	fire_armed = false
	if not title_screen and not choosing:
		paused = true
		sound.set_paused(true)
	queue_redraw()

func upgrade(index: int) -> void:
	if not choosing or index < 0 or index >= choices.size() or not session.run.can_upgrade(choices[index]): return
	apply_upgrade(choices[index])
	floor_number += 1
	new_floor()

func apply_upgrade(kind: int) -> void:
	session.run.apply_upgrade(kind)

func shield_velocity(e: Dictionary, delta: float, toward: Vector2) -> Vector2:
	return mobs.shield_velocity(self,e,delta,toward)

func enemy_attack_cue(key: String, position: Vector2, flash: bool = true) -> void:
	sound.enemy_audio.request(self,key,position)
	combat_events.actor_fired.emit(position,key)
	if flash and attack_open(position):
		var count := 0
		for effect in effects:
			if effect.kind == 4: count += 1
		if count < 64: effects.append({"kind":4,"p":position,"life":0.16})

func emit_shot(p: Vector2, direction: Vector2, speed: float, damage: float, hostile: bool, distance: float = 10000.0) -> void:
	if not hostile and distance == Catalog.PRIMARY.reach: combat_events.weapon_fired.emit(p,direction,-1)
	bullets.append({"p": p, "v": direction * speed, "damage": damage, "hostile": hostile, "life": distance / speed})

func burst(p: Vector2, color: Color, count: int = 8) -> void:
	for i in range(count):
		particles.append({"p": p, "v": Vector2.from_angle(effects_rng.randf() * TAU) * effects_rng.randf_range(30, 180), "life": 0.35, "color": color})

func hurt_enemy(e: Dictionary, damage: float, direction: Vector2, knockback: float = 180.0, armor_checked: bool = false) -> void:
	if e.hp <= 0: return
	if e.kind == Catalog.Enemy.BOSS and boss_variant in [3,4] and not armor_checked and (boss.bastion if boss_variant == 4 else boss.fortress).block_damage(self,e,damage,direction): return
	if e.kind != Catalog.Enemy.BOSS: e.push += direction * knockback
	if e.kind == Catalog.Enemy.SHIELD and direction.dot(e.dir) < -0.35:
		combat_events.enemy_hit.emit(e.p,0.0,true,false)
		return
	e.hp -= damage
	var killed: bool = e.hp <= 0
	if killed and not boss_floor and Catalog.is_mob(e.kind):
		time_left += Catalog.ENEMIES[e.kind].time_bonus
	combat_events.enemy_hit.emit(e.p,damage,false,killed)
	if killed and e.kind == Catalog.Enemy.BOSS: combat_events.boss_destroyed.emit(e.p,boss.COLORS[boss_variant])


func die(reason: String = "HIT") -> void:
	session.die(self, reason)

func _physics_process(delta: float) -> void:
	sound.set_paused(paused)
	if not paused: presentation.advance(self,delta)
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
	var previous_player := player
	player = preload("res://scripts/player_motion.gd").move(self,player, movement.normalized() * (SPEED + move_bonus) * delta, PLAYER_HIT_RADIUS)
	presentation.track_motion(self,previous_player,player,delta)
	camera_pos = camera_pos.lerp(player, 1.0 - exp(-12 * delta))
	var room_id: int = cells.get(tile(player), -1)
	if room_id >= 0:
		if not discovered.has(room_id): combat_events.room_entered.emit(room_id,player)
		discovered[room_id] = true
	hud.minimap.observe(self)
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
	mobs.begin_frame()
	for e in enemies:
		if e.hp <= 0: continue
		var enemy_delta := delta
		# Unseen patrols run at 10 Hz, staggered by room. Entered rooms and
		# pursuing enemies retain full-rate reactions, motion and collisions.
		if not e.active and not e.searching and not discovered.has(e.room) and e.push == Vector2.ZERO:
			if (simulation_tick + e.room) % IDLE_UPDATE_PHASES != 0: continue
			enemy_delta = patrol_elapsed.get(e.room, delta)
		var was_active: bool = e.active
		update_awareness(e, room_id, delta)
		if not was_active and e.active: combat_events.actor_alerted.emit(e.p,e.dir)
		if e.active: e.cd -= delta
		var toward: Vector2 = (player - e.p).normalized()
		var velocity := Vector2.ZERO
		if e.active:
			if e.kind == Catalog.Enemy.BOSS:
				velocity = boss.enemy_velocity(self,e,delta,toward)
			else:
				velocity = mobs.velocity(self,e,delta,player-previous_player)
		elif not e.searching and e.kind != Catalog.Enemy.BOSS:
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
		if b.get("energy_orb",false):
			b.orb_age += delta
			b.orb_flash = maxf(0.0,b.orb_flash-delta)
			if b.orb_phase == "charge":
				var expansion: float = clampf(b.orb_age/1.05,0.0,1.0)
				b.orb_radius = lerpf(18.0,50.0,expansion*expansion*(3.0-2.0*expansion))
				if b.orb_age >= 1.05:
					b.orb_phase = "flight"
					b.orb_age = 0.0
					b.v = b.p.direction_to(player)*125.0*b.orb_speed_scale
			else:
				var speed: float = minf(b.v.length()+165.0*b.orb_speed_scale*delta,340.0*b.orb_speed_scale)
				var angle: float = b.v.angle()
				if b.orb_age < 0.8: angle = rotate_toward(angle,b.p.angle_to_point(player),0.8*delta)
				b.v = Vector2.from_angle(angle)*speed
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
				if b.p.distance_to(player) < PLAYER_HIT_RADIUS + (22.0 if b.get("energy_orb",false) else 2.0):
					die()
					if pending_respawn: return
					b.life = 0
					break
			else:
				if boss_variant == 4:
					var absorbed := false
					for orb in bullets:
						if not orb.get("energy_orb",false) or orb.life <= 0: continue
						if b.p.distance_to(orb.p) > orb.orb_radius+2.0: continue
						orb.orb_flash = 0.15
						b.life = 0
						absorbed = true
						break
					if absorbed: break
				if boss_variant in [3,4] and boss_floor and (boss.bastion if boss_variant == 4 else boss.fortress).intercept_bullet(self,b):
					b.life = 0
					break
				var target := bullet_target(b.p)
				if not target.is_empty():
					hurt_enemy(target, b.damage, b.v.normalized(),180.0,true)
					b.life = 0
			if b.life <= 0: break
	bullets = bullets.filter(func(b: Dictionary) -> bool: return b.life > 0)
	for e in enemies:
		if e.hp <= 0: kills += 1; burst(e.p, Color("ff647c"), 12)
	enemies = enemies.filter(func(e: Dictionary) -> bool: return e.hp > 0)
	if boss_floor and not stairs_unlocked and boss.remaining(self) == 0:
		stairs_unlocked = true
		combat_events.stairs_opened.emit(stairs)
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
		session.run.roll_choices(rng)
		sound.play_sfx("clear")
		best_cleared = maxi(best_cleared, floor_number)
		choosing = true
		combat_events.scene_changed.emit("cards")
	queue_redraw()

func label_at(p: Vector2, value: String, size: int = 18, color: Color = Color.WHITE) -> void:
	hud.label_at(self, p, value, size, color)

func attack_warning(e: Dictionary) -> float:
	if not e.active or e.charge > 0 or e.get("stun",0.0) > 0 or e.kind == Catalog.Enemy.CHASER: return 0.0
	if e.kind == Catalog.Enemy.BOSS: return boss.warning(e)
	var duration: float = Catalog.ENEMIES[e.kind].warning_duration
	return clampf(1.0-e.cd/duration,0.0,1.0) if duration > 0 else 0.0

func _draw() -> void:
	var screen := get_viewport_rect().size
	if title_screen:
		world_view.draw_particles(self)
		hud.draw_title(self, screen)
		return
	world_view.draw(self, screen)
	hud.draw(self, screen)

# One presentation transform for the 3D camera, 2D attacks and pointer input.
# Quantization affects rendering only, never simulation positions or camera follow.
func view_scale() -> Vector2:
	return Vector2(1,cos(deg_to_rad(view_pitch_degrees))) if depth_enabled else Vector2.ONE

func view_origin() -> Vector2:
	if not depth_enabled: return camera_pos
	var scale_value := view_scale()
	return (camera_pos*scale_value*4.0).round()/4.0/scale_value

func world_to_screen(point: Vector2) -> Vector2:
	return (point-view_origin())*view_scale()+get_viewport_rect().size*0.5

func screen_to_world(point: Vector2) -> Vector2:
	return (point-get_viewport_rect().size*0.5)/view_scale()+view_origin()

func world_transform() -> Transform2D:
	var scale_value := view_scale()
	return Transform2D(Vector2(scale_value.x,0),Vector2(0,scale_value.y),world_to_screen(Vector2.ZERO))

func set_view_pitch(degrees: float) -> void:
	view_pitch_degrees = clampf(degrees,0,40)
	if depth_view != null and depth_enabled: depth_view.sync(self)
	queue_redraw()

func set_depth_view(enabled: bool) -> void:
	if enabled and depth_view == null:
		depth_view = preload("res://scripts/depth_view.gd").new()
		add_child(depth_view)
	depth_enabled = enabled
	if depth_view != null: depth_view.set_active(enabled)
	queue_redraw()



func menu_origin_y(screen: Vector2, is_pause: bool) -> float:
	var top := -65.0 if is_pause else -165.0
	# Include both rows of player stats when centering the complete menu.
	var bottom := 362.0
	return (screen.y - top - bottom) * 0.5

func upgrade_card_rect(screen: Vector2, index: int) -> Rect2:
	var width := minf(290.0,(screen.x-88.0)/3.0)
	var total := width*3+40
	return Rect2((screen.x-total)*0.5+index*(width+20), menu_origin_y(screen, false)-40,width,190)

func player_stats() -> Array[Dictionary]:
	return [
		{"name":"DAMAGE", "value":"%.2fx" % power, "detail":"%+.0f%%" % ((power - 1.0) * 100.0)},
		{"name":"FIRE RATE", "value":"%.2fx" % fire_rate, "detail":"+%.0f%%" % ((fire_rate - 1.0) * 100.0)},
		{"name":"MOVE SPEED", "value":"%.0f" % (SPEED + move_bonus), "detail":"%+.0f" % move_bonus},
		{"name":"SCATTER RANGE", "value":"%.2fx" % (1.0+session.run.expansion), "detail":"+%.0f%% / MAX +50%%" % (session.run.expansion*100)},
		{"name":"SHOCK RADIUS", "value":"%.2fx" % (1.0+session.run.expansion*0.5), "detail":"+%.0f%% / MAX +25%%" % (session.run.expansion*50)},
		{"name":"LANCE WIDTH", "value":"%.2fx" % session.run.lance_width_multiplier(), "detail":"+%.0f%% / MAX +100%%" % ((session.run.lance_width_multiplier()-1.0)*100)},
		{"name":"SUB RECHARGE", "value":"%.2fx" % (1.0+session.run.recharge), "detail":"+%.0f%% / MAX +50%%" % (session.run.recharge*100)}
	]

func centered_title_label(screen: Vector2, y: float, value: String, size: int, color: Color = Color.WHITE) -> void:
	hud.centered_title_label(self, screen, y, value, size, color)

func fullscreen_button_rect() -> Rect2:
	return Rect2(get_viewport_rect().size.x-202,22,180,42)

func toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode in [DisplayServer.WINDOW_MODE_FULLSCREEN,DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN] else DisplayServer.WINDOW_MODE_FULLSCREEN)
	queue_redraw()
