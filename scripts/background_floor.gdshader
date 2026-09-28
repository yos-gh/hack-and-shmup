shader_type spatial;
render_mode unshaded, world_vertex_coords;
varying vec2 floor_position;
#include "res://scripts/background_facets.gdshaderinc"
// Presentation clock and decorative ripples (world x, world y, start clock, strength).
// The clock only advances with unpaused gameplay, so a still frame stays still.
uniform float clock = 0.0;
uniform vec4 ripples[8];
uniform int ripple_count = 0;
uniform vec3 grid_color : source_color = vec3(0.4, 0.8, 0.9);

void vertex() {
	floor_position = VERTEX.xy;
}

float line_mask(vec2 p, float period, float width) {
	vec2 cell = abs(fract(p / period + 0.5) - 0.5) * period;
	vec2 aa = max(fwidth(p), vec2(0.0001));
	vec2 line = 1.0 - smoothstep(vec2(width * 0.5), vec2(width * 0.5) + aa, cell);
	return max(line.x, line.y);
}

void fragment() {
	vec2 p = floor_position;
	// Geometry-grid ripple: a travelling ring pushes lines outward and lights them.
	vec2 push = vec2(0.0);
	float wave_light = 0.0;
	for (int i = 0; i < 8; i++) {
		if (i >= ripple_count) break;
		vec4 r = ripples[i];
		vec2 d = p - vec2(r.x, -r.y);
		float dist = length(d);
		float age = max(clock - r.z, 0.0);
		float front = age * (260.0 + 140.0 * r.w);
		float fade = pow(max(1.0 - age / 1.6, 0.0), 2.0) * r.w;
		float band = exp(-pow((dist - front) / (26.0 + 10.0 * r.w), 2.0)) * fade;
		push += d / max(dist, 0.001) * band * 9.0;
		wave_light += band;
	}
	vec2 q = p - push;
	float known = 1.0 - step(0.60, COLOR.a);
	float minor = line_mask(q, 32.0, 1.0);
	float major = line_mask(q, 128.0, 1.6);
	// Roguelike floor dot at every tile centre: the terminal "." under the neon.
	vec2 tile_offset = (fract(q / 32.0) - 0.5) * 32.0;
	float dot_mask = 1.0 - smoothstep(0.9, 0.9 + length(fwidth(q)) * 1.2, length(tile_offset));
	// Four-cell major crossings carry a small "+" marker.
	vec2 cross_offset = abs(fract(q / 128.0 + 0.5) - 0.5) * 128.0;
	float cross_mask = (1.0 - step(5.0, max(cross_offset.x, cross_offset.y))) * major;
	vec2 pane = fract(floor_position / 128.0);
	vec2 edge = min(pane, 1.0 - pane);
	float center = smoothstep(0.0, 0.4, min(edge.x, edge.y));
	float facet = glass_facets(floor_position / 48.0);
	vec3 glass = COLOR.rgb * (0.78 + known * (0.10 * facet + 0.06 * center));
	float lit = mix(0.16, 1.0, known);
	float grid = minor * 0.16 + major * 0.34 + cross_mask * 0.45 + dot_mask * 0.30;
	vec3 neon = grid_color * grid * lit * (1.0 + wave_light * 2.5);
	neon += grid_color * wave_light * 0.10 * lit;
	ALBEDO = glass + neon;
	ALPHA = clamp(COLOR.a + grid * 0.3 * lit + wave_light * 0.2 * lit, 0.0, 1.0);
}
