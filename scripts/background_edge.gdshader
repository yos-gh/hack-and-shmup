shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec2 depth_slant = vec2(0.45,-0.30);
uniform bool boundary = false;
varying float edge_distance;
varying float layer_depth;

void vertex() {
	vec4 a = MODEL_MATRIX * vec4(-0.5,0.0,0.0,1.0);
	vec4 b = MODEL_MATRIX * vec4(0.5,0.0,0.0,1.0);
	a.xy += depth_slant * max(-a.z,0.0);
	b.xy += depth_slant * max(-b.z,0.0);
	vec4 ca = PROJECTION_MATRIX * VIEW_MATRIX * a;
	vec4 cb = PROJECTION_MATRIX * VIEW_MATRIX * b;
	vec2 direction = (cb.xy/cb.w-ca.xy/ca.w)*VIEWPORT_SIZE;
	vec2 side = vec2(-direction.y,direction.x)/max(length(direction),0.0001);
	vec4 clip = mix(ca,cb,VERTEX.x+0.5);
	clip.xy += side * VERTEX.y * 4.3 / VIEWPORT_SIZE * clip.w;
	POSITION = clip;
	edge_distance = VERTEX.y*2.15;
	layer_depth = max(-mix(a.z,b.z,VERTEX.x+0.5),0.0);
}

void fragment() {
	ALBEDO = COLOR.rgb;
	float coverage = clamp(1.15-abs(edge_distance),0.0,1.0);
	ALPHA = COLOR.a*coverage*(boundary ? 1.0 : exp(-layer_depth/58.0));
}
