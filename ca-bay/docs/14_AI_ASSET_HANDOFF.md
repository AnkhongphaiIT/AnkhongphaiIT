# 14 — QUY TRÌNH TÀI NGUYÊN 0 ĐỒNG VÀ CHUYỂN YÊU CẦU CHO CHATGPT

## 1. Ranh giới đã chốt

Claude Code tự tạo thư mục, source, công cụ sản xuất/import/kiểm tra và tài nguyên bằng code. ChatGPT Plus được dùng qua **người dùng chuyển yêu cầu và file thủ công**. Không dùng OpenAI API trả phí, không mua credit, không tự động đăng nhập hay điều khiển website ChatGPT để vượt bước bàn giao. Không cần đưa mật khẩu, cookie hoặc khóa riêng vào dự án.

ChatGPT hỗ trợ concept, ảnh tham khảo nguyên bản, bảng màu, phác UI, nội dung brief và kịch bản âm thanh/thoại. Khả năng tạo file cụ thể tùy công cụ hiện có của phiên; ảnh không trở thành mesh 3D, bản mô tả âm thanh không trở thành WAV. Nếu không có đầu ra đó, chuyển sang phương án miễn phí bên dưới và ghi rõ trạng thái. Không tự báo đã tạo tài nguyên khi chỉ có prompt hoặc liên kết không tải được.

## 2. Kiểm tra đầu vào trước khi dựng

Đọc registry, kiểm tra file thật, danh mục phần mềm, đường dẫn Godot/export template, công cụ âm thanh, dung lượng và phiên bản sẵn có. Kiểm tra đúng năng lực và giấy phép của công cụ/model đã chọn tại thời điểm dùng. Bộ tài liệu hiện tại chưa có media; đây là việc phải sản xuất, không yêu cầu người dùng tự gửi đủ hàng trăm file mới được bắt đầu.

Lập một báo cáo `handoff/preflight_report.md` gồm: tài nguyên có thật, việc Claude tự tạo được, việc cần người dùng cung cấp, thiếu sót chỉ chặn một hạng mục và việc còn làm tiếp được. Chỉ yêu cầu người dùng những thứ Claude không thể tự giải quyết: file sở hữu riêng, đồng ý dùng giọng ghi âm, relay ChatGPT, thông tin tài khoản hoặc quyết định không thể suy ra. Không xin lại các quyết định đã chốt.

## 3. Sản xuất miễn phí theo thứ tự

| Bước | Claude tự thực hiện | Vai trò ChatGPT/người dùng | Kết quả kiểm được |
|---|---|---|---|
| 1. Bộ mẫu | Màu, shader đơn giản, mesh khối, phao, cần, một cá, tay FP | Duyệt 1 bảng concept khi cần | Slice chạy được bằng tài nguyên nguyên bản |
| 2. Hình 3D | Mesh procedural Godot hoặc script Blender nếu cài sẵn/được phép; gộp lưới, socket, collider | Ảnh concept làm tham khảo; chỉnh hướng thẩm mỹ | Cảnh 3D import được, đúng kích thước và ngân sách |
| 3. Chuyển động | Track biến đổi hoặc node animation, mô phỏng quẫy; tạo mô hình đồng đội | Clip tham khảo nếu người dùng có quyền | Chạy thật ở camera mình và camera đồng đội |
| 4. 2D/UI | Theme, layout, vector nguyên bản; bake icon từ model | Concept menu, ảnh quảng bá nếu hữu ích | PNG/font/UI có nguồn, alpha và chữ đúng |
| 5. SFX/nhạc | Tổng hợp nguyên bản bằng oscillator/noise/envelope, phối giai điệu riêng; xuất WAV/OGG offline | ChatGPT viết mô tả nhịp/nhạc hoặc mã đề xuất để Claude rà soát | File nghe được, vòng lặp ổn, không phụ thuộc API/runtime audio chưa thử |
| 6. Voice | Chốt script và CSV từng dòng/locale; thu người tình nguyện hoặc local TTS hợp lệ | Người dùng thu giọng có đồng ý hoặc hỗ trợ relay công cụ hiện có | WAV riêng từng dòng Việt/Anh, phụ đề khớp |
| 7. Mở rộng | Nhân pipeline ra 3 đảo/15 loài/3 boss, đói và mỹ phẩm | Chỉ relay các batch cần ảnh mới | Coverage và nghiệm thu thực tế |

Công cụ mã nguồn mở/miễn phí không tự động làm mọi model, sample, soundfont hay giọng đi kèm thành tài nguyên được phép phát hành. Lưu giấy phép cụ thể của từng đầu vào, kiểm tra quyền dùng và phân phối đầu ra. Với TTS phải kiểm cả phần mềm, trọng số model, giọng và hạn chế sử dụng; không suy luận từ giấy phép repository. Nếu thiếu bằng chứng thì giữ `license: tbd`, không đưa file đó vào bản phát hành và dùng tự tạo/ghi âm có quyền làm phương án thay thế. Không clone giọng người thật khi chưa có sự đồng ý phù hợp.

