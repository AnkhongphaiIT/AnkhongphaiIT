# 06 — QUY CHUẨN TÀI NGUYÊN V2 VÀ DANH MỤC THẬT

> Bộ này là đặc tả sản xuất, **không có media/runtime assets**. Có 287 ID: P0: 177, P1: 109, P2: 1. Tất cả đang `planned`, giấy phép `tbd`; chưa có checksum, file hoặc thông số đo thực tế. Giữ 189 ID gốc để tương thích và bổ sung phạm vi v2. Font trước đây chỉ ghi dự kiến OFL nay cũng trở về tbd cho tới khi có bằng chứng của file thực.
>
> Registry `data/contracts/asset_registry.json` là nguồn ID, loại, đường dẫn, trạng thái. Bảng §7 được sinh trực tiếp từ registry; hai bên phải trùng bộ ID. Đường dẫn `res://` là đường dẫn đích trong dự án Godot sẽ tạo. Công cụ asset_check, icon_baker, mesh_merge và các cảnh kiểm nêu dưới đây là việc Claude cần xây dựng, chưa được cung cấp trong ZIP. Ưu tiên P0 là nền tảng/slice, P1 là mở rộng bắt buộc của bản hoàn chỉnh nếu gameplay sử dụng; P2 giữ tương thích ngoài phạm vi. P1 không có nghĩa được bỏ khỏi mục tiêu 3 đảo/15 loài/3 boss.

## 1. Nguyên tắc chung

1. **Mã tài nguyên = tên file** (không đuôi), chữ thường ASCII, `snake_case`, bắt đầu bằng tiền tố loại:

| Tiền tố | Loại | Định dạng | Thư mục (`res://`) |
|---|---|---|---|
| `mdl_` | Mô hình 3D | `.glb` + cảnh bọc `.tscn` | `assets/models/<nhóm>/` |
| `mat_` | Vật liệu | `.tres` | `assets/materials/` |
| `shd_` | Shader | `.gdshader` | `assets/shaders/` |
| `tex_` | Texture | `.png` | `assets/textures/` |
| `env_` | Môi trường/bầu trời | `.tres` | `assets/env/` |
| `vfx_` | Hiệu ứng | `.tscn` | `assets/vfx/` |
| `anm_` | Clip animation | Trong thư viện `.tres` | `assets/anim/` |
| `ui_` | Cảnh/theme UI | `.tscn` / `.tres` | `ui/…` hoặc `assets/ui/` |
| `ico_` | Icon | `.png` 256×256 | `assets/icons/` |
| `fnt_` | Phông chữ | `.tres` (FontVariation trỏ tới các file `.ttf` của cùng họ phông, đặt trong `assets/fonts/<họ>/`) | `assets/fonts/` |
| `sfx_` / `mus_` / `amb_` / `vo_` | Âm thanh ngắn / nhạc / âm nền / giọng | `.wav` / `.ogg`; có biến thể thì file là `<mã>_01`, `<mã>_02`… và registry ghi đường dẫn mẫu `<mã>_{nn}.wav` + `variants` | `assets/audio/<loại>/` |

2. **Code không bao giờ ghi đường dẫn tài nguyên trực tiếp** — code hỏi `AssetRegistry.path(id)` (xem `07` §4). Nhờ vậy thay tài nguyên tạm bằng tài nguyên thật không cần sửa code.
3. **Vòng đời trạng thái** (trường `status` trong registry): `planned` → `placeholder` → `in_review` → `approved` → (`deprecated`). Claude phụ trách tích hợp tự duyệt trong quyền đã được giao sau khi kiểm kỹ thuật, nguồn/quyền và hình/nghe thực tế. Không yêu cầu chủ dự án duyệt mọi batch; chỉ hỏi khi có lựa chọn không thể tự giải quyết theo phong cách đã chốt, đồng thời tiếp tục phần độc lập.
4. **Tài nguyên tạm (placeholder) phải dùng đúng ID, đúng socket, đúng kích thước** như bản thật để code chạy được từ ngày đầu.
5. **Nguồn tài nguyên:** tự tạo (bằng code/Blender), nguồn CC0/CC-BY đã kiểm đúng file và lưu bằng chứng (CC-BY ghi công). Ghi `license`, `source_url`, `author` trong registry. **Cấm** trích xuất tài nguyên từ How to Fish hoặc game khác, cấm đồ lại ảnh chụp màn hình.

## 2. Quy chuẩn 3D

### 2.1. Đơn vị, trục, hướng

| Mục | Quy định |
|---|---|
| Đơn vị | 1 đơn vị = **1 mét** |
| Trục lên | **+Y** (glTF/Godot). Trong Blender làm việc với Z-up, xuất glTF bật "+Y Up" |
| Mặt trước tài nguyên | **+Z** (quy ước glTF: mặt trước hướng +Z). Trong Blender: mặt trước nhìn về **−Y** |
| Trong code Godot | Hướng "đi tới" của node là −Z; khi quay sinh vật về mục tiêu dùng `look_at(target, Vector3.UP, true)` (tham số `use_model_front`) để mặt trước +Z nhìn vào mục tiêu |
| Transform khi xuất | Đã "apply" hết: vị trí 0, xoay 0, tỷ lệ 1 |
| Vật cầm tay (cần, chổi, dép…) | Gốc tại `socket_grip`; **đầu làm việc** (ngọn cần, bó chổi, mũi dép) hướng **+Z** như mọi tài nguyên |
| **Ngoại lệ — tay FP (`mdl_fp_hands`)** | Dựng trong **không gian camera**: gốc = điểm mắt, nhìn theo **−Z**, phải = +X, lên = +Y (giống Camera3D của Godot). `socket_hand_r`/`socket_hand_l` được xoay sao cho trục +Z của socket chỉ theo hướng nhìn của camera → vật cầm tay gắn vào socket tự hướng đúng, không cần xoay thêm |

### 2.2. Pivot

| Nhóm | Pivot đặt ở |
|---|---|
| Sinh vật, boss, vật phẩm rời | Tâm khối bao thân (gần trọng tâm) — để vật lý rơi/xoay tự nhiên |
| NPC, đồ đứng, công trình | Tâm mặt tiếp đất (chân) |
| Công cụ cầm tay, cần câu | Điểm cầm (trùng `socket_grip`) |
| Mô-đun môi trường | Tâm đáy, bám lưới 0,5 m |

### 2.3. Kích thước
- Sinh vật: chiều dài mô hình = `length_m` trong `creatures.json` **±10%**.
- NPC: 1,5–1,7 m; người chơi (thân của mình ẩn khỏi camera FP, đồng đội có thân đầy đủ) là capsule cao 1,8 m, mắt ở 1,6 m (thông số ở `balance.json` → `player`).
- Công cụ/vật phẩm: kích thước thật; riêng dép và phao được phóng to để đọc được — **số trong bảng §7 là kích thước cuối cùng sau khi phóng** (phao Ø 0,16 m; dép dài 0,38 m), `asset_check` kiểm theo số này.

### 2.4. Màu, vật liệu, texture
- **Màu nằm ở vertex color** (thuộc tính màu của đỉnh, kênh `COLOR_0` khi xuất glTF), mã màu lấy từ `05` §3; tô phẳng (mỗi mặt một màu, pháp tuyến tách cạnh).
- Mỗi mô hình tối đa **2 vật liệu**: `mat_palette_lit` (mặc định) và `mat_palette_unshaded` (phần tự phát sáng: than hồng, tín hiệu UI).
- Cảnh bọc `.tscn` gán vật liệu **theo từng MeshInstance3D**: mọi lưới dùng `mat_palette_lit`, trừ lưới có tên kết thúc `_Unshaded` dùng `mat_palette_unshaded` → không phụ thuộc vật liệu trong file `.glb`. Phần tự phát sáng (than hồng và phần tín hiệu cần thiết) **phải là lưới riêng** tên `…_Unshaded`; `mesh_merge.gd` chỉ gộp các lưới cùng nhóm vật liệu.
- Không texture chi tiết. `tex_palette_main.png` (64×64, 8×8 ô màu) chỉ dùng làm bảng tra cho họa sĩ hoặc cho chế độ UV-palette (tùy chọn, không bắt buộc ở bản đầu).

### 2.5. Ngân sách tam giác (tạm thời)
Ngân sách cho **từng tài nguyên** ở bảng dưới; ngân sách **cả khung hình** (tam giác, draw call theo tầng thiết bị) chỉ nằm ở `07_TECHNICAL_DESIGN.md`.

| Nhóm | Tối đa (tam giác) |
|---|---|
| Sinh vật nhỏ (tép, cua, cá rô) | 500 |
| Sinh vật vừa (cá trê) | 900 |
| Boss | 3.000 |
| NPC | 1.800 |
| Tay góc nhìn thứ nhất (hai tay) | 1.500 |
| Cần câu / công cụ / phao | 400 / 500 / 150 |
| Vật phẩm nhỏ | 300 |
| Đạo cụ nhỏ / vừa | 400 / 1.200 |
| Sạp hàng, bến, đò | 3.000 mỗi cái |
| Địa hình cù lao slice (toàn bộ) | 12.000 |

### 2.6. LOD, UV
- Không làm LOD thủ công cho sinh vật/đạo cụ nhỏ. Địa hình và công trình dùng *visibility range* (ẩn/hiện theo khoảng cách) của Godot. Có thể để Godot tự sinh LOD khi import.
- Không cần UV khi dùng vertex color. Không dùng lightmap ở MVP.

### 2.7. Định dạng, xuất, cảnh bọc
- Bản cuối: **glTF 2.0 nhị phân `.glb`**, chỉ gồm mesh (+ node con cho phần chuyển động rời). Không camera, không đèn.
- Mỗi mô hình có **cảnh bọc** `res://assets/models/<nhóm>/<id>.tscn` chứa: instance `.glb` (hoặc lưới tạm), các `Marker3D` socket (§2.9), collider (§2.8), `material_override`. **Code chỉ tham chiếu cảnh bọc.**
- Cách tạo được chấp nhận: (a) Blender + script Python sinh mô hình (lưu script ở `art_src/models/<id>/build_<id>.py` để tái tạo); (b) **"mô hình bằng code"**: cảnh Godot ghép từ khối cơ bản (BoxMesh, CylinderMesh, SphereMesh, PrismMesh) — dùng cho placeholder và có thể dùng làm bản cuối nếu đạt ngân sách draw call (gộp lưới bằng công cụ `tools/mesh_merge.gd` trước khi `approved`).
- File nguồn (`.blend`, script) để ở `art_src/` và **không được đưa vào bản build** (xem `07_TECHNICAL_DESIGN.md`).

### 2.8. Collider

| Nhóm | Collider | Tên node |
|---|---|---|
| Sinh vật/boss | 1 `CollisionShape3D` hình capsule hoặc hộp ôm thân; vùng đầu là `Area3D` + `SphereShape3D` tại `socket_head`, đặt ở lớp `hitzone` (13), `monitorable` bật, `monitoring` tắt. Cách phân định trúng đầu/thân: `07_TECHNICAL_DESIGN.md` | `Col`, `Hitzone_Head` |
| Vật phẩm | 1 hình cơ bản | `Col` |
| Đạo cụ, công trình | Hình cơ bản/lồi (convex); không dùng lưới lõm | `Col_*` |
| Địa hình | Lưới lõm (trimesh) được phép | `Col_Terrain` |

Lớp va chạm (collision layer) theo `data/contracts/collision_layers.json`.

### 2.9. Socket (điểm gắn — là **hợp đồng** với code)

