extends RefCounted

const MobVisuals = preload("res://scripts/mob_visuals.gd")
const Catalog = preload("res://scripts/combat_catalog.gd")
var particle_batch: MultiMesh
var particles_warmed := false
var radial_cache: Dictionary = {}
var radial_floor := -1
var radial_discovery := -1
var radial_reach := -1.0

func shock_outline(game, origin: Vector2, radius: float) -> PackedVector2Array:
	var discovery: int = game.discovered.hash()
	if radial_floor != game.floor_revision or radial_discovery != discovery or radial_reach != game.SHOCK_RADIUS:
		radial_cache.clear()
		radial_floor = game.floor_revision
		radial_discovery = discovery
		radial_reach = game.SHOCK_RADIUS
	if not radial_cache.has(origin):
		if radial_cache.size() >= 8: radial_cache.clear()
		var reach := PackedVector2Array()
		for i in range(97): reach.append(game.attack_end(origin,Vector2.from_angle(i*TAU/96),game.SHOCK_RADIUS))
		radial_cache[origin] = reach
	var full: PackedVector2Array = radial_cache[origin]
	if radius >= game.SHOCK_RADIUS: return full
	var outline := PackedVector2Array()
	for i in range(97):
		var ray := Vector2.from_angle(i*TAU/96)
		var distance := origin.distance_to(full[i])
		var length := minf(radius,distance)
		# Keep the existing four-pixel ray march's partial final sample exactly.
		if radius > distance and radius < distance+4.001 and game.attack_open(origin+ray*radius): length = radius
		outline.append(origin+ray*length)
	return outline


