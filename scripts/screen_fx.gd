extends CanvasLayer
## Full-screen presentation pass above world, HUD and menus. Input passes through.
var game: Node
var rect := ColorRect.new()

func setup(host: Node) -> void:
	game = host
	layer = 50
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://scripts/screen_fx.gdshader")
	rect.material = material
	add_child(rect)

func _process(_delta: float) -> void:
	var fx = game.presentation
	var danger := 0.0
	var hurt := 0.0
	if not game.title_screen and not game.choosing and not game.paused and not game.practice.selecting:
		hurt = clampf(game.hit_flash*1.6,0,0.45)
		if not game.boss_floor and game.time_left <= 5.0: danger = (0.5+0.5*sin(fx.clock*TAU*1.6))*0.10
	rect.material.set_shader_parameter("impact",clampf(fx.impact+hurt,0,1))
	rect.material.set_shader_parameter("tint",Color(1,0.12,0.22,maxf(hurt,danger)))
