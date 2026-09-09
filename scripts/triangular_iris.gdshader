shader_type spatial;

void vertex() {
	// Fixed outer triangle; its triangular opening contracts to 30%.
	VERTEX.xy *= mix(1.0, 0.3, clamp(INSTANCE_CUSTOM.r, 0.0, 1.0) * UV.x);
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.65;
	METALLIC = 0.15;
}