# Read-only 2D presentation. All commands use the host CanvasItem during _draw.
# Combat coordinates and attack clipping remain owned by the simulation.
func draw(game, screen: Vector2) -> void:
	if game.depth_enabled:
		game.draw_texture_rect(game.depth_view.viewport.get_texture(), Rect2(Vector2.ZERO, screen), false)
	game.draw_set_transform_matrix(game.world_transform())
	var view := Rect2(game.screen_to_world(Vector2.ZERO)-Vector2(32,32),screen/game.view_scale()+Vector2(64,64))
	if not game.depth_enabled:
		for c in game.cells:
			var p = Vector2(c) * game.TILE
			if not view.has_point(p): continue
			var id: int = game.cells[c]
			var visible = id == -1 or game.discovered.has(id)
			var color = Color("182735") if visible else Color("0b121c")
			game.draw_rect(Rect2(p + Vector2.ONE, Vector2.ONE * 30), color)
			for d in [Vector2i.UP, Vector2i.LEFT, Vector2i.DOWN, Vector2i.RIGHT]:
				if not game.cells.has(c + d):
					var edge = p + Vector2(16,16) + Vector2(d) * 16
					var side = Vector2(-d.y, d.x) * 16
					game.draw_line(edge - side, edge + side, Color("354858") if visible else Color("16202d"), 3)
	game.presentation.draw_world(game)
	if game.stairs_unlocked and game.discovered.has(game.goal_room): game.presentation.draw_stairs(game)
	draw_lasers(game)
	draw_options(game)
	for e in game.enemies:
		if game.cells.get(game.tile(e.p), -1) >= 0 and not game.discovered.has(game.cells[game.tile(e.p)]): continue
		var p: Vector2 = e.p
		MobVisuals.draw_warning(game,e)
		var warning = game.attack_warning(e)
		if game.depth_enabled and e.kind == Catalog.Enemy.BOSS: continue
		if not e.active:
			game.draw_line(p + e.dir * 13, p + e.dir * 23, Color("ffb95e") if e.searching else Color("8194aa"), 2)
		if game.depth_enabled and Catalog.is_mob(e.kind):
			if e.kind == Catalog.Enemy.SHIELD:
				var facing: Vector2 = e.dir
				var edge: Vector2 = facing.orthogonal()*15
				game.draw_line(p+facing*16-edge, p+facing*16+edge, Color("c7eaff"), 4)
			continue
		if e.kind == Catalog.Enemy.CHASER:
			game.draw_rect(Rect2(p - Vector2(10,10), Vector2(20,20)), Color("f3637a"))
		elif e.kind == Catalog.Enemy.SNIPER:
			game.draw_circle(p, 12, Color("ffb95e").lerp(Color("fff4dd"),maxf(warning,game.boss.shot_flash(game,e.p))))
			game.draw_circle(p, lerpf(5.0,1.5,warning), Color("342338"))
		elif e.kind == Catalog.Enemy.SHIELD:
			var extent = 12.0 - warning*2.0
			game.draw_rect(Rect2(p - Vector2.ONE*extent, Vector2.ONE*extent*2), Color("ad8fff").lerp(Color("fff4dd"),warning))
			var dir: Vector2 = e.dir
			var side = dir.orthogonal() * 15
			game.draw_line(p + dir * 16 - side, p + dir * 16 + side, Color("c7eaff"), 4)
		elif e.kind in [Catalog.Enemy.FLANKER,Catalog.Enemy.INTERCEPTOR]:
			MobVisuals.draw_body(game,e)
		else:
			var ink: Color = game.boss.COLORS[game.boss_variant]
			ink = ink.lerp(Color("fff5ff"),game.boss.shot_flash(game,e.p)*0.8)
			if game.boss_variant == 0:
				game.draw_colored_polygon(PackedVector2Array([p+Vector2(-20,0),p+Vector2(0,-20),p+Vector2(20,0),p+Vector2(0,20)]),ink.darkened(0.55))
			elif game.boss_variant == 1:
				var angle: float = e.dir.angle()
				game.draw_colored_polygon(PackedVector2Array([p+Vector2(-24,-18).rotated(angle),p+Vector2(24,0).rotated(angle),p+Vector2(-24,18).rotated(angle)]),ink.darkened(0.35))
			else:
				game.draw_circle(p,24,ink.darkened(0.55))
				game.draw_arc(p,29,0,TAU,32,ink,2)
			var extent = lerpf(12.0,7.0,warning)
			game.draw_rect(Rect2(p-Vector2.ONE*extent,Vector2.ONE*extent*2),ink.lerp(Color.WHITE,warning))
	for b in game.bullets:
		if game.cells.get(game.tile(b.p), -1) >= 0 and not game.discovered.has(game.cells[game.tile(b.p)]): continue
		var bullet_ink = Color("ff788e") if b.get("pressure",false) else (Color("d996ed") if b.get("guided",false) else Color("ffb95e"))
		if not b.hostile and b.get("scatter_visual",false):
			var tail: Vector2 = game.attack_end(b.p,-b.v.normalized(),16)
			game.draw_line(tail,b.p,Color(0.45,1,0.86,0.45),4)
			game.draw_line(tail.lerp(b.p,0.5),b.p,Color("e2fff5"),2)
		else:
			var tail: Vector2 = b.p-b.v.normalized()*12
			if b.hostile:
				game.draw_line(tail,b.p,Color("151520"),6,true)
				game.draw_line(tail,b.p,bullet_ink,4,true)
				game.draw_line(b.p-b.v.normalized()*4,b.p,Color("fff0d5"),1.5,true)
			else:
				game.draw_line(tail,b.p,Color(0.35,1,0.82,0.22),4,true)
				game.draw_line(tail,b.p,Color("d5fff2"),1.5,true)
	var preview_aim: Vector2 = game.controls.aim(game)
	var preview_alpha = 0.18 if game.sub_cd <= 0 else 0.06
	if game.sub_weapon == 0:
		var fan = PackedVector2Array([game.player])
		for i in range(25): fan.append(game.attack_end(game.player, preview_aim.rotated((i / 24.0 - 0.5) * Catalog.WEAPONS[0].spread * (Catalog.WEAPONS[0].pellets-1)), game.session.run.sub_reach(0)))
		fan.append(game.player)
		draw_radial_fill(game, game.player, fan, Color(1,0.75,0.4,preview_alpha * 0.4))
		game.draw_polyline(fan,Color(1,0.75,0.4,preview_alpha * 2),1)
	elif game.sub_weapon == 2:
		draw_lance(game,game.LanceTrace.lanes(game,game.player,preview_aim),preview_alpha,0)
	if game.sub_weapon == 1:
		var outline = PackedVector2Array()
		outline = shock_outline(game,game.player,game.SHOCK_RADIUS)
		draw_radial_fill(game, game.player, outline, Color(0.3, 1, 0.85, 0.035))
		game.draw_polyline(outline, Color(0.3, 1, 0.85, 0.3 if game.sub_cd <= 0 else 0.08), 1)
	for effect in game.effects:
		if effect.kind == 5:
			if effect.life < 0.02: continue
			var progress: float = clampf(1-effect.life/0.30,0,1)
			var ink := Color(1,0.42,0.55,(1-progress)*0.8)
			for i in range(6):
				var axis := Vector2.from_angle(i*TAU/6)
				var center: Vector2 = effect.p+axis*(8+progress*22)
				var side := axis.orthogonal()*(3*(1-progress))
				game.draw_polyline(PackedVector2Array([center-axis*3-side,center+side,center+axis*5+side]),ink,1.6,true)
			game.draw_arc(effect.p,8+progress*12,0,TAU,24,Color(1,0.8,0.85,(1-progress)*(1-progress)*0.5),1,true)
		elif effect.kind == 2:
			var fade: float = clampf(effect.life/0.10,0,1)
			var radius := 9+(1-fade)*6
			if effect.blocked:
				var ink := Color(0.55,0.82,1.0,fade)
				for side in [-1,1]:
					var points := PackedVector2Array([effect.p+Vector2(side*(radius-4),-8),effect.p+Vector2(side*radius,-4),effect.p+Vector2(side*radius,4),effect.p+Vector2(side*(radius-4),8)])
					game.draw_polyline(points,ink,2,true)
			else:
				var ink := Color(1.0,0.9,0.76,fade)
				game.draw_circle(effect.p,3*fade,Color(1,0.98,0.9,fade*0.8))
				for i in range(4):
					var ray := Vector2.from_angle(PI/4+i*PI/2)
					game.draw_line(effect.p+ray*(radius-5),effect.p+ray*radius,ink,2,true)
		elif effect.kind == 0:
			var outline = PackedVector2Array()
			var reach_outline = PackedVector2Array()
			var progress: float = 1.0 - effect.life / 0.4
			outline = shock_outline(game,effect.p,game.SHOCK_RADIUS * minf(1, progress * 3))
			reach_outline = shock_outline(game,effect.p,game.SHOCK_RADIUS)
			# Damage is immediate: show the clipped full reach from the first frame.
			var arrival := maxf(0,1.0-progress/0.45)
			draw_radial_fill(game, effect.p, reach_outline, Color(0.3,1,0.85,arrival*0.045))
			game.draw_polyline(reach_outline,Color(0.4,1,0.9,arrival*0.65),1.5)
			game.draw_polyline(outline,Color(0.3,1,0.85,effect.life/0.4*0.22),11,true)
			game.draw_polyline(outline,Color(0.7,1,0.93,effect.life/0.4),2,true)
		elif effect.kind == 1:
			var fade: float = minf(1.0,effect.life/0.09)
			var core: float = clampf((effect.life-0.16)/0.12,0,1)
			draw_lance(game,effect.rays,0.28*fade,core)
	draw_particles(game)
	for entry in game.damage_labels:
		var number = damage_number(entry.damage)
		var alpha = minf(1.0, entry.life / 0.2)
		game.label_at(entry.p + Vector2(1,1), number, 17, Color(0.02,0.03,0.05,alpha))
		game.label_at(entry.p, number, 17, Color(1.0,0.95,0.75,alpha))
	if game.grace <= 0 or fmod(game.grace, 0.16) < 0.1:
		if not game.depth_enabled: game.draw_circle(game.player, 12, Color("63f5ce"))
		game.draw_circle(game.player, game.PLAYER_HIT_RADIUS, Color("13252f"))
	var aim: Vector2 = game.controls.aim(game)
	if not game.depth_enabled:
		for side in [-1.0,1.0]:
			var barrel_offset: Vector2 = aim.orthogonal()*side*3.5
			game.draw_line(game.player+aim*9+barrel_offset,game.player+aim*19+barrel_offset,Color("3ba88f"),2.5)
	game.draw_line(game.player + aim * 12, game.player + aim * 21, Color.WHITE, 2)
	# Keep the clipped firing fan above the hull and the narrow aiming marker.
	for effect in game.effects:
		if effect.kind != 3: continue
		var fade: float = clampf(effect.life/0.08,0,1)
		for tip in effect.tips:
			if effect.p.distance_to(tip) <= 12: continue
			var start: Vector2 = effect.p.move_toward(tip,12)
			game.draw_line(start,tip,Color(0.76,1,0.9,fade*0.85),2)
	if game.grace > 0:
		# The existing one-second protection is readable without delaying retry.
		var remaining: float = clampf(game.grace,0,1)
		game.draw_arc(game.player,21,-PI/2,-PI/2+TAU*remaining,48,Color("63f5ce"),2)
	if not game.boss_floor and game.time_left <= 5.0:
		game.draw_arc(game.player,29,-PI/2,-PI/2+TAU*clampf(game.time_left/5,0.001,1),48,Color(1,0.28,0.34,0.8),3)

