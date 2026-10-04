extends RefCounted

const RunPassword = preload("res://scripts/run_password.gd")

# Title CONTINUE screen: type or paste a pause-screen password to resume there.
var selecting := false
var text := ""
var error := ""

func open(game) -> void:
	game.return_to_title()
	selecting = true
	error = ""
	game.queue_redraw()

func close(game) -> void:
	game.return_to_title()

func submit(game) -> void:
	if not selecting: return
	var data := RunPassword.decode(text)
	if data.has("error"):
		error = data.error
		game.sound.play_sfx("armor")
		game.queue_redraw()
		return
	text = ""
	error = ""
	game.session.resume_run(game,data)
