extends RefCounted

const Catalog = preload("res://scripts/combat_catalog.gd")

# Presentation only; input and shared hit-region calculations stay on the host.
func draw(game, screen: Vector2) -> void:
	game.draw_set_transform(Vector2.ZERO)
	if game.view_comparison:
		label_at(game, Vector2(26,108), "F6 / " + ("3D STUDY" if game.depth_enabled else "CLASSIC 2D"), 13, Color("8194aa"))
	var layout := hud_layout(screen)
	var weapon: Rect2 = layout.weapon
	var timer: Rect2 = layout.timer
	game.draw_rect(Rect2(0,0,screen.x,76), Color("0b111c"))
	label_at(game, Vector2(26,32), "DEPTH  %02d" % game.floor_number, 23)
	label_at(game, Vector2(26,56), "KILLS %d   /   RETRIES %d" % [game.kills, game.deaths], 13, Color("8194aa"))
	game.draw_line(Vector2(238,18),Vector2(238,58),Color("263847"),1)
	var ready: bool = game.sub_cd <= 0
	var weapon_ink := Color("63f5ce") if ready else Color("ffb95e")
	draw_weapon_icon(game, weapon.position+Vector2(15,20), game.sub_weapon, weapon_ink)
	label_at(game, weapon.position+Vector2(42,20), Catalog.WEAPONS[game.sub_weapon].title, 20 if weapon.size.x >= 250 else 16, weapon_ink)
	label_at(game, weapon.position+Vector2(42,40), "RMB / READY" if ready else "WAIT %.1fs" % game.sub_cd, 12, Color("8194aa"))
	game.draw_rect(Rect2(weapon.position+Vector2(0,51),Vector2(weapon.size.x,3)),Color("263847"))
	game.draw_rect(Rect2(weapon.position+Vector2(0,51),Vector2(weapon.size.x*cooldown_fraction(game),3)),weapon_ink)
	if game.boss_floor:
		label_at(game, timer.position+Vector2(0,20), "CORE %d / 6" % game.boss.remaining(game) if game.boss_variant == 0 else "BOSS", 23, game.boss.COLORS[game.boss_variant])
		label_at(game, timer.position+Vector2(0,42), "NO TIME LIMIT", 12, Color("8194aa"))
		game.draw_rect(Rect2(0,76,screen.x*game.boss.health(game)/maxf(game.boss_max_hp,1),3),game.boss.COLORS[game.boss_variant])
	else:
		var urgent: bool = game.time_left <= 5.0
		var time_ink := Color("ff647c") if urgent else Color("63f5ce")
		if urgent: game.draw_rect(timer.grow(7),Color("291923"))
		label_at(game, timer.position+Vector2(0,20), "%04.1f s" % game.time_left, 25, time_ink)
		label_at(game, timer.position+Vector2(0,42), "LOW TIME" if urgent else "TO DESCEND", 12, time_ink if urgent else Color("8194aa"))
		game.draw_rect(Rect2(0,76,screen.x * clampf(game.time_left / maxf(game.time_limit, 0.01),0,1),3), time_ink)
	# Spatial overview reflects the actual irregular graph, including the goal bearing.
	if layout.map.size.x > 0:
		var bounds = Rect2(Vector2(game.rooms[0].position),Vector2(game.rooms[0].size))
		for r in game.rooms: bounds = bounds.merge(Rect2(Vector2(r.position),Vector2(r.size)))
		var map_scale = minf(130.0/bounds.size.x,52.0/bounds.size.y)
		var map_origin: Vector2 = layout.map.position
		for link in game.room_links:
			var a = map_origin + (Vector2(game.rooms[link.x].get_center())-bounds.position)*map_scale
			var b = map_origin + (Vector2(game.rooms[link.y].get_center())-bounds.position)*map_scale
			game.draw_line(a,b,Color("354858"),1)
		for i in range(game.rooms.size()):
			var mp = map_origin + (Vector2(game.rooms[i].position)-bounds.position)*map_scale
			game.draw_rect(Rect2(mp,Vector2(game.rooms[i].size)*map_scale),Color("63f5ce") if game.cells.get(game.tile(game.player),-1)==i else (Color("354858") if game.discovered.has(i) else Color("171f2b")))
			if i == game.goal_room and game.stairs_unlocked: game.draw_circle(mp+Vector2(game.rooms[i].size)*map_scale*0.5,2,Color("ffb95e"))
	game.draw_rect(Rect2(0,screen.y - 40,screen.x,40), Color("0b111c"))
	label_at(game, Vector2(26,screen.y - 15), "WASD  MOVE     LMB  MACHINE GUN     RMB  SUB WEAPON     Q/E / WHEEL  SWITCH     ESC  PAUSE     M  AUDIO", 13, Color("a4b3c6"))
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
	var mouse = game.controls.pointer(game)
	game.draw_arc(mouse, 8, 0, TAU, 16, Color("63f5ce"), 1)
	if game.paused or game.choosing:
		game.draw_rect(Rect2(Vector2.ZERO, screen), Color(0.02,0.03,0.06,0.93))
		var menu_y = game.menu_origin_y(screen, game.paused)
		if game.paused:
			centered_title_label(game, screen,menu_y-30,"PAUSED",28)
			centered_title_label(game, screen,menu_y+20,"CLICK TO RESUME",22,Color("63f5ce"))
			centered_title_label(game, screen,menu_y+58,"ESC / RETURN TO TITLE",18,Color("8194aa"))
		else:
			centered_title_label(game, screen,menu_y - 130, "FLOOR CLEARED / CHOOSE AN UPGRADE", 24, Color("63f5ce"))
			centered_title_label(game, screen,menu_y - 90, "CLICK A CARD OR PRESS 1 / 2 / 3", 16, Color("8194aa"))
			for i in range(3):
				var p = game.upgrade_card_rect(screen, i).position
				game.draw_rect(Rect2(p,Vector2(290,150)),Color("182735"))
				game.draw_rect(Rect2(p,Vector2(290,150)),Color("63f5ce"),false,2)
				label_at(game, p + Vector2(18,32), "0%d / %s" % [i + 1, Catalog.UPGRADES[game.choices[i]].title], 20)
				label_at(game, p + Vector2(18,86), Catalog.UPGRADES[game.choices[i]].description, 15, Color("a4b3c6"))
		draw_player_stats(game, screen, menu_y + 155)