| Nhóm | Socket bắt buộc |
|---|---|
| Sinh vật | `socket_mouth` (móc câu), `socket_head` (tâm vùng đầu), `socket_carry` (điểm cầm), `socket_fx_top` (chỗ hiện sao KO), `socket_acc_body` (gắn phụ kiện biến thể) |
| Boss | Như sinh vật + `socket_spit` (gốc đạn), `socket_tail` (tâm cú quật) |
| Cần câu | `socket_grip`, `socket_tip`, `socket_reel` |
| Công cụ | `socket_grip`, `socket_hit` (tâm vùng đánh / điểm nhả khi ném) |
| NPC | `socket_head`, `socket_mouth`, `socket_hand_r`, `socket_speech` (bóng thoại) |
| Sạp bán | `socket_sell_basket` (tâm thúng nhận hàng), `socket_display_01…n` (chỗ bày hàng) |
| Tay FP | `socket_hand_r`, `socket_hand_l` |
| Điểm boss | `socket_boss_spawn` |

### 2.10. Rig và animation
- **MVP không dùng khung xương (skinning).** NPC, boss, tay FP dùng **cấu trúc bộ phận cứng**: node con đặt tên `Part_Head`, `Part_Body`, `Part_ArmL`, `Part_ArmR`, `Part_Mouth`, `Part_Tail`…; animation là track biến đổi (vị trí/xoay/tỷ lệ) trong `AnimationPlayer`.
- Clip lưu trong thư viện `AnimationLibrary`: `assets/anim/anm_lib_fp.tres`, `anm_lib_npc_basic.tres`, `anm_lib_boss_ca_loc.tres`. Tên clip = mã `anm_…`.
- **Sự kiện trong animation** (method track gọi `_on_anim_event(name)`) chỉ dùng tên trong danh sách `08_SHARED_CONTRACTS.md` (`impact`, `release`, `spawn_projectile`, `footstep`, `mouth_open`, `mouth_close`).
- Sinh vật không có clip: chuyển động bơi/giãy bằng shader `shd_creature_wiggle` (tham số `wiggle_amp`, `wiggle_speed`, `wiggle_axis`) + vật lý. **Báo trước đòn của sinh vật thường** làm bằng code (phình 10% + rung trong `attack.telegraph_s`) kèm `vfx_attack_warn` và `sfx_creature_warn` — không cần clip.

### 2.11. Quy tắc import trong Godot
- `.glb`: import dạng Scene; tắt "Light Baking"; tắt "Ensure Tangents"; giữ vertex color.
- Âm thanh: xem §5; ảnh UI: xem §3.
- Mọi thay đổi thiết lập import ghi trong `.import` (được commit cùng file).

### 2.12. Kiểm tra tự động trong engine
`tools/asset_check.gd` (chạy trong editor hoặc headless) kiểm tra từng cảnh bọc: số tam giác ≤ ngân sách nhóm; kích thước khối bao so với `length_m` (sinh vật); đủ socket theo nhóm; chỉ dùng vật liệu cho phép; tỷ lệ 1; tên node collider. Xuất báo cáo `build/reports/asset_check.md`.

## 3. Quy chuẩn 2D và UI

| Mục | Quy định |
|---|---|
| Độ phân giải tham chiếu | **1280×720**, chế độ co giãn `canvas_items`, tỷ lệ `expand`; chỉ chạy **ngang** |
| Kích thước phải thử | 800×450, 1280×720, 1920×1080 và màn desktop 21:9; không kiểm mobile như yêu cầu v2 |
| Panel, nút | Ưu tiên `StyleBoxFlat` trong theme `ui_theme_main` (vẽ bằng engine, không cần ảnh); nếu dùng ảnh: PNG RGBA, 9-slice với lề ghi rõ trong brief |
| Icon | **Chỉ PNG** RGBA **256×256**, nền trong suốt, lề 8 px; hiển thị 64–96 px; icon vật phẩm render bằng `tools/icon_baker` (camera phối cảnh FOV 30°, xoay 35°, cúi −20°, đèn cố định); icon giao diện (tiền, máu) được phép vẽ vector nhưng file nguồn SVG để ở `art_src/`, bản đưa vào game là PNG |
| Vùng an toàn | HUD neo trong hình chữ nhật `DisplayServer.get_display_safe_area()` |
| Trạng thái | 5 trạng thái (bình thường, rê, nhấn, vô hiệu, focus) — `05` §10.2 |
| Chữ | **Không có chữ trong ảnh.** Mọi nhãn là khóa dịch (`data/loc/strings.csv`) |
| Phông | `fnt_be_vietnam_pro` (Medium + Bold). Chuỗi thử dấu: `Cá lóc trùm đã bị hạ! Ắ ẳ ẵ ặ Ỗ ổ ộ ờ ợ ữ ự Đđ` — mọi ký tự phải hiển thị đúng ở 14–40 px |
| Import ảnh UI | Tắt mipmap, lọc tuyến tính; icon bật "Fix Alpha Border" |

## 4. Quy chuẩn VFX
- Mỗi hiệu ứng là cảnh `assets/vfx/<id>.tscn`, gốc `Node3D` có hàm `play(params: Dictionary)` và tín hiệu `finished`; tự giải phóng khi xong.
- Dùng `CPUParticles3D` (ổn định trên renderer tương thích/web — xác nhận ở kiểm thử renderer web); ≤ 64 hạt mỗi hiệu ứng ở slice; tổng hạt đồng thời ≤ 300.
- Chữ nổi (`vfx_trick_text`): `Label3D` billboard, có viền, phông Bold, nội dung qua khóa dịch.
- Dây câu (`vfx_fishing_line`): cách vẽ chốt ở thử nghiệm dây câu trong 10_VALIDATION.md; màu `#F4F1DE` 90% đục, trông như 2–3 px ở 1280×720.
- Hiệu ứng được gọi qua `data/contracts/vfx_event_map.json` (sự kiện → hiệu ứng → điểm gắn), không gọi thẳng từ gameplay.


## 5. Chuẩn âm thanh và voice

| Loại | Đầu ra dùng trong game | Nghiệm thu |
|---|---|---|
| SFX | WAV PCM16 mono 44.1 kHz, thông thường ≤2 s; loop được ghi rõ | Peak ≤−3 dBFS, không clipping/click, fade 5 ms khi phù hợp; âm cắn khác âm UI |
| Nhạc | OGG Vorbis stereo 44.1 kHz | Giai điệu gốc hoặc quyền rõ; khoảng −18 LUFS, loop liền, lưu điểm loop |
| Ambient | OGG stereo 44.1 kHz, loop ≥30 s | Khoảng −26 LUFS; không lấn thoại/cắn câu; đúng đảo |
| Gibberish | WAV mono PCM16 44.1 kHz, 8–12 âm tiết/giọng | Không bị dùng như bằng chứng hoàn thành thoại Việt/Anh |
| Thoại Việt/Anh | Một WAV mono PCM16 44.1 kHz mỗi line_id và locale | Lời khớp phụ đề, phát/skip đúng, quyền voice rõ; khoảng −18 LUFS, peak ≤−3 dBFS |
| Chỉ mục pack thoại | JSON line_id → đường dẫn/asset_id và checksum của từng file | Chỉ là bảng tra; registry planned pack không chứng minh có dòng audio |

Mức loudness là mục tiêu mix để đo/nghe và điều chỉnh, không cam kết trước khi có file. Nhạc/ambient/voice có thể dài hơn giới hạn SFX. Lưu bản WAV nguồn khi chuyển sang OGG. Mỗi biến thể `{nn}` có chỉ số, hash và nguồn riêng; không tự tạo đường dẫn nếu thiếu biến thể.

**Sản xuất 0 đồng:** xuất audio offline bằng code nguyên bản; ghi âm có sự đồng ý hoặc local TTS có giấy phép phần mềm và model/giọng được kiểm riêng. Không coi công cụ miễn phí là bảo đảm quyền thương mại. Không bắt buộc cài công cụ lớn chỉ để có placeholder; không gọi API trả phí. Không phụ thuộc AudioStreamGenerator runtime cho bản web khi chưa xác minh. ChatGPT relay cung cấp concept/brief/script khi phiên không xuất media.

Các bus: Master, Music, SFX, UI, Ambience, Voice. Kiểm 4 người chơi cùng lúc không vỡ tiếng. Map audio dùng các sự kiện nội bộ đã xác nhận; đảo chọn nhạc theo dữ liệu island, ambient theo island_id. `restore_island` phải tra đảo hiện tại, asset_id đảo 1 chỉ là fallback. Loop quay cần, căng dây, bước thoại và nướng dùng controller vòng đời, phải dừng khi kết thúc hoặc mất kết nối.

`dialogue.line_started` được DialogueController resolve qua line_id + locale + voice_asset_id hoặc pack JSON; không gắn cố định toàn bộ câu vào một file trong map. Nếu thiếu dòng, bản phát triển dùng phụ đề/gibberish, ghi lỗi coverage. Bản cuối vẫn phải hoàn tất audio cả vi/en. Sự kiện đói/lootbox chỉ phát cho người chơi nhận; join/left chỉ trong phòng hiện tại; không phát lặp khi replay snapshot. Lootbox VFX/SFX chỉ chạy sau giao dịch máy chủ đã commit và khử trùng transaction_id.

## 6. Nguồn, quyền và tương thích

`handoff/source_manifest.json` giữ ID giống registry, tất cả chưa có file. Bổ sung license/source/author/tool/model/version/điều khoản/ngày kiểm/hash theo `14_AI_ASSET_HANDOFF.md`. Giấy phép tbd chặn phát hành file tương ứng, không chặn viết gameplay bằng tài nguyên tự tạo. `self_made` chỉ dùng khi đã thực sự tự tạo nguyên bản; `verified_custom` cần điều khoản lưu được và kiểm phạm vi sử dụng. Không gán CC0 cho đầu ra ChatGPT hoặc TTS theo mặc định.

| ID kỹ thuật giữ lại | Nghĩa hiển thị/sản xuất v2 |
|---|---|
| mdl_item_milk_tea, ico_bait_milk_tea | Mồi cá tạp; hình hộp mồi, không đồ uống |
| mdl_proj_boba_pearl | Khối nước bắn; không hạt trân châu |
| mdl_acc_boba_pearls | Mảng vảy Ánh Bạc tự nhiên, không các viên gắn quanh thân |
| vfx_boba_sparkle | Phản chiếu bạc/tín hiệu UI phát hiện hiếm; không phép |
| ui_touch_controls | Dự phòng tương thích P2; desktop v2 không cần triển khai |

Sáu skin cosmetic trong gameplay tái dùng mô hình/cảnh gốc với phối màu đã định; không cần tạo sáu bản model giống nhau. Sáu NPC có thể dùng hai bộ mesh gốc theo dữ liệu nhưng phải phân biệt qua phối màu, phụ kiện, tên và giọng. Bộ gốc chứa một số ID dự phòng; chỉ build dependency thực sự dùng, không tự mở rộng gameplay vì thấy ID trong registry.

## 7. Danh mục sinh từ registry

| Loại | Số ID |
|---|---:|
| ambience | 3 |
| anim_clip | 60 |
| anim_library | 7 |
| environment | 3 |
| font | 1 |
| icon | 32 |
| material | 2 |
| model | 54 |
| music | 4 |
| sfx | 59 |
| shader | 4 |
| texture | 1 |
| ui | 24 |
| vfx | 19 |
| voice | 14 |
| **Tổng** | **287** |

### model

