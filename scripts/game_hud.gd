extends RefCounted

var minimap = preload("res://scripts/minimap.gd").new()

const Catalog = preload("res://scripts/combat_catalog.gd")
const Pickups = preload("res://scripts/pickups.gd")
const CYAN := Color("63f5ce")
const AMBER := Color("ffb95e")
const DANGER := Color("ff647c")
const MUTED := Color("7f93a8")
const PANEL := Color("0c1824")
# Banner typing state; presentation only.
var banner_start := 0.0
var banner_last := 0.0

# Presentation only; input and shared hit-region calculations stay on the host.
func draw(game, screen: Vector2) -> void:
	game.draw_set_transform(Vector2.ZERO)
	var clock: float = game.presentation.clock
	if game.view_comparison:
		label_at(game, Vector2(26,108), "F6 / " + (("3D  |  F7 / TILT %d DEG" % game.view_pitch_degrees) if game.depth_enabled else "CLASSIC 2D"), 13, Color("8194aa"))
	var layout := hud_layout(screen)
	var weapon: Rect2 = layout.weapon
	var timer: Rect2 = layout.timer
	var bar_width: float = layout.map.position.x-12 if layout.map.size.x>0 else screen.x
	# Top console: graded glass strip with a neon rule.
	gradient_rect(game, Rect2(0,0,screen.x,76), Color(0.012,0.027,0.05,0.97), Color(0.03,0.07,0.1,0.9))
	game.draw_line(Vector2(0,75.5),Vector2(screen.x,75.5),Color(0.25,0.55,0.62,0.55),1)
	draw_depth(game)
	game.draw_line(Vector2(238,16),Vector2(238,60),Color(0.25,0.45,0.52,0.45),1)
	game.draw_rect(Rect2(236,36,4,4),Color(0.39,0.96,0.81,0.7))
	draw_weapon(game, weapon)
	if game.boss_floor:
		var boss_ink: Color = game.boss.COLORS[game.boss_variant]
		label_at(game, timer.position+Vector2(0,22), "BOSS", 25, boss_ink)
		label_at(game, timer.position+Vector2(0,43), "NO TIME LIMIT", 12, MUTED)
		var fraction: float = clampf(game.boss.health(game)/maxf(game.boss_max_hp,1),0,1)
		meter(game, Rect2(0,76,bar_width,4), fraction, boss_ink, clock)
		if game.boss_variant == 3:
			# The Abyss Wyrm's two forms split the bar at its midpoint.
			var split: float = game.boss.wyrm.SECOND_FORM/(1.0+game.boss.wyrm.SECOND_FORM)
			game.draw_rect(Rect2(bar_width*split-1,72,2,12),Color(boss_ink,0.9))
		if not game.stairs_unlocked:
			var caption: String = "%s  %d%%" % [game.boss.NAMES[game.boss_variant], ceili(fraction*100)]
			label_at(game, Vector2(14,96), caption, 11, Color(boss_ink,0.85))
	else:
		var urgent: bool = game.time_left <= 5.0
		var time_ink := DANGER if urgent else CYAN
		if urgent:
			var beat: float = 0.5+0.5*sin(clock*TAU*1.6)
			game.draw_colored_polygon(chamfer(timer.grow(7),8),Color(0.35,0.05,0.1,0.55+beat*0.25))
			game.draw_polyline(closed(chamfer(timer.grow(7),8)),Color(DANGER,0.5+beat*0.5),1.5,true)
		var seconds := "%04.1f" % game.time_left
		label_at(game, timer.position+Vector2(0,26), seconds, 34, time_ink)
		var digits_width: float = game.font.get_string_size(seconds,HORIZONTAL_ALIGNMENT_LEFT,-1,34).x
		label_at(game, timer.position+Vector2(digits_width+4,26), "s", 18, Color(time_ink,0.75))
		label_at(game, timer.position+Vector2(0,45), "LOW TIME" if urgent else "TO DESCEND", 12, time_ink if urgent else MUTED)
		meter(game, Rect2(0,76,bar_width,4), clampf(game.time_left / maxf(game.time_limit, 0.01),0,1), time_ink, clock)
	draw_buffs(game)
	draw_help(game, screen)
	if game.debug_invincible: label_at(game, Vector2(screen.x*0.5-110,screen.y-42), "DEBUG: INVINCIBLE (F8)", 13, Color("ff91b1"))
	if game.practice.active: label_at(game, Vector2(screen.x-240,screen.y-14),"PRACTICE" if game.controls.using_gamepad else "PRACTICE / R RETRY / B SELECT",12,CYAN)
	if game.banner > 0: draw_banner(game, screen)
	if game.hit_flash > 0:
		game.draw_rect(Rect2(Vector2(4,4),screen-Vector2(8,8)),Color(1,0.3,0.35,game.hit_flash*2),false,4)
	if game.hit_banner > 0:
		glitch_title(game, screen, 158, "HIT / RETRY", 30, Color(1,0.5,0.5,minf(1,game.hit_banner*3)), game.hit_banner)
	if game.timeout_banner > 0:
		glitch_title(game, screen, 158, "TIME UP / RETRY", 30, Color(1,0.3,0.35,minf(1,game.timeout_banner*3)), game.timeout_banner)
	if game.presentation.transition > 0:
		var progress: float = 1-game.presentation.transition/0.3
		var fade: float = (1-progress)*0.5
		game.draw_line(Vector2(0,80+progress*25),Vector2(screen.x,80+progress*25),Color(0.39,0.96,0.81,fade),2,true)
		game.draw_line(Vector2(0,80+progress*25),Vector2(screen.x,80+progress*25),Color(0.39,0.96,0.81,fade*0.25),9,true)
	if layout.map.size.x > 0: minimap.draw(game,layout.map)
	if not game.controls.using_gamepad or game.replay_input.has("cursor"):
		draw_cursor(game, game.controls.pointer(game), clock)

