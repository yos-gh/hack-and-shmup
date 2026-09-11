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
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * mix(1.0,3.0,front_face) * exp(-layer_depth / mix(58.0,130.0,front_face));
}
