shader_type spatial;

void vertex() {
	// Fixed isosceles shell; its circular opening shrinks from 5px to 1.5px.
	VERTEX.xy *= mix(1.0, 0.3, clamp(INSTANCE_CUSTOM.r, 0.0, 1.0) * UV.x);
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.65;
	METALLIC = 0.15;
}
