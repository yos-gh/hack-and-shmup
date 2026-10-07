// Presentation-only full-screen pass: neon bloom, impact fringe, vignette and
// faint terminal scanlines. Reads the finished frame; never feeds simulation.
// SCREEN_FX_LITE drops the bloom, which is what needs the mipmapped screen copy.
#ifdef SCREEN_FX_LITE
uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;
#else
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap, repeat_disable;
#endif
uniform float bloom_strength = 0.75;
uniform float impact = 0.0;
uniform vec4 tint : source_color = vec4(0.0);

vec3 glow_level(vec2 uv, float lod, vec2 texel, float floor_level) {
	vec2 o = texel * exp2(lod) * 0.5;
	vec3 sum = textureLod(screen_texture, uv + vec2(o.x, o.y), lod).rgb;
	sum += textureLod(screen_texture, uv + vec2(-o.x, o.y), lod).rgb;
	sum += textureLod(screen_texture, uv + vec2(o.x, -o.y), lod).rgb;
	sum += textureLod(screen_texture, uv + vec2(-o.x, -o.y), lod).rgb;
	sum *= 0.25;
	// The dim backdrop contributes nothing; only lit strokes spread light.
	float peak = max(sum.r, max(sum.g, sum.b));
	return sum * smoothstep(floor_level, floor_level * 2.4, peak);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 texel = SCREEN_PIXEL_SIZE;
	vec2 from_center = uv - 0.5;
	float fringe = (0.25 + impact * 5.0) * dot(from_center, from_center) * 4.0;
	vec2 shift = from_center * texel * fringe * 6.0;
	vec3 base = vec3(
		textureLod(screen_texture, uv + shift, 0.0).r,
		textureLod(screen_texture, uv, 0.0).g,
		textureLod(screen_texture, uv - shift, 0.0).b);
	vec3 color = base;
#ifndef SCREEN_FX_LITE
	vec3 glow = glow_level(uv, 1.0, texel, 0.24) * 0.35
		+ glow_level(uv, 2.5, texel, 0.14) * 0.6
		+ glow_level(uv, 4.0, texel, 0.10) * 0.5
		+ glow_level(uv, 5.5, texel, 0.08) * 0.4;
	color += glow * bloom_strength;
#endif
	// Hue-preserving shoulder: compress by the brightest channel so saturated
	// neon keeps its colour instead of washing toward white.
	float peak = max(color.r, max(color.g, color.b));
	float mapped = peak <= 0.8 ? peak : 0.8 + 0.2 * (1.0 - exp(-(peak - 0.8) / 0.2));
	color *= mapped / max(peak, 0.0001);
	float scan = 0.965 + 0.035 * sin(FRAGCOORD.y * 3.14159);
	color *= scan;
	float edge = smoothstep(0.95, 0.25, length(from_center * vec2(1.0, 1.15)));
	color *= mix(0.62, 1.0, edge);
	color = mix(color, tint.rgb, tint.a * (1.0 - edge * 0.75));
	COLOR = vec4(color, 1.0);
}
