extends RefCounted

const Queries = preload("res://scripts/floor_queries.gd")
const TILE := 32.0
const SPEED := 245.0
const ENTRY_CLEARANCE := 96.0
var rng := RandomNumberGenerator.new()
var floor_number := 1
var move_bonus := 0.0
var power := 1.0
var fire_rate := 1.0
var cells: Dictionary = {}
var rooms: Array[Rect2i] = []
var room_shapes: Array[int] = []
var entrances: Dictionary = {}
var enemies: Array[Dictionary] = []
var room_links: Array[Vector2i] = []
var corridor_cells: Dictionary = {}
var flow: Dictionary = {}
var player := Vector2.ZERO
var spawn_point := Vector2.ZERO
var stairs := Vector2.ZERO
var goal_room := 0
var boss_floor := false
var boss_variant := 0
var boss_max_hp := 0.0
var route_seconds := 0.0
var time_limit := 0.0

func tile(p: Vector2) -> Vector2i:
	return Queries.tile(self,p)

func center(p: Vector2i) -> Vector2:
	return Queries.center(self,p)

func walkable(p: Vector2, radius: float = 10.0) -> bool:
	return Queries.walkable(self,p,radius)

func entry_safe(p: Vector2, room_id: int) -> bool:
	return Queries.entry_safe(self,p,room_id)

func build_flow() -> void:
	Queries.build_flow(self)

func enemy_health(kind: int, depth: int) -> float:
	return Queries.enemy_health(self,kind,depth)

func room_contains(p: Vector2i, r: Rect2i, shape: int) -> bool:
	return Queries.room_contains(self,p,r,shape)

func connect_rooms(a: int, b: int) -> void:
	Queries.connect_rooms(self,a,b)
