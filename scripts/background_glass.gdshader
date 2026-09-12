shader_type spatial;
render_mode unshaded, world_vertex_coords, depth_prepass_alpha, cull_disabled;

uniform vec2 depth_slant = vec2(0.45,-0.30);
uniform bool front_shell = false;
uniform bool two_sided = false;
#include "res://scripts/background_facets.gdshaderinc"
varying float front_face;
varying float layer_depth;
varying vec2 glass_position;

void vertex() {
	// Only decorative depth is oblique. The playable XY plane never moves.
	float depth = max(-VERTEX.z, 0.0);
	layer_depth = depth;
	// Open glass curtains are viewed from either side of the room boundary.
	front_face = front_shell ? abs(normalize(NORMAL).y) : 0.0;
	vec3 n = abs(normalize(NORMAL));
	glass_position = n.z > 0.5 ? VERTEX.xy : vec2(n.x > 0.5 ? VERTEX.y : VERTEX.x,VERTEX.z);
	VERTEX.xy += depth_slant * depth;
}

void fragment() {
	if (!two_sided && !FRONT_FACING) discard;
	// The near wall has a finite, readable fascia; supports below it recede.
	float wall_band = front_face * (1.0-smoothstep(31.0,33.0,layer_depth));
	float support = COLOR.a * exp(-layer_depth/85.0);
	if (front_shell) support *= mix(1.0,0.45,smoothstep(32.0,44.0,layer_depth));
	float facet = glass_facets(glass_position/32.0);
	// Keep the fascia readable even where a facet happens to be dark.
	ALBEDO = COLOR.rgb * mix(0.35+1.3*facet,0.90+0.30*facet,wall_band);
	ALPHA = mix(support,0.34*min(COLOR.a/0.13,1.0),wall_band);
}