func draw_buffs(game) -> void:
	var y := 112.0 if game.boss_floor else 92.0
	for kind in range(game.pickups.timers.size()):
		var left: float = game.pickups.timers[kind]
		if left <= 0: continue
		var ink: Color = Pickups.COLORS[kind]
		var alpha := 0.35 if game.pickups.fading(kind) else 1.0
		var panel := Rect2(12,y,150,34)
		game.draw_colored_polygon(chamfer(panel,6),Color(PANEL,0.82))
		game.draw_polyline(closed(chamfer(panel,6)),Color(ink,0.45*alpha),1,true)
		var mark := panel.position+Vector2(16,17)
		var diamond := PackedVector2Array([mark+Vector2(0,-7),mark+Vector2(6,0),mark+Vector2(0,7),mark+Vector2(-6,0)])
		game.draw_colored_polygon(diamond,Color(ink,0.85*alpha))
		label_at(game, panel.position+Vector2(30,16), Pickups.NAMES[kind], 13, Color(ink,alpha))
		label_at(game, panel.position+Vector2(108,16), "%4.1f" % left, 13, Color(Color("eafffa"),alpha))
		meter(game, Rect2(panel.position+Vector2(30,24),Vector2(110,3)), clampf(left/Pickups.DURATIONS[kind],0,1), Color(ink,alpha), game.presentation.clock)
		y += 40.0

func draw_depth(game) -> void:
	label_at(game, Vector2(26,24), "DLVL", 11, MUTED)
	var depth := "%02d" % game.floor_number
	label_at(game, Vector2(24,62), depth, 42, Color("eafffa"))
	var x: float = 32+game.font.get_string_size(depth,HORIZONTAL_ALIGNMENT_LEFT,-1,42).x
	label_at(game, Vector2(x,40), "KILLS", 10, MUTED)
	label_at(game, Vector2(x+38,40), str(game.kills), 13, Color("c9dbe3"))
	label_at(game, Vector2(x,58), "RETRY", 10, MUTED)
	label_at(game, Vector2(x+38,58), str(game.deaths), 13, Color("c9dbe3") if game.deaths == 0 else Color("ff9fae"))

func draw_weapon(game, weapon: Rect2) -> void:
	var ready: bool = game.sub_cd <= 0
	var weapon_ink := CYAN if ready else AMBER
	var plate := chamfer(Rect2(weapon.position-Vector2(10,4),weapon.size+Vector2(20,8)),10)
	game.draw_colored_polygon(plate,Color(PANEL,0.9))
	game.draw_polyline(closed(plate),Color(weapon_ink,0.45 if ready else 0.28),1.2,true)
	var fraction := cooldown_fraction(game)
	var hub: Vector2 = weapon.position+Vector2(15,22)
	game.draw_arc(hub,17,0,TAU,40,Color(weapon_ink,0.18),2,true)
	game.draw_arc(hub,17,-PI/2,-PI/2+TAU*fraction,40,weapon_ink,2,true)
	draw_weapon_icon(game, hub, game.sub_weapon, weapon_ink)
	var wide: bool = weapon.size.x >= 250
	label_at(game, weapon.position+Vector2(42,23), Catalog.WEAPONS[game.sub_weapon].title, 24 if wide else 18, weapon_ink)
	var secondary_key: String = "RB" if game.controls.using_gamepad else "RMB"
	label_at(game, weapon.position+Vector2(42,40), secondary_key + " / READY" if ready else "WAIT %.1fs" % game.sub_cd, 12, MUTED)
	if wide:
		# Loadout pips: which of the three sub weapons is selected.
		for i in range(3):
			var pip: Vector2 = weapon.position+Vector2(weapon.size.x-44+i*16,18)
			var diamond := PackedVector2Array([pip+Vector2(0,-5),pip+Vector2(5,0),pip+Vector2(0,5),pip+Vector2(-5,0)])
			if i == game.sub_weapon: game.draw_colored_polygon(diamond,weapon_ink)
			else: game.draw_polyline(closed(diamond),Color(MUTED,0.7),1,true)
	var track := Rect2(weapon.position+Vector2(0,50),Vector2(weapon.size.x,4))
	game.draw_rect(track,Color("1a2c3a"))
	game.draw_rect(Rect2(track.position,Vector2(track.size.x*fraction,track.size.y)),weapon_ink)
	for x in range(10,int(track.size.x),10): game.draw_rect(Rect2(track.position+Vector2(x,0),Vector2(1,track.size.y)),Color(PANEL,0.9))

