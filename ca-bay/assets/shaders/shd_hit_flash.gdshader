// shd_hit_flash — vật thể (boss, đạo cụ) chớp trắng ngắn khi trúng đòn; màu từ vertex color.
shader_type spatial;
render_mode cull_back, diffuse_lambert;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	ALBEDO = mix(COLOR.rgb * tint.rgb, vec3(1.0), flash);
	ROUGHNESS = 0.9;
}
