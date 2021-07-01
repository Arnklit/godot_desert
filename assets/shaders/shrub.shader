shader_type spatial;

//render_mode depth_draw_alpha_prepass;

uniform vec4 albedo : hint_color;
uniform sampler2D texture_albedo : hint_albedo;
uniform float specular : hint_range(0,1);
uniform float alpha_scissor_threshold : hint_range(0,1);
uniform float roughness : hint_range(0,1);
uniform sampler2D texture_roughness : hint_white;
uniform sampler2D texture_occlusion : hint_white;
uniform vec4 occlusion_texture_channel;
uniform vec4 roughness_texture_channel;
uniform sampler2D texture_normal : hint_normal;
uniform float normal_scale : hint_range(-16,16);
uniform vec4 transmission : hint_color;
uniform sampler2D texture_transmission : hint_black;
varying vec3 rand_vals;
uniform float hue_randomness : hint_range(0.0, 1.0) = 1.0;
uniform float value_randomness : hint_range(0.0, 1.0) = 1.0;
uniform float ambient_wind = 1.0;

vec3 rand3(vec2 x) {
    return fract(cos(mod(vec3(dot(x, vec2(13.9898, 8.141)),
							  dot(x, vec2(3.4562, 17.398)),
                              dot(x, vec2(13.254, 5.867))), vec3(3.14))) * 43758.5453);
}

vec3 rgb_to_hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = c.g < c.b ? vec4(c.bg, K.wz) : vec4(c.gb, K.xy);
	vec4 q = c.r < p.x ? vec4(p.xyw, c.r) : vec4(c.r, p.yzx);

	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec3 get_ambient_wind_displacement(float amount, float hash, float t) {
	// TODO This is an initial basic implementation. It may be improved in the future, especially for strong wind.
	float amp = ambient_wind * (1.0 - amount);
	// Main displacement
	vec3 disp = amp * vec3(cos(t), 0.0, sin(t * 1.2));
	// Fine displacement
	float fine_disp_frequency = 2.0;
	disp += 0.2 * amp * vec3(cos(t * (fine_disp_frequency + hash)), 0.0, sin(t * (fine_disp_frequency + hash) * 1.2));
	return disp;
}

void vertex() {
	vec4 obj_pos = WORLD_MATRIX * vec4(0, 0, 0, 1);
	rand_vals = rand3(obj_pos.xz) - vec3(0.5);
	VERTEX += get_ambient_wind_displacement(COLOR.r, rand_vals.z, TIME);
	NORMAL = (WORLD_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
}

void fragment() {
	vec4 albedo_tex = texture(texture_albedo, UV);
	vec3 albedo_hsv = rgb_to_hsv(albedo_tex.rgb);
	albedo_hsv.x = fract(albedo_hsv.x + rand_vals.x * hue_randomness);
	albedo_hsv.y -= 0.3;
	albedo_hsv.z = clamp(albedo_hsv.z + rand_vals.y * value_randomness - 0.05, 0.0, 1.0);
	albedo_tex.rgb = hsv_to_rgb(albedo_hsv);
	ALBEDO = albedo.rgb * albedo_tex.rgb;
	//ALPHA = float( albedo.a * albedo_tex.a > alpha_scissor_threshold );
	if (albedo.a * albedo_tex.a < alpha_scissor_threshold)
		discard;
	//vec4 orm_tex = texture(texture_orm, UV);
	float occlusion_tex = dot(texture(texture_occlusion, UV), occlusion_texture_channel);
	AO = occlusion_tex;
	float roughness_tex = dot(texture(texture_roughness, UV), roughness_texture_channel);
	ROUGHNESS = roughness_tex * roughness;
	SPECULAR = specular;
	NORMALMAP = texture(texture_normal, UV).rgb;
	NORMALMAP_DEPTH = normal_scale;
	vec3 transmission_tex = texture(texture_transmission, UV).rgb;
	TRANSMISSION = (transmission.rgb * transmission_tex);
}
