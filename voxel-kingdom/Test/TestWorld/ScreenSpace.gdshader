shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

uniform float heat_haze_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float in_lava : hint_range(0.0, 1.0) = 0.0;
uniform float cave_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float droplet_start_time = -10.0;

uniform float vignette_strength : hint_range(0.0, 1.0) = 0.25;
uniform float aberration_strength : hint_range(0.0, 0.01) = 0.0015;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// simple soft circular droplet mask
float droplet_mask(vec2 uv, vec2 center, float radius) {
	float d = distance(uv * vec2(1.77, 1.0), center * vec2(1.77, 1.0));
	return smoothstep(radius, radius * 0.3, d);
}

void fragment() {
	vec2 uv = SCREEN_UV;

	// ---- heat haze distortion (lava proximity) ----
	if (heat_haze_intensity > 0.001) {
		float wave = sin(uv.y * 40.0 + TIME * 3.0) * 0.0025 * heat_haze_intensity;
		wave += sin(uv.y * 13.0 - TIME * 1.7) * 0.0015 * heat_haze_intensity;
		uv.x += wave;
	}

	vec3 color = texture(screen_texture, uv).rgb;

	// ---- chromatic aberration (subtle, always on, stronger toward edges) ----
	vec2 center_offset = uv - vec2(0.5);
	float edge_dist = length(center_offset);
	vec2 aberr_dir = normalize(center_offset + 0.0001) * aberration_strength * edge_dist;

	float r = texture(screen_texture, uv - aberr_dir).r;
	float b = texture(screen_texture, uv + aberr_dir).b;
	color.r = mix(color.r, r, 0.6);
	color.b = mix(color.b, b, 0.6);

	// ---- base global vignette ----
	float vig = smoothstep(0.85, 0.35, edge_dist);
	color *= mix(1.0 - vignette_strength, 1.0, vig);

	// ---- cave darkness vignette (stronger, tighter falloff) ----
	float cave_vig = smoothstep(0.75, 0.2, edge_dist);
	float cave_darken = mix(1.0, cave_vig, cave_intensity * 0.6);
	color *= cave_darken;

	// ---- lava red vignette when actually standing in it ----
	if (in_lava > 0.001) {
		vec3 lava_tint = vec3(0.55, 0.12, 0.05);
		float lava_vig = smoothstep(0.85, 0.25, edge_dist);
		color = mix(color, lava_tint, (1.0 - lava_vig) * in_lava * 0.55);
	}

	// ---- surfacing droplets ----
	float elapsed = TIME - droplet_start_time;
	if (elapsed >= 0.0 && elapsed < 0.35) {
		float fade = 1.0 - smoothstep(0.0, 0.35, elapsed);
		float drop_total = 0.0;

		for (int i = 0; i < 10; i++) {
			float fi = float(i);
			vec2 seed = vec2(fi * 13.7, fi * 27.3);
			vec2 pos = vec2(hash21(seed), hash21(seed + 5.0));
			float radius = 0.02 + hash21(seed + 9.0) * 0.05;
			drop_total += droplet_mask(uv, pos, radius);
		}

		drop_total = clamp(drop_total, 0.0, 1.0) * fade;
		color = mix(color, vec3(0.75, 0.85, 0.95), drop_total * 0.5);
		color *= mix(1.0, 0.85, drop_total);
	}

	COLOR = vec4(color, 1.0);
}