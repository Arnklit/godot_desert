shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_back,diffuse_burley,specular_schlick_ggx,world_vertex_coords;

uniform vec4 albedo : hint_color;
uniform sampler2D texture_albedo : hint_albedo;
uniform float roughness : hint_range(0,1);
uniform sampler2D texture_roughness : hint_white;
uniform vec4 roughness_texture_channel;
uniform sampler2D texture_normal : hint_normal;
uniform float normal_scale : hint_range(-16,16);
uniform sampler2D texture_ambient_occlusion : hint_white;
uniform vec4 ao_texture_channel;
uniform float ao_light_affect;

uniform sampler2D gradient : hint_black;
uniform sampler2D gradient_offset : hint_black;
uniform float gradient_offset_tiling = 3.0;
uniform float gradient_size = 3.0;
uniform float gradient_hue_effect : hint_range(0.0, 1.0) = 0.1;
uniform float gradient_value_effect : hint_range(0.0, 1.0) = 0.25;


uniform sampler2D t_texture_albedo : hint_albedo;
uniform float t_roughness : hint_range(0,1) = 1.0;
uniform sampler2D t_texture_roughness : hint_white;
uniform sampler2D t_texture_normal : hint_normal;
uniform float t_normal_scale : hint_range(-16,16) = 1.0;
uniform sampler2D t_texture_ambient_occlusion : hint_white;

uniform float terrain_height_mult = 1.0;
uniform sampler2D terrain_height_map : hint_black;
uniform sampler2D terrain_normal_map : hint_normal;

varying vec3 uv1_triplanar_pos;
uniform float uv1_blend_sharpness = 1.0;
varying vec3 uv1_power_normal;
uniform vec3 uv1_scale;
uniform float blend_distance : hint_range(0.01,2.0) = 1.0;
uniform float blend_offset = 0.669;

varying float diff;
varying vec2 terrain_uv;

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

void vertex() {
	terrain_uv = (VERTEX.xz / 40.0) + 0.5;
	
	float height = texture(terrain_height_map, terrain_uv).y * terrain_height_mult;
	diff = height + blend_offset - VERTEX.y;
	diff = 1.0 - diff;
	diff /= blend_distance;
	diff -= 1.0;
	diff = clamp(diff, 0.0, 1.0);

	// Calculate triplanar tangents and binormals
	
	vec3 T_TANGENT = vec3(0.0,0.0,-1.0) * abs(NORMAL.x);
	T_TANGENT+= vec3(1.0,0.0,0.0) * abs(NORMAL.y);
	T_TANGENT+= vec3(1.0,0.0,0.0) * abs(NORMAL.z);
	T_TANGENT = normalize(T_TANGENT);
	vec3 T_BINORMAL = vec3(0.0,1.0,0.0) * abs(NORMAL.x);
	T_BINORMAL+= vec3(0.0,0.0,-1.0) * abs(NORMAL.y);
	T_BINORMAL+= vec3(0.0,1.0,0.0) * abs(NORMAL.z);
	T_BINORMAL = normalize(T_BINORMAL);
	
	// Reading in terrain normals from texture to blend with
	vec3 T_NORMAL = texture(terrain_normal_map, terrain_uv).rgb;
	T_NORMAL = (T_NORMAL - 0.5) * 2.0;
	
	NORMAL = mix(T_NORMAL, NORMAL, diff);
	TANGENT = mix(T_TANGENT, TANGENT, diff);
	BINORMAL = mix(T_BINORMAL, BINORMAL, diff);
	
	uv1_power_normal=pow(abs(NORMAL),vec3(uv1_blend_sharpness));
	uv1_power_normal/=dot(uv1_power_normal,vec3(1.0));
	uv1_triplanar_pos = VERTEX * uv1_scale;
	uv1_triplanar_pos *= vec3(1.0,-1.0, 1.0);
}

vec4 triplanar_texture(sampler2D p_sampler,vec3 p_weights,vec3 p_triplanar_pos) {
	vec4 samp=vec4(0.0);
	samp+= texture(p_sampler,p_triplanar_pos.xy) * p_weights.z;
	samp+= texture(p_sampler,p_triplanar_pos.xz) * p_weights.y;
	samp+= texture(p_sampler,p_triplanar_pos.zy * vec2(-1.0,1.0)) * p_weights.x;
	return samp;
}

void fragment() {
	float gradient_offset_value = texture(gradient_offset, terrain_uv * gradient_offset_tiling).r;
	vec4 gradient_value = texture(gradient, vec2((uv1_triplanar_pos.y / gradient_size) + gradient_offset_value * 0.25, 0.5));
	ALBEDO = gradient_value.rgb;
	vec2 base_uv = UV;
	vec4 albedo_tex = texture(texture_albedo,base_uv);
	vec4 t_albedo_tex = triplanar_texture(t_texture_albedo,uv1_power_normal,uv1_triplanar_pos);
	
	
	vec3 albedo_hsv = rgb_to_hsv(albedo_tex.rgb);
	albedo_hsv.x = fract(albedo_hsv.x + gradient_value.x * gradient_hue_effect - gradient_hue_effect / 2.0);
	albedo_hsv.z = clamp(albedo_hsv.z - gradient_value.z * gradient_value_effect, 0.0, 1.0);
	albedo_hsv = hsv_to_rgb(albedo_hsv);
	
	vec3 combined_albedo = mix(t_albedo_tex.rgb, albedo_hsv.rgb, diff) * albedo.rgb;
	
	ALBEDO = combined_albedo;
	float roughness_tex = dot(texture(texture_roughness,base_uv),roughness_texture_channel);
	float t_roughness_tex = dot(triplanar_texture(texture_roughness,uv1_power_normal,uv1_triplanar_pos),roughness_texture_channel);
	ROUGHNESS = mix(roughness_tex, t_roughness_tex, diff) * roughness;
	vec3 t_normal_map = triplanar_texture(t_texture_normal,uv1_power_normal,uv1_triplanar_pos).rgb;
	NORMALMAP = mix(t_normal_map, texture(texture_normal,base_uv).rgb, diff);
	NORMALMAP_DEPTH = normal_scale;
	float t_ao = dot(triplanar_texture(t_texture_ambient_occlusion,uv1_power_normal,uv1_triplanar_pos),ao_texture_channel);
	AO = mix(t_ao, dot(texture(texture_ambient_occlusion,base_uv),ao_texture_channel), diff);
	AO_LIGHT_AFFECT = ao_light_affect;
}
