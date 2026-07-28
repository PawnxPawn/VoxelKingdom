shader_type sky;

uniform vec3 horizon_color_day : source_color = vec3(0.65, 0.79, 1.0);
uniform vec3 zenith_color_day : source_color = vec3(0.29, 0.51, 0.98);
uniform vec3 horizon_color_night : source_color = vec3(0.02, 0.02, 0.06);
uniform vec3 zenith_color_night : source_color = vec3(0.0, 0.0, 0.02);
uniform vec3 sunset_color : source_color = vec3(0.95, 0.45, 0.25);

uniform vec3 sun_color : source_color = vec3(3.0, 2.6, 1.8);
uniform float sun_angular_size : hint_range(0.5, 15.0) = 4.0;
uniform float sun_glare_size : hint_range(0.5, 8.0) = 4.0;


uniform float pixelation_steps : hint_range(4.0, 64.0) = 16.0;

uniform sampler2D cloud_noise : hint_default_black;
uniform float cloud_height : hint_range(0.0, 1.0) = 0.55;
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.45;
uniform float cloud_speed : hint_range(0.0, 1.0) = 0.02;
uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);

vec3 quantize(vec3 color, float steps) {
	return floor(color * steps + 0.5) / steps;
}

void sky() {
	float sun_h = clamp(LIGHT0_DIRECTION.y, -1.0, 1.0);
	float day_factor = smoothstep(-0.2, 0.3, sun_h);
	float sunset_factor = 1.0 - smoothstep(0.0, 0.35, abs(sun_h));

	vec3 horizon = mix(horizon_color_night, horizon_color_day, day_factor);
	vec3 zenith = mix(zenith_color_night, zenith_color_day, day_factor);
	horizon = mix(horizon, sunset_color, sunset_factor * day_factor);

	float sky_gradient = clamp(EYEDIR.y, 0.0, 1.0);
	sky_gradient = pow(sky_gradient, 0.55);
	vec3 sky_col = mix(horizon, zenith, sky_gradient);
	sky_col = quantize(sky_col, pixelation_steps);

	float sun_dot = dot(EYEDIR, LIGHT0_DIRECTION);
	float sun_disc = smoothstep(cos(radians(sun_angular_size)), cos(radians(sun_angular_size) * 0.9), sun_dot);

	float glare_size = sun_angular_size * sun_glare_size;
	float glare = smoothstep(cos(radians(glare_size)), cos(radians(sun_angular_size)), sun_dot);
	glare = pow(glare, 2.0);

	sky_col = mix(sky_col, sun_color, sun_disc * day_factor);
	sky_col += sun_color * glare * 0.6 * day_factor; 


	if (EYEDIR.y > 0.02) {
		vec2 cloud_uv = EYEDIR.xz / (EYEDIR.y + cloud_height);
		cloud_uv *= 0.15;
		cloud_uv += TIME * cloud_speed;
		float n = texture(cloud_noise, cloud_uv).r;
		float cloud_mask = step(1.0 - cloud_coverage, n);
		vec3 lit_cloud = cloud_color * mix(0.5, 1.0, day_factor);
		sky_col = mix(sky_col, lit_cloud, cloud_mask * smoothstep(0.0, 0.15, EYEDIR.y));
	}

	COLOR = sky_col;
}