| ID | Ưu tiên | Đường dẫn đích | Đặc tả | Nghiệm thu |
|---|---|---|---|---|
| `mdl_env_isl01_terrain` | P0 | `res://assets/models/env/mdl_env_isl01_terrain.tscn` | Mặt đất cù lao 1 (bãi bùn, cỏ, bờ); ~60×60 m vùng chơi + viền; ≤ 12.000 tam giác; bờ thoải ở bến và bãi câu | AC-MDL |
| `mdl_env_pier` | P0 | `res://assets/models/env/mdl_env_pier.tscn` | Bến đò  điểm câu chính; Sàn gỗ 3×12 m, cao 0,8 m trên nước, cọc tre; ≤ 3.000 | AC-MDL |
| `mdl_env_vendor_stall` | P0 | `res://assets/models/env/mdl_env_vendor_stall.tscn` | Sạp Cô Ba (bán/mua); Sạp tre mái lá dừa nước; thúng tre; kệ bày 4 món; ≤ 3.000 | AC-MDL |
| `mdl_env_ferry_boat` | P0 | `res://assets/models/env/mdl_env_ferry_boat.tscn` | Đò Ông Tư (đạo cụ tĩnh ở slice); Đò gỗ 5 m, mái che | AC-MDL |
| `mdl_env_palm_coconut` | P0 | `res://assets/models/env/mdl_env_palm_coconut.tscn` | Cây dừa; Cao 6–8 m, thân đốt, 6–8 tàu lá; ≤ 800 | AC-MDL |
| `mdl_env_nipa_palm` | P0 | `res://assets/models/env/mdl_env_nipa_palm.tscn` | Bụi dừa nước ven bờ; Cao 2–3 m; ≤ 600 | AC-MDL |
| `mdl_env_rock_set` | P0 | `res://assets/models/env/mdl_env_rock_set.tscn` | Đá (3 biến thể trong 1 file); 0,5–2 m; ≤ 300 mỗi cục | AC-MDL |
| `mdl_env_boss_spot_post` | P0 | `res://assets/models/env/mdl_env_boss_spot_post.tscn` | Cọc tre đánh dấu điểm gọi boss; Cọc 2 m + dải vải đỏ; ≤ 200 | AC-MDL |
| `mdl_env_sign_board` | P0 | `res://assets/models/env/mdl_env_sign_board.tscn` | Bảng gỗ hướng dẫn; 1×0,7 m; chữ bằng Label3D (khóa dịch) | AC-MDL |
| `mdl_chr_npc_co_ba` | P0 | `res://assets/models/chr/mdl_chr_npc_co_ba.tscn` | NPC bán cá; 1,55 m; áo bà ba tím nhạt, khăn rằn, tạp dề; bộ phận cứng; ≤ 1.800 | AC-MDL |
| `mdl_chr_npc_ong_tu` | P0 | `res://assets/models/chr/mdl_chr_npc_ong_tu.tscn` | NPC lái đò, giao nhiệm vụ; 1,65 m; nón lá, râu bạc; ≤ 1.800 | AC-MDL |
| `mdl_fp_hands` | P0 | `res://assets/models/fp/mdl_fp_hands.tscn` | Hai tay góc nhìn thứ nhất; Găng hoạt hình 4 ngón, cổ tay áo; ≤ 1.500 | AC-MDL |
| `mdl_tool_rod_bamboo` | P0 | `res://assets/models/tools/mdl_tool_rod_bamboo.tscn` | Cần tre (cần khởi đầu); Dài 2,2 m, 5 đốt, guồng gỗ; ≤ 400 | AC-MDL |
| `mdl_tool_bobber` | P0 | `res://assets/models/tools/mdl_tool_bobber.tscn` | Phao; Ø 0,16 m (kích thước cuối, đã phóng to), đỏ–trắng; ≤ 150 | AC-MDL |
| `mdl_tool_slipper` | P0 | `res://assets/models/tools/mdl_tool_slipper.tscn` | Dép tổ ong; Dài 0,38 m (kích thước cuối, đã phóng to), vân tổ ong nổi; ≤ 500 | AC-MDL |
| `mdl_tool_broom` | P0 | `res://assets/models/tools/mdl_tool_broom.tscn` | Chổi chà; Dài 1,1 m, bó que + dây buộc; ≤ 500 | AC-MDL |
| `mdl_cre_tep` | P0 | `res://assets/models/creatures/mdl_cre_tep.tscn` | Tép; length_m theo data; cong chữ C, râu dài; ≤ 500 | AC-MDL |
| `mdl_cre_ca_ro` | P0 | `res://assets/models/creatures/mdl_cre_ca_ro.tscn` | Cá rô; Thân bầu, vây lưng gai; ≤ 500 | AC-MDL |
| `mdl_cre_ca_tre` | P0 | `res://assets/models/creatures/mdl_cre_ca_tre.tscn` | Cá trê; Dẹt dài, 4 râu; ≤ 900 | AC-MDL |
| `mdl_cre_cua_dong` | P0 | `res://assets/models/creatures/mdl_cre_cua_dong.tscn` | Cua đồng; Mai vuông, 2 càng to; ≤ 500 | AC-MDL |
| `mdl_cre_boss_ca_loc` | P0 | `res://assets/models/creatures/mdl_cre_boss_ca_loc.tscn` | Cá Lóc đầu đàn; 3.000 tam giác tối đa, vảy tự nhiên; không bụng trà sữa hay hạt trên má. | AC-MDL |
| `mdl_item_milk_tea` | P0 | `res://assets/models/items/mdl_item_milk_tea.tscn` | ID kỹ thuật cũ: Mồi cá tạp, hộp nhỏ đựng mồi; không cốc trà sữa. | AC-MDL |
| `mdl_item_golden_scale` | P0 | `res://assets/models/items/mdl_item_golden_scale.tscn` | Vảy Lóc Vàng (vật phẩm nhiệm vụ); Vảy 0,3 m vàng phát sáng nhẹ; ≤ 300 | AC-MDL |
| `mdl_item_worm_jar` | P0 | `res://assets/models/items/mdl_item_worm_jar.tscn` | Hũ trùn (hàng bày bán); Hũ 0,2 m; ≤ 300 | AC-MDL |
| `mdl_proj_boba_pearl` | P0 | `res://assets/models/proj/mdl_proj_boba_pearl.tscn` | ID kỹ thuật cũ: khối nước bắn low-poly; không hạt trân châu. | AC-MDL |
| `mdl_item_backpack_display` | P0 | `res://assets/models/items/mdl_item_backpack_display.tscn` | Hàng bày cho nâng cấp túi (túi vải); Túi vải 0,4 m; ≤ 300 | AC-MDL |
| `mdl_item_reel_display` | P0 | `res://assets/models/items/mdl_item_reel_display.tscn` | Hàng bày cho nâng cấp guồng; Guồng câu 0,2 m; ≤ 300 | AC-MDL |
| `mdl_env_grill` | P1 | `res://assets/models/env/mdl_env_grill.tscn` | Vỉ nướng; Than hồng dùng mat_palette_unshaded | AC-MDL |
| `mdl_cre_egret` | P1 | `res://assets/models/creatures/mdl_cre_egret.tscn` | Cò trộm (cò trắng); Cao 0,9 m, chân dài, mỏ vàng; đi rón rén | AC-MDL |
| `mdl_acc_boba_pearls` | P1 | `res://assets/models/acc/mdl_acc_boba_pearls.tscn` | ID kỹ thuật cũ: mảng vảy Ánh Bạc bám thân, không hình hạt/đột biến; dùng chung socket_acc_body. | AC-MDL |
| `mdl_tool_slingshot` | P1 | `res://assets/models/tools/mdl_tool_slingshot.tscn` | Ná thun | AC-MDL |
| `mdl_tool_swatter` | P1 | `res://assets/models/tools/mdl_tool_swatter.tscn` | Vợt muỗi điện; Phần lưới dùng mat_palette_unshaded khi phóng điện | AC-MDL |
| `mdl_tool_coconut_bomb` | P1 | `res://assets/models/tools/mdl_tool_coconut_bomb.tscn` | Dụng cụ hài bằng vỏ dừa; hiệu ứng nước/bụi/confetti cơ học, không phép thuật. | AC-MDL |
| `mdl_tool_rod_carbon` | P1 | `res://assets/models/tools/mdl_tool_rod_carbon.tscn` | Cần "xịn" | AC-MDL |
| `mdl_env_isl02_terrain` | P1 | `res://assets/models/env/mdl_env_isl02_terrain.tscn` | Địa hình đảo 2 | AC-MDL |
| `mdl_env_isl03_terrain` | P1 | `res://assets/models/env/mdl_env_isl03_terrain.tscn` | Địa hình đảo 3 | AC-MDL |
| `mdl_cre_ca_me` | P1 | `res://assets/models/creatures/mdl_cre_ca_me.tscn` | Cá mè thân dẹp, đầu nhỏ; dài theo creatures.json, đủ 5 socket sinh vật, ≤900 tam giác; hình bóng khác các loài khác. | AC-MDL |
| `mdl_cre_ca_thoi_loi` | P1 | `res://assets/models/creatures/mdl_cre_ca_thoi_loi.tscn` | Cá thòi lòi, mắt cao, vây chống; dài theo creatures.json, đủ 5 socket sinh vật, ≤900 tam giác; hình bóng khác các loài khác. | AC-MDL |
| `mdl_cre_luon` | P1 | `res://assets/models/creatures/mdl_cre_luon.tscn` | Lươn thân dài, đầu nhỏ; dài theo creatures.json, đủ 5 socket sinh vật, ≤900 tam giác; hình bóng khác các loài khác. | AC-MDL |
| `mdl_cre_ca_doi` | P1 | `res://assets/models/creatures/mdl_cre_ca_doi.tscn` | Cá đối thân thuôn, đuôi chẻ; dài theo creatures.json, đủ 5 socket sinh vật, ≤900 tam giác; hình bóng khác các loài khác. | AC-MDL |
| `mdl_cre_cua_bun` | P1 | `res://assets/models/creatures/mdl_cre_cua_bun.tscn` | Cua bùn mai rộng, càng lớn; dài theo creatures.json, đủ 5 socket sinh vật, ≤900 tam giác; hình bóng khác các loài khác. | AC-MDL |
| `mdl_cre_tom_cang` | P1 | `res://assets/models/creatures/mdl_cre_tom_cang.tscn` | Tôm càng, càng trước dài; dài theo creatures.json, đủ 5 socket sinh vật, ≤900 tam giác; hình bóng khác các loài khác. | AC-MDL |
| `mdl_cre_ca_nuc` | P1 | `res://assets/models/creatures/mdl_cre_ca_nuc.tscn` | Cá nục thân thoi, đuôi chẻ; dài theo creatures.json, đủ 5 socket sinh vật, ≤900 tam giác; hình bóng khác các loài khác. | AC-MDL |
| `mdl_cre_ca_chuon` | P1 | `res://assets/models/creatures/mdl_cre_ca_chuon.tscn` | Cá chuồn, vây ngực rộng; dài theo creatures.json, đủ 5 socket sinh vật, ≤900 tam giác; hình bóng khác các loài khác. | AC-MDL |
| `mdl_cre_ca_trich` | P1 | `res://assets/models/creatures/mdl_cre_ca_trich.tscn` | Cá trích thân bạc dẹp; dài theo creatures.json, đủ 5 socket sinh vật, ≤900 tam giác; hình bóng khác các loài khác. | AC-MDL |
| `mdl_cre_muc_ong` | P1 | `res://assets/models/creatures/mdl_cre_muc_ong.tscn` | Mực ống, thân ống và xúc tu; dài theo creatures.json, đủ 5 socket sinh vật, ≤900 tam giác; hình bóng khác các loài khác. | AC-MDL |
| `mdl_cre_ca_hong` | P1 | `res://assets/models/creatures/mdl_cre_ca_hong.tscn` | Cá hồng, thân dẹp và vây gai; dài theo creatures.json, đủ 5 socket sinh vật, ≤900 tam giác; hình bóng khác các loài khác. | AC-MDL |
| `mdl_cre_boss_cua_bun` | P1 | `res://assets/models/creatures/mdl_cre_boss_cua_bun.tscn` | Cua Bùn đầu đàn, càng đối xứng dễ đọc; ≤3.000 tam giác, đủ socket boss, kích thước theo dữ liệu. | AC-MDL |
| `mdl_cre_boss_ca_bop` | P1 | `res://assets/models/creatures/mdl_cre_boss_ca_bop.tscn` | Cá Bớp đầu đàn, thân khỏe và vây lưng nhận dạng; ≤3.000 tam giác, đủ socket boss, kích thước theo dữ liệu. | AC-MDL |
| `mdl_item_rice_ball` | P1 | `res://assets/models/items/mdl_item_rice_ball.tscn` | Cơm nắm trong lá, thức ăn phục hồi đói; ≤300 tam giác, pivot tâm vật và collider đơn giản. | AC-MDL |
| `mdl_item_grilled_fish` | P1 | `res://assets/models/items/mdl_item_grilled_fish.tscn` | Cá nướng, thức ăn theo dữ liệu; ≤300 tam giác, pivot tâm vật và collider đơn giản. | AC-MDL |
| `mdl_item_survey_tag` | P1 | `res://assets/models/items/mdl_item_survey_tag.tscn` | Thẻ ghi nhận khảo sát nghề cá; ≤300 tam giác, pivot tâm vật và collider đơn giản. | AC-MDL |
| `mdl_item_festival_medal` | P1 | `res://assets/models/items/mdl_item_festival_medal.tscn` | Huy hiệu lễ hội làng chài; ≤300 tam giác, pivot tâm vật và collider đơn giản. | AC-MDL |
| `mdl_chr_player_remote` | P0 | `res://assets/models/chr/mdl_chr_player_remote.tscn` | Thân đồng đội đầy đủ, ≤1.800 tam giác; 4 phối màu, socket tay/đầu; ẩn thân mình khỏi camera FP. | AC-MDL |