func meter(game, rect: Rect2, fraction: float, ink: Color, clock: float) -> void:
	game.draw_rect(rect,Color(ink,0.10))
	var filled := Rect2(rect.position,Vector2(rect.size.x*fraction,rect.size.y))
	game.draw_rect(filled,ink)
	game.draw_rect(Rect2(filled.position+Vector2(0,rect.size.y),Vector2(filled.size.x,3)),Color(ink,0.18))
	# A travelling highlight keeps the meter alive without changing its value.
	if filled.size.x > 40:
		var x: float = fmod(clock*260.0,filled.size.x+120.0)-60.0
		var from: float = clampf(x-40,0,filled.size.x)
		var to: float = clampf(x+40,0,filled.size.x)
		if to > from: game.draw_rect(Rect2(filled.position+Vector2(from,0),Vector2(to-from,rect.size.y)),Color(1,1,1,0.35))
	for x in range(24,int(filled.size.x),24): game.draw_rect(Rect2(rect.position+Vector2(x,0),Vector2(2,rect.size.y)),Color(0.02,0.04,0.07,0.75))
	if fraction > 0: game.draw_rect(Rect2(filled.end-Vector2(3,rect.size.y),Vector2(3,rect.size.y)),Color.WHITE)

func draw_help(game, screen: Vector2) -> void:
	gradient_rect(game, Rect2(0,screen.y-40,screen.x,40), Color(0.03,0.07,0.1,0.8), Color(0.012,0.027,0.05,0.95))
	game.draw_line(Vector2(0,screen.y-40),Vector2(screen.x,screen.y-40),Color(0.25,0.55,0.62,0.45),1)
	var help := "LS / DPAD  MOVE     RS  AIM     A / LB  FIRE     RB  SUB WEAPON     LT / RT  SWITCH     B  PAUSE" if game.controls.using_gamepad else "WASD  MOVE     LMB  MACHINE GUN     RMB  SUB WEAPON     Q/E / WHEEL  SWITCH     ESC  PAUSE     M  AUDIO"
	# Keycap chips: "KEY  ACTION" pairs separated by wide gaps.
	var x := 22.0
	var baseline: float = screen.y-15
	for entry in help.split("     "):
		var split: int = entry.find("  ")
		var key: String = entry.substr(0,split)
		var action: String = entry.substr(split+2)
		var key_width: float = game.body_font.get_string_size(key,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
		var chip := Rect2(x,baseline-13,key_width+12,18)
		game.draw_rect(chip,Color(0.1,0.2,0.26,0.9))
		game.draw_rect(chip,Color(0.35,0.7,0.72,0.55),false,1)
		label_at(game, Vector2(x+6,baseline), key, 12, Color("dff7f2"))
		x += chip.size.x+6
		label_at(game, Vector2(x,baseline), action, 12, Color("93a8ba"))
		x += game.body_font.get_string_size(action,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+18

func draw_banner(game, screen: Vector2) -> void:
	var text: String = ("BOSS DEFEATED / DESCEND" if game.stairs_unlocked else game.boss.NAMES[game.boss_variant]) if game.boss_floor else "FIND THE STAIRS. KEEP DESCENDING."
	if game.banner > banner_last + 0.001: banner_start = game.banner
	banner_last = game.banner
	var elapsed: float = maxf(0,banner_start-game.banner)
	var shown: int = mini(text.length(),int(elapsed*48.0))
	var fade: float = clampf(game.banner/0.6,0,1)
	var line := "> " + text.substr(0,shown)
	var width: float = game.body_font.get_string_size("> "+text,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
	var origin := Vector2((screen.x-width)*0.5,112)
	game.draw_rect(Rect2(origin-Vector2(14,21),Vector2(width+36,30)),Color(0.02,0.05,0.08,0.7*fade))
	game.draw_line(origin+Vector2(-14,9),origin+Vector2(width+22,9),Color(CYAN,0.4*fade),1)
	game.draw_string(game.body_font, origin, line, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(CYAN,fade))
	# Terminal block cursor blinks while typing and after.
	if fmod(game.presentation.clock,0.5) < 0.3 or shown < text.length():
		var cursor_x: float = origin.x+game.body_font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x+3
		game.draw_rect(Rect2(cursor_x,origin.y-14,9,17),Color(CYAN,0.85*fade))

func glitch_title(game, screen: Vector2, y: float, text: String, size: int, ink: Color, life: float) -> void:
	var width: float = game.font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	var origin := Vector2((screen.x-width)*0.5,y)
	var split: float = clampf(life-0.5,0,1)*10.0
	game.draw_rect(Rect2(0,y-size-6,screen.x,size+18),Color(0.1,0.0,0.03,0.55*ink.a))
	game.draw_string(game.font, origin+Vector2(-split,0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.2,0.9,1,ink.a*0.5))
	game.draw_string(game.font, origin+Vector2(split,0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1,0.1,0.3,ink.a*0.6))
	game.draw_string(game.font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ink)

func draw_cursor(game, mouse: Vector2, clock: float) -> void:
	var spin: float = clock*1.2
	for i in range(4):
		var axis := Vector2.from_angle(spin+i*PI/2)
		game.draw_line(mouse+axis*6,mouse+axis*12,CYAN,1.6,true)
	game.draw_arc(mouse, 8, 0, TAU, 20, Color(CYAN,0.35), 1, true)
	game.draw_circle(mouse, 1.5, Color.WHITE)

func draw_title(game, screen: Vector2) -> void:
	pass # Menu Controls own title and practice presentation.

func draw_player_stats(game, screen: Vector2, y: float) -> void:
	centered_title_label(game, screen, y, "CURRENT STATS", 15, Color("8194aa"))
	var stats = game.player_stats()
	for i in range(stats.size()):
		var x = screen.x * 0.5 + (i - 1) * 250.0
		var item: Dictionary = stats[i]
		game.draw_rect(Rect2(x - 115, y + 15, 230, 105), Color("182735"))
		var column = Vector2(x * 2.0, screen.y)
		centered_title_label(game, column, y + 40, item.name, 15, Color("8194aa"))
		centered_title_label(game, column, y + 73, item.value, 25, Color("63f5ce"))
		centered_title_label(game, column, y + 101, item.detail, 15, Color("a4b3c6"))

func label_at(game, p: Vector2, value: String, size: int = 18, color: Color = Color.WHITE) -> void:
	game.draw_string(game.font if size>=18 else game.body_font, p, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func centered_title_label(game, screen: Vector2, y: float, value: String, size: int, color: Color = Color.WHITE) -> void:
	var width = (game.font if size>=18 else game.body_font).get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	label_at(game, Vector2((screen.x - width) * 0.5, y), value, size, color)

func hud_layout(screen: Vector2) -> Dictionary:
	var show_map := screen.x >= 900
	var map := Rect2(screen.x-190,6,174,132) if show_map else Rect2()
	var timer := Rect2(map.position.x-204 if show_map else screen.x-204,12,180,52)
	var width := minf(320,timer.position.x-284)
	return {"timer": timer, "map": map, "weapon": Rect2((236+timer.position.x-width)*0.5,12,width,52)}

func cooldown_fraction(game) -> float:
	if game.sub_cd <= 0: return 1.0
	return clampf(1.0-game.sub_cd/maxf(game.sub_cd_total,0.001),0,1)

func draw_weapon_icon(game, origin: Vector2, weapon: int, ink: Color) -> void:
	preload("res://scripts/visual_icons.gd").draw_icon(game,preload("res://scripts/visual_icons.gd").WEAPONS[weapon],origin,10,ink)

static func chamfer(rect: Rect2, cut: float) -> PackedVector2Array:
	return PackedVector2Array([rect.position+Vector2(cut,0),Vector2(rect.end.x,rect.position.y),Vector2(rect.end.x,rect.end.y-cut),rect.end-Vector2(cut,0),Vector2(rect.position.x,rect.end.y),rect.position+Vector2(0,cut)])

static func closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	result.append(points[0])
	return result

static func gradient_rect(canvas: CanvasItem, rect: Rect2, top: Color, bottom: Color) -> void:
	canvas.draw_polygon(PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]),PackedColorArray([top,top,bottom,bottom]))
