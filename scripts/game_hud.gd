extends RefCounted

var minimap = preload("res://scripts/minimap.gd").new()

const Catalog = preload("res://scripts/combat_catalog.gd")

# Presentation only; input and shared hit-region calculations stay on the host.
func draw(game, screen: Vector2) -> void:
	game.draw_set_transform(Vector2.ZERO)
	if game.view_comparison:
		label_at(game, Vector2(26,108), "F6 / " + (("3D  |  F7 / TILT %d DEG" % game.view_pitch_degrees) if game.depth_enabled else "CLASSIC 2D"), 13, Color("8194aa"))
	var layout := hud_layout(screen)
	var weapon: Rect2 = layout.weapon
	var timer: Rect2 = layout.timer
	var bar_width: float = layout.map.position.x-12 if layout.map.size.x>0 else screen.x
	game.draw_rect(Rect2(0,0,screen.x,76), Color("090f18"))
	game.draw_line(Vector2(0,75),Vector2(screen.x,75),Color("304956"),1)
	game.draw_rect(Rect2(weapon.position-Vector2(10,4),weapon.size+Vector2(20,8)),Color("111f2b"))
	label_at(game, Vector2(26,32), "DEPTH  %02d" % game.floor_number, 23)
	label_at(game, Vector2(26,56), "KILLS %d   /   RETRIES %d" % [game.kills, game.deaths], 13, Color("8194aa"))
	game.draw_line(Vector2(238,18),Vector2(238,58),Color("263847"),1)
	var ready: bool = game.sub_cd <= 0
	var weapon_ink := Color("63f5ce") if ready else Color("ffb95e")
	draw_weapon_icon(game, weapon.position+Vector2(15,20), game.sub_weapon, weapon_ink)
	label_at(game, weapon.position+Vector2(42,23), Catalog.WEAPONS[game.sub_weapon].title, 24 if weapon.size.x >= 250 else 18, weapon_ink)
	var secondary_key: String = "RMB"
	label_at(game, weapon.position+Vector2(42,40), secondary_key + " / READY" if ready else "WAIT %.1fs" % game.sub_cd, 12, Color("8194aa"))
	game.draw_rect(Rect2(weapon.position+Vector2(0,51),Vector2(weapon.size.x,3)),Color("263847"))
	game.draw_rect(Rect2(weapon.position+Vector2(0,51),Vector2(weapon.size.x*cooldown_fraction(game),3)),weapon_ink)
	if game.boss_floor:
		label_at(game, timer.position+Vector2(0,20), "CORE %d / 6" % game.boss.remaining(game) if game.boss_variant == 0 else "BOSS", 23, game.boss.COLORS[game.boss_variant])
		label_at(game, timer.position+Vector2(0,42), "NO TIME LIMIT", 12, Color("8194aa"))
		game.draw_rect(Rect2(0,76,bar_width*game.boss.health(game)/maxf(game.boss_max_hp,1),3),game.boss.COLORS[game.boss_variant])
	else:
		var urgent: bool = game.time_left <= 5.0
		var time_ink := Color("ff647c") if urgent else Color("63f5ce")
		if urgent: game.draw_rect(timer.grow(7),Color("291923"))
		label_at(game, timer.position+Vector2(0,20), "%04.1f s" % game.time_left, 31, time_ink)
		label_at(game, timer.position+Vector2(0,42), "LOW TIME" if urgent else "TO DESCEND", 12, time_ink if urgent else Color("8194aa"))
		game.draw_rect(Rect2(0,76,bar_width * clampf(game.time_left / maxf(game.time_limit, 0.01),0,1),3), time_ink)
	game.draw_rect(Rect2(0,screen.y - 40,screen.x,40), Color("090f18"))
	game.draw_line(Vector2(0,screen.y-40),Vector2(screen.x,screen.y-40),Color("304956"),1)
	var help := "WASD  MOVE     LMB  MACHINE GUN     RMB  SUB WEAPON     Q/E / WHEEL  SWITCH     ESC  PAUSE     M  AUDIO"
	label_at(game, Vector2(26,screen.y - 15), help, 13, Color("a4b3c6"))
	if game.practice.active: label_at(game, Vector2(screen.x-240,screen.y-15),"PRACTICE / R RETRY / B SELECT",12,Color("63f5ce"))
	if game.banner > 0:
		centered_title_label(game, screen,110,("BOSS DEFEATED / DESCEND" if game.stairs_unlocked else game.boss.NAMES[game.boss_variant]) if game.boss_floor else "FIND THE STAIRS. KEEP DESCENDING.",18,Color("63f5ce"))
	if game.hit_flash > 0:
		game.draw_rect(Rect2(Vector2.ZERO,screen),Color(1,0.25,0.3,game.hit_flash*0.35))
		game.draw_rect(Rect2(Vector2(4,4),screen-Vector2(8,8)),Color(1,0.3,0.35,game.hit_flash*2),false,6)
	if game.hit_banner > 0:
		label_at(game, Vector2(screen.x/2-105,145),"HIT / RETRY",26,Color(1,0.5,0.5,minf(1,game.hit_banner*3)))
	if game.timeout_banner > 0:
		label_at(game, Vector2(screen.x / 2 - 145,145),"TIME UP / RETRY",26,Color(1,0.3,0.35,minf(1,game.timeout_banner*3)))
	if game.presentation.transition > 0:
		var progress: float = 1-game.presentation.transition/0.3
		var fade: float = (1-progress)*0.5
		game.draw_line(Vector2(0,80+progress*25),Vector2(screen.x,80+progress*25),Color(0.39,0.96,0.81,fade),2,true)
	if layout.map.size.x > 0: minimap.draw(game,layout.map)
	var mouse = game.controls.pointer(game)
	game.draw_arc(mouse, 8, 0, TAU, 16, Color("63f5ce"), 1)

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
	preload("res://scripts/visual_icons.gd").draw_icon(game,preload("res://scripts/visual_icons.gd").WEAPONS[weapon],origin,12,ink)