### material

| ID | Ưu tiên | Đường dẫn đích | Đặc tả | Nghiệm thu |
|---|---|---|---|---|
| `mat_palette_lit` | P0 | `res://assets/materials/mat_palette_lit.tres` | Vật liệu chung mọi mô hình; StandardMaterial3D: dùng vertex color làm albedo, roughness 1, metallic 0 | AC-MDL |
| `mat_palette_unshaded` | P0 | `res://assets/materials/mat_palette_unshaded.tres` | Phần tự phát sáng; Unshaded, vertex color | AC-MDL |

### shader

| ID | Ưu tiên | Đường dẫn đích | Đặc tả | Nghiệm thu |
|---|---|---|---|---|
| `shd_water` | P0 | `res://assets/shaders/shd_water.gdshader` | Mặt nước; Dịch đỉnh sóng nhỏ, màu từ vertex color, không depth texture | AC-VFX |
| `shd_creature_wiggle` | P0 | `res://assets/shaders/shd_creature_wiggle.gdshader` | Uốn thân sinh vật; Tham số wiggle_amp, wiggle_speed, wiggle_axis; tắt khi KO | AC-VFX |
| `shd_fp_viewmodel` | P0 | `res://assets/shaders/shd_fp_viewmodel.gdshader` | Tay/công cụ FP không xuyên cảnh; Cách làm chốt ở EXP-10 | AC-VFX |
| `shd_hit_flash` | P0 | `res://assets/shaders/shd_hit_flash.gdshader` | Nháy trắng khi trúng đòn; Uniform flash_amount 0–1 | AC-VFX |

### environment

| ID | Ưu tiên | Đường dẫn đích | Đặc tả | Nghiệm thu |
|---|---|---|---|---|
| `env_isl01_day` | P0 | `res://assets/env/env_isl01_day.tres` | Bầu trời + ánh sáng môi trường đảo 1; Gradient trời, sương từ ~60 m, màu theo 05 §3–4 | AC-MDL |
| `env_isl02_day` | P1 | `res://assets/env/env_isl02_day.tres` | Bầu trời/ánh sáng đảo theo 05; môi trường đơn giản tương thích web, không texture nặng. | AC-MDL |
| `env_isl03_day` | P1 | `res://assets/env/env_isl03_day.tres` | Bầu trời/ánh sáng đảo theo 05; môi trường đơn giản tương thích web, không texture nặng. | AC-MDL |

### texture

| ID | Ưu tiên | Đường dẫn đích | Đặc tả | Nghiệm thu |
|---|---|---|---|---|
| `tex_palette_main` | P0 | `res://assets/textures/tex_palette_main.png` | Bảng tra màu cho họa sĩ; 64×64, 8×8 ô | AC-ICO |

### vfx

| ID | Ưu tiên | Đường dẫn đích | Đặc tả | Nghiệm thu |
|---|---|---|---|---|
| `vfx_fishing_line` | P0 | `res://assets/vfx/vfx_fishing_line.tscn` | Dây câu từ socket_tip tới phao/sinh vật; Cập nhật mỗi khung; độ võng theo độ căng | AC-VFX |
| `vfx_lure_splash` | P0 | `res://assets/vfx/vfx_lure_splash.tscn` | Phao chạm nước; Vòng + 8–12 giọt | AC-VFX |
| `vfx_bobber_ripple` | P0 | `res://assets/vfx/vfx_bobber_ripple.tscn` | Rỉa/chờ; Vòng gợn phẳng mở rộng | AC-VFX |
| `vfx_bite_splash` | P0 | `res://assets/vfx/vfx_bite_splash.tscn` | Cá cắn; Vòng lớn + tia nước | AC-VFX |
| `vfx_yank_burst` | P0 | `res://assets/vfx/vfx_yank_burst.tscn` | Cá bị giật khỏi nước; Cột nước ngắn + giọt | AC-VFX |
| `vfx_air_trail` | P0 | `res://assets/vfx/vfx_air_trail.tscn` | Vệt sau sinh vật đang bay; Vệt mờ trắng ngắn | AC-VFX |
| `vfx_hit_confetti` | P0 | `res://assets/vfx/vfx_hit_confetti.tscn` | Trúng đòn / KO; Mảnh vảy tam giác màu sinh vật + ánh vàng | AC-VFX |
| `vfx_ko_stars` | P0 | `res://assets/vfx/vfx_ko_stars.tscn` | Sao quay khi KO; 3 sao quay tại socket_fx_top | AC-VFX |
| `vfx_trick_text` | P0 | `res://assets/vfx/vfx_trick_text.tscn` | Chữ tượng thanh/tên trick; Label3D billboard | AC-VFX |
| `vfx_coin_burst` | P0 | `res://assets/vfx/vfx_coin_burst.tscn` | Bán hàng; Đồng vảy vàng bắn lên | AC-VFX |
| `vfx_boss_telegraph_ring` | P0 | `res://assets/vfx/vfx_boss_telegraph_ring.tscn` | Vòng báo trước đòn boss; Trắng → đỏ trong telegraph_s | AC-VFX |
| `vfx_escape_bubbles` | P0 | `res://assets/vfx/vfx_escape_bubbles.tscn` | Sinh vật sổng về nước; Bọt + gợn | AC-VFX |
| `vfx_bite_indicator` | P0 | `res://assets/vfx/vfx_bite_indicator.tscn` | Dấu "!" nổi trên phao khi cá cắn; Chữ/biểu tượng billboard 0,4 s | AC-VFX |
| `vfx_attack_warn` | P0 | `res://assets/vfx/vfx_attack_warn.tscn` | Dấu cảnh báo trên sinh vật sắp tấn công; Biểu tượng nhỏ tại socket_fx_top trong attack.telegraph_s | AC-VFX |
| `vfx_cast_preview` | P0 | `res://assets/vfx/vfx_cast_preview.tscn` | Vòng cung dự kiến điểm rơi khi nạp lực (cảm ứng); Chuỗi chấm mờ trên mặt nước; do cần câu sở hữu (08 §5.5) | AC-VFX |
| `vfx_smoke_grill` | P1 | `res://assets/vfx/vfx_smoke_grill.tscn` | Khói nướng; Khối cầu low-poly trắng | AC-VFX |
| `vfx_boba_sparkle` | P1 | `res://assets/vfx/vfx_boba_sparkle.tscn` | ID kỹ thuật cũ: phản chiếu bạc/UI phát hiện hiếm ngắn; không phép thuật. | AC-VFX |
| `vfx_confetti_explosion` | P1 | `res://assets/vfx/vfx_confetti_explosion.tscn` | Nổ kim tuyến; ≤ 64 hạt | AC-VFX |
| `vfx_lootbox_reveal` | P1 | `res://assets/vfx/vfx_lootbox_reveal.tscn` | Hộp phần thưởng UI: ≤32 hạt, có thể skip; không near-miss, không chi phối xác suất; sau commit server. | AC-VFX |

### ui

| ID | Ưu tiên | Đường dẫn đích | Đặc tả | Nghiệm thu |
|---|---|---|---|---|
| `ui_theme_main` | P0 | `res://ui/theme/ui_theme_main.tres` | Theme chung (màu, StyleBox, cỡ chữ); Theo 05 §3, §10 | AC-UI |
| `ui_hud` | P0 | `res://ui/hud/ui_hud.tscn` | Cảnh HUD tổng; Bố cục 05 §10.1; neo vùng an toàn | AC-UI |
| `ui_hotbar` | P0 | `res://ui/hud/ui_hotbar.tscn` | Thanh công cụ 4 ô (cần, tay, dép, chổi) + ô mồi; Ô 80 px; ô chọn phóng 1,15× + viền; ô mồi hiện số lượng | AC-UI |
| `ui_bag_row` | P0 | `res://ui/hud/ui_bag_row.tscn` | Hàng ô túi (sinh vật/vật phẩm đang cất); 3–5 ô nhỏ 56 px cạnh hotbar; hiện icon + giá | AC-UI |
| `ui_strain_meter` | P0 | `res://ui/hud/ui_strain_meter.tscn` | Thước căng dây khi kéo cá; Cung tròn quanh tâm ngắm, đổi vàng → đỏ theo độ căng | AC-UI |
| `ui_damage_vignette` | P0 | `res://ui/hud/ui_damage_vignette.tscn` | Viền đỏ khi bị đánh; Lớp phủ mép màn hình, mờ dần 0,5 s | AC-UI |
| `ui_tutorial_hint` | P0 | `res://ui/hud/ui_tutorial_hint.tscn` | Hộp gợi ý hướng dẫn; 1 dòng + biểu tượng phím/nút theo thiết bị | AC-UI |
| `ui_toast` | P0 | `res://ui/hud/ui_toast.tscn` | Thông báo ngắn (hết túi, sổng cá, dép tự về…); Tối đa 2 dòng, 2 s | AC-UI |
| `ui_touch_controls` | P2 | `res://ui/touch/ui_touch_controls.tscn` | Giữ ID tương thích, ngoài phạm vi desktop v2; không là điều kiện phát hành. | AC-UI |
| `ui_prompt` | P0 | `res://ui/hud/ui_prompt.tscn` | Gợi ý tương tác dưới tâm ngắm; Biểu tượng phím/nút + nhãn | AC-UI |
| `ui_objective_line` | P0 | `res://ui/hud/ui_objective_line.tscn` | Dòng mục tiêu; 1 dòng, tối đa 48 ký tự hiển thị | AC-UI |
| `ui_trick_popup` | P0 | `res://ui/hud/ui_trick_popup.tscn` | Popup trick + giá; Tối đa scoring.popup_max_lines dòng trick (nhiều hơn thì hiện các trick hệ số cao nhất + dòng "+N trick khác") + tổng + tên sinh vật + giá; tự ẩn 2,5 s | AC-UI |
| `ui_boss_bar` | P0 | `res://ui/hud/ui_boss_bar.tscn` | Thanh máu + thanh trốn; Rộng 50% màn hình, giữa trên; thanh trốn ngay dưới thanh máu | AC-UI |
| `ui_dex_panel` | P0 | `res://ui/menus/ui_dex_panel.tscn` | Sổ Cá (loài + trick); 2 tab; ô loài có icon/"?" | AC-UI |
| `ui_pause_menu` | P0 | `res://ui/menus/ui_pause_menu.tscn` | Tạm dừng; Tiếp tục, Tùy chọn, Về menu | AC-UI |
| `ui_settings_panel` | P0 | `res://ui/menus/ui_settings_panel.tscn` | Tùy chọn; Theo REQ-SET-001 | AC-UI |
| `ui_main_menu` | P0 | `res://ui/menus/ui_main_menu.tscn` | Menu chính; Nút "Chơi" nổi bật (1 cú bấm) | AC-UI |
| `ui_dialogue_bubble` | P0 | `res://ui/widgets/ui_dialogue_bubble.tscn` | Bóng thoại NPC; Chữ hiện dần, bấm để qua | AC-UI |
| `ui_logo_placeholder` | P0 | `res://ui/widgets/ui_logo_placeholder.tscn` | Logo tạm; Chữ render bằng phông, không ảnh | AC-UI |
| `ui_room_lobby` | P0 | `res://ui/ui_room_lobby.tscn` | Tạo/vào phòng 1–4 người, lỗi kết nối và trạng thái sẵn sàng; chữ Việt/Anh tách khỏi hình. | AC-UI |
| `ui_party_status` | P0 | `res://ui/ui_party_status.tscn` | Danh sách đồng đội và trạng thái; không che tâm ngắm; chữ Việt/Anh tách khỏi hình. | AC-UI |
| `ui_hunger_meter` | P0 | `res://ui/ui_hunger_meter.tscn` | Thanh đói có nhãn, icon và ngưỡng; chữ Việt/Anh tách khỏi hình. | AC-UI |
| `ui_cosmetics_panel` | P1 | `res://ui/ui_cosmetics_panel.tscn` | 6 skin phối màu dụng cụ; hiển thị sở hữu; chữ Việt/Anh tách khỏi hình. | AC-UI |
| `ui_lootbox_panel` | P1 | `res://ui/ui_lootbox_panel.tscn` | Mở hộp miễn phí: nguồn, xác suất, đồ trùng; kết quả sau xác nhận máy chủ; chữ Việt/Anh tách khỏi hình. | AC-UI |

