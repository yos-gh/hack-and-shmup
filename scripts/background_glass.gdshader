shader_type spatial;
render_mode unshaded, world_vertex_coords, depth_prepass_alpha;

uniform vec2 depth_slant = vec2(0.45,-0.30);
uniform bool front_shell = false;
varying float front_face;
varying float layer_depth;

void vertex() {
	// Only decorative depth is oblique. The playable XY plane never moves.
	float depth = max(-VERTEX.z, 0.0);
	layer_depth = depth;
	front_face = front_shell ? max(-normalize(NORMAL).y,0.0) : 0.0;
	VERTEX.xy += depth_slant * depth;
}

void fragment() {
	// The near wall has a finite, readable fascia; supports below it recede.
	float wall_band = front_face * (1.0-smoothstep(31.0,33.0,layer_depth));
	float support = COLOR.a * exp(-layer_depth/58.0);
	ALBEDO = COLOR.rgb * mix(1.0,0.88,wall_band);
	ALPHA = mix(support,0.62,wall_band);
}
