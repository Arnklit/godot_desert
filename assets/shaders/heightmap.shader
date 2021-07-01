shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_disabled,diffuse_burley,specular_schlick_ggx,world_vertex_coords;
uniform vec4 albedo : hint_color;
uniform sampler2D texture_albedo : hint_albedo;
uniform float specular;
uniform float roughness : hint_range(0,1) = 1.0;
uniform sampler2D texture_roughness : hint_white;
uniform vec4 roughness_texture_channel;
uniform sampler2D texture_normal : hint_normal;
uniform float normal_scale : hint_range(-16,16);
uniform sampler2D texture_ambient_occlusion : hint_white;
uniform vec4 ao_texture_channel;
uniform float ao_light_affect;

uniform float terrain_height_mult = 16.198;
uniform sampler2D terrain_height_map : hint_black;
uniform sampler2D terrain_normal_map : hint_normal;

varying vec3 uv1_triplanar_pos;
uniform float uv1_blend_sharpness = 1.0;
varying vec3 uv1_power_normal;
uniform vec3 uv1_scale;


void vertex() {
	float height = texture(terrain_height_map, UV).y;
	VERTEX.y += height * terrain_height_mult;
	
	vec3 terrain_normals = texture(terrain_normal_map, UV).rgb;
	terrain_normals = (terrain_normals - 0.5) * 2.0;
	NORMAL = terrain_normals;
	
	TANGENT = vec3(0.0,0.0,1.0) * abs(NORMAL.x);
	TANGENT+= vec3(1.0,0.0,0.0) * abs(NORMAL.y);
	TANGENT+= vec3(1.0,0.0,0.0) * abs(NORMAL.z);
	TANGENT = normalize(TANGENT);
	BINORMAL = vec3(0.0,1.0,0.0) * abs(NORMAL.x);
	BINORMAL+= vec3(0.0,0.0,-1.0) * abs(NORMAL.y);
	BINORMAL+= vec3(0.0,1.0,0.0) * abs(NORMAL.z);
	BINORMAL = normalize(BINORMAL);
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
	vec4 albedo_tex = triplanar_texture(texture_albedo,uv1_power_normal,uv1_triplanar_pos);
	ALBEDO = albedo.rgb * albedo_tex.rgb;
	float roughness_tex = dot(triplanar_texture(texture_roughness,uv1_power_normal,uv1_triplanar_pos),roughness_texture_channel);
	ROUGHNESS = roughness_tex * roughness;
	SPECULAR = specular;
	NORMALMAP = triplanar_texture(texture_normal,uv1_power_normal,uv1_triplanar_pos).rgb;
	NORMALMAP_DEPTH = normal_scale;
	AO = dot(triplanar_texture(texture_ambient_occlusion,uv1_power_normal,uv1_triplanar_pos),ao_texture_channel);
	AO_LIGHT_AFFECT = ao_light_affect;
}