### font

| ID | Ưu tiên | Đường dẫn đích | Đặc tả | Nghiệm thu |
|---|---|---|---|---|
| `fnt_be_vietnam_pro` | P0 | `res://assets/fonts/fnt_be_vietnam_pro.tres` | Phông chữ (Medium, Bold); OFL; đủ dấu tiếng Việt | AC-UI |

### icon

| ID | Ưu tiên | Đường dẫn đích | Đặc tả | Nghiệm thu |
|---|---|---|---|---|
| `ico_tool_hand` | P0 | `res://assets/icons/ico_tool_hand.png` | Ô tay không; Bàn tay xòe | AC-ICO |
| `ico_tool_slipper` | P0 | `res://assets/icons/ico_tool_slipper.png` | Ô dép; Chiếc dép nghiêng | AC-ICO |
| `ico_tool_broom` | P0 | `res://assets/icons/ico_tool_broom.png` | Ô chổi; Chổi chéo góc | AC-ICO |
| `ico_rod_bamboo` | P0 | `res://assets/icons/ico_rod_bamboo.png` | Ô cần; Cần chéo góc | AC-ICO |
| `ico_bait_bread` | P0 | `res://assets/icons/ico_bait_bread.png` | Ô mồi bánh mì; Mẩu bánh mì | AC-ICO |
| `ico_bait_worm` | P0 | `res://assets/icons/ico_bait_worm.png` | Ô mồi trùn; Hũ trùn | AC-ICO |
| `ico_bait_milk_tea` | P0 | `res://assets/icons/ico_bait_milk_tea.png` | ID kỹ thuật cũ: icon Mồi cá tạp; bake từ mdl_item_milk_tea. | AC-ICO |
| `ico_item_golden_scale` | P0 | `res://assets/icons/ico_item_golden_scale.png` | Vật phẩm nhiệm vụ; Vảy vàng | AC-ICO |
| `ico_cre_tep` | P0 | `res://assets/icons/ico_cre_tep.png` | Sổ Cá + túi; Tép | AC-ICO |
| `ico_cre_ca_ro` | P0 | `res://assets/icons/ico_cre_ca_ro.png` | Sổ Cá + túi; Cá rô | AC-ICO |
| `ico_cre_ca_tre` | P0 | `res://assets/icons/ico_cre_ca_tre.png` | Sổ Cá + túi; Cá trê | AC-ICO |
| `ico_cre_cua_dong` | P0 | `res://assets/icons/ico_cre_cua_dong.png` | Sổ Cá + túi; Cua đồng | AC-ICO |
| `ico_cre_boss_ca_loc` | P0 | `res://assets/icons/ico_cre_boss_ca_loc.png` | Sổ Cá; Cá Lóc Trùm | AC-ICO |
| `ico_money` | P0 | `res://assets/icons/ico_money.png` | Biểu tượng tiền trên HUD; Vảy vàng nhỏ; PNG (nguồn SVG ở art_src/) | AC-ICO |
| `ico_health` | P0 | `res://assets/icons/ico_health.png` | Biểu tượng máu; Trái tim vảy cá; PNG (nguồn SVG ở art_src/) | AC-ICO |
| `ico_cre_ca_me` | P1 | `res://assets/icons/ico_cre_ca_me.png` | Bake 256×256 RGBA từ mdl_cre_ca_me đã duyệt; rõ ở 64 px. | AC-ICO |
| `ico_cre_ca_thoi_loi` | P1 | `res://assets/icons/ico_cre_ca_thoi_loi.png` | Bake 256×256 RGBA từ mdl_cre_ca_thoi_loi đã duyệt; rõ ở 64 px. | AC-ICO |
| `ico_cre_luon` | P1 | `res://assets/icons/ico_cre_luon.png` | Bake 256×256 RGBA từ mdl_cre_luon đã duyệt; rõ ở 64 px. | AC-ICO |
| `ico_cre_ca_doi` | P1 | `res://assets/icons/ico_cre_ca_doi.png` | Bake 256×256 RGBA từ mdl_cre_ca_doi đã duyệt; rõ ở 64 px. | AC-ICO |
| `ico_cre_cua_bun` | P1 | `res://assets/icons/ico_cre_cua_bun.png` | Bake 256×256 RGBA từ mdl_cre_cua_bun đã duyệt; rõ ở 64 px. | AC-ICO |
| `ico_cre_tom_cang` | P1 | `res://assets/icons/ico_cre_tom_cang.png` | Bake 256×256 RGBA từ mdl_cre_tom_cang đã duyệt; rõ ở 64 px. | AC-ICO |
| `ico_cre_ca_nuc` | P1 | `res://assets/icons/ico_cre_ca_nuc.png` | Bake 256×256 RGBA từ mdl_cre_ca_nuc đã duyệt; rõ ở 64 px. | AC-ICO |
| `ico_cre_ca_chuon` | P1 | `res://assets/icons/ico_cre_ca_chuon.png` | Bake 256×256 RGBA từ mdl_cre_ca_chuon đã duyệt; rõ ở 64 px. | AC-ICO |
| `ico_cre_ca_trich` | P1 | `res://assets/icons/ico_cre_ca_trich.png` | Bake 256×256 RGBA từ mdl_cre_ca_trich đã duyệt; rõ ở 64 px. | AC-ICO |
| `ico_cre_muc_ong` | P1 | `res://assets/icons/ico_cre_muc_ong.png` | Bake 256×256 RGBA từ mdl_cre_muc_ong đã duyệt; rõ ở 64 px. | AC-ICO |
| `ico_cre_ca_hong` | P1 | `res://assets/icons/ico_cre_ca_hong.png` | Bake 256×256 RGBA từ mdl_cre_ca_hong đã duyệt; rõ ở 64 px. | AC-ICO |
| `ico_cre_boss_cua_bun` | P1 | `res://assets/icons/ico_cre_boss_cua_bun.png` | Bake từ mdl_cre_boss_cua_bun; PNG 256×256 RGBA. | AC-ICO |
| `ico_cre_boss_ca_bop` | P1 | `res://assets/icons/ico_cre_boss_ca_bop.png` | Bake từ mdl_cre_boss_ca_bop; PNG 256×256 RGBA. | AC-ICO |
| `ico_item_rice_ball` | P1 | `res://assets/icons/ico_item_rice_ball.png` | Bake 256×256 RGBA từ mdl_item_rice_ball; không chứa chữ. | AC-ICO |
| `ico_item_grilled_fish` | P1 | `res://assets/icons/ico_item_grilled_fish.png` | Bake 256×256 RGBA từ mdl_item_grilled_fish; không chứa chữ. | AC-ICO |
| `ico_item_survey_tag` | P1 | `res://assets/icons/ico_item_survey_tag.png` | Bake 256×256 RGBA từ mdl_item_survey_tag; không chứa chữ. | AC-ICO |
| `ico_item_festival_medal` | P1 | `res://assets/icons/ico_item_festival_medal.png` | Bake 256×256 RGBA từ mdl_item_festival_medal; không chứa chữ. | AC-ICO |

### anim_library

| ID | Ưu tiên | Đường dẫn đích | Đặc tả | Nghiệm thu |
|---|---|---|---|---|
| `anm_lib_fp` | P0 | `res://assets/anim/anm_lib_fp.tres` | Thư viện clip tay góc nhìn thứ nhất; AnimationLibrary chứa mọi anm_fp_* | AC-ANM |
| `anm_lib_npc_basic` | P0 | `res://assets/anim/anm_lib_npc_basic.tres` | Thư viện clip NPC dùng chung; Chứa mọi anm_npc_* | AC-ANM |
| `anm_lib_boss_ca_loc` | P0 | `res://assets/anim/anm_lib_boss_ca_loc.tres` | Thư viện clip boss Cá Lóc Trùm; Chứa mọi anm_boss_ca_loc_* | AC-ANM |
| `anm_lib_egret` | P1 | `res://assets/anim/anm_lib_egret.tres` | Thư viện clip cò; Chứa anm_egret_* | AC-ANM |
| `anm_lib_boss_cua_bun` | P1 | `res://assets/anim/anm_lib_boss_cua_bun.tres` | Thư viện 12 clip boss; được tái dùng thuật toán nhưng phải có đủ clip mang ID riêng. | AC-ANM |
| `anm_lib_boss_ca_bop` | P1 | `res://assets/anim/anm_lib_boss_ca_bop.tres` | Thư viện 12 clip boss; được tái dùng thuật toán nhưng phải có đủ clip mang ID riêng. | AC-ANM |
| `anm_lib_player_remote` | P0 | `res://assets/anim/anm_lib_player_remote.tres` | Các clip quan sát đồng đội, phát theo trạng thái đã đồng bộ. | AC-ANM |

### anim_clip

