extends RefCounted

const Catalog = preload("res://scripts/combat_catalog.gd")

# Read-only 2D presentation. All commands use the host CanvasItem during _draw.
# Combat coordinates and attack clipping remain owned by the simulation.
func draw(game, screen: Vector2) -> void:
	if game.depth_enabled:
		game.draw_texture_rect(game.depth_view.viewport.get_texture(), Rect2(Vector2.ZERO, screen), false)
	var offset = screen * 0.5 - game.camera_pos
	game.draw_set_transform(offset)
	var view = Rect2(-offset - Vector2(32,32), screen + Vector2(64,64))
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
	if game.stairs_unlocked and game.discovered.has(game.goal_room):
		game.draw_rect(Rect2(game.stairs - Vector2(23,23), Vector2(46,46)), Color("24493c"))
		for i in range(4): game.draw_line(game.stairs + Vector2(-16 + i * 4, -12 + i * 8), game.stairs + Vector2(16, -12 + i * 8), Color("65ffcf"), 3)
		game.label_at(game.stairs + Vector2(-30,-34), "DESCEND", 13, Color("65ffcf"))
	draw_lasers(game)
	draw_options(game)
	for e in game.enemies:
		if game.cells.get(game.tile(e.p), -1) >= 0 and not game.discovered.has(game.cells[game.tile(e.p)]): continue
		var p: Vector2 = e.p
		var warning = game.attack_warning(e)
		if game.depth_enabled and e.kind == 3 and game.boss_variant == 2: continue
		if not e.active:
			game.draw_line(p + e.dir * 13, p + e.dir * 23, Color("ffb95e") if e.searching else Color("8194aa"), 2)
		if game.depth_enabled and e.kind < 3:
			if e.kind == 2:
				var facing: Vector2 = e.dir
				var edge: Vector2 = facing.orthogonal()*15
				game.draw_line(p+facing*16-edge, p+facing*16+edge, Color("c7eaff"), 4)
			continue
		if e.kind == 0:
			game.draw_rect(Rect2(p - Vector2(10,10), Vector2(20,20)), Color("f3637a"))
		elif e.kind == 1:
			game.draw_circle(p, 12, Color("ffb95e").lerp(Color("fff4dd"),warning))
			game.draw_circle(p, lerpf(5.0,1.5,warning), Color("342338"))
		elif e.kind == 2:
			var extent = 12.0 - warning*2.0
			game.draw_rect(Rect2(p - Vector2.ONE*extent, Vector2.ONE*extent*2), Color("ad8fff").lerp(Color("fff4dd"),warning))
			var dir: Vector2 = e.dir
			var side = dir.orthogonal() * 15
			game.draw_line(p + dir * 16 - side, p + dir * 16 + side, Color("c7eaff"), 4)
		else:
			var ink: Color = game.boss.COLORS[game.boss_variant]
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
		game.draw_line(b.p, b.p - b.v.normalized() * 12, bullet_ink if b.hostile else Color("b2fff0"), 4 if b.hostile else 2)
	var preview_aim: Vector2 = game.controls.aim(game)
	var preview_alpha = 0.18 if game.sub_cd <= 0 else 0.06
	if game.sub_weapon == 0:
		var fan = PackedVector2Array([game.player])
		for i in range(25): fan.append(game.attack_end(game.player, preview_aim.rotated((i / 24.0 - 0.5) * Catalog.WEAPONS[0].spread * (Catalog.WEAPONS[0].pellets-1)), Catalog.WEAPONS[0].reach))
		fan.append(game.player)
		draw_radial_fill(game, game.player, fan, Color(1,0.75,0.4,preview_alpha * 0.4))
		game.draw_polyline(fan,Color(1,0.75,0.4,preview_alpha * 2),1)
	elif game.sub_weapon == 2:
		var end = game.attack_end(game.player, preview_aim, game.LANCE_RANGE)
		game.draw_line(game.player,end,Color(0.78,0.94,1,preview_alpha),game.LANCE_WIDTH)
		var side = preview_aim.orthogonal()*game.LANCE_WIDTH*0.5
		game.draw_line(end-side,end+side,Color(0.78,0.94,1,preview_alpha*2),2)
	if game.sub_weapon == 1:
		var outline = PackedVector2Array()
		for i in range(97): outline.append(game.attack_end(game.player, Vector2.from_angle(i * TAU / 96), game.SHOCK_RADIUS))
		draw_radial_fill(game, game.player, outline, Color(0.3, 1, 0.85, 0.035))
		game.draw_polyline(outline, Color(0.3, 1, 0.85, 0.3 if game.sub_cd <= 0 else 0.08), 1)
	for effect in game.effects:
		if effect.kind == 2:
			var fade: float = clampf(effect.life/0.10,0,1)
			if effect.blocked:
				# Open brackets distinguish a shield stop from a damaging hit.
				var ink := Color(0.55,0.82,1.0,fade*0.8)
				game.draw_arc(effect.p,12,-0.65,0.65,8,ink,2)
				game.draw_arc(effect.p,12,PI-0.65,PI+0.65,8,ink,2)
			else:
				var ink := Color(1.0,0.9,0.76,fade*0.85)
				for i in range(4):
					var ray := Vector2.from_angle(PI/4+i*PI/2)
					game.draw_line(effect.p+ray*6,effect.p+ray*11,ink,2)
		elif effect.kind == 0:
			var outline = PackedVector2Array()
			var progress: float = 1.0 - effect.life / 0.4
			for i in range(97): outline.append(game.attack_end(effect.p, Vector2.from_angle(i * TAU / 96), game.SHOCK_RADIUS * minf(1, progress * 3)))
			draw_radial_fill(game, effect.p, outline, Color(0.3, 1, 0.85, effect.life * 0.4))
			game.draw_polyline(outline, Color(0.4, 1, 0.9, effect.life / 0.4), 5)
		else:
			var direction: Vector2 = effect.p.direction_to(effect.end)
			var length: float = effect.p.distance_to(effect.end)
			var tip_size = minf(18.0, length * 0.4)
			var neck: Vector2 = effect.end - direction * tip_size
			var side = direction.orthogonal()
			var ink = Color(0.78, 0.94, 1.0, 0.55 * minf(1.0, effect.life / 0.09))
			if length > 1.0:
				game.draw_line(effect.p, neck, ink, game.LANCE_WIDTH)
				game.draw_colored_polygon(PackedVector2Array([effect.end, neck + side * game.LANCE_WIDTH * 0.65, neck - side * game.LANCE_WIDTH * 0.65]), ink)
	for p in game.particles: game.draw_rect(Rect2(p.p, Vector2(3,3)), Color(p.color, p.life / 0.35))
	for entry in game.damage_labels:
		var number = str(int(round(entry.damage))) if is_equal_approx(entry.damage, round(entry.damage)) else "%.1f" % entry.damage
		var alpha = minf(1.0, entry.life / 0.2)
		game.label_at(entry.p + Vector2(1,1), number, 17, Color(0.02,0.03,0.05,alpha))
		game.label_at(entry.p, number, 17, Color(1.0,0.95,0.75,alpha))
	if game.grace <= 0 or fmod(game.grace, 0.16) < 0.1:
		if not game.depth_enabled: game.draw_circle(game.player, 12, Color("63f5ce"))
		game.draw_circle(game.player, game.PLAYER_HIT_RADIUS, Color("13252f"))
	var aim: Vector2 = game.controls.aim(game)
	game.draw_line(game.player + aim * 8, game.player + aim * 23, Color.WHITE, 5)
	if game.grace > 0: game.draw_arc(game.player, 21, 0, TAU, 32, Color("63f5ce"), 1)
	if not game.boss_floor and game.time_left <= 5.0:
		game.draw_arc(game.player,29,-PI/2,-PI/2+TAU*clampf(game.time_left/5,0.001,1),48,Color(1,0.28,0.34,0.8),3)

