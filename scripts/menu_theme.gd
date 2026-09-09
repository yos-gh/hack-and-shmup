extends RefCounted

static func create() -> Theme:
	var theme := Theme.new()
	var background := StyleBoxFlat.new()
	background.bg_color = Color("0b111c")
	theme.set_stylebox("panel", "PanelContainer", background)
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("263847") if state in ["hover","pressed"] else Color("182735")
		box.border_color = Color("63f5ce")
		box.set_border_width_all(1 if state in ["hover","focus"] else 0)
		box.content_margin_top = 6
		box.content_margin_bottom = 6
		box.content_margin_left = 8
		box.content_margin_right = 8
		theme.set_stylebox(state,"Button",box)
	return theme
