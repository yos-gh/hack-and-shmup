// Continuous triangular interpolation: no time, camera coordinates or hard noise edges.
float glass_hash(vec2 p) {
	return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);
}

float glass_field(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = smoothstep(vec2(0.0),vec2(1.0),fract(p));
	return mix(mix(glass_hash(cell),glass_hash(cell+vec2(1.0,0.0)),f.x),
		mix(glass_hash(cell+vec2(0.0,1.0)),glass_hash(cell+vec2(1.0)),f.x),f.y);
}

float glass_facets(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float a = glass_hash(cell);
	float b = glass_hash(cell+vec2(1.0,0.0));
	float c = glass_hash(cell+vec2(0.0,1.0));
	float d = glass_hash(cell+vec2(1.0));
	if (glass_hash(cell+vec2(17.0,9.0))>0.5) {
		f.x = 1.0-f.x;
		float swap = a; a = b; b = swap;
		swap = c; c = d; d = swap;
	}
	float continuous = f.x > f.y ? a*(1.0-f.x)+b*(f.x-f.y)+d*f.y
		: a*(1.0-f.y)+c*(f.y-f.x)+d*f.x;
	float edge = min(min(min(f.x,f.y),min(1.0-f.x,1.0-f.y)),abs(f.x-f.y)*0.7071);
	float interior = smoothstep(0.0,max(length(fwidth(p)),0.0001),edge);
	float face = f.x > f.y ? (a+b+d)/3.0 : (a+c+d)/3.0;
	return mix(continuous,face,interior*0.85);
}
