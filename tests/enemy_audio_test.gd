extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
 if not value:
  push_error("FAIL: "+message)
  failures += 1
func run() -> void:
 var game = load("res://main.tscn").instantiate()
 root.add_child(game)
 game.start_run()
 game.set_physics_process(false)
 var audio = game.sound.enemy_audio
 audio.set_process(false)
 game.cells.clear()
 game.discovered = {0:true}
 for x in range(-50,51):
  for y in range(-30,31): game.cells[Vector2i(x,y)] = 0
 game.player = Vector2(16,16)
 game.camera_pos = game.player
 game.cells[Vector2i(6,0)] = 1
 audio.reset()
 audio.request(game,"sniper_fire",Vector2(208,16))
 check(audio.pending.is_empty(),"unentered room stays silent")
 for i in range(100): audio.request(game,"sniper_fire",game.player+Vector2(20+i*2,0))
 check(audio.pending.size()==1,"100 simultaneous sniper shots collapse to one cue")
 var cues: Array = audio.take(0)
 check(cues.size()==1 and cues[0].screen.x<game.get_viewport_rect().size.x/2+21,"nearest on-screen source wins")
 audio.request(game,"sniper_fire",game.player)
 check(audio.take(0.03).is_empty(),"nearby repeats suppressed without accumulating stale audio")
 audio.request(game,"sniper_fire",game.player)
 check(audio.take(0.07).size()==1,"later volley remains audible")
 audio.reset()
 for key in audio.PRIORITY: audio.request(game,key,game.player+Vector2(-100,0))
 audio._process(0.1)
 check(audio.voices[0].playing and audio.voices[0].stream == game.sound.clips.hunter_lock,"laser advance warning owns reserved voice")
 check(audio.voices.slice(1).filter(func(v): return v.playing).size()==4,"general attack mix bounded to four voices")
 check(is_equal_approx(audio.voices[1].volume_db,audio.levels[1]-6),"laser warning ducks ordinary enemy attacks")
 check(audio.voices[0].position.x<game.get_viewport_rect().size.x/2,"left attack placed left of listener")
 for voice in audio.voices: check(voice.playback_type==AudioServer.PLAYBACK_TYPE_STREAM,"enemy sounds use streaming mixer")
 game.sound.set_paused(true)
 check(audio.voices.all(func(v): return not v.playing),"pause stops transient enemy voices")
 audio.request(game,"sniper_fire",game.player)
 check(audio.pending.is_empty(),"paused game queues no cues")
 game.sound.set_paused(false)
 game.sound.set_levels(0,1,1)
 check(audio.voices.all(func(v): return v.volume_linear==0),"master gain silences enemy audio")
 game.sound.set_levels(1,1,1)
 game.sound.set_audio_mode(2)
 check(audio.voices.all(func(v): return not v.playing),"mute stops enemy audio")
 game.sound.set_audio_mode(0)
 audio.request(game,"hunter_lock",game.player)
 audio._process(0.1)
 game.sound.play_sfx("death")
 check(audio.voices.all(func(v): return not v.playing),"death takes precedence over enemy mix")
 audio.reset()
 game.restart_attempt()
 check(audio.pending.is_empty() and audio.cooldown.is_empty(),"retry clears queued and rate-limit state")
 game.sound.voices[0].stop()
 for phase in range(3):
  load("res://tools/dev_scenario.gd").configure(game,"halo45",19045,1)
  var owner: Dictionary = game.enemies[0]
  owner.active = true
  owner.shots = phase
  game.camera_pos = owner.p
  game.player = owner.p+Vector2(140,0)
  audio.reset()
  game.boss.fire_halo(game,owner,Vector2.RIGHT)
  check(audio.pending.has("halo_fire") and audio.pending.size()==1,"each HALO pattern emits one opening-wave cue")
  audio.reset()
  game.boss.emit_salvo(game,{"owner":owner,"origin":owner.p+Vector2(0,100),"aim":Vector2.RIGHT,"offsets":[-0.1,0.0,0.1],"speed":110.0})
  check(audio.pending.has("halo_option") and audio.pending.size()==1,"satellite salvo emits one cue, not one per bullet")
 # Verify real stereo mixer output, not only the pending play flag.
 game.sound.music.stop()
 for voice in game.sound.voices: voice.stop()
 audio.reset()
 game.camera_pos = game.player
 for x in range(-50,51):
  for y in range(-30,31): game.cells[Vector2i(x,y)] = 0
 game.discovered[0] = true
 var capture := AudioEffectCapture.new()
 AudioServer.add_bus_effect(0,capture)
 await create_timer(0.15).timeout
 var powers: Array[Vector2] = []
 for direction in [-1,1]:
  audio.reset()
  await create_timer(0.1).timeout
  capture.clear_buffer()
  audio.request(game,"hunter_lock",game.player+Vector2(direction*350,0))
  audio._process(0.1)
  await create_timer(0.18).timeout
  var samples := capture.get_buffer(capture.get_frames_available())
  var power := Vector2.ZERO
  for sample in samples: power += sample*sample
  powers.append(power)
  print("MIX: ", direction, " ", power, " listener ", root.audio_listener_enable_2d)
 check(powers[0].x+powers[0].y>0.00001 and powers[1].x+powers[1].y>0.00001,"enemy cues reach actual stereo mixer")
 check(powers[0].x>powers[0].y and powers[1].y>powers[1].x,"actual pan favors correct side")
 AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
 game.free()
 if failures == 0: print("PASS: enemy cue aggregation, visibility, priorities, stereo placement, levels, pause/mute/reset and HALO waves")
 quit(1 if failures else 0)
