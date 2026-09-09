extends Resource

# Authored definition; runtime code treats catalog resources as read-only.
@export var health_one: float = 1.0
@export var health_fifteen: float = 1.0
@export var time_bonus: float = 0.0

func health(depth: int) -> float:
	return lerpf(health_one,health_fifteen,(depth-1)/14.0)
