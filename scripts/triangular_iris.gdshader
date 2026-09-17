shader_type spatial;
render_mode depth_draw_never;
varying float breath;

void vertex() {
	breath = 0.98+0.02*sin(INSTANCE_CUSTOM.g*1.6);
	// Fixed isosceles shell; its circular opening shrinks from 5px to 1.5px.
	VERTEX.xy *= mix(1.0, 0.3, clamp(INSTANCE_CUSTOM.r, 0.0, 1.0) * UV.x);
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge = pow(1.0-facing, 3.0);
	ALBEDO = mix(COLOR.rgb, vec3(0.82,0.93,1.0), edge*0.28);
	ROUGHNESS = 0.42;
	SPECULAR = 0.08;
	METALLIC = 0.05;
	ALPHA = mix(mix(0.16,0.32,facing),0.98,smoothstep(0.2,0.8,UV.x));
	EMISSION = COLOR.rgb*0.06*breath;
}
