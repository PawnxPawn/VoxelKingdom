shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx, depth_draw_opaque;

uniform sampler2D atlas_texture : source_color, filter_nearest, repeat_enable;
uniform float tile_size = 0.25;
uniform float canvas_size = 128;

uniform float lava_brightness : hint_range(0.0, 5.0) = 1.8;
uniform float lava_emission_strength : hint_range(0.0, 10.0) = 4.0;
uniform float scroll_speed = 0.02;
uniform float glow_pulse_speed = 0.5;

varying vec2 tile_origin;

void vertex() {
	tile_origin = UV2;
}

void fragment() {
	float tile_percent = tile_size / 1.0;
	
	// Scrolling UVs
	vec2 scroll = vec2(TIME * scroll_speed, TIME * scroll_speed * 0.3);
	vec2 local_uv = fract(UV + scroll);
	
	float inset = 0.5 / canvas_size;
	local_uv = clamp(local_uv, inset, 1.0 - inset);
	
	vec2 atlas_uv = tile_origin + local_uv * tile_percent;
	vec4 tex_color = texture(atlas_texture, atlas_uv);
	
	// Base color
	vec3 lava_color = tex_color.rgb * lava_brightness;
	
	// Emission glow
	float pulse = 0.5 + 0.5 * sin(TIME * glow_pulse_speed);
	vec3 emission = lava_color * lava_emission_strength * pulse;
	
	ALBEDO = lava_color;
	EMISSION = emission;
	
	SPECULAR = 0.0;
	ROUGHNESS = 1.0;
	
	METALLIC = 0.1;
}