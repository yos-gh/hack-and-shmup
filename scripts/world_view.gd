extends RefCounted

const MobVisuals = preload("res://scripts/mob_visuals.gd")
const Catalog = preload("res://scripts/combat_catalog.gd")
const Pickups = preload("res://scripts/pickups.gd")
const DepthView = preload("res://scripts/depth_view.gd")
const BossFx = preload("res://scripts/boss_fx.gd")
var particle_batch: MultiMesh
var particles_warmed := false
var field_projectiles = preload("res://scripts/field_projectiles.gd").new()
var radial_cache: Dictionary = {}
var radial_floor := -1
var radial_discovery := -1
var radial_reach := -1.0
var glow_texture: Texture2D = soft_glow()
var guide_key: Array = []
var guide_rays: Array = []
var burst_strokes := PackedVector2Array()
var burst_stroke_colors := PackedColorArray()
var burst_rings := PackedVector2Array()
var burst_ring_colors := PackedColorArray()
var burst_dots := PackedVector2Array()
var burst_dot_colors := PackedColorArray()
const DOT_SEGMENTS := 16

static func soft_glow() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0,0.25,1.0])
	gradient.colors = PackedColorArray([Color(1,1,1,1),Color(1,1,1,0.35),Color(1,1,1,0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5,0.5)
	texture.fill_to = Vector2(0.5,0.0)
	texture.width = 64
	texture.height = 64
	return texture

func glow(game, p: Vector2, radius: float, color: Color) -> void:
	game.draw_texture_rect(glow_texture,Rect2(p-Vector2.ONE*radius,Vector2.ONE*radius*2),false,color)

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
	if game.boss_floor and game.boss_variant == 0: game.boss.fortress.draw(game)
	if game.boss_floor and game.boss_variant == 1: game.boss.bastion.draw(game)
	if game.boss_floor and game.boss_variant == 2: game.boss.triad.draw(game)
	if game.boss_floor and game.boss_variant == 3: game.boss.wyrm.draw(game)
	for e in game.enemies:
		var room: int = game.cells.get(game.tile(e.p), -1)
		if room >= 0 and not game.discovered.has(room): continue
		var p: Vector2 = e.p
		MobVisuals.draw_warning(game,e)
		if e.kind == Catalog.Enemy.BOSS: continue
		# Every remaining mob mark stays within 25px of its body, inside the
		# view's 32px margin, so off-screen mobs would draw nothing visible.
		if not view.has_point(p): continue
		var warning = game.attack_warning(e)
		if e.has("drop"): draw_carrier_mark(game,e)
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
	draw_pickups(game)
	field_projectiles.draw(game,view)
	for b in game.bullets:
		var shape: String = Catalog.projectile_shape(b)
		if shape == "pearl": continue
		if game.cells.get(game.tile(b.p), -1) >= 0 and not game.discovered.has(game.cells[game.tile(b.p)]): continue
		if b.get("energy_orb",false):
			var radius: float = b.orb_radius
			var charge: bool = b.orb_phase == "charge"
			var flash: float = clampf(b.orb_flash/0.15,0.0,1.0)
			glow(game,b.p,radius*2.1,Color(0.62,0.3,1.0,0.32+flash*0.3))
			if not charge and b.v.length() > 0:
				var tail: Vector2 = b.p-b.v.normalized()*minf(58.0,b.v.length()*0.2)
				game.draw_line(tail,b.p,Color(0.72,0.4,1.0,0.25),radius*0.7,true)
			game.draw_circle(b.p,radius+6,Color(0.57,0.26,0.82,0.14+flash*0.18))
			game.draw_circle(b.p,radius,Color(0.6,0.31,0.91,0.37+flash*0.2))
			game.draw_arc(b.p,radius,0,TAU,48,Color(0.9,0.67,1.0,0.8),3,true)
			game.draw_arc(b.p,radius*0.66,0,TAU,40,Color(0.9,0.77,1.0,0.5),2,true)
			game.draw_circle(b.p,radius*0.36,Color(0.94,0.83,1.0,0.8))
			if charge:
				var progress: float = clampf(b.orb_age/1.05,0.0,1.0)
				game.draw_arc(b.p,radius+12,-PI/2,-PI/2+TAU*progress,48,Color(1.0,0.88,1.0,0.85),3,true)
			else:
				for spoke in range(6):
					var axis: Vector2 = Vector2.from_angle(spoke*TAU/6+b.orb_age*1.5)
					game.draw_line(b.p+axis*(radius+4),b.p+axis*(radius+13),Color(0.86,0.66,1.0,0.5),2,true)
			continue
		var bullet_ink = Color("ff788e") if b.get("pressure",false) else (Color("d996ed") if b.get("guided",false) else Color("ffb95e"))
		if not b.hostile and b.get("scatter_visual",false):
			var tail: Vector2 = game.attack_end(b.p,-b.v.normalized(),22)
			game.draw_line(tail,b.p,Color(0.45,1,0.86,0.22),6,true)
			game.draw_line(tail.lerp(b.p,0.3),b.p,Color(0.55,1,0.88,0.7),2.5,true)
			game.draw_line(tail.lerp(b.p,0.7),b.p,Color("f2fffb"),1.5,true)
		else:
			var heading: Vector2 = b.v.normalized()
			if b.hostile:
				var tail: Vector2 = b.p-heading*12
				if b.get("guided",false):
					# Guided seekers leave a fading exhaust plume.
					for k in range(3):
						game.draw_line(b.p-heading*(10+k*9),b.p-heading*(19+k*9),Color(bullet_ink,0.32-k*0.09),5.0-k,true)
				# Hostile shots keep a dark keyline, then a warm danger halo and hot core.
				glow(game,b.p,11,Color(bullet_ink,0.30))
				game.draw_line(tail,b.p,Color("151520"),6,true)
				game.draw_line(tail,b.p,bullet_ink,4,true)
				game.draw_line(b.p-heading*5,b.p,Color("fff6e6"),2,true)
				if shape == "seeker":
					var fin: Vector2 = heading.orthogonal()*5
					game.draw_polyline(PackedVector2Array([tail+fin,b.p-heading*5,tail-fin]),bullet_ink,2,true)
			else:
				var tail: Vector2 = b.p-heading*18
				game.draw_line(tail,b.p,Color(0.35,1,0.82,0.18),5,true)
				game.draw_line(tail.lerp(b.p,0.35),b.p,Color(0.5,1,0.86,0.6),2.2,true)
				game.draw_line(b.p-heading*6,b.p,Color("f4fffb"),1.6,true)
	var preview_aim: Vector2 = game.controls.aim(game)
	var preview_alpha = 0.18 if game.sub_cd <= 0 else 0.06
	if game.sub_weapon == 0:
		var fan = PackedVector2Array([game.player])
		for i in range(25): fan.append(game.attack_end(game.player, preview_aim.rotated((i / 24.0 - 0.5) * Catalog.WEAPONS[0].spread * (Catalog.WEAPONS[0].pellets-1)), game.session.run.sub_reach(0)))
		fan.append(game.player)
		draw_radial_fill(game, game.player, fan, Color(1,0.75,0.4,preview_alpha * 0.4))
		game.draw_polyline(fan,Color(1,0.75,0.4,preview_alpha * 2),1)
	elif game.sub_weapon == 2:
		draw_lance_guide(game,guide_lanes(game,preview_aim),game.sub_cd <= 0,game.hud.cooldown_fraction(game))
	if game.sub_weapon == 1:
		var outline = PackedVector2Array()
		outline = shock_outline(game,game.player,game.SHOCK_RADIUS)
		draw_radial_fill(game, game.player, outline, Color(0.3, 1, 0.85, 0.035))
		game.draw_polyline(outline, Color(0.3, 1, 0.85, 0.3 if game.sub_cd <= 0 else 0.08), 1)
	# Kill bursts and hit marks arrive in dozens at once (a Shockwave clearing a
	# crowd): their strokes and dots are gathered and drawn once after the loop
	# instead of as hundreds of separate polyline/arc/circle draws.
	burst_strokes.clear()
	burst_stroke_colors.clear()
	burst_rings.clear()
	burst_ring_colors.clear()
	burst_dots.clear()
	burst_dot_colors.clear()
	for effect in game.effects:
		if effect.kind == 5:
			if effect.life < 0.02: continue
			var progress: float = clampf(1-effect.life/0.30,0,1)
			var ink := Color(1,0.42,0.55,(1-progress)*0.9)
			var flash: float = maxf(0,1-progress*3.0)
			if flash > 0: glow(game,effect.p,14+progress*24,Color(1,0.75,0.8,flash*0.45))
			glow(game,effect.p,26+progress*22,Color(1,0.3,0.45,(1-progress)*0.2))
			for i in range(6):
				var axis := Vector2.from_angle(i*TAU/6+progress*0.6)
				var center: Vector2 = effect.p+axis*(8+progress*30)
				var side := axis.orthogonal()*(3*(1-progress))
				add_stroke(burst_strokes,burst_stroke_colors,PackedVector2Array([center-axis*3-side,center+side,center+axis*5+side]),ink)
			add_ring(burst_strokes,burst_stroke_colors,effect.p,8+progress*26,32,Color(1,0.85,0.9,(1-progress)*(1-progress)*0.8))
			add_ring(burst_rings,burst_ring_colors,effect.p,6+progress*16,24,Color(1,0.45,0.6,(1-progress)*0.5))
		elif effect.kind == 2:
			var fade: float = clampf(effect.life/0.10,0,1)
			var radius := 9+(1-fade)*6
			if effect.blocked:
				var ink := Color(0.55,0.82,1.0,fade)
				for side in [-1,1]:
					var points := PackedVector2Array([effect.p+Vector2(side*(radius-4),-8),effect.p+Vector2(side*radius,-4),effect.p+Vector2(side*radius,4),effect.p+Vector2(side*(radius-4),8)])
					add_stroke(burst_strokes,burst_stroke_colors,points,ink)
			else:
				var ink := Color(1.0,0.9,0.76,fade)
				glow(game,effect.p,14,Color(1,0.85,0.6,fade*0.55))
				add_dot(effect.p,3*fade,Color(1,0.98,0.9,fade*0.8))
				for i in range(4):
					var ray := Vector2.from_angle(PI/4+i*PI/2)
					add_stroke(burst_strokes,burst_stroke_colors,PackedVector2Array([effect.p+ray*(radius-5),effect.p+ray*radius]),ink)
		elif effect.kind == 0:
			var outline = PackedVector2Array()
			var reach_outline = PackedVector2Array()
			var progress: float = 1.0 - effect.life / 0.4
			outline = shock_outline(game,effect.p,game.SHOCK_RADIUS * minf(1, progress * 3))
			reach_outline = shock_outline(game,effect.p,game.SHOCK_RADIUS)
			# Damage is immediate: show the clipped full reach from the first frame.
			var arrival := maxf(0,1.0-progress/0.45)
			var remaining: float = effect.life/0.4
			draw_radial_fill(game, effect.p, reach_outline, Color(0.3,1,0.85,arrival*0.07))
			if arrival > 0: glow(game,effect.p,game.SHOCK_RADIUS*0.6,Color(0.5,1,0.9,arrival*0.35))
			game.draw_polyline(reach_outline,Color(0.4,1,0.9,arrival*0.65),1.5)
			game.draw_polyline(outline,Color(0.2,0.9,1.0,remaining*0.10),26,true)
			game.draw_polyline(outline,Color(0.3,1,0.85,remaining*0.25),11,true)
			game.draw_polyline(outline,Color(0.85,1,0.96,remaining),2.5,true)
		elif effect.kind == 1:
			var fade: float = minf(1.0,effect.life/0.09)
			var core: float = clampf((effect.life-0.16)/0.12,0,1)
			draw_lance_fire(game,effect.rays,fade,core)
	if not burst_dots.is_empty():
		var indices := PackedInt32Array()
		indices.resize(burst_dots.size()/DOT_SEGMENTS*(DOT_SEGMENTS-2)*3)
		var k := 0
		for base in range(0,burst_dots.size(),DOT_SEGMENTS):
			for i in range(1,DOT_SEGMENTS-1):
				indices[k] = base
				indices[k+1] = base+i
				indices[k+2] = base+i+1
				k += 3
		RenderingServer.canvas_item_add_triangle_array(game.get_canvas_item(),indices,burst_dots,burst_dot_colors)
	if not burst_strokes.is_empty(): game.draw_multiline_colors(burst_strokes,burst_stroke_colors,2.0,true)
	if not burst_rings.is_empty(): game.draw_multiline_colors(burst_rings,burst_ring_colors,1.2,true)
	draw_particles(game)
	for entry in game.damage_labels:
		var number = damage_number(entry.damage)
		var alpha = minf(1.0, entry.life / 0.2)
		# Fresh numbers pop slightly larger, then settle.
		var size := 17 if entry.life < 0.55 else 20
		game.label_at(entry.p + Vector2(1,2), number, size, Color(0.02,0.03,0.05,alpha*0.9))
		game.label_at(entry.p, number, size, Color(1.0,0.95,0.75,alpha).lerp(Color.WHITE,clampf((entry.life-0.5)*6,0,1)))
	draw_phase_trail(game)
	if game.grace <= 0 or fmod(game.grace, 0.16) < 0.1:
		var breath: float = 0.5+0.5*sin(game.presentation.clock*5.0)
		glow(game,game.player,34+breath*4,Color(0.3,1,0.85,0.20+breath*0.06))
		if not game.depth_enabled: game.draw_circle(game.player, 12, Color("63f5ce"))
		var spin: float = game.presentation.clock*1.4
		for i in range(3):
			var start: float = spin+i*TAU/3
			game.draw_arc(game.player,17,start,start+0.75,10,Color(0.39,0.96,0.81,0.6),1.5,true)
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
	draw_buffs(game)
	if game.grace > 0:
		# The existing one-second protection is readable without delaying retry.
		var remaining: float = clampf(game.grace,0,1)
		game.draw_arc(game.player,21,-PI/2,-PI/2+TAU*remaining,48,Color("63f5ce"),2)
	if not game.boss_floor and game.time_left <= 5.0:
		game.draw_arc(game.player,29,-PI/2,-PI/2+TAU*clampf(game.time_left/5,0.001,1),48,Color(1,0.28,0.34,0.8),3)

# The aiming guide reuses its traced lanes while the player, aim, width and
# opened rooms are unchanged.
func guide_lanes(game, aim: Vector2) -> Array:
	var key: Array = [game.player,aim,game.LANCE_WIDTH,game.floor_revision,game.discovered.hash()]
	if key != guide_key:
		guide_key = key
		guide_rays = game.LanceTrace.lanes(game,game.player,aim)
	return guide_rays

const LANCE_INK := Color(0.55,0.84,1.0)
const TAPER_SAMPLES := [0.0,5.0,10.0,17.0,26.0]

# Tapered outline of one lane: left edge forward, right edge back.
func lane_polygon(game, ray: Dictionary, direction: Vector2, scale: float = 1.0) -> PackedVector2Array:
	var length: float = ray.p.distance_to(ray.end)
	var side := direction.orthogonal()
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var samples: Array = TAPER_SAMPLES.filter(func(d): return d < length)
	samples.append(length)
	for d in samples:
		var center: Vector2 = game.LanceTrace.lane_point(ray,direction,d)
		var half: float = ray.width*0.5*game.LanceTrace.taper(d)*scale
		left.append(center-side*half)
		right.append(center+side*half)
	right.reverse()
	left.append_array(right)
	return left

# All lane fills as one triangle list: lanes abut without overlap, so a single
# draw matches per-lane polygons while avoiding one draw call per unit of width.
func draw_lane_fills(game, rays: Array, direction: Vector2, color: Color) -> void:
	var side := direction.orthogonal()
	var points := PackedVector2Array()
	var indices := PackedInt32Array()
	var tapers: Array = TAPER_SAMPLES.map(func(d): return game.LanceTrace.taper(d))
	for ray in rays:
		var length: float = ray.p.distance_to(ray.end)
		if length*length < 0.01: continue
		var offset: Vector2 = ray.p-ray.origin
		var half: float = ray.width*0.5
		var base := points.size()
		for j in range(TAPER_SAMPLES.size()+1):
			var d: float = TAPER_SAMPLES[j] if j < TAPER_SAMPLES.size() else length
			if d >= length and j < TAPER_SAMPLES.size(): continue
			var t: float = tapers[j] if j < TAPER_SAMPLES.size() else game.LanceTrace.taper(length)
			var center: Vector2 = ray.origin+offset*t+direction*d
			points.append(center-side*half*t)
			points.append(center+side*half*t)
		for k in range(base,points.size()-2,2):
			indices.append_array([k,k+2,k+1,k+1,k+2,k+3])
	if indices.is_empty(): return
	RenderingServer.canvas_item_add_triangle_array(game.get_canvas_item(),indices,points,PackedColorArray([color]))

func lance_direction(rays: Array) -> Vector2:
	for ray in rays:
		if ray.p.distance_squared_to(ray.end) > 0.01: return ray.p.direction_to(ray.end)
	return Vector2.ZERO

# Outer silhouette plus a stepped cap where lanes stop at different walls.
func lance_outline(game, rays: Array, direction: Vector2, ink: Color, width: float) -> void:
	var side := direction.orthogonal()
	for index in [0,rays.size()-1]:
		var ray: Dictionary = rays[index]
		var length: float = ray.p.distance_to(ray.end)
		if length < 0.1: continue
		var sign_value := -1.0 if index == 0 else 1.0
		var edge := PackedVector2Array()
		var samples: Array = TAPER_SAMPLES.filter(func(d): return d < length)
		samples.append(length)
		for d in samples:
			edge.append(game.LanceTrace.lane_point(ray,direction,d)+side*sign_value*ray.width*0.5*game.LanceTrace.taper(d))
		game.draw_polyline(edge,ink,width,true)
	var previous := Vector2.INF
	var caps := PackedVector2Array()
	for ray in rays:
		if ray.p.distance_squared_to(ray.end) < 0.01: continue
		var half: Vector2 = side*ray.width*0.5
		caps.append_array([ray.end-half,ray.end+half])
		if previous != Vector2.INF and previous.distance_to(ray.end-half) > 1.5:
			caps.append_array([previous,ray.end-half])
		previous = ray.end+half
	if not caps.is_empty(): game.draw_multiline(caps,ink,width)

func draw_lance_guide(game, rays: Array, ready: bool, fraction: float) -> void:
	var direction := lance_direction(rays)
	if direction == Vector2.ZERO: return
	draw_lane_fills(game,rays,direction,Color(LANCE_INK,0.07 if ready else 0.025))
	lance_outline(game,rays,direction,Color(LANCE_INK,0.6 if ready else 0.16),1.2)
	var middle: Dictionary = rays[int(rays.size()*0.5)]
	var length: float = middle.p.distance_to(middle.end)
	var origin: Vector2 = middle.origin
	if ready:
		# Marching dashes flow outward along the armed beam.
		var phase: float = fmod(game.presentation.clock*140.0,26.0)
		var d := 14.0+phase
		while d < length:
			game.draw_line(origin+direction*d,origin+direction*minf(d+11.0,length),Color(0.78,0.93,1.0,0.55),1.5,true)
			d += 26.0
	else:
		# Recharge fills the lane from the muzzle outward.
		game.draw_line(origin+direction*14,origin+direction*maxf(14,length*fraction),Color(LANCE_INK,0.32),2,true)

func draw_lance_fire(game, rays: Array, fade: float, core: float) -> void:
	var direction := lance_direction(rays)
	if direction == Vector2.ZERO: return
	draw_lane_fills(game,rays,direction,Color(0.62,0.86,1,0.34*fade))
	lance_outline(game,rays,direction,Color(0.82,0.96,1,0.9*fade),1.6)
	if core <= 0: return
	# The hot core follows the central lanes and the same muzzle taper.
	var middle: Dictionary = rays[int(rays.size()*0.5)]
	var total: float = game.LANCE_WIDTH
	var shaft := {"p":middle.origin,"origin":middle.origin,"end":middle.end,"width":total}
	game.draw_colored_polygon(lane_polygon(game,shaft,direction,1.9),Color(0.4,0.75,1,0.22*core))
	game.draw_colored_polygon(lane_polygon(game,shaft,direction,0.62),Color(0.85,0.97,1,0.85*core))
	game.draw_colored_polygon(lane_polygon(game,shaft,direction,0.22),Color(1,1,1,core))
	glow(game,middle.origin+direction*10,total*1.4+10,Color(0.7,0.92,1,core*0.7))
	glow(game,middle.end,total*2.0+10,Color(0.7,0.92,1,core*0.8))
	for i in range(4):
		var spark := Vector2.from_angle(direction.angle()+PI+(i-1.5)*0.55)
		game.draw_line(middle.end+spark*4,middle.end+spark*(10+total*0.8*core),Color(0.9,0.97,1,core),1.5,true)

# The same non-degenerate fan triangles as one triangle list: the Shockwave
# guide and blast would otherwise issue a polygon draw per outline segment.
func draw_radial_fill(game, origin: Vector2, outline: PackedVector2Array, color: Color) -> void:
	var points := PackedVector2Array([origin])
	points.append_array(outline)
	var indices := PackedInt32Array()
	for i in range(outline.size() - 1):
		if absf((outline[i] - origin).cross(outline[i + 1] - origin)) > 0.01:
			indices.append_array([0, i + 1, i + 2])
	if indices.is_empty(): return
	RenderingServer.canvas_item_add_triangle_array(game.get_canvas_item(), indices, points, PackedColorArray([color]))

# Polyline and closed ring as segment pairs for one draw_multiline_colors call.
static func add_stroke(lines: PackedVector2Array, colors: PackedColorArray, points: PackedVector2Array, color: Color) -> void:
	for i in range(points.size() - 1):
		lines.append(points[i])
		lines.append(points[i + 1])
		colors.append(color)

static func add_ring(lines: PackedVector2Array, colors: PackedColorArray, center: Vector2, radius: float, segments: int, color: Color) -> void:
	var previous := center + Vector2(radius, 0)
	for i in range(1, segments + 1):
		var next := center + Vector2.from_angle(i * TAU / segments) * radius
		lines.append(previous)
		lines.append(next)
		colors.append(color)
		previous = next

func add_dot(center: Vector2, radius: float, color: Color) -> void:
	for i in range(DOT_SEGMENTS):
		burst_dots.append(center + Vector2.from_angle(i * TAU / DOT_SEGMENTS) * radius)
		burst_dot_colors.append(color)

func draw_lasers(game) -> void:
	var clock: float = game.presentation.clock
	for beam in game.boss.lasers:
		if beam.owner.hp <= 0: continue
		var triad: bool = game.boss_variant == 2
		var hue: Color = beam.get("hue",Color("ffd9a8") if triad else Color("ff5a52"))
		var charging := -1.0
		if beam.warning > 0: charging = 1.0-beam.warning/beam.get("warning_total",1.15 if triad else 0.95)
		var flash: float = clampf((beam.duration-(beam.peak_duration-0.12))/0.12,0.0,1.0) if beam.warning <= 0 else 0.0
		BossFx.beam(game,beam.a,beam.b,float(beam.get("width",14.0)),hue,charging,flash,clock,beam.get("charge_radius",-1.0))

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
		# Speed-stretched sparks, white-hot at birth, cooling to their ink.
		particle_batch.set_instance_transform_2d(i,Transform2D(axis*(2.5+fade*6.5),axis.orthogonal()*(0.9+fade*0.9),p.p))
		particle_batch.set_instance_color(i,Color(p.color.lerp(Color.WHITE,fade*fade*0.55),minf(1,fade*1.4)))
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

# A faint glint orbiting a carrier; readable once learned, easy to overlook.
func draw_carrier_mark(game, e: Dictionary) -> void:
	var angle: float = game.presentation.clock*2.2+e.p.x*0.01
	var p: Vector2 = e.p+Vector2.from_angle(angle)*19
	var ink: Color = Pickups.COLORS[e.drop]
	game.draw_circle(p,1.8,Color(ink,0.75))
	game.draw_line(p-Vector2(3.5,0),p+Vector2(3.5,0),Color(ink,0.35),1)
	game.draw_line(p-Vector2(0,3.5),p+Vector2(0,3.5),Color(ink,0.35),1)

func draw_pickups(game) -> void:
	var clock: float = game.presentation.clock
	for item in game.pickups.items:
		if not DepthView.item_visible(game,item): continue
		var ink: Color = Pickups.COLORS[item.kind]
		var pulse: float = 0.5+0.5*sin(clock*4.0+item.p.x*0.03)
		glow(game,item.p,36+pulse*8,Color(ink,0.22+pulse*0.10))
		if item.pull > 0:
			# Streak back along the pull toward where the item came from.
			var tail: Vector2 = item.p+item.p.direction_to(game.player)*-minf(36.0,item.pull*0.05)
			game.draw_line(tail,item.p,Color(ink,0.55),3,true)
		var spin: float = clock*1.6+item.p.x*0.02
		if not game.depth_enabled:
			var diamond := PackedVector2Array()
			for k in range(4): diamond.append(item.p+Vector2.from_angle(spin+k*TAU/4)*9)
			game.draw_colored_polygon(diamond,Color(ink,0.35))
			diamond.append(diamond[0])
			game.draw_polyline(diamond,ink,1.5,true)
		# Ground halo: two counter-rotating arcs under the crystal.
		for k in range(2):
			var start: float = (spin if k == 0 else -spin*1.3)+k*PI
			game.draw_arc(item.p,15,start,start+1.6,12,Color(ink,0.45),1.2,true)
		if item.kind == Pickups.Kind.SPREAD:
			for k in [-1.0,0.0,1.0]:
				var tip: Vector2 = item.p+Vector2.UP.rotated(k*0.5)*23
				game.draw_line(tip-Vector2.UP.rotated(k*0.5)*4,tip,Color(ink,0.7),1.5,true)

func draw_phase_trail(game) -> void:
	var trail: Array[Vector2] = game.pickups.trail
	var ink: Color = Pickups.COLORS[Pickups.Kind.PHASE]
	for k in range(trail.size()):
		var fade: float = 1.0-float(k+1)/(trail.size()+1)
		game.draw_arc(trail[k],12,0,TAU,24,Color(ink,0.32*fade),2,true)
		game.draw_circle(trail[k],5,Color(ink,0.12*fade))

func draw_buffs(game) -> void:
	var clock: float = game.presentation.clock
	var ring := 25.0
	for kind in range(game.pickups.timers.size()):
		var left: float = game.pickups.timers[kind]
		if left <= 0: continue
		var fraction: float = clampf(left/Pickups.DURATIONS[kind],0,1)
		var ink: Color = Pickups.COLORS[kind]
		if game.pickups.fading(kind): ink.a = 0.25
		game.draw_arc(game.player,ring,-PI/2,-PI/2+TAU*fraction,40,ink,2,true)
		ring += 5.0
	if game.pickups.invincible():
		var ink: Color = Pickups.COLORS[Pickups.Kind.PHASE]
		for k in range(4):
			var a: float = clock*3.2+k*TAU/4
			game.draw_arc(game.player,19,a,a+0.5,8,Color(ink,0.0 if game.pickups.fading(Pickups.Kind.PHASE) else 0.75),2,true)
	if game.pickups.spread() and not game.depth_enabled:
		var aim: Vector2 = game.controls.aim(game)
		var ink: Color = Pickups.COLORS[Pickups.Kind.SPREAD]
		for side in [-1.0,1.0]:
			var splay: Vector2 = aim.rotated(side*Pickups.SPREAD_ANGLE*2.0)
			var root: Vector2 = game.player+aim.orthogonal()*side*7.0
			game.draw_line(root+splay*8,root+splay*16,ink,2)
	for flash in game.pickups.flashes:
		var t: float = 1.0-flash.life/0.45
		var ink: Color = Pickups.COLORS[flash.kind]
		game.draw_arc(game.player,14+t*46,0,TAU,40,Color(ink,(1.0-t)*0.8),3.0*(1.0-t)+1,true)
