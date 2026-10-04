extends RefCounted
## Shared boss presentation: shield rings, energy cores, beams, target marks and
## impacts. Read-only snapshots of boss state; never consumes gameplay RNG.
const DANGER := Color("ff4d6a")
const WHITE_HOT := Color("fff6ea")

static func glow(game, p: Vector2, radius: float, color: Color) -> void:
	game.world_view.glow(game,p,radius,color)

static func arc_band(center: Vector2, a: float, b: float, inner: float, outer: float, steps: int = 4) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(steps+1): points.append(center+Vector2.from_angle(lerpf(a,b,float(i)/steps))*outer)
	for i in range(steps,-1,-1): points.append(center+Vector2.from_angle(lerpf(a,b,float(i)/steps))*inner)
	return points

# Segmented armour ring in the boss's own hue. Damage heats a plate toward red;
# a broken plate leaves a ghost socket that refills as it rebuilds.
static func shield_ring(game, e: Dictionary, count: int, ink: Color, rebuild: float, inner: float = 84.0, outer: float = 108.0) -> void:
	var mid := (inner+outer)*0.5
	game.draw_arc(e.p,mid,0,TAU,96,Color(ink,0.06),outer-inner+6)
	for i in range(count):
		var plate: Dictionary = e.plates[i]
		var a: float = (i-0.44)*TAU/count
		var b: float = (i+0.44)*TAU/count
		if plate.hp > 0:
			var health: float = clampf(plate.hp/plate.max_hp,0,1)
			var tone := ink.lerp(DANGER,1.0-health)
			var panel := arc_band(e.p,a,b,inner,outer)
			game.draw_colored_polygon(panel,Color(tone.darkened(0.6),0.62))
			panel.append(panel[0])
			game.draw_polyline(panel,Color(tone,0.95),1.6,true)
			game.draw_arc(e.p,outer-4,a+0.05,b-0.05,6,Color(tone.lightened(0.35),0.55),1,true)
			if health < 0.55:
				# Fracture line across the damaged plate.
				var c := (a+b)*0.5
				var crack := PackedVector2Array([e.p+Vector2.from_angle(c-0.08)*outer,e.p+Vector2.from_angle(c+0.03)*(mid+3),e.p+Vector2.from_angle(c-0.04)*(mid-4),e.p+Vector2.from_angle(c+0.07)*inner])
				game.draw_polyline(crack,Color(WHITE_HOT,0.7*(1.0-health/0.55)),1.2,true)
		else:
			var refill: float = clampf(1.0-plate.timer/maxf(rebuild,0.001),0,1)
			var ghost := arc_band(e.p,a,b,inner,outer)
			ghost.append(ghost[0])
			game.draw_polyline(ghost,Color(ink,0.14),1,true)
			game.draw_arc(e.p,outer,a,lerpf(a,b,refill),8,Color(ink,0.6),2,true)

# Reactor core: a contained heart inside counter-rotating segment rings that
# sit in the gap between the core crystal and the shield ring.
static func energy_core(game, p: Vector2, radius: float, ink: Color, clock: float, rage: bool) -> void:
	var spin := clock*(1.6 if rage else 0.8)
	var beat := 0.5+0.5*sin(clock*(9.0 if rage else 4.0))
	var hue := ink.lerp(DANGER,0.55) if rage else ink
	glow(game,p,radius*2.4,Color(hue,0.12+beat*0.06))
	for i in range(6):
		var start := spin+i*TAU/6
		game.draw_arc(p,radius*1.6,start,start+TAU/6*0.62,10,Color(hue,0.9),2,true)
	for i in range(3):
		var start := -spin*1.4+i*TAU/3
		game.draw_arc(p,radius*1.95,start,start+0.55,10,Color(hue.lightened(0.3),0.65),1.2,true)
	for i in range(12):
		var axis := Vector2.from_angle(spin*0.5+i*TAU/12)
		game.draw_line(p+axis*radius*2.15,p+axis*radius*(2.25+beat*0.1),Color(hue,0.45),1.2,true)
	glow(game,p,radius*(0.55+beat*0.12),Color(hue.lerp(Color.WHITE,0.4),0.55))
	game.draw_circle(p,radius*(0.14+beat*0.04),WHITE_HOT)

# Barrel charge: gathering light and a collapsing ring before a volley.
static func charge(game, p: Vector2, progress: float, ink: Color, radius: float = 27.0) -> void:
	progress = clampf(progress,0,1)
	glow(game,p,12+radius*progress,Color(ink,0.25+0.55*progress))
	game.draw_arc(p,lerpf(radius,radius*0.45,progress),0,TAU,24,Color(ink.lerp(Color.WHITE,progress*0.6),0.4+0.6*progress),1.5+progress*1.5,true)

# Ground telegraph for area strikes. Radius is the exact hit radius.
static func target_mark(game, p: Vector2, radius: float, progress: float, ink: Color, clock: float) -> void:
	progress = clampf(progress,0,1)
	var urgent := progress > 0.75 and fmod(clock,0.12) < 0.06
	game.draw_circle(p,radius,Color(ink,0.06+0.10*progress+(0.08 if urgent else 0.0)))
	game.draw_arc(p,radius,0,TAU,56,Color(ink,0.75),1.6,true)
	game.draw_arc(p,radius*progress,0,TAU,48,Color(WHITE_HOT,0.35+0.45*progress),2,true)
	var spin := clock*1.3
	for i in range(4):
		var start := spin+i*PI/2
		game.draw_arc(p,radius+7,start,start+0.4,8,Color(ink,0.9),2.2,true)
	for axis in [Vector2.RIGHT,Vector2.DOWN]:
		game.draw_line(p-axis*8,p+axis*8,Color(ink,0.8),1.2,true)

