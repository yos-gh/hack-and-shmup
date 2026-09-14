extends RefCounted
## Presentation clock and bounded value snapshots. Never consumes gameplay RNG.
var clock := 0.0
var transition := 0.0
var pulses: Array[Dictionary] = []
var trails: Array[Dictionary] = []
var pulse_pool: Array[Dictionary] = []
var trail_pool: Array[Dictionary] = []
func _init() -> void:
	for i in range(32): pulse_pool.append({})
	for i in range(96): trail_pool.append({})
var muzzle := 0.0
var muzzle_direction := Vector2.RIGHT
var trail_clock := 0.0
func bind_to(game) -> void:
	game.combat_events.actor_fired.connect(func(p,_cue): pulse("fire",p,Color("ffd79a"),0.16,10))
	game.combat_events.actor_alerted.connect(func(p,d): pulse("alert",p,Color("ff9f9e"),0.22,12,d))
	game.combat_events.weapon_fired.connect(func(p,d,w):
		muzzle = 0.09 if w == -1 else 0.16
		muzzle_direction = d
		if w >= 0: pulse("weapon",p,Color("63f5ce"),0.18,24,d))
	game.combat_events.charge_changed.connect(func(p,d,started): pulse("charge" if started else "stop",p,Color("c3a0ff"),0.2,24,d))
	game.combat_events.room_entered.connect(func(room,p):
		pulse("room",p,Color("63f5ce"),0.35,0)
		pulses[-1]["room"] = room
		var boundary := PackedVector2Array()
		for i in range(49): boundary.append(game.attack_end(p,Vector2.from_angle(i*TAU/48),420))
		pulses[-1]["boundary"] = boundary)
	game.combat_events.stairs_opened.connect(func(p): pulse("unlock",p,Color("63f5ce"),0.6,40))
	game.combat_events.scene_changed.connect(func(_scene): transition = 0.3)
	game.combat_events.boss_destroyed.connect(func(p,c): pulse("boss",p,c,0.6,64))
func reset() -> void:
	pulse_pool.append_array(pulses)
	trail_pool.append_array(trails)
	pulses.clear()
	trails.clear()
	muzzle = 0
	trail_clock = 0
	transition = 0
func pulse(kind: String, p: Vector2, color: Color, life: float, radius: float, direction: Vector2 = Vector2.RIGHT) -> void:
	var item: Dictionary = pulses.pop_front() if pulse_pool.is_empty() else pulse_pool.pop_back()
	item.clear()
	item.merge({"kind":kind,"p":p,"color":color,"life":life,"duration":life,"radius":radius,"direction":direction})
	pulses.append(item)
func advance(_game, delta: float) -> void:
	clock += delta
	muzzle = maxf(0,muzzle-delta)
	transition = maxf(0,transition-delta)
	for i in range(pulses.size()-1,-1,-1):
		pulses[i].life -= delta
		if pulses[i].life<=0: pulse_pool.append(pulses.pop_at(i))
	for i in range(trails.size()-1,-1,-1):
		trails[i].life -= delta
		if trails[i].life<=0: trail_pool.append(trails.pop_at(i))
func track_motion(game, a: Vector2, b: Vector2, delta: float) -> void:
	trail_clock += delta
	if trail_clock < 0.03: return
	trail_clock = 0
	if a.distance_squared_to(b)>0.1: add_trail(b,(b-a).normalized(),Color("63f5ce"),10,0.15)
	for enemy in game.enemies:
		if enemy.hp<=0 or not game.attack_open(enemy.p): continue
		if enemy.charge>0: add_trail(enemy.p,enemy.dir,Color("ad8fff"),15,0.15)
		elif enemy.kind == 3 and game.boss_variant == 1 and game.boss.lasers.is_empty(): add_trail(enemy.p,enemy.dir,Color("7be8ff"),18,0.15)
func add_trail(p: Vector2, direction: Vector2, color: Color, radius: float, life: float) -> void:
	var item: Dictionary = trails.pop_front() if trail_pool.is_empty() else trail_pool.pop_back()
	item.p = p
	item.direction = direction
	item.color = color
	item.radius = radius
	item.life = life
	trails.append(item)
func draw_world(game) -> void:
	var quiet: float = 0.35 if game.preferences.reduce_flash else 1.0
	for t in trails:
		if not game.attack_open(t.p): continue
		var alpha: float = t.life/0.15*0.35*quiet
		var side: Vector2 = t.direction.orthogonal()*t.radius
		var end: Vector2 = game.attack_end(t.p,-t.direction,18)
		game.draw_line(t.p+side*0.5,end+side*0.2,Color(t.color,alpha),2,true)
		game.draw_line(t.p-side*0.5,end-side*0.2,Color(t.color,alpha),2,true)
	for p in pulses:
		if not game.attack_open(p.p): continue
		var progress: float = 1-p.life/p.duration
		var ink := Color(p.color,(1-progress)*quiet*0.7)
		if p.kind == "room":
			var outline := PackedVector2Array()
			for tip in p.boundary: outline.append(p.p.lerp(tip,progress))
			game.draw_polyline(outline,Color(ink,ink.a*0.35),2,true)
		elif p.kind == "boss":
			for i in range(12):
				var axis := Vector2.from_angle(i*TAU/12)
				var center: Vector2 = game.attack_end(p.p,axis,12+progress*p.radius)
				game.draw_line(center-axis.orthogonal()*5,center+axis.orthogonal()*5,ink,2,true)
			game.draw_arc(p.p,4+(1-progress)*12,0,TAU,24,ink,2,true)
		elif p.kind == "fire":
			for i in range(3):
				var direction := Vector2.from_angle(i*TAU/3+progress)
				game.draw_line(p.p+direction*6,p.p+direction*(8+progress*8),ink,1.5,true)
		else:
			var axis: Vector2 = p.direction
			var center: Vector2 = game.attack_end(p.p,axis,8+progress*p.radius)
			var side := axis.orthogonal()*(6+progress*8)
			game.draw_polyline(PackedVector2Array([center-side-axis*6,center,center+side-axis*6]),ink,2,true)
	if muzzle>0:
		var end: Vector2 = game.attack_end(game.player,muzzle_direction,25)
		game.draw_line(game.player+muzzle_direction*12,end,Color(0.85,1,0.94,muzzle/0.16*quiet),3,true)
func draw_stairs(game) -> void:
	var point: Vector2 = game.stairs
	var phase := fmod(clock*0.7,1.0)
	for i in range(4):
		var depth := float(i)+phase
		var radius := 22-depth*2
		var center := point+Vector2(0,depth*3)
		var ink := Color(0.39,1,0.81,(1-depth/5)*0.65)
		game.draw_polyline(PackedVector2Array([center+Vector2(-radius,-radius*0.45),center+Vector2(radius,-radius*0.45),center+Vector2(radius,radius*0.45),center+Vector2(-radius,radius*0.45),center+Vector2(-radius,-radius*0.45)]),ink,1.5,true)
	preload("res://scripts/visual_icons.gd").draw_icon(game,"descend",point,10,Color("dcfff3"))
	game.label_at(point+Vector2(-29,-30),"DESCEND",14,Color("9af5d9"))
