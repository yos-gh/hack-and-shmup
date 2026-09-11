shader_type spatial;
render_mode unshaded, world_vertex_coords, depth_prepass_alpha;

void vertex() {
	// Only decorative depth is oblique. The playable XY plane never moves.
	float depth = max(-VERTEX.z, 0.0);
	VERTEX.xy += vec2(0.45, -0.30) * depth;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a;
}
