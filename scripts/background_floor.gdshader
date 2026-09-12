shader_type spatial;
render_mode unshaded, world_vertex_coords;
varying vec2 floor_position;
uniform vec3 inner_color = vec3(0.57,0.36,0.69);
#include "res://scripts/background_facets.gdshaderinc"

void vertex() {
	floor_position = VERTEX.xy;
}

void fragment() {
	// Broad glass panes with a subdued inner edge, anchored to the XY plane.
	vec2 pane = fract(floor_position / 128.0);
	vec2 edge = min(pane,1.0-pane);
	float rim = 1.0-smoothstep(0.0,0.022,min(edge.x,edge.y));
	float center = smoothstep(0.0,0.4,min(edge.x,edge.y));
	float known = mix(1.0,0.45,step(0.60,COLOR.a));
	float facet = glass_facets(floor_position/48.0);
	float cloud = glass_field(floor_position/192.0+vec2(7.0,3.0));
	vec3 tint = mix(COLOR.rgb,inner_color*0.14,smoothstep(0.35,0.85,cloud)*known);
	ALBEDO = tint * (0.85+known*(0.75*facet+0.10*center+0.12*rim));
	ALPHA = COLOR.a;
}
