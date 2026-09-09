extends RefCounted

# Synchronous value-only notifications; listeners never receive mutable enemies.
signal enemy_hit(position: Vector2, damage: float, blocked: bool, killed: bool)
signal player_died(reason: String)