## 4. Thư mục bàn giao

```text
handoff/
  README.md
  templates/
    batch_manifest.template.json
    batch_request.template.md
    voice_lines.template.csv
    source_record.template.json
  source_manifest.json
  preflight_report.md                 # Claude tạo sau khi kiểm máy thật
  requests/<batch_id>/request.md      # yêu cầu cụ thể xuất cho người dùng
  incoming/<batch_id>/                # người dùng chép file nhận được vào đây
  validated/<batch_id>/               # bản gốc đã kiểm, chưa ghi đè tài nguyên
  rejected/<batch_id>/report.md        # báo lỗi; giữ file gốc để sửa
  reports/<batch_id>.json             # checksum, thông số, pass/fail và lý do
art_src/                             # nguồn có thể tái tạo; ngoài bản web
assets/                              # chỉ đầu ra được phép dùng trong game
```

Các đường dẫn trên là cấu trúc mà Claude tạo trong **dự án game tương lai**; chỉ templates và source manifest kế hoạch được cung cấp trong ZIP tài liệu. Không coi thư mục/filename trong ví dụ là file đã có.

## 5. Batch yêu cầu gửi ChatGPT

Claude gom tối đa 4–6 concept liên quan mỗi batch. Mỗi mục có `request_id`, `asset_id` mục tiêu, `deliverable_kind`, phiên bản, mục đích, camera, tỷ lệ, màu, nền, kích thước đề nghị, hạn chế và cách duyệt. Dùng `prompts/CHATGPT_ASSET_REQUEST.md` và template đi kèm. Ghi rõ file là **concept_only** hay **runtime_candidate**. Mọi concept model đều là `concept_only` dù hình đẹp.

Thứ tự hữu ích: một bảng style làng chài → tay/cần/cá mẫu → ba đảo → nhóm loài/boss → UI/ảnh quảng bá. Icon cuối không gửi vẽ riêng khi đã có quy trình bake model. Không yêu cầu ChatGPT tạo chữ tiếng Việt nằm trong ảnh UI.

Người dùng dán prompt, nhận ảnh/file nếu phiên hỗ trợ, tải về và chép vào `incoming/<batch_id>`. Claude đọc **file đã xuất hiện thật**, đối chiếu ID và nhập. Nếu ChatGPT chỉ trả lời văn bản, lưu làm brief/script, không đặt phần mở rộng `.png/.wav/.glb` giả. Có thể tiếp tục game bằng bản procedural trong lúc chờ batch.

## 6. Hợp đồng nhập và kiểm tra

Manifest có đường dẫn tương đối trong batch; cấm `..`, đường dẫn tuyệt đối và liên kết ra ngoài thư mục incoming. Không thực thi macro, script hoặc lệnh đi kèm đầu ra AI. Mã đề xuất chỉ được xem như dữ liệu để rà soát trước khi viết vào công cụ dự án.

1. Kiểm tra `batch_id`, `request_id`, ID tồn tại trong registry, loại và phiên bản phù hợp; chặn ID trùng hoặc file ngoài danh sách. File nhiều frame/variant phải có chỉ số rõ.
2. Đọc byte để nhận dạng định dạng thật, đối chiếu đuôi/MIME, kích thước file và file rỗng. Claude tự tính SHA-256 cho mỗi file; không tin checksum do manifest đầu vào tự khai. Lưu cả hash khai báo và hash đo; sai thì từ chối.
3. Ảnh: đo chiều rộng/cao, kênh màu/alpha, không hỏng, không viền trắng không mong muốn. Icon cuối 256×256 RGBA; concept chỉ theo kích thước batch. Ảnh to không tự coi là có quyền dùng hay đúng style.
4. Audio: giải mã thật; đo sample rate, channels, bit depth, duration, peak và loudness nếu có công cụ; kiểm silence, clipping, loop/click và nghe tay. WAV SFX/voice mono 44.1 kHz PCM16 theo `06`; nhạc/ambient OGG stereo 44.1 kHz. Không chỉ sửa đuôi file.
5. 3D: chỉ nhận model thật; import thử vào Godot, đo AABB, số tam giác, vật liệu, transform, socket, collider và animation. Ảnh concept không qua nhánh 3D. Không chạy mã nhúng lạ khi mở scene/script.
6. Nguồn: có author/source/tool/version, ngày tạo/tải, URL điều khoản hoặc license file, license scope và bằng chứng quyền của giọng nếu có; không chứa bí mật. Thiếu bằng chứng → chưa duyệt phát hành.
7. Ghi báo cáo, giữ bản gốc, tạo biến thể chuyển đổi có hash mới, import vào nhánh staging. Chạy kiểm game rồi cập nhật registry; không ghi đè bản `approved` trước khi bản mới vượt kiểm tra.