func draw_title(game, screen: Vector2) -> void:
	if game.practice.selecting:
		draw_practice(game,screen)
		return
	game.draw_rect(Rect2(Vector2.ZERO,screen),Color("0b111c"))
	var audio_button = game.audio_button_rect()
	game.draw_rect(audio_button,Color("182735"))
	game.draw_rect(audio_button,Color("63f5ce"),false,1)
	var audio_caption: String = ["AUDIO: ALL","AUDIO: SE ONLY","AUDIO: OFF"][game.audio_mode]
	var audio_width = game.font.get_string_size(audio_caption,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
	label_at(game, Vector2(audio_button.get_center().x-audio_width/2,audio_button.position.y+27),audio_caption,14,Color("63f5ce"))
	var button = game.fullscreen_button_rect()
	game.draw_rect(button,Color("182735"))
	game.draw_rect(button,Color("63f5ce"),false,1)
	var fullscreen = DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN,DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	var caption = "WINDOWED" if fullscreen else "FULLSCREEN"
	var caption_width = game.font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
	label_at(game, Vector2(button.get_center().x-caption_width/2,button.position.y+27),caption,16,Color("63f5ce"))
	var origin = screen * 0.5
	for i in range(6):
		var width = 210.0 + i*62
		game.draw_rect(Rect2(origin-Vector2(width/2,260-i*14),Vector2(width,24)),Color(0.15,0.32,0.34,0.2),false,1)
	centered_title_label(game, screen,origin.y+-90,"HACK / SHMUP",54,Color("63f5ce"))
	centered_title_label(game, screen,origin.y+-50,"ENDLESS DESCENT / PROTOTYPE",18,Color("8194aa"))
	centered_title_label(game, screen,origin.y+35,"DEEPEST CLEARED  %02d" % game.best_cleared,24,Color("ffb95e"))
	centered_title_label(game, screen,origin.y+105,"CLICK OR ENTER TO DESCEND",22)
	centered_title_label(game, screen,origin.y+148,"WASD MOVE / MOUSE AIM / Q & E WEAPONS",14,Color("8194aa"))
	centered_title_label(game, screen,origin.y+176,"M AUDIO / RECORD LASTS UNTIL YOU QUIT",14,Color("8194aa"))
	if not OS.has_feature("web"):
		centered_title_label(game, screen,origin.y+232,"ESC / QUIT",14,Color("8194aa"))
	centered_title_label(game, screen,origin.y+204,"B / BOSS PRACTICE",14,Color("63f5ce"))

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
	game.draw_string(game.font, p, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func centered_title_label(game, screen: Vector2, y: float, value: String, size: int, color: Color = Color.WHITE) -> void:
	var width = game.font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	label_at(game, Vector2((screen.x - width) * 0.5, y), value, size, color)

func draw_practice(game, screen: Vector2) -> void:
	game.draw_rect(Rect2(Vector2.ZERO,screen),Color("0b111c"))
	var y := screen.y*0.5-24
	game.centered_title_label(screen,y-195,"BOSS PRACTICE",36,Color("63f5ce"))
	game.centered_title_label(screen,y-157,"LEFT / RIGHT: BOSS     UP / DOWN: FLOOR",15,Color("8194aa"))
	for i in range(7):
		var rect = game.practice.button(screen,i)
		var ink := Color("63f5ce") if i == game.practice.variant or i == 5 else Color("8194aa")
		game.draw_rect(rect,Color("182735"))
		game.draw_rect(rect,ink,false,1.5)
		var caption: String = game.boss.NAMES[i] if i < 3 else ["-","+","ENTER / START","ESC / BACK"][i-3]
		var width: float = game.font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
		game.label_at(Vector2(rect.get_center().x-width/2,rect.get_center().y+6),caption,18,ink)
	game.centered_title_label(screen,y+42,"FLOOR %02d" % game.practice.depth,25)
	game.centered_title_label(screen,y+96,"%d AUTO UPGRADES / NORMAL DAMAGE / NO RECORD" % (game.practice.depth-1),15,Color("8194aa"))
	game.centered_title_label(screen,y+128,"IN GAME: R RETRY / B SELECT / ESC PAUSE",14,Color("8194aa"))

func hud_layout(screen: Vector2) -> Dictionary:
	var show_map := screen.x >= 900
	var map := Rect2(screen.x-154,12,130,48) if show_map else Rect2()
	var timer := Rect2(map.position.x-204 if show_map else screen.x-204,12,180,52)
	var width := minf(320,timer.position.x-284)
	return {"timer": timer, "map": map, "weapon": Rect2((236+timer.position.x-width)*0.5,12,width,52)}

func cooldown_fraction(game) -> float:
	if game.sub_cd <= 0: return 1.0
	return clampf(1.0-game.sub_cd/maxf(game.sub_cd_total,0.001),0,1)

func draw_weapon_icon(game, origin: Vector2, weapon: int, ink: Color) -> void:
	match weapon:
		0:
			for angle in [-0.45,0.0,0.45]:
				game.draw_line(origin-Vector2(12,0),origin+Vector2(14,0).rotated(angle),ink,2)
		1:
			game.draw_arc(origin,12,0,TAU,24,ink,2)
			game.draw_circle(origin,3,ink)
		2:
			game.draw_line(origin-Vector2(13,0),origin+Vector2(13,0),ink,3)
			game.draw_polyline(PackedVector2Array([origin+Vector2(7,-5),origin+Vector2(14,0),origin+Vector2(7,5)]),ink,2)
