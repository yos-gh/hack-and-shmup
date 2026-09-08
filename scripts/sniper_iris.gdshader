shader_type spatial;

// Torus local XZ radius. Keep the outside at 12px and close the actual opening
// from 5px to 1.5px, matching the shared 2D warning rather than hiding it below a dot.
void vertex() {
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
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.65;
	METALLIC = 0.15;
}
