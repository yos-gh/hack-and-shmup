extends RefCounted

# Session flags and transitions; combat remains owned by Game.
var run = preload("res://scripts/run_state.gd").new()
var best_cleared := 0
var floor_snapshot = preload("res://scripts/floor_snapshot.gd").new()
var title_screen := true
var paused := false
var choosing := false
var pending_respawn := false
var fire_armed := false

func restart_attempt(game) -> void:
	game.boss.reset()
	game.sound.enemy_audio.reset()
	game.stairs_unlocked = not game.boss_floor
	floor_snapshot.restore(game)
	game.enemy_buckets.clear()
	game.patrol_elapsed.clear()
	game.simulation_tick = 0
	game.bullets.clear()
	game.particles.clear()
	game.effects.clear()
	game.damage_labels.clear()
	game.discovered.clear()
	game.discovered[0] = true
	game.camera_pos = game.player
	game.main_cd = 0.0
	game.sub_cd = 0.0
	game.sub_cd_total = 0.0
	game.sound.reset_time_warning()
	game.grace = 1.0
	game.flow_cd = 0.0
	game.pending_respawn = false
	game.banner = 3.0
	game.choosing = false


func start_run(game) -> void:
	game.replay_input.clear()
	game.practice.active = false
	game.practice.selecting = false
	run.reset()
	game.title_screen = false
	game.paused = false
	game.fire_armed = false
	game.timeout_banner = 0
	game.hit_banner = 0
	game.hit_flash = 0
	game.sound.set_paused(false)
	game.new_floor()


func return_to_title(game) -> void:
	game.boss.reset()
	game.sound.enemy_audio.reset()
	game.bullets.clear()
	game.particles.clear()
	game.effects.clear()
	game.damage_labels.clear()
	game.practice.active = false
	game.practice.selecting = false
	game.title_screen = true
	game.paused = false
	game.choosing = false
	game.pending_respawn = false
	game.sound.set_paused(false)
	game.queue_redraw()


func die(game, reason: String = "HIT") -> void:
	if game.pending_respawn or (game.grace > 0 and reason != "TIME UP"): return
	game.deaths += 1
	game.death_reason = reason
	game.pending_respawn = true
	game.combat_events.player_died.emit(reason)
	game.queue_redraw()