| ID | Ưu tiên | Đường dẫn đích | Đặc tả | Nghiệm thu |
|---|---|---|---|---|
| `anm_fp_idle` | P0 | `res://assets/anim/anm_lib_fp.tres` | Tay cầm đồ, thở nhẹ; Lặp 2–3 s | AC-ANM |
| `anm_fp_equip` | P0 | `res://assets/anim/anm_lib_fp.tres` | Rút đồ; 0,2–0,3 s | AC-ANM |
| `anm_fp_cast_charge` | P0 | `res://assets/anim/anm_lib_fp.tres` | Kéo cần ra sau (giữ); 0,2 s vào + giữ tư thế | AC-ANM |
| `anm_fp_cast_release` | P0 | `res://assets/anim/anm_lib_fp.tres` | Vung cần; 0,25 s; sự kiện release | AC-ANM |
| `anm_fp_reel_loop` | P0 | `res://assets/anim/anm_lib_fp.tres` | Quay guồng; Lặp 0,5 s | AC-ANM |
| `anm_fp_yank` | P0 | `res://assets/anim/anm_lib_fp.tres` | Giật cần; 0,3 s | AC-ANM |
| `anm_fp_slap` | P0 | `res://assets/anim/anm_lib_fp.tres` | Tát/đấm; 0,25 s; sự kiện impact | AC-ANM |
| `anm_fp_throw` | P0 | `res://assets/anim/anm_lib_fp.tres` | Ném dép; 0,3 s; sự kiện release | AC-ANM |
| `anm_fp_sweep` | P0 | `res://assets/anim/anm_lib_fp.tres` | Quét chổi; 0,35 s; sự kiện impact | AC-ANM |
| `anm_fp_pickup` | P0 | `res://assets/anim/anm_lib_fp.tres` | Nhặt vật; 0,2 s | AC-ANM |
| `anm_npc_idle` | P0 | `res://assets/anim/anm_lib_npc_basic.tres` | NPC đứng/ngồi; Lặp 3–4 s | AC-ANM |
| `anm_npc_talk` | P0 | `res://assets/anim/anm_lib_npc_basic.tres` | Nói chuyện; Lặp; sự kiện mouth_open/mouth_close | AC-ANM |
| `anm_npc_happy` | P0 | `res://assets/anim/anm_lib_npc_basic.tres` | Vui khi nhận hàng tốt; 0,8 s | AC-ANM |
| `anm_npc_disgust` | P0 | `res://assets/anim/anm_lib_npc_basic.tres` | Chê hàng rẻ; 0,8 s | AC-ANM |
| `anm_boss_ca_loc_land` | P0 | `res://assets/anim/anm_lib_boss_ca_loc.tres` | Boss nhảy lên bãi đấu (LANDING); 1,2 s; sự kiện impact khi chạm đất | AC-ANM |
| `anm_boss_ca_loc_idle` | P0 | `res://assets/anim/anm_lib_boss_ca_loc.tres` | Boss nghỉ; Lặp 1,5 s | AC-ANM |
| `anm_boss_ca_loc_telegraph_slam` | P0 | `res://assets/anim/anm_lib_boss_ca_loc.tres` | Báo trước quật đuôi; = telegraph_s của đòn | AC-ANM |
| `anm_boss_ca_loc_slam` | P0 | `res://assets/anim/anm_lib_boss_ca_loc.tres` | Quật đuôi; 0,4 s; sự kiện impact | AC-ANM |
| `anm_boss_ca_loc_telegraph_charge` | P0 | `res://assets/anim/anm_lib_boss_ca_loc.tres` | Báo trước lao tới; = telegraph_s | AC-ANM |
| `anm_boss_ca_loc_charge` | P0 | `res://assets/anim/anm_lib_boss_ca_loc.tres` | Lao tới (lặp khi chạy); Lặp 0,5 s; sát thương do vùng va chạm khi lao (07 §6.3), không dùng sự kiện impact | AC-ANM |
| `anm_boss_ca_loc_stunned` | P0 | `res://assets/anim/anm_lib_boss_ca_loc.tres` | Choáng (cửa sổ đánh); Lặp; mắt xoắn | AC-ANM |
| `anm_boss_ca_loc_telegraph_spit` | P0 | `res://assets/anim/anm_lib_boss_ca_loc.tres` | Báo trước phun (má phồng); = telegraph_s của move_boba_spit | AC-ANM |
| `anm_boss_ca_loc_spit` | P0 | `res://assets/anim/anm_lib_boss_ca_loc.tres` | Phun trân châu (pha 2); 0,6 s; sự kiện spawn_projectile | AC-ANM |
| `anm_boss_ca_loc_phase_change` | P0 | `res://assets/anim/anm_lib_boss_ca_loc.tres` | Chuyển pha (bụng căng, đổi màu); 1,0 s | AC-ANM |
| `anm_boss_ca_loc_escape` | P0 | `res://assets/anim/anm_lib_boss_ca_loc.tres` | Lặn trốn; 1,2 s | AC-ANM |
| `anm_boss_ca_loc_defeat` | P0 | `res://assets/anim/anm_lib_boss_ca_loc.tres` | Bị hạ; 1,5 s | AC-ANM |
| `anm_egret_walk` | P1 | `res://assets/anim/anm_lib_egret.tres` | Cò đi rón rén; Lặp | AC-ANM |
| `anm_egret_fly` | P1 | `res://assets/anim/anm_lib_egret.tres` | Cò bay đi (tay không hoặc ngậm đồ); Lặp | AC-ANM |
| `anm_boss_cua_bun_land` | P1 | `res://assets/anim/anm_lib_boss_cua_bun.tres` | Cua Bùn đầu đàn, càng đối xứng dễ đọc: land; khớp timing bosses.json, không tự áp sát thương; spit chỉ là nước. | AC-ANM |
| `anm_boss_cua_bun_idle` | P1 | `res://assets/anim/anm_lib_boss_cua_bun.tres` | Cua Bùn đầu đàn, càng đối xứng dễ đọc: idle; khớp timing bosses.json, không tự áp sát thương; spit chỉ là nước. | AC-ANM |
| `anm_boss_cua_bun_phase_change` | P1 | `res://assets/anim/anm_lib_boss_cua_bun.tres` | Cua Bùn đầu đàn, càng đối xứng dễ đọc: phase_change; khớp timing bosses.json, không tự áp sát thương; spit chỉ là nước. | AC-ANM |
| `anm_boss_cua_bun_escape` | P1 | `res://assets/anim/anm_lib_boss_cua_bun.tres` | Cua Bùn đầu đàn, càng đối xứng dễ đọc: escape; khớp timing bosses.json, không tự áp sát thương; spit chỉ là nước. | AC-ANM |
| `anm_boss_cua_bun_defeat` | P1 | `res://assets/anim/anm_lib_boss_cua_bun.tres` | Cua Bùn đầu đàn, càng đối xứng dễ đọc: defeat; khớp timing bosses.json, không tự áp sát thương; spit chỉ là nước. | AC-ANM |
| `anm_boss_cua_bun_telegraph_slam` | P1 | `res://assets/anim/anm_lib_boss_cua_bun.tres` | Cua Bùn đầu đàn, càng đối xứng dễ đọc: telegraph_slam; khớp timing bosses.json, không tự áp sát thương; spit chỉ là nước. | AC-ANM |
| `anm_boss_cua_bun_slam` | P1 | `res://assets/anim/anm_lib_boss_cua_bun.tres` | Cua Bùn đầu đàn, càng đối xứng dễ đọc: slam; khớp timing bosses.json, không tự áp sát thương; spit chỉ là nước. | AC-ANM |
| `anm_boss_cua_bun_telegraph_charge` | P1 | `res://assets/anim/anm_lib_boss_cua_bun.tres` | Cua Bùn đầu đàn, càng đối xứng dễ đọc: telegraph_charge; khớp timing bosses.json, không tự áp sát thương; spit chỉ là nước. | AC-ANM |
| `anm_boss_cua_bun_charge` | P1 | `res://assets/anim/anm_lib_boss_cua_bun.tres` | Cua Bùn đầu đàn, càng đối xứng dễ đọc: charge; khớp timing bosses.json, không tự áp sát thương; spit chỉ là nước. | AC-ANM |
| `anm_boss_cua_bun_stunned` | P1 | `res://assets/anim/anm_lib_boss_cua_bun.tres` | Cua Bùn đầu đàn, càng đối xứng dễ đọc: stunned; khớp timing bosses.json, không tự áp sát thương; spit chỉ là nước. | AC-ANM |
| `anm_boss_cua_bun_telegraph_spit` | P1 | `res://assets/anim/anm_lib_boss_cua_bun.tres` | Cua Bùn đầu đàn, càng đối xứng dễ đọc: telegraph_spit; khớp timing bosses.json, không tự áp sát thương; spit chỉ là nước. | AC-ANM |
| `anm_boss_cua_bun_spit` | P1 | `res://assets/anim/anm_lib_boss_cua_bun.tres` | Cua Bùn đầu đàn, càng đối xứng dễ đọc: spit; khớp timing bosses.json, không tự áp sát thương; spit chỉ là nước. | AC-ANM |
| `anm_boss_ca_bop_land` | P1 | `res://assets/anim/anm_lib_boss_ca_bop.tres` | Cá Bớp đầu đàn, thân khỏe và vây lưng nhận dạng: land; khớp timing bosses.json, không tự áp sát thương; spit chỉ là nước. | AC-ANM |
| `anm_boss_ca_bop_idle` | P1 | `res://assets/anim/anm_lib_boss_ca_bop.tres` | Cá Bớp đầu đàn, thân khỏe và vây lưng nhận dạng: idle; khớp timing bosses.json, không tự áp sát thương; spit chỉ là nước. | AC-ANM |
| `anm_boss_ca_bop_phase_change` | P1 | `res://assets/anim/anm_lib_boss_ca_bop.tres` | Cá Bớp đầu đàn, thân khỏe và vây lưng nhận dạng: phase_change; khớp timing bosses.json, không tự áp sát thương; spit chỉ là nước. | AC-ANM |
| `anm_boss_ca_bop_escape` | P1 | `res://assets/anim/anm_lib_boss_ca_bop.tres` | Cá Bớp đầu đàn, thân khỏe và vây lưng nhận dạng: escape; khớp timing bosses.json, không tự áp sát thương; spit chỉ là nước. | AC-ANM |
| `anm_boss_ca_bop_defeat` | P1 | `res://assets/anim/anm_lib_boss_ca_bop.tres` | Cá Bớp đầu đàn, thân khỏe và vây lưng nhận dạng: defeat; khớp timing bosses.json, không tự áp sát thương; spit chỉ là nước. | AC-ANM |
| `anm_boss_ca_bop_telegraph_slam` | P1 | `res://assets/anim/anm_lib_boss_ca_bop.tres` | Cá Bớp đầu đàn, thân khỏe và vây lưng nhận dạng: telegraph_slam; khớp timing bosses.json, không tự áp sát thương; spit chỉ là nước. | AC-ANM |
| `anm_boss_ca_bop_slam` | P1 | `res://assets/anim/anm_lib_boss_ca_bop.tres` | Cá Bớp đầu đàn, thân khỏe và vây lưng nhận dạng: slam; khớp timing bosses.json, không tự áp sát thương; spit chỉ là nước. | AC-ANM |
| `anm_boss_ca_bop_telegraph_charge` | P1 | `res://assets/anim/anm_lib_boss_ca_bop.tres` | Cá Bớp đầu đàn, thân khỏe và vây lưng nhận dạng: telegraph_charge; khớp timing bosses.json, không tự áp sát thương; spit chỉ là nước. | AC-ANM |
| `anm_boss_ca_bop_charge` | P1 | `res://assets/anim/anm_lib_boss_ca_bop.tres` | Cá Bớp đầu đàn, thân khỏe và vây lưng nhận dạng: charge; khớp timing bosses.json, không tự áp sát thương; spit chỉ là nước. | AC-ANM |
| `anm_boss_ca_bop_stunned` | P1 | `res://assets/anim/anm_lib_boss_ca_bop.tres` | Cá Bớp đầu đàn, thân khỏe và vây lưng nhận dạng: stunned; khớp timing bosses.json, không tự áp sát thương; spit chỉ là nước. | AC-ANM |
| `anm_boss_ca_bop_telegraph_spit` | P1 | `res://assets/anim/anm_lib_boss_ca_bop.tres` | Cá Bớp đầu đàn, thân khỏe và vây lưng nhận dạng: telegraph_spit; khớp timing bosses.json, không tự áp sát thương; spit chỉ là nước. | AC-ANM |
| `anm_boss_ca_bop_spit` | P1 | `res://assets/anim/anm_lib_boss_ca_bop.tres` | Cá Bớp đầu đàn, thân khỏe và vây lưng nhận dạng: spit; khớp timing bosses.json, không tự áp sát thương; spit chỉ là nước. | AC-ANM |
| `anm_player_remote_idle` | P0 | `res://assets/anim/anm_lib_player_remote.tres` | Đồng đội idle; track trình bày, không tự quyết gameplay. | AC-ANM |
| `anm_player_remote_walk` | P0 | `res://assets/anim/anm_lib_player_remote.tres` | Đồng đội walk; track trình bày, không tự quyết gameplay. | AC-ANM |
| `anm_player_remote_run` | P0 | `res://assets/anim/anm_lib_player_remote.tres` | Đồng đội run; track trình bày, không tự quyết gameplay. | AC-ANM |
| `anm_player_remote_cast` | P0 | `res://assets/anim/anm_lib_player_remote.tres` | Đồng đội cast; track trình bày, không tự quyết gameplay. | AC-ANM |
| `anm_player_remote_reel` | P0 | `res://assets/anim/anm_lib_player_remote.tres` | Đồng đội reel; track trình bày, không tự quyết gameplay. | AC-ANM |
| `anm_player_remote_use_tool` | P0 | `res://assets/anim/anm_lib_player_remote.tres` | Đồng đội use_tool; track trình bày, không tự quyết gameplay. | AC-ANM |
| `anm_player_remote_knocked_out` | P0 | `res://assets/anim/anm_lib_player_remote.tres` | Đồng đội knocked_out; track trình bày, không tự quyết gameplay. | AC-ANM |
| `anm_player_remote_revive` | P0 | `res://assets/anim/anm_lib_player_remote.tres` | Đồng đội revive; track trình bày, không tự quyết gameplay. | AC-ANM |

