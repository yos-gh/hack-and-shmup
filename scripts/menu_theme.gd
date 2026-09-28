extends RefCounted

static func create() -> Theme:
	var theme := Theme.new()
	theme.default_font = preload("res://assets/fonts/Barlow-Medium.ttf")
	theme.default_font_size = 17
	theme.set_font("font","Button",preload("res://assets/fonts/Rajdhani-SemiBold.ttf"))
	theme.set_font_size("font_size","Button",20)
	var background := StyleBoxFlat.new()
	background.bg_color = Color("090f18")
	theme.set_stylebox("panel", "PanelContainer", background)
	# Command buttons lean forward; upgrade cards stay square so their text aligns.
	theme.set_type_variation("CardButton","Button")
	for variant in ["Button","CardButton"]:
		for state in ["normal", "hover", "pressed", "focus"]:
			theme.set_stylebox(state,variant,button_box(state,variant == "CardButton"))
	theme.set_color("font_color","Button",Color("d9e8ed"))
	theme.set_color("font_hover_color","Button",Color("ffffff"))
	theme.set_color("font_focus_color","Button",Color("ffffff"))
	theme.set_color("font_pressed_color","Button",Color("63f5ce"))
	theme.set_color("font_outline_color","Button",Color(0.02,0.05,0.08))
	theme.set_constant("outline_size","Button",3)
	theme.set_color("font_outline_color","Label",Color(0.01,0.03,0.05,0.9))
	theme.set_constant("outline_size","Label",3)
	return theme

static func button_box(state: String, card: bool) -> StyleBoxFlat:
	var lit := state in ["hover","focus"]
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07,0.19,0.23,0.92) if state == "hover" else (Color(0.05,0.17,0.2,0.95) if state == "pressed" else Color(0.035,0.075,0.11,0.88))
	if state == "focus": box.bg_color = Color.TRANSPARENT
	box.border_color = Color("63f5ce") if lit or state == "pressed" else Color(0.22,0.4,0.46)
	box.set_border_width_all(2 if lit else 1)
	box.border_width_left = 4 if state in ["hover","pressed"] else box.border_width_left
	box.corner_radius_top_left = 2
	box.corner_radius_bottom_right = 2
	# Focus draws above the button, so only hover carries the glow shadow.
	if state == "hover":
		box.shadow_color = Color(0.39,0.96,0.81,0.28)
		box.shadow_size = 10
	if not card: box.skew = Vector2(0.22,0)
	box.anti_aliasing = true
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	box.content_margin_left = 12
	box.content_margin_right = 12
	return box
