extends Control
var game: Node
var kind := "title"
var icon := ""
var age := 0.0
var hover := 0.0
const SoundMode = preload("res://scripts/sound_mode.gd")
# Roguelike map glyphs drifting behind the console: the terminal half of the look.
const GLYPHS := ["@","#",".",">","<","$","%","&","+","|","-","!","?","*","~","^"]
func _ready() -> void: mouse_filter = Control.MOUSE_FILTER_IGNORE
func _process(delta: float) -> void:
	age += delta
	queue_redraw()
func _draw() -> void:
	if not icon.is_empty():
		draw_icon_badge()
		return
	if kind in ["title","practice","sound","continue"]:
		if game.depth_view != null:
			draw_texture_rect(game.depth_view.viewport.get_texture(),Rect2(Vector2.ZERO,size),false,Color(0.75,0.9,0.95,0.6))
		var Hud := preload("res://scripts/game_hud.gd")
		Hud.gradient_rect(self,Rect2(Vector2.ZERO,size*Vector2(1,0.5)),Color(0.01,0.02,0.04,0.78),Color(0.02,0.04,0.07,0.45))
		Hud.gradient_rect(self,Rect2(Vector2(0,size.y*0.5),size*Vector2(1,0.5)),Color(0.02,0.04,0.07,0.45),Color(0.01,0.02,0.04,0.85))
		draw_glyph_field()
		if kind == "title":
			var center: Vector2 = SoundMode.emblem_center(size)
			# The emblem quietly brightens under the pointer: clicking it opens the hidden sound mode.
			hover = move_toward(hover,1.0 if SoundMode.hits_emblem(size,get_local_mouse_position()) else 0.0,get_process_delta_time()*6)
			draw_texture_rect(soft_glow(),Rect2(center-Vector2(90,90),Vector2(180,180)),false,Color(0.3,1,0.85,0.18+hover*0.14))
			for i in range(3):
				var radius := 36.0+i*11
				var start := age*(0.5-i*0.18)*(1+hover*1.5)*(1 if i%2 == 0 else -1)
				draw_arc(center,radius,start,start+TAU*0.78,48,Color(0.39,0.96,0.81,0.55-i*0.13+hover*0.25),1.8,true)
				draw_arc(center,radius,start+TAU*0.82,start+TAU*0.9,8,Color(1,0.73,0.37,0.7-i*0.15+hover*0.25),1.8,true)
			preload("res://scripts/visual_icons.gd").draw_icon(self,"descend",center+Vector2(0,sin(age*2.0)*2),18,Color("b5fff0"))
			var mark := Vector2(size.x*0.5,size.y*0.5-110)
			var width := minf(580,size.x-120)
			draw_texture_rect(soft_glow(),Rect2(mark-Vector2(width*0.6,70),Vector2(width*1.2,140)),false,Color(0.2,0.9,0.8,0.10))
			preload("res://scripts/visual_icons.gd").draw_wordmark(self,mark,width,age)
			var rule := mark.y+46
			draw_line(Vector2(size.x*0.5-width*0.42,rule),Vector2(size.x*0.5-90,rule),Color(0.39,0.96,0.81,0.35),1,true)
			draw_line(Vector2(size.x*0.5+90,rule),Vector2(size.x*0.5+width*0.42,rule),Color(0.39,0.96,0.81,0.35),1,true)
		if kind == "sound": draw_playback()
		draw_line(Vector2(50,size.y-70),Vector2(size.x-50,size.y-70),Color("2c5a66"),1,true)
		for x in [50,size.x-50]:
			draw_line(Vector2(x,140),Vector2(x,size.y-70),Color("213844"),1,true)
			draw_rect(Rect2(x-3,137,6,6),Color(0.39,0.96,0.81,0.6))
	else:
		draw_rect(Rect2(Vector2.ZERO,size),Color(0.012,0.025,0.045,0.88))
		# Faint tactical grid under the menu glass.
		for x in range(0,int(size.x),48): draw_line(Vector2(x,0),Vector2(x,size.y),Color(0.3,0.8,0.8,0.035),1)
		for y in range(0,int(size.y),48): draw_line(Vector2(0,y),Vector2(size.x,y),Color(0.3,0.8,0.8,0.035),1)
		var sweep := fmod(age*120.0,size.y+200)-100
		draw_rect(Rect2(0,sweep,size.x,2),Color(0.39,0.96,0.81,0.06))
	var reveal := clampf(age/0.22,0,1)
	draw_line(Vector2(size.x*0.5*(1-reveal),size.y-2),Vector2(size.x*0.5*(1+reveal),size.y-2),Color("63f5ce"),2,true)

