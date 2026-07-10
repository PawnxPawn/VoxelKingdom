shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D atlas_texture : source_color, filter_nearest, repeat_enable;
uniform float tile_size = 0.25;
uniform float canvas_size = 128;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.5;

varying vec2 tile_origin;

void vertex() {
	tile_origin = UV2;
}

void fragment() {
	float tile_percent = tile_size / 1.0;
	vec2 local_uv = fract(UV);
	float inset = 0.5 / canvas_size;
	local_uv = clamp(local_uv, inset, 1.0 - inset);
	vec2 atlas_uv = tile_origin + local_uv * tile_percent;
	vec4 tex_color = texture(atlas_texture, atlas_uv);
	ALBEDO = tex_color.rgb * COLOR.rgb;
	ALPHA = tex_color.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
}