func draw_radial_fill(game, origin: Vector2, outline: PackedVector2Array, color: Color) -> void:
	for i in range(outline.size() - 1):
		if absf((outline[i] - origin).cross(outline[i + 1] - origin)) > 0.01:
			game.draw_colored_polygon(PackedVector2Array([origin, outline[i], outline[i + 1]]), color)

func draw_options(game) -> void:
	if game.depth_enabled and game.boss_variant == 2: return
	for option in game.boss.options:
		var charge: float = game.boss.option_warning(option)
		var ink := Color("ffc46b").lerp(Color("fff5e2"),charge)
		game.draw_circle(option.p,11,Color("263847"))
		game.draw_arc(option.p,11,0,TAU,16,ink,1.5)
		var half := 5.0-charge*2.0
		game.draw_rect(Rect2(option.p-Vector2.ONE*half,Vector2.ONE*half*2),ink)

func draw_lasers(game) -> void:
	for beam in game.boss.lasers:
		if beam.owner.hp <= 0: continue
		if beam.warning > 0:
			game.draw_line(beam.a,beam.b,Color(1,0.45,0.35,0.65),1.5)
		else:
			game.draw_line(beam.a,beam.b,Color(1,0.35,0.25,0.35),12)
			game.draw_line(beam.a,beam.b,Color("ffe2c9"),4)
