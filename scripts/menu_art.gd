extends Control
var game: Node
var kind := "title"
var icon := ""
var age := 0.0
func _ready() -> void: mouse_filter = Control.MOUSE_FILTER_IGNORE
func _process(delta: float) -> void:
	age += delta
	queue_redraw()
func _draw() -> void:
	if not icon.is_empty():
		preload("res://scripts/visual_icons.gd").draw_icon(self,icon,size*0.5,minf(size.x,size.y)*0.34,Color("8dffe0"))
		return
	if kind == "title" or kind == "practice":
		if game.depth_view != null:
			draw_texture_rect(game.depth_view.viewport.get_texture(),Rect2(Vector2.ZERO,size),false,Color(0.65,0.8,0.85,0.5))
		draw_rect(Rect2(Vector2.ZERO,size),Color(0.025,0.045,0.07,0.62))
		if kind == "title":
			var center := Vector2(size.x*0.5,size.y*0.5-222)
			for i in range(3):
				var radius := 36.0+i*11
				var start := age*0.12*(1 if i%2 == 0 else -1)
				draw_arc(center,radius,start,start+TAU*0.78,48,Color(0.39,0.96,0.81,0.32-i*0.07),1.5,true)
			preload("res://scripts/visual_icons.gd").draw_icon(self,"descend",center,18,Color("91ffdf"))
			preload("res://scripts/visual_icons.gd").draw_wordmark(self,Vector2(size.x*0.5,size.y*0.5-110),minf(580,size.x-120))
		draw_line(Vector2(50,size.y-70),Vector2(size.x-50,size.y-70),Color("284754"),1,true)
		for x in [50,size.x-50]:
			draw_line(Vector2(x,140),Vector2(x,size.y-70),Color("213844"),1,true)
	else:
		draw_rect(Rect2(Vector2.ZERO,size),Color(0.02,0.035,0.055,0.91))
	var reveal := clampf(age/0.22,0,1)
	draw_line(Vector2(size.x*0.5*(1-reveal),size.y-2),Vector2(size.x*0.5*(1+reveal),size.y-2),Color("63f5ce"),2,true)
