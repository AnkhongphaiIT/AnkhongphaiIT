// shd_creature_wiggle — cá còn sống uốn mình theo trục thân (-Z là đầu); chớp trắng khi trúng đòn.
// wiggle = 0 khi xỉu. Màu lấy từ vertex color (bảng màu Art Bible).
shader_type spatial;
render_mode cull_back, diffuse_lambert;
uniform float wiggle : hint_range(0.0, 1.0) = 1.0;
uniform float speed = 9.0;
uniform float amount = 0.06;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
void vertex() {
	float tail = clamp(VERTEX.z * 2.0, 0.0, 1.0);   // phần đuôi (+Z) lắc mạnh hơn
	VERTEX.x += sin(TIME * speed + VERTEX.z * 6.0) * amount * wiggle * (0.3 + tail);
}
void fragment() {
	ALBEDO = mix(COLOR.rgb, vec3(1.0), flash);
	ROUGHNESS = 0.9;
}
