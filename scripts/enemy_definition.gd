extends Resource

# Authored definition; runtime code treats catalog resources as read-only.
@export var health_one: float = 1.0
@export var health_fifteen: float = 1.0
@export var time_bonus: float = 0.0

@export var move_speed := 0.0
@export var patrol_speed := 18.0
@export var bullet_speed := 0.0
@export var shot_interval := 0.0
@export var warning_duration := 0.0
@export var activation_delay := 0.55
@export var charge_speed := 0.0
@export var charge_duration := 0.0
@export var charge_recovery := 0.0
@export var wall_recovery := 0.0
@export var stun_duration := 0.0

func health(depth: int) -> float:
	return lerpf(health_one,health_fifteen,(depth-1)/14.0)
