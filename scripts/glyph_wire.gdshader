shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform int opening_mode = 0;
varying float edge_distance;
varying float charge;
vec3 deform(vec3 p, float warning) {
	if (opening_mode == 1) {
		float radial = length(p.xz);
		float inner = mix(5.0/12.0,1.5/12.0,warning);
		if (radial>0.0001) p.xz *= (inner+(radial-5.0/12.0)*(1.0-inner)/(1.0-5.0/12.0))/radial;
	} else if (opening_mode == 2 && length(p.xy)<0.5) { p.xy *= mix(1.0,0.3,warning); }
	return p;
}
void vertex() {
	vec4 a = PROJECTION_MATRIX*VIEW_MATRIX*MODEL_MATRIX*vec4(deform(VERTEX,INSTANCE_CUSTOM.r),1.0);
	vec4 b = PROJECTION_MATRIX*VIEW_MATRIX*MODEL_MATRIX*vec4(deform(CUSTOM0.xyz,INSTANCE_CUSTOM.r),1.0);
	vec2 delta = (b.xy/b.w-a.xy/a.w)*VIEWPORT_SIZE;
	vec2 side = vec2(-delta.y,delta.x)/max(length(delta),0.001);
	vec4 clip = mix(a,b,UV.x);
	clip.xy += side*UV.y*(opening_mode == 2 ? 1.4 : 2.4)/VIEWPORT_SIZE*clip.w;
	clip.z -= 0.00001*clip.w;
	POSITION = clip;
	edge_distance = UV.y*1.4;
	charge = INSTANCE_CUSTOM.r;
}
void fragment() {
	ALBEDO = mix(COLOR.rgb,vec3(0.91,1.0,0.98),0.22+charge*0.45);
	ALPHA = COLOR.a*clamp(1.2-abs(edge_distance),0.0,1.0);
}