static func impact(game, p: Vector2, radius: float, age: float, ink: Color, duration: float = 0.22) -> void:
	var k := clampf(age/duration,0,1)
	glow(game,p,radius*(1.4+0.6*k),Color(ink.lerp(Color.WHITE,0.35),(1.0-k)*0.85))
	game.draw_circle(p,radius,Color(ink,0.32*(1.0-k)))
	game.draw_arc(p,radius*(0.8+0.55*k),0,TAU,56,Color(WHITE_HOT.lerp(ink,k),1.0-k),1.5+4.0*(1.0-k),true)
	for i in range(10):
		var axis := Vector2.from_angle(i*TAU/10+0.3)
		game.draw_line(p+axis*radius*(0.5+0.7*k),p+axis*radius*(0.7+0.9*k),Color(ink,(1.0-k)*0.8),1.5,true)

# Hostile beam: a hollow, flickering lane while charging, then a layered
# hot beam with muzzle flare and a sparking contact point.
static func beam(game, a: Vector2, b: Vector2, width: float, ink: Color, charging: float, flash: float, clock: float, charge_radius: float = -1.0) -> void:
	var direction := a.direction_to(b)
	if direction.is_zero_approx(): return
	var side := direction.orthogonal()*width*0.5
	var length := a.distance_to(b)
	if charging >= 0:
		var t := clampf(charging,0,1)
		var blink := 1.0 if t < 0.8 or fmod(clock,0.1) < 0.05 else 0.35
		game.draw_colored_polygon(PackedVector2Array([a-side,b-side,b+side,a+side]),Color(ink,(0.04+0.08*t)*blink))
		for s in [-1.0,1.0]: game.draw_line(a+side*s,b+side*s,Color(ink,(0.25+0.45*t)*blink),1.2,true)
		var phase := fmod(clock*260.0,40.0)
		var d := phase
		while d < length:
			game.draw_line(a+direction*d,a+direction*minf(d+16,length),Color(ink.lerp(Color.WHITE,0.4),0.25+0.4*t),1.2,true)
			d += 40.0
		charge(game,a,t,ink,charge_radius if charge_radius > 0 else maxf(22,width))
		return
	var shimmer := 0.85+0.15*sin(clock*47.0)
	# Broad beams stay translucent so bullets and the player remain readable.
	var broad := clampf((width-20.0)/60.0,0,1)
	game.draw_line(a,b,Color(ink,lerpf(0.14,0.07,broad)*shimmer),width*lerpf(2.4,1.35,broad),true)
	game.draw_line(a,b,Color(ink,lerpf(0.5,0.16,broad)),width,true)
	game.draw_line(a,b,Color(ink.lerp(Color.WHITE,0.55),lerpf(0.8,0.18,broad)),maxf(2,width*lerpf(0.45,0.4,broad)),true)
	game.draw_line(a,b,Color(WHITE_HOT,lerpf(0.95,0.75,broad)),maxf(1.5,width*lerpf(0.16,0.07,broad)),true)
	for s in [-1.0,1.0]: game.draw_line(a+side*s,b+side*s,Color(ink.lerp(Color.WHITE,0.3),lerpf(0.7,0.9,broad)),lerpf(1.0,1.8,broad),true)
	# Energy pulses travelling down the beam.
	var d := fmod(clock*900.0,120.0)
	while d < length:
		game.draw_line(a+direction*d,a+direction*minf(d+28,length),Color(WHITE_HOT,lerpf(0.5,0.35,broad)),maxf(1.5,width*lerpf(0.3,0.05,broad)),true)
		d += 120.0
	if flash > 0: game.draw_line(a,b,Color(0.95,1.0,0.94,0.9*flash),maxf(3,width*0.5),true)
	glow(game,a,width*lerpf(1.8,0.9,broad)+16,Color(ink,lerpf(0.8,0.45,broad)))
	glow(game,b,width*lerpf(1.5,0.8,broad)+14,Color(ink.lerp(Color.WHITE,0.4),lerpf(0.75,0.4,broad)))
	for i in range(5):
		var spark := Vector2.from_angle(direction.angle()+PI+sin(clock*31.0+i*2.1)*1.1)
		game.draw_line(b+spark*3,b+spark*(8+width*0.6+4*sin(clock*23.0+i)),Color(WHITE_HOT,0.8),1.5,true)

# Marching dashes from a source to its target.
static func dashed(game, a: Vector2, b: Vector2, color: Color, clock: float, dash: float = 10.0, gap: float = 8.0, width: float = 1.5) -> void:
	var length := a.distance_to(b)
	if length < 1: return
	var direction := a.direction_to(b)
	var d := fmod(clock*120.0,dash+gap)
	while d < length:
		game.draw_line(a+direction*d,a+direction*minf(d+dash,length),color,width,true)
		d += dash+gap
