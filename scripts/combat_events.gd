extends RefCounted

# Synchronous value-only notifications; listeners never receive mutable enemies.
signal enemy_hit(position: Vector2, damage: float, blocked: bool, killed: bool)
signal player_died(reason: String)
signal weapon_fired(position: Vector2, direction: Vector2, weapon: int)
signal charge_changed(position: Vector2, direction: Vector2, started: bool)
signal room_entered(room_id: int, position: Vector2)
signal stairs_opened(position: Vector2)
signal scene_changed(scene: String)
signal boss_destroyed(position: Vector2, color: Color)
signal actor_fired(position: Vector2, cue: String)
signal actor_alerted(position: Vector2, direction: Vector2)