func draw_lance(game, rays: Array, alpha: float, core: float) -> void:
	for i in range(rays.size()):
		var ray: Dictionary = rays[i]
		if ray.p.distance_squared_to(ray.end) < 0.01: continue
		var side: Vector2 = ray.p.direction_to(ray.end).orthogonal()*ray.width*0.5
		game.draw_colored_polygon(PackedVector2Array([ray.p-side,ray.end-side,ray.end+side,ray.p+side]),Color(0.62,0.86,1,alpha))
		game.draw_line(ray.end-side,ray.end+side,Color(0.78,0.94,1,minf(1,alpha*2)),1)
		if absf(i-(rays.size()-1)*0.5) <= 1 and core > 0:
			game.draw_line(ray.p,ray.end,Color(0.88,0.98,1,0.9*core),ray.width)

func draw_radial_fill(game, origin: Vector2, outline: PackedVector2Array, color: Color) -> void:
	for i in range(outline.size() - 1):
		if absf((outline[i] - origin).cross(outline[i + 1] - origin)) > 0.01:
			game.draw_colored_polygon(PackedVector2Array([origin, outline[i], outline[i + 1]]), color)

func draw_options(game) -> void:
	if game.depth_enabled and game.boss_variant == 2: return
	for option in game.boss.options:
		var charge: float = game.boss.option_warning(option)
		var ink := Color("ffc46b").lerp(Color("fff5e2"),maxf(charge,game.boss.shot_flash(game,option.p)))
		game.draw_circle(option.p,11,Color("263847"))
		game.draw_arc(option.p,11,0,TAU,16,ink,1.5)
		var half := 5.0-charge*2.0
		game.draw_rect(Rect2(option.p-Vector2.ONE*half,Vector2.ONE*half*2),ink)