### sfx

| ID | Ưu tiên | Đường dẫn đích | Đặc tả | Nghiệm thu |
|---|---|---|---|---|
| `sfx_cast_charge` | P0 | `res://assets/audio/sfx/sfx_cast_charge.wav` | Cần uốn khi nạp lực; Kẽo kẹt tre, lặp ngắn | AC-SFX |
| `sfx_cast_whoosh` | P0 | `res://assets/audio/sfx/sfx_cast_whoosh.wav` | Vung cần; Vút 0,3 s | AC-SFX |
| `sfx_lure_splash` | P0 | `res://assets/audio/sfx/sfx_lure_splash.wav` | Phao chạm nước; "Tõm" nhỏ | AC-SFX |
| `sfx_lure_ground` | P0 | `res://assets/audio/sfx/sfx_lure_ground.wav` | Phao rơi đất; "Cộc" | AC-SFX |
| `sfx_nibble` | P0 | `res://assets/audio/sfx/sfx_nibble.wav` | Cá rỉa; "Plip" nhẹ | AC-SFX |
| `sfx_bite_alert` | P0 | `res://assets/audio/sfx/sfx_bite_alert.wav` | Cá cắn; 2 nốt chuông + "bụp" nước, 0,4 s | AC-SFX |
| `sfx_perfect_yank` | P0 | `res://assets/audio/sfx/sfx_perfect_yank.wav` | Giật chuẩn; Lấp lánh 0,3 s | AC-SFX |
| `sfx_reel_loop` | P0 | `res://assets/audio/sfx/sfx_reel_loop.wav` | Guồng quay; Lạch cạch, lặp liền | AC-SFX |
| `sfx_line_strain` | P0 | `res://assets/audio/sfx/sfx_line_strain.wav` | Dây căng khi cá vùng vẫy; Kẽo kẹt tăng dần, lặp | AC-SFX |
| `sfx_escape_bloop` | P0 | `res://assets/audio/sfx/sfx_escape_bloop.wav` | Cá sổng; "Bloop" hài | AC-SFX |
| `sfx_launch_pop` | P0 | `res://assets/audio/sfx/sfx_launch_pop.wav` | Cá bị giật khỏi nước; "BỤP" nước | AC-SFX |
| `sfx_air_whistle` | P0 | `res://assets/audio/sfx/sfx_air_whistle.wav` | Sinh vật bay; Huýt gió ngắn | AC-SFX |
| `sfx_flop` | P0 | `res://assets/audio/sfx/sfx_flop_{nn}.wav` | Cá quẫy trên cạn; 3 biến thể | AC-SFX |
| `sfx_hit_slap` | P0 | `res://assets/audio/sfx/sfx_hit_slap.wav` | Tay trúng; "Bốp" | AC-SFX |
| `sfx_hit_bonk` | P0 | `res://assets/audio/sfx/sfx_hit_bonk.wav` | Chổi trúng; "Boing" gỗ | AC-SFX |
| `sfx_slipper_throw` | P0 | `res://assets/audio/sfx/sfx_slipper_throw.wav` | Ném dép; Vút + xoay | AC-SFX |
| `sfx_slipper_hit` | P0 | `res://assets/audio/sfx/sfx_slipper_hit.wav` | Dép trúng; "CHÁT!" | AC-SFX |
| `sfx_ko_stars` | P0 | `res://assets/audio/sfx/sfx_ko_stars.wav` | KO; Chuông sao quay | AC-SFX |
| `sfx_trick_ding` | P0 | `res://assets/audio/sfx/sfx_trick_ding.wav` | Mỗi trick trong popup; "Ting" 1 nốt, code tăng cao độ | AC-SFX |
| `sfx_coin_gain` | P0 | `res://assets/audio/sfx/sfx_coin_gain.wav` | Nhận tiền; Leng keng | AC-SFX |
| `sfx_sell_basket` | P0 | `res://assets/audio/sfx/sfx_sell_basket.wav` | Vật rơi vào thúng; "Phịch" + tre | AC-SFX |
| `sfx_buy` | P0 | `res://assets/audio/sfx/sfx_buy.wav` | Mua thành công; Chuông quầy | AC-SFX |
| `sfx_error_nope` | P0 | `res://assets/audio/sfx/sfx_error_nope.wav` | Thiếu tiền/không được; "Nè-nè" hài | AC-SFX |
| `sfx_pickup` | P0 | `res://assets/audio/sfx/sfx_pickup.wav` | Nhặt; Ngắn | AC-SFX |
| `sfx_drop_thud` | P0 | `res://assets/audio/sfx/sfx_drop_thud.wav` | Thả/rơi; "Phịch" | AC-SFX |
| `sfx_player_hurt` | P0 | `res://assets/audio/sfx/sfx_player_hurt.wav` | Người chơi bị đánh; "Úi" (không lời) | AC-SFX |
| `sfx_player_ko` | P0 | `res://assets/audio/sfx/sfx_player_ko.wav` | Người chơi xỉu; "Oái" + sao | AC-SFX |
| `sfx_footstep_wood` | P0 | `res://assets/audio/sfx/sfx_footstep_wood_{nn}.wav` | Bước trên bến; 3 biến thể | AC-SFX |
| `sfx_footstep_sand` | P0 | `res://assets/audio/sfx/sfx_footstep_sand_{nn}.wav` | Bước trên cát/bùn; 3 biến thể | AC-SFX |
| `sfx_jump` | P0 | `res://assets/audio/sfx/sfx_jump.wav` | Nhảy; Ngắn | AC-SFX |
| `sfx_land` | P0 | `res://assets/audio/sfx/sfx_land.wav` | Tiếp đất; Ngắn | AC-SFX |
| `sfx_boss_roar` | P0 | `res://assets/audio/sfx/sfx_boss_roar.wav` | Nước quẫy và gầm cách điệu ngắn; không tiếng ợ trà sữa. | AC-SFX |
| `sfx_boss_telegraph` | P0 | `res://assets/audio/sfx/sfx_boss_telegraph.wav` | Báo trước đòn boss; Còi ngắn tăng dần | AC-SFX |
| `sfx_boss_escape_warning` | P0 | `res://assets/audio/sfx/sfx_boss_escape_warning.wav` | Khi còn escape_warning_s trước lúc boss trốn; Tít tít | AC-SFX |
| `sfx_boss_phase` | P0 | `res://assets/audio/sfx/sfx_boss_phase.wav` | Quẫy nước mạnh + nhạc nhấn nguyên bản; báo đổi pha rõ. | AC-SFX |
| `sfx_boss_escape_splash` | P0 | `res://assets/audio/sfx/sfx_boss_escape_splash.wav` | Boss lặn trốn; Tiếng lặn to + "bloop" | AC-SFX |
| `sfx_creature_warn` | P0 | `res://assets/audio/sfx/sfx_creature_warn.wav` | Sinh vật sắp tấn công; Tiếng gầm gừ nhỏ hài, 0,3 s | AC-SFX |
| `sfx_swing_whoosh` | P0 | `res://assets/audio/sfx/sfx_swing_whoosh.wav` | Vung tay/chổi (trúng hay trượt); Vút ngắn | AC-SFX |
| `sfx_boss_defeat_fanfare` | P0 | `res://assets/audio/sfx/sfx_boss_defeat_fanfare.wav` | Hạ boss; Kèn vui 2 s | AC-SFX |
| `sfx_quest_complete` | P0 | `res://assets/audio/sfx/sfx_quest_complete.wav` | Hoàn thành bước nhiệm vụ; Chuông ngắn | AC-SFX |
| `sfx_new_species` | P0 | `res://assets/audio/sfx/sfx_new_species.wav` | Loài mới; Hợp âm vui 1 s | AC-SFX |
| `sfx_ui_click` | P0 | `res://assets/audio/sfx/sfx_ui_click.wav` | Bấm nút; Rất ngắn | AC-SFX |
| `sfx_ui_back` | P0 | `res://assets/audio/sfx/sfx_ui_back.wav` | Quay lại; Rất ngắn | AC-SFX |
| `sfx_tutorial_pop` | P0 | `res://assets/audio/sfx/sfx_tutorial_pop.wav` | Hiện gợi ý; Nhẹ | AC-SFX |
| `sfx_grill_sizzle_loop` | P1 | `res://assets/audio/sfx/sfx_grill_sizzle_loop.wav` | Xèo xèo; Lặp | AC-SFX |
| `sfx_cook_done` | P1 | `res://assets/audio/sfx/sfx_cook_done.wav` | Chín; "Ting" | AC-SFX |
| `sfx_burnt` | P1 | `res://assets/audio/sfx/sfx_burnt.wav` | Cháy; "Xì" + ho | AC-SFX |
| `sfx_egret_call` | P1 | `res://assets/audio/sfx/sfx_egret_call.wav` | Tiếng cò khi bắt đầu rình; Nghe từ xa | AC-SFX |
| `sfx_egret_steal` | P1 | `res://assets/audio/sfx/sfx_egret_steal.wav` | Cò ngậm được đồ, vỗ cánh | AC-SFX |
| `sfx_rare_reveal` | P1 | `res://assets/audio/sfx/sfx_rare_reveal.wav` | Lộ biến thể hiếm; Hợp âm lấp lánh | AC-SFX |
| `sfx_slingshot_shot` | P1 | `res://assets/audio/sfx/sfx_slingshot_shot.wav` | Bắn ná | AC-SFX |
| `sfx_swatter_zap` | P1 | `res://assets/audio/sfx/sfx_swatter_zap.wav` | Vợt điện "tách" | AC-SFX |
| `sfx_coconut_boom` | P1 | `res://assets/audio/sfx/sfx_coconut_boom.wav` | Nổ dừa (vui, không đáng sợ) | AC-SFX |
| `sfx_hunger_low` | P0 | `res://assets/audio/sfx/sfx_hunger_low.wav` | Bụng reo nhẹ khi vào ngưỡng thấp; hạn chế lặp; WAV PCM16 mono 44.1 kHz, ≤2 s, peak ≤−3 dBFS. | AC-SFX |
| `sfx_eat` | P0 | `res://assets/audio/sfx/sfx_eat.wav` | Ăn ngắn, không gây khó chịu; WAV PCM16 mono 44.1 kHz, ≤2 s, peak ≤−3 dBFS. | AC-SFX |
| `sfx_lootbox_open` | P1 | `res://assets/audio/sfx/sfx_lootbox_open.wav` | Nắp hộp mở gỗ và âm nhận vật ngắn; WAV PCM16 mono 44.1 kHz, ≤2 s, peak ≤−3 dBFS. | AC-SFX |
| `sfx_player_join` | P1 | `res://assets/audio/sfx/sfx_player_join.wav` | Đồng đội vào phòng; WAV PCM16 mono 44.1 kHz, ≤2 s, peak ≤−3 dBFS. | AC-SFX |
| `sfx_player_leave` | P1 | `res://assets/audio/sfx/sfx_player_leave.wav` | Đồng đội rời phòng; WAV PCM16 mono 44.1 kHz, ≤2 s, peak ≤−3 dBFS. | AC-SFX |
| `sfx_connection_lost` | P1 | `res://assets/audio/sfx/sfx_connection_lost.wav` | Mất kết nối, ngắn dễ phân biệt; WAV PCM16 mono 44.1 kHz, ≤2 s, peak ≤−3 dBFS. | AC-SFX |

