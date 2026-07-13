//-###########################################
// Water Shader
//-###########################################

shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx, depth_draw_opaque;

uniform sampler2D atlas_texture : source_color, filter_nearest, repeat_enable;
uniform float tile_size = 0.25;
uniform float canvas_size = 128;

uniform float water_alpha : hint_range(0.0, 1.0) = 0.65;
uniform float top_face_lower_amount = 0.1;
uniform float scroll_speed = 0.03;

varying vec2 tile_origin;


void vertex() {
    tile_origin = UV2;
    
    float is_top_face = step(0.9, NORMAL.y);
    VERTEX.y -= is_top_face * top_face_lower_amount;
}


void fragment() {
    float tile_percent = tile_size / 1.0;
    
    vec2 scroll = vec2(TIME * scroll_speed, TIME * scroll_speed * 0.6);
    vec2 local_uv = fract(UV + scroll);
    
    float inset = 0.5 / canvas_size;
    local_uv = clamp(local_uv, inset, 1.0 - inset);
    
    vec2 atlas_uv = tile_origin + local_uv * tile_percent;
    vec4 tex_color = texture(atlas_texture, atlas_uv);
    
    ALBEDO = tex_color.rgb * COLOR.rgb;
    ALPHA = water_alpha;
    ROUGHNESS = 0.05;
}
