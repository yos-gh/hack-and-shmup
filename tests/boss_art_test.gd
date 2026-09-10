extends SceneTree
const Scenario = preload("res://tools/dev_scenario.gd")
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
 game.set_process_unhandled_input(false)
 DirAccess.make_dir_recursive_absolute("res://docs/validation/boss-art")
 for scenario in ["siege5","hunter15"]:
  Scenario.configure(game,scenario,19045,1)
  game.set_depth_view(true)
  var enemy: Dictionary = game.enemies[0]
  enemy.active = true
  game.camera_pos = enemy.p
  game.player = enemy.p+Vector2(160,0)
  game.banner = 0
  var prefix := "siege" if scenario == "siege5" else "hunter"
  var core: MultiMesh = game.depth_view.batches[prefix+"_core"]
  var sizes: Array[float] = []
  var frames: Array[Image] = []
  for phase in range(3):
   enemy.cd = [0.8,0.0,2.5][phase]
   game.boss.lasers.clear()
   if scenario == "hunter15" and phase == 1:
    game.boss.add_laser(enemy.p,enemy.p+Vector2(350,0),0.05,0.35,enemy)
    game.player = enemy.p+Vector2(0,160)
   else: game.player = enemy.p+Vector2(160,0)
   var before := var_to_bytes([Scenario.digest(game),game.boss.salvos,game.effects_rng.state])
   game.depth_view.sync(game)
   sizes.append(core.get_instance_transform(0).basis.x.length())
   if scenario == "hunter15" and phase == 1:
    check(core.get_instance_transform(0).basis.x.normalized().dot(Vector3.RIGHT)>0.99,"hunter faces locked laser even when player crosses it")
   await process_frame
   await process_frame
   await RenderingServer.frame_post_draw
   check(before == var_to_bytes([Scenario.digest(game),game.boss.salvos,game.effects_rng.state]),"boss rendering preserves simulation and RNG")
   var frame: Image = game.depth_view.viewport.get_texture().get_image()
   frames.append(frame)
   check(frame.get_pixelv(Vector2i(frame.get_size()/2)).get_luminance()>0.15,"boss core visibly rendered")
   root.get_texture().get_image().save_png("res://docs/validation/boss-art/%s-%d.png" % [scenario,phase])
  check(sizes[1]<sizes[0] and is_equal_approx(sizes[0],sizes[2]),"core contracts and recovers")
  var changes := 0
  var center := Vector2i(frames[0].get_size()/2)
  for y in range(-20,21):
   for x in range(-20,21):
    if not frames[0].get_pixelv(center+Vector2i(x,y)).is_equal_approx(frames[1].get_pixelv(center+Vector2i(x,y))): changes += 1
  check(changes>20,"charge visibly changes rendered body")
  game.rebuild_enemy_buckets()
  check(game.bullet_target(enemy.p+Vector2(20,0)) == enemy,"larger bosses accept edge hits")
  check(game.bullet_target(enemy.p+Vector2(24,0)).is_empty(),"shots outside enlarged body miss")
  if scenario == "siege5":
   game.boss.fire(game,enemy,Vector2.RIGHT)
   check(game.boss.shot_flash(game,enemy.p) == 1.0,"firing triggers immediate local flash")
   check(game.boss.shot_flash(game,game.enemies[1].p) == 0,"other turrets do not flash")
   game.depth_view.sync(game)
   await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://docs/validation/boss-art/siege-shot.png")
   game.effects.clear()
   check(game.boss.shot_flash(game,enemy.p) == 0,"flash expires without retained state")
   game.boss.emit_salvo(game,{"owner":enemy,"aim":Vector2.RIGHT,"offsets":[0.0],"speed":210.0})
   check(game.boss.shot_flash(game,enemy.p) == 1.0,"delayed volley also identifies firing turret")
  for other in game.enemies: other.hp = 0
  game.depth_view.sync(game)
  check(core.visible_instance_count == 0,"dead bosses removed immediately")
  game.restart_attempt()
  game.depth_view.sync(game)
  check(core.visible_instance_count == 0,"retry does not expose unopened boss room")
  game.discovered[1] = true
  game.depth_view.sync(game)
  check(core.visible_instance_count == (6 if scenario == "siege5" else 1),"all bosses restored after room entry")
  Scenario.configure(game,"normal19",19045,1)
  game.depth_view.sync(game)
  for key in game.depth_view.batches:
   if key.begins_with("siege_") or key.begins_with("hunter_"):
    check(game.depth_view.batches[key].visible_instance_count == 0,"floor transition clears every boss component")
 game.free()
 if failures == 0: print("PASS: both boss models, visible charge/reset, locked aim, state isolation and lifecycle cleanup")
 quit(1 if failures else 0)
