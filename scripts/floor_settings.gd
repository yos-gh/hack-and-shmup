extends Resource

# Explicit generation input; no live session or scene references.
@export var depth := 1
@export var move_bonus := 0.0
@export var power := 1.0
@export var fire_rate := 1.0
@export var recharge := 0.0
@export var physics_ticks := 60.0
@export_range(-1,2) var boss_choice := -1
