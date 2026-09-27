// shd_fp_viewmodel — tay/cần góc nhìn thứ nhất: vẽ sau cùng, không bị cảnh vật che/xuyên (không kiểm độ sâu với cảnh).
shader_type spatial;
render_mode cull_back, depth_test_disabled, diffuse_lambert;
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.9;
}
