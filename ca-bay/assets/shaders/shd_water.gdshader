// shd_water — mặt nước sông/biển low-poly: sóng nhẹ theo thời gian, màu theo độ sâu (COLOR.r), bọt ở mép nông.
shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
uniform vec4 shallow : source_color = vec4(0.34, 0.71, 0.65, 1.0);
uniform vec4 deep : source_color = vec4(0.16, 0.5, 0.53, 1.0);
uniform vec4 foam : source_color = vec4(0.96, 0.95, 0.87, 1.0);
varying float v_depth;
void vertex() {
	float t = TIME * 0.8;
	VERTEX.y += 0.05 * sin(VERTEX.x * 0.35 + t) + 0.04 * cos(VERTEX.z * 0.42 + t * 1.3);
	v_depth = COLOR.r;
}
void fragment() {
	float f = smoothstep(0.08, 0.0, v_depth);
	vec3 c = mix(shallow.rgb, deep.rgb, clamp(v_depth, 0.0, 1.0));
	ALBEDO = mix(c, foam.rgb, f * 0.55);
	ROUGHNESS = 0.25;
	SPECULAR = 0.4;
}
