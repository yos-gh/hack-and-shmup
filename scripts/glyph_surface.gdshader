shader_type spatial;
render_mode depth_prepass_alpha;

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge = pow(1.0-facing, 3.0);
	ALBEDO = mix(COLOR.rgb, vec3(0.82,0.93,1.0), edge*0.12);
	ROUGHNESS = 0.42;
	SPECULAR = 0.08;
	METALLIC = 0.05;
	ALPHA = mix(0.58,0.96,facing);
}
