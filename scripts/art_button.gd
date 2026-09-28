extends Button
var hover_amount := 0.0
var age := 0.0
func _process(delta: float) -> void:
	age += delta
	hover_amount = move_toward(hover_amount,1.0 if is_hovered() or has_focus() or button_pressed else 0.0,delta*8)
	queue_redraw()
func _draw() -> void:
	if hover_amount <= 0: return
	var ink := Color(0.39,0.96,0.81,hover_amount*0.8)
	var length := minf(24,size.x*0.12)
	for p in [Vector2(3,3),Vector2(size.x-3,size.y-3)]:
		var sign_value := 1.0 if p.x<4 else -1.0
		draw_line(p,p+Vector2(length*sign_value,0),ink,2,true)
		draw_line(p,p+Vector2(0,length*sign_value),ink,2,true)
	var x := fmod(age*100,maxf(1,size.x))
	draw_line(Vector2(x,1),Vector2(minf(size.x,x+22),1),Color(ink,hover_amount*0.45),2,true)
	# Selection chevrons slide in beside command buttons.
	if size.y <= 60 and not text.is_empty():
		var slide := (1.0-hover_amount)*10.0+sin(age*6.0)*1.5
		var mid := size.y*0.5
		for i in range(2):
			var tip := Vector2(-8-slide-i*7,mid)
			draw_polyline(PackedVector2Array([tip+Vector2(-5,-6),tip,tip+Vector2(-5,6)]),Color(ink,ink.a*(1.0-i*0.45)),2,true)
