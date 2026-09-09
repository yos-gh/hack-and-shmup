extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
 if not value:
  push_error("FAIL: "+message)
  failures += 1
func run() -> void:
 var game = load("res://main.tscn").instantiate()
 root.add_child(game)
 game.set_physics_process(false)
 game.start_run()
 game.cells.clear()
 game.discovered = {0:true}
 for x in range(100):
  for y in range(4): game.cells[Vector2i(x,y)] = 0
 game.player = Vector2(48,64)
 var trace = game.LanceTrace
 var open_end: Vector2 = trace.endpoint(game,game.player,Vector2.RIGHT)
 check(absf(open_end.x-3200) < 0.01,"ray reaches map boundary beyond screen and old range")
 game.cells.erase(Vector2i(10,1))
 var rays: Array = trace.lanes(game,game.player,Vector2.RIGHT)
 var short := false
 var long := false
 for ray in rays:
  if ray.p.y < 64: short = short or absf(ray.end.x-320) < 0.01
  else: long = long or absf(ray.end.x-3200) < 0.01
 check(short and long,"blocked half stops while open half continues")
 check(trace.hits(game,{"p":Vector2(2500,76)},rays,Vector2.RIGHT),"open half hits offscreen target")
 check(not trace.hits(game,{"p":Vector2(2500,46)},rays,Vector2.RIGHT),"blocked half does not hit behind obstacle")
 check(not trace.hits(game,{"p":Vector2(2500,115)},rays,Vector2.RIGHT),"outside beam misses")
 for y in range(4): game.cells[Vector2i(30,y)] = 1
 rays = trace.lanes(game,game.player,Vector2.RIGHT)
 for ray in rays: check(ray.end.x < 961,"unentered room stops every lane")
 check(not trace.hits(game,{"p":Vector2(980,76)},rays,Vector2.RIGHT),"unentered room cannot receive damage")
 game.discovered[1] = true
 rays = trace.lanes(game,game.player,Vector2.RIGHT)
 check(trace.hits(game,{"p":Vector2(2500,76)},rays,Vector2.RIGHT),"entering room opens forward path")
 check(trace.endpoint(game,Vector2(80,80),Vector2.LEFT).x < 0.01,"negative direction reaches boundary")
 check(trace.endpoint(game,Vector2(80,80),Vector2.UP).y < 0.01,"vertical ray reaches boundary")
 game.cells.erase(Vector2i(3,2))
 var corner: Vector2 = trace.endpoint(game,Vector2(80,80),Vector2(1,1).normalized())
 check(corner.x < 96.01 and corner.y < 96.01,"diagonal cannot leak through blocked corner")
 game.free()
 if failures == 0: print("PASS: unbounded lance, partial occlusion, entry barrier, directions and corners")
 quit(1 if failures else 0)