func draw_lasers(game) -> void:
	for beam in game.boss.lasers:
		if beam.owner.hp <= 0: continue
		if beam.warning > 0:
			game.draw_line(beam.a,beam.b,Color(0.08,0.06,0.1,0.65),3,true)
			game.draw_line(beam.a,beam.b,Color(1,0.45,0.35,0.65),1.5,true)
		else:
			game.draw_line(beam.a,beam.b,Color(1,0.35,0.25,0.35),12)
			game.draw_line(beam.a,beam.b,Color("ff8c68"),7,true)
			game.draw_line(beam.a,beam.b,Color("fff3dc"),3,true)

func draw_particles(game) -> void:
	if particle_batch == null:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for p in [Vector3(-1,0,0),Vector3(0,1,0),Vector3(1,0,0),Vector3(-1,0,0),Vector3(1,0,0),Vector3(0,-1,0)]:
			surface.add_vertex(p)
		particle_batch = MultiMesh.new()
		particle_batch.transform_format = MultiMesh.TRANSFORM_2D
		particle_batch.use_colors = true
		particle_batch.mesh = surface.commit()
		particle_batch.instance_count = 2048
	var count: int = game.particles.size()
	if particle_batch.instance_count < count: particle_batch.instance_count = maxi(count,particle_batch.instance_count*2)
	particle_batch.visible_instance_count = count
	for i in range(count):
		var p: Dictionary = game.particles[i]
		var fade: float = clampf(p.life/0.35,0,1)
		var axis: Vector2 = p.v.normalized()
		particle_batch.set_instance_transform_2d(i,Transform2D(axis*(2+fade*3),axis.orthogonal()*1.5,p.p))
		particle_batch.set_instance_color(i,Color(p.color,fade))
	if count > 0:
		game.draw_multimesh(particle_batch,null)
		particles_warmed = true
	elif not particles_warmed:
		# Prepare the canvas pipeline before the first mass kill, not during it.
		particle_batch.visible_instance_count = 1
		particle_batch.set_instance_transform_2d(0,Transform2D.IDENTITY)
		particle_batch.set_instance_color(0,Color.TRANSPARENT)
		game.draw_multimesh(particle_batch,null)
		particles_warmed = true

static func damage_number(damage: float) -> String:
	return str(roundi(damage * 10.0))
