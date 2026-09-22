extends RefCounted
## World-space body dimensions shared by 2D/3D presentation and weapon hit tests.
const SIZE_SCALE := [1.5, 2.0, 2.0, 1.0]
const AUTHORED_SCALE := [1.3, 1.12, 1.0, 1.0]
const SIEGE_EXTENT := 20.0
const HUNTER_EXTENT := Vector2(24.0, 18.0)
const HALO_RADIUS := 29.0

static func model_scale(variant: int) -> float:
	return AUTHORED_SCALE[variant] * SIZE_SCALE[variant]

static func hit_radius(variant: int) -> float:
	# Enclose the whole central body, including armor/wings; satellites are separate.
	var radius: float = [SIEGE_EXTENT, HUNTER_EXTENT.length(), HALO_RADIUS, 48.0][variant]
	return radius * model_scale(variant)
