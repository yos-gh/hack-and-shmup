shader_type spatial;
render_mode depth_draw_never;
varying float breath;

void vertex() { breath = 0.98+0.02*sin(INSTANCE_CUSTOM.g*1.6); }

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge = pow(1.0-facing, 3.0);
	// Dark tinted glass body: the neon wire carries the silhouette and the glow.
	ALBEDO = mix(COLOR.rgb*0.8, vec3(0.82,0.93,1.0), edge*0.22);
	ROUGHNESS = 0.42;
	SPECULAR = 0.08;
	METALLIC = 0.05;
	ALPHA = mix(0.14,0.28,facing);
	EMISSION = COLOR.rgb*0.05*breath;
}
