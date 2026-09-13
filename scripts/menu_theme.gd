extends RefCounted

static func create() -> Theme:
	var theme := Theme.new()
	var background := StyleBoxFlat.new()
	background.bg_color = Color("090f18")
	theme.set_stylebox("panel", "PanelContainer", background)
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("203c46") if state == "hover" else (Color("284b50") if state == "pressed" else Color("111f2b"))
		box.border_color = Color("63f5ce") if state in ["hover","focus"] else Color("385361")
		box.set_border_width_all(1)
		if state == "focus": box.bg_color = Color.TRANSPARENT
		box.border_width_left = 3 if state in ["hover","pressed"] else 1
		box.content_margin_top = 6
		box.content_margin_bottom = 6
		box.content_margin_left = 8
		box.content_margin_right = 8
		theme.set_stylebox(state,"Button",box)
	theme.set_color("font_color","Button",Color("d9e8ed"))
	theme.set_color("font_hover_color","Button",Color("ffffff"))
	theme.set_color("font_pressed_color","Button",Color("63f5ce"))
	return theme
