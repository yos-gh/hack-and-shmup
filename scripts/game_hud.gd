extends RefCounted

# Presentation only; input and shared hit-region calculations stay on the host.
func draw(game, screen: Vector2) -> void:
	game.draw_set_transform(Vector2.ZERO)
	if game.view_comparison:
		label_at(game, Vector2(26,108), "F6 / " + ("3D STUDY" if game.depth_enabled else "CLASSIC 2D"), 13, Color("8194aa"))
	game.draw_rect(Rect2(0,0,screen.x,76), Color("0b111c"))
	label_at(game, Vector2(26,32), "DEPTH  %02d" % game.floor_number, 23)
	label_at(game, Vector2(26,56), "KILLS %d   /   RETRIES %d" % [game.kills, game.deaths], 13, Color("8194aa"))
	label_at(game, Vector2(650,31), "RMB  /  " + game.SUB_NAMES[game.sub_weapon], 20, Color("ffb95e"))
	label_at(game, Vector2(650,56), "READY" if game.sub_cd <= 0 else "RECHARGING  %.1fs" % game.sub_cd, 13, Color("8194aa"))
	if game.boss_floor:
		label_at(game, Vector2(930,31), "CORE %d / 6" % game.boss.remaining(game) if game.boss_variant == 0 else "BOSS", 23, game.boss.COLORS[game.boss_variant])
		label_at(game, Vector2(930,56), "NO TIME LIMIT", 12, Color("8194aa"))
		game.draw_rect(Rect2(0,76,screen.x*game.boss.health(game)/maxf(game.boss_max_hp,1),3),game.boss.COLORS[game.boss_variant])
	else:
		label_at(game, Vector2(930,31), "%04.1f s" % game.time_left, 25, Color("ff647c") if game.time_left < 5 else Color("63f5ce"))
		label_at(game, Vector2(930,56), "TO DESCEND", 12, Color("8194aa"))
		game.draw_rect(Rect2(0,76,screen.x * clampf(game.time_left / maxf(game.time_limit, 0.01),0,1),3), Color("ff647c") if game.time_left < 5 else Color("63f5ce"))
	# Spatial overview reflects the actual irregular graph, including the goal bearing.
	var bounds = Rect2(Vector2(game.rooms[0].position),Vector2(game.rooms[0].size))
	for r in game.rooms: bounds = bounds.merge(Rect2(Vector2(r.position),Vector2(r.size)))
	var map_scale = minf(130.0/bounds.size.x,52.0/bounds.size.y)
	var map_origin = Vector2(screen.x-145,10)
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
			var names = ["HEAVY ROUNDS", "OVERCLOCK", "QUICKSTEP", "HUNTER"]
			var descriptions = ["+35% base weapon damage", "+20% base firing speed", "+20 movement speed", "+20% damage / +10 speed"]
			for i in range(3):
				var p = game.upgrade_card_rect(screen, i).position
				game.draw_rect(Rect2(p,Vector2(290,150)),Color("182735"))
				game.draw_rect(Rect2(p,Vector2(290,150)),Color("63f5ce"),false,2)
				label_at(game, p + Vector2(18,32), "0%d / %s" % [i + 1, names[game.choices[i]]], 20)
				label_at(game, p + Vector2(18,86), descriptions[game.choices[i]], 15, Color("a4b3c6"))
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