SHA-256 và metadata chỉ được điền sau khi đọc file thật. Giá trị `null` trong templates là chưa biết, không phải pass. Mọi chuyển đổi ảnh/âm thanh giữ liên hệ với file gốc trong manifest. Bản ghi planned có `files: []`, không có URL/hàm băm giả.

## 7. Voice Việt/Anh bắt buộc ở bản cuối

CSV script tối thiểu có `line_id,npc_id,locale,text,asset_id,emotion,status,source_record_id`. Mỗi câu có ID ổn định và hai hàng `vi`/`en`, không ghép hai ngôn ngữ trong cùng audio. Voice registry có một ID/file cho từng dòng hoặc một pack có bảng ánh xạ dòng minh bạch; báo cáo coverage đếm **dòng × ngôn ngữ**, không đếm pack.

Sáu NPC trong `data/content/npcs.json` có pack giọng riêng mỗi ngôn ngữ: Cô Ba (`npc_co_ba`), Ông Tư (`npc_ong_tu`), Bảy Chợ (`npc_bay_cho`), Cô Tám (`npc_co_tam`), Nam Sáu (`npc_nam_sau`) và Chị Lan (`npc_chi_lan`). Có 12 pack thoại rõ nghĩa dự kiến, tách khỏi 2 bộ gibberish dùng chung. Pack planned là chỗ giữ danh mục, chưa xác nhận diễn viên hay model TTS. Khi script đã đóng, Claude mở rộng từng dòng cụ thể và ghi file thật. Không dùng tên nghệ sĩ/người quen làm chỉ dẫn mô phỏng giọng.

Trạng thái: `script_missing` → `script_ready` → `audio_missing` → `in_review` → `approved`. `fallback_gibberish` là ghi chú ở bản phát triển, không trạng thái hoàn thành. Điều kiện cuối: tất cả câu bắt buộc có phụ đề và audio nghe được cho cả hai ngôn ngữ, phát/skip đúng, mix rõ, giấy phép/đồng ý lưu đủ. Nếu chưa có phương án 0 đồng phù hợp, tiếp tục phần game khác và báo đúng các câu còn thiếu; không báo game hoàn tất đầy đủ.


| NPC ID | Pack Việt | Pack Anh |
|---|---|---|
| `npc_co_ba` | `vo_dialogue_co_ba_vi` | `vo_dialogue_co_ba_en` |
| `npc_ong_tu` | `vo_dialogue_ong_tu_vi` | `vo_dialogue_ong_tu_en` |
| `npc_bay_cho` | `vo_dialogue_bay_cho_vi` | `vo_dialogue_bay_cho_en` |
| `npc_co_tam` | `vo_dialogue_co_tam_vi` | `vo_dialogue_co_tam_en` |
| `npc_nam_sau` | `vo_dialogue_nam_sau_vi` | `vo_dialogue_nam_sau_en` |
| `npc_chi_lan` | `vo_dialogue_chi_lan_vi` | `vo_dialogue_chi_lan_en` |

Trường `assets.voice` hiện tại trong dữ liệu NPC trỏ đến gibberish dùng để dự phòng phát triển. Thoại rõ nghĩa phải được DialogueController tra bằng NPC ID + locale theo bảng trên và `line_id` từ khóa lời thoại; không phát cả pack như một file âm thanh. Sau khi triển khai, chỉ báo hoàn thành khi mỗi dòng bắt buộc của cả 6 NPC đã có audio thật ở cả hai ngôn ngữ.

## 8. Quyền và truy nguồn

`handoff/source_manifest.json` giữ một bản ghi cho mỗi asset ID với trạng thái ban đầu planned. Khi có file, bổ sung nguồn thật theo `source_record.template.json`; thư viện nội bộ/shared file ghi đủ các ID dùng chung. `license: self_made` chỉ dành cho tài nguyên thực sự tạo nguyên bản; không gán cho sample tải về hay giọng TTS chưa kiểm. `verified_custom` dùng khi đã lưu và kiểm một điều khoản phù hợp khác; `tbd` không được phát hành.

Giấy phép của file ảnh tạo trong ChatGPT phải được kiểm theo điều khoản áp dụng tài khoản tại thời điểm tạo; không gán CC0 tự động. Nguồn third party kèm attribution nếu điều khoản yêu cầu. `CREDITS.md` và danh mục license phải được tạo từ dữ liệu đã duyệt. Không khẳng định mọi công cụ miễn phí đều được dùng thương mại.

## 9. Báo tiến độ trung thực

Mỗi mốc báo: bao nhiêu ID planned/placeholder/in_review/approved, bao nhiêu file thật, bao nhiêu dòng voice mỗi ngôn ngữ còn thiếu, batch nào chờ relay và tính năng nào vẫn chạy. Tổng ID không thay thế tổng file. Không yêu cầu người dùng trả tiền để giải quyết thiếu tài nguyên trong phạm vi ngân sách 0 đã chốt. Nếu một phần không thể hoàn tất với lựa chọn hiện tại, ghi giới hạn và đề nghị lựa chọn cụ thể, trong khi hoàn thành các phần không bị phụ thuộc.
