shader_type spatial;
render_mode depth_draw_never;
varying float breath;

// Torus local XZ radius. Keep the outside at 12px and close the actual opening
// from 5px to 1.5px, matching the shared 2D warning rather than hiding it below a dot.
void vertex() {
	breath = INSTANCE_CUSTOM.b > 0.5 ? 1.0 : 0.98+0.02*sin(INSTANCE_CUSTOM.g*1.6);
	float base_inner = 5.0 / 12.0;
	float inner = mix(base_inner, 1.5 / 12.0, clamp(INSTANCE_CUSTOM.r, 0.0, 1.0));
	float radial = length(VERTEX.xz);
	float derivative = (1.0 - inner) / (1.0 - base_inner);
	if (radial > 0.0001) {
		VERTEX.xz *= (inner + (radial - base_inner) * derivative) / radial;
		NORMAL.xz /= derivative;
		NORMAL = normalize(NORMAL);
	}
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge = pow(1.0-facing, 3.0);
	ALBEDO = mix(COLOR.rgb, vec3(0.82,0.93,1.0), edge*0.28);
	ROUGHNESS = 0.42;
	SPECULAR = 0.08;
	METALLIC = 0.05;
	ALPHA = mix(0.16,0.32,facing);
	EMISSION = COLOR.rgb*0.06*breath;
}
