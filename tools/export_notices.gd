extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		printerr("Expected output text path")
		quit(1)
		return
	var text: String = "THIRD-PARTY NOTICES\n\nGodot " + Engine.get_version_info().string + "\n\n"
	text += Engine.get_license_text() + "\n\n"
	text += "ENGINE COMPONENT COPYRIGHT INFORMATION\n\n"
	for entry in Engine.get_copyright_info():
		text += str(entry.name) + "\n"
		for part in entry.parts:
			text += "Files: " + ", ".join(part.files) + "\n"
			text += "Copyright: " + "\n".join(part.copyright) + "\n"
			text += "License: " + str(part.license) + "\n\n"
	var licenses := Engine.get_license_info()
	var names := licenses.keys()
	names.sort()
	for name in names:
		text += "\nLICENSE: " + str(name) + "\n\n" + str(licenses[name]) + "\n"
	var sentry := FileAccess.get_file_as_string("res://addons/sentry/LICENSE.md")
	if sentry.is_empty() or licenses.is_empty():
		printerr("Required bundled notices missing")
		quit(1)
		return
	text += "\nSENTRY GODOT SDK\n\n" + sentry
	for family in ["Rajdhani","Barlow"]:
		text += "\nFONT: "+family+"\n\n"+FileAccess.get_file_as_string("res://assets/fonts/"+family+"-OFL.txt")
	var output := FileAccess.open(args[0],FileAccess.WRITE)
	if output == null:
		printerr("Cannot write notices")
		quit(1)
		return
	output.store_string(text)
	output.flush()
	var error := output.get_error()
	output.close()
	if error != OK:
		quit(1)
		return
	print("PASS: bundled engine and Sentry notices exported")
	quit()