### voice

| ID | Ưu tiên | Đường dẫn đích | Đặc tả | Nghiệm thu |
|---|---|---|---|---|
| `vo_npc_gibberish_female` | P0 | `res://assets/audio/vo/vo_npc_gibberish_female_{nn}.wav` | Giọng Cô Ba; 8–12 âm tiết | AC-VOICE |
| `vo_npc_gibberish_male` | P0 | `res://assets/audio/vo/vo_npc_gibberish_male_{nn}.wav` | Giọng Ông Tư; 8–12 âm tiết, trầm | AC-VOICE |
| `vo_dialogue_co_ba_vi` | P1 | `res://assets/audio/vo/vo_dialogue_co_ba_vi.json` | Chỉ mục pack thoại co_ba/vi, chưa có audio: JSON line_id → asset/file riêng từng câu; mọi câu bắt buộc phải có WAV và phụ đề; không tính pack là coverage hoàn thành. | AC-VOICE |
| `vo_dialogue_co_ba_en` | P1 | `res://assets/audio/vo/vo_dialogue_co_ba_en.json` | Chỉ mục pack thoại co_ba/en, chưa có audio: JSON line_id → asset/file riêng từng câu; mọi câu bắt buộc phải có WAV và phụ đề; không tính pack là coverage hoàn thành. | AC-VOICE |
| `vo_dialogue_ong_tu_vi` | P1 | `res://assets/audio/vo/vo_dialogue_ong_tu_vi.json` | Chỉ mục pack thoại ong_tu/vi, chưa có audio: JSON line_id → asset/file riêng từng câu; mọi câu bắt buộc phải có WAV và phụ đề; không tính pack là coverage hoàn thành. | AC-VOICE |
| `vo_dialogue_ong_tu_en` | P1 | `res://assets/audio/vo/vo_dialogue_ong_tu_en.json` | Chỉ mục pack thoại ong_tu/en, chưa có audio: JSON line_id → asset/file riêng từng câu; mọi câu bắt buộc phải có WAV và phụ đề; không tính pack là coverage hoàn thành. | AC-VOICE |
| `vo_dialogue_nam_sau_vi` | P1 | `res://assets/audio/vo/vo_dialogue_nam_sau_vi.json` | Chỉ mục pack thoại nam_sau/vi, chưa có audio: JSON line_id → asset/file riêng từng câu; mọi câu bắt buộc phải có WAV và phụ đề; không tính pack là coverage hoàn thành. | AC-VOICE |
| `vo_dialogue_nam_sau_en` | P1 | `res://assets/audio/vo/vo_dialogue_nam_sau_en.json` | Chỉ mục pack thoại nam_sau/en, chưa có audio: JSON line_id → asset/file riêng từng câu; mọi câu bắt buộc phải có WAV và phụ đề; không tính pack là coverage hoàn thành. | AC-VOICE |
| `vo_dialogue_chi_lan_vi` | P1 | `res://assets/audio/vo/vo_dialogue_chi_lan_vi.json` | Chỉ mục pack thoại chi_lan/vi, chưa có audio: JSON line_id → asset/file riêng từng câu; mọi câu bắt buộc phải có WAV và phụ đề; không tính pack là coverage hoàn thành. | AC-VOICE |
| `vo_dialogue_chi_lan_en` | P1 | `res://assets/audio/vo/vo_dialogue_chi_lan_en.json` | Chỉ mục pack thoại chi_lan/en, chưa có audio: JSON line_id → asset/file riêng từng câu; mọi câu bắt buộc phải có WAV và phụ đề; không tính pack là coverage hoàn thành. | AC-VOICE |
| `vo_dialogue_bay_cho_vi` | P1 | `res://assets/audio/vo/vo_dialogue_bay_cho_vi.json` | Chỉ mục pack thoại bay_cho/vi, chưa có audio: JSON line_id → asset/file riêng từng câu; mọi câu bắt buộc phải có WAV và phụ đề; không tính pack là coverage hoàn thành. | AC-VOICE |
| `vo_dialogue_bay_cho_en` | P1 | `res://assets/audio/vo/vo_dialogue_bay_cho_en.json` | Chỉ mục pack thoại bay_cho/en, chưa có audio: JSON line_id → asset/file riêng từng câu; mọi câu bắt buộc phải có WAV và phụ đề; không tính pack là coverage hoàn thành. | AC-VOICE |
| `vo_dialogue_co_tam_vi` | P1 | `res://assets/audio/vo/vo_dialogue_co_tam_vi.json` | Chỉ mục pack thoại co_tam/vi, chưa có audio: JSON line_id → asset/file riêng từng câu; mọi câu bắt buộc phải có WAV và phụ đề; không tính pack là coverage hoàn thành. | AC-VOICE |
| `vo_dialogue_co_tam_en` | P1 | `res://assets/audio/vo/vo_dialogue_co_tam_en.json` | Chỉ mục pack thoại co_tam/en, chưa có audio: JSON line_id → asset/file riêng từng câu; mọi câu bắt buộc phải có WAV và phụ đề; không tính pack là coverage hoàn thành. | AC-VOICE |


### music

| ID | Ưu tiên | Đường dẫn đích | Đặc tả | Nghiệm thu |
|---|---|---|---|---|
| `mus_isl01_day_loop` | P0 | `res://assets/audio/mus/mus_isl01_day_loop.ogg` | Nhạc đảo 1; 05 §11 | AC-SFX |
| `mus_boss_loop` | P0 | `res://assets/audio/mus/mus_boss_loop.ogg` | Nhạc boss; 05 §11 | AC-SFX |
| `mus_isl02_day_loop` | P1 | `res://assets/audio/mus/mus_isl02_day_loop.ogg` | Nhạc đảo 2 | AC-SFX |
| `mus_isl03_day_loop` | P1 | `res://assets/audio/mus/mus_isl03_day_loop.ogg` | Nhạc đảo 3 | AC-SFX |

### ambience

| ID | Ưu tiên | Đường dẫn đích | Đặc tả | Nghiệm thu |
|---|---|---|---|---|
| `amb_river_day_loop` | P0 | `res://assets/audio/amb/amb_river_day_loop.ogg` | Âm nền sông; Sông, gió, chim | AC-SFX |
| `amb_isl02_day_loop` | P1 | `res://assets/audio/amb/amb_isl02_day_loop.ogg` | Gió rừng dừa, nước và chim nhẹ; nguyên bản/đúng quyền; OGG stereo 44.1 kHz, loop ≥30 s, khoảng −26 LUFS. | AC-SFX |
| `amb_isl03_day_loop` | P1 | `res://assets/audio/amb/amb_isl03_day_loop.ogg` | Sóng biển và gió mũi đá; nguyên bản/đúng quyền; OGG stereo 44.1 kHz, loop ≥30 s, khoảng −26 LUFS. | AC-SFX |

## 8. Thứ tự sản xuất có thể chạy được

1. Phao/cần/tay/cá rô + đảo 1 + vật liệu + UI tối thiểu + vài SFX để chứng minh câu/bán/lưu chạy thật.
2. Thân và clip đồng đội, room/party UI; kiểm 2 rồi 4 người trước khi nhân content.
3. Bổ sung sinh vật, NPC, boss 1, câu chuyện, food/đói và icon bake. Sau đó đủ ba đảo, 15 loài thường và ba boss với đủ clip.
4. Hộp miễn phí/mỹ phẩm phối màu; UI xác suất và xác nhận kết quả. Không cần chờ ảnh mới để làm logic.
5. Nhạc ba đảo/boss, ambient mỗi đảo, SFX/gibberish; thu/tổng hợp và kiểm tất cả dòng thoại vi/en.
6. Đo web build, cắt tài nguyên không dùng, kiểm quyền/CREDITS, kiểm 4 người và voice coverage trước mốc cuối.

Batch hình ChatGPT chạy song song qua người dùng; mọi nhánh độc lập tiếp tục bằng bản procedural. Chưa có thoại hợp lệ không được báo hoàn thành toàn bộ âm thanh. P0/P1 là thứ tự, không tự giảm phạm vi người dùng đã chọn.

## 9. Tiêu chí và bàn giao

- **AC-MDL:** file scene/model thật import được; đúng mét/trục/pivot/size/socket/collider, trong ngân sách tam giác; primitive gộp lưới đạt draw call đo thật; kiểm silhouette và web renderer.
- **AC-ICO:** PNG 256×256 RGBA, lề 8 px, không nền giả, rõ ở 64 px, bake đúng model cuối; icon UI nguyên bản được vẽ vector rồi raster hóa.
- **AC-ANM:** thư viện có clip đúng tên, timing khớp dữ liệu, method track chỉ sự kiện hợp đồng; multiplayer không biến animation thành nguồn quyền gameplay.
- **AC-VFX:** tự kết thúc, pool hữu hạn, không che tín hiệu, không texture/shader unsupported; ≤64 hạt/hiệu ứng và ≤300 hạt cùng lúc là ngân sách ban đầu cần đo ở 4 người.
- **AC-UI:** desktop sizes trong §3, chuột/bàn phím, không chồng HUD, hai ngôn ngữ không tràn, phông đủ dấu; nền tương phản và có focus.
- **AC-SFX:** decode được, thông số đo đúng §5, nghe thật, loop/duck/mix rõ, không clipping, nguồn/quyền đủ.
- **AC-VOICE:** đủ từng dòng bắt buộc × vi/en, file và phụ đề khớp, được nghe kiểm, skip/fallback chạy đúng; gibberish không bù coverage.

Trước import: nhận batch → kiểm ID/path/file magic → tự tính SHA-256 → đo metadata → kiểm nguồn/quyền → import staging → chạy kiểm trong engine/web → ghi review → cập nhật trạng thái. Giữ file gốc và source/script, không ghi đè bản approved khi batch mới lỗi. Chi tiết cùng templates ở `14_AI_ASSET_HANDOFF.md`.
