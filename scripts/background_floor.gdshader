shader_type spatial;
render_mode unshaded, world_vertex_coords;
varying vec2 floor_position;

void vertex() {
	floor_position = VERTEX.xy;
}

void fragment() {
	// Broad glass panes with a subdued inner edge, anchored to the XY plane.
	vec2 pane = fract(floor_position / 128.0);
	vec2 edge = min(pane,1.0-pane);
	float rim = 1.0-smoothstep(0.0,0.022,min(edge.x,edge.y));
	float center = smoothstep(0.0,0.4,min(edge.x,edge.y));
	ALBEDO = COLOR.rgb * (0.88 + 0.22*center + 0.25*rim);
	ALPHA = COLOR.a;
}