# Sound mode: elapsed time against the track length, with the loop point marked in amber.
func draw_playback() -> void:
	var bar: Rect2 = game.sound_mode.progress_rect(size)
	var player: AudioStreamPlayer = game.sound.music
	draw_rect(bar,Color(0.22,0.4,0.46,0.6))
	if player.stream == null: return
	var length := maxf(player.stream.get_length(),0.001)
	var elapsed := player.get_playback_position() if player.playing else 0.0
	draw_rect(Rect2(bar.position,Vector2(bar.size.x*clampf(elapsed/length,0,1),bar.size.y)),Color("63f5ce"))
	var loop_x: float = bar.position.x+bar.size.x*clampf(player.stream.loop_offset/length,0,1)
	draw_line(Vector2(loop_x,bar.position.y-5),Vector2(loop_x,bar.end.y+5),Color(1,0.73,0.37,0.9),2)
	var clock := func(seconds: float) -> String: return "%d:%02d" % [int(seconds)/60,int(seconds)%60]
	draw_string(game.body_font,bar.position+Vector2(0,22),clock.call(elapsed),HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("91aaaf"))
	draw_string(game.body_font,Vector2(bar.position.x,bar.end.y+18),clock.call(length),HORIZONTAL_ALIGNMENT_RIGHT,bar.size.x,13,Color("91aaaf"))
	draw_string(game.body_font,Vector2(loop_x-40,bar.end.y+18),"LOOP",HORIZONTAL_ALIGNMENT_CENTER,80,11,Color(1,0.73,0.37,0.8))

func draw_glyph_field() -> void:
	var font: Font = game.body_font
	for i in range(64):
		var column := fposmod(float(i)*0.618034,1.0)
		var speed := 14.0+float((i*37)%23)
		var y := fposmod(float((i*131)%997)+age*speed,size.y+40)-20
		var x := column*size.x
		# Keep the centre clear for the logo and commands.
		var weight := clampf(absf(x-size.x*0.5)/(size.x*0.5)*1.8-0.45,0,1)
		if weight <= 0: continue
		var flicker := 0.5+0.5*sin(age*3.0+i*1.7)
		var glyph: String = GLYPHS[(i*7+int(age*0.8+i))%GLYPHS.size()]
		var ink := Color(0.39,0.96,0.81) if i%5 != 0 else Color(1,0.73,0.37)
		draw_string(font,Vector2(x,y),glyph,HORIZONTAL_ALIGNMENT_LEFT,-1,14+(i%3)*4,Color(ink,(0.10+flicker*0.12)*weight))

func draw_icon_badge() -> void:
	var center := size*0.5
	var radius := minf(size.x,size.y)*0.34
	draw_texture_rect(soft_glow(),Rect2(center-Vector2.ONE*radius*2.2,Vector2.ONE*radius*4.4),false,Color(0.3,1,0.85,0.16))
	draw_arc(center,radius*1.45,0,TAU,48,Color(0.39,0.96,0.81,0.22),1,true)
	for i in range(6):
		var start := age*0.8+i*TAU/6
		draw_arc(center,radius*1.45,start,start+0.5,8,Color(0.55,1,0.9,0.75),2,true)
	preload("res://scripts/visual_icons.gd").draw_icon(self,icon,center,radius,Color("a6ffe8"))

static var glow_cache: Texture2D
static func soft_glow() -> Texture2D:
	if glow_cache == null: glow_cache = preload("res://scripts/world_view.gd").soft_glow()
	return glow_cache
