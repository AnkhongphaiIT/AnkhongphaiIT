# ASSET_COVERAGE — độ phủ tài nguyên (sinh tự động từ file thật)

Cập nhật: 2026-09-27 bằng `tools/asset_generation/sync_asset_status.py`. Tổng asset ID: 287; file thật đã băm: 266.
`in_review` = file thật do dự án tự tạo, đã kiểm tự động, **chưa có người duyệt bằng mắt/tai**; `placeholder` = bản tạm không phát hành; `planned` = chưa có file.

| Loại | planned | placeholder | in_review | approved | deprecated | Tổng |
|---|---|---|---|---|---|---|
| ambience | 0 | 0 | 3 | 0 | 0 | 3 |
| anim_clip | 60 | 0 | 0 | 0 | 0 | 60 |
| anim_library | 7 | 0 | 0 | 0 | 0 | 7 |
| environment | 0 | 0 | 3 | 0 | 0 | 3 |
| font | 0 | 0 | 0 | 1 | 0 | 1 |
| icon | 0 | 0 | 32 | 0 | 0 | 32 |
| material | 0 | 0 | 2 | 0 | 0 | 2 |
| model | 0 | 0 | 54 | 0 | 0 | 54 |
| music | 0 | 0 | 4 | 0 | 0 | 4 |
| sfx | 0 | 0 | 59 | 0 | 0 | 59 |
| shader | 0 | 0 | 4 | 0 | 0 | 4 |
| texture | 1 | 0 | 0 | 0 | 0 | 1 |
| ui | 2 | 0 | 21 | 0 | 1 | 24 |
| vfx | 19 | 0 | 0 | 0 | 0 | 19 |
| voice | 0 | 12 | 2 | 0 | 0 | 14 |
| **Tổng** | **89** | **12** | **184** | **1** | **1** | **287** |

Thoại rõ nghĩa: 62/62 dòng × ngôn ngữ có file, **tất cả là bản tạm espeak-ng (placeholder)** → yêu cầu giọng đọc VI/EN chưa đạt (NEED-VOICE-LICENSE / voice_v1).

Còn `planned`:

- `tex_palette_main` (texture, P0)
- `vfx_fishing_line` (vfx, P0)
- `vfx_lure_splash` (vfx, P0)
- `vfx_bobber_ripple` (vfx, P0)
- `vfx_bite_splash` (vfx, P0)
- `vfx_yank_burst` (vfx, P0)
- `vfx_air_trail` (vfx, P0)
- `vfx_hit_confetti` (vfx, P0)
- `vfx_ko_stars` (vfx, P0)
- `vfx_trick_text` (vfx, P0)
- `vfx_coin_burst` (vfx, P0)
- `vfx_boss_telegraph_ring` (vfx, P0)
- `vfx_escape_bubbles` (vfx, P0)
- `vfx_bite_indicator` (vfx, P0)
- `vfx_attack_warn` (vfx, P0)
- `vfx_cast_preview` (vfx, P0)
- `ui_damage_vignette` (ui, P0)
- `ui_logo_placeholder` (ui, P0)
- `anm_lib_fp` (anim_library, P0)
- `anm_lib_npc_basic` (anim_library, P0)
- `anm_lib_boss_ca_loc` (anim_library, P0)
- `anm_fp_idle` (anim_clip, P0)
- `anm_fp_equip` (anim_clip, P0)
- `anm_fp_cast_charge` (anim_clip, P0)
- `anm_fp_cast_release` (anim_clip, P0)
- `anm_fp_reel_loop` (anim_clip, P0)
- `anm_fp_yank` (anim_clip, P0)
- `anm_fp_slap` (anim_clip, P0)
- `anm_fp_throw` (anim_clip, P0)
- `anm_fp_sweep` (anim_clip, P0)
- `anm_fp_pickup` (anim_clip, P0)
- `anm_npc_idle` (anim_clip, P0)
- `anm_npc_talk` (anim_clip, P0)
- `anm_npc_happy` (anim_clip, P0)
- `anm_npc_disgust` (anim_clip, P0)
- `anm_boss_ca_loc_land` (anim_clip, P0)
- `anm_boss_ca_loc_idle` (anim_clip, P0)
- `anm_boss_ca_loc_telegraph_slam` (anim_clip, P0)
- `anm_boss_ca_loc_slam` (anim_clip, P0)
- `anm_boss_ca_loc_telegraph_charge` (anim_clip, P0)
- `anm_boss_ca_loc_charge` (anim_clip, P0)
- `anm_boss_ca_loc_stunned` (anim_clip, P0)
- `anm_boss_ca_loc_telegraph_spit` (anim_clip, P0)
- `anm_boss_ca_loc_spit` (anim_clip, P0)
- `anm_boss_ca_loc_phase_change` (anim_clip, P0)
- `anm_boss_ca_loc_escape` (anim_clip, P0)
- `anm_boss_ca_loc_defeat` (anim_clip, P0)
- `vfx_smoke_grill` (vfx, P1)
- `anm_lib_egret` (anim_library, P1)
- `anm_egret_walk` (anim_clip, P1)
- `anm_egret_fly` (anim_clip, P1)
- `vfx_boba_sparkle` (vfx, P1)
- `vfx_confetti_explosion` (vfx, P1)
- `anm_lib_boss_cua_bun` (anim_library, P1)
- `anm_boss_cua_bun_land` (anim_clip, P1)
- `anm_boss_cua_bun_idle` (anim_clip, P1)
- `anm_boss_cua_bun_phase_change` (anim_clip, P1)
- `anm_boss_cua_bun_escape` (anim_clip, P1)
- `anm_boss_cua_bun_defeat` (anim_clip, P1)
- `anm_boss_cua_bun_telegraph_slam` (anim_clip, P1)
- `anm_boss_cua_bun_slam` (anim_clip, P1)
- `anm_boss_cua_bun_telegraph_charge` (anim_clip, P1)
- `anm_boss_cua_bun_charge` (anim_clip, P1)
- `anm_boss_cua_bun_stunned` (anim_clip, P1)
- `anm_boss_cua_bun_telegraph_spit` (anim_clip, P1)
- `anm_boss_cua_bun_spit` (anim_clip, P1)
- `anm_lib_boss_ca_bop` (anim_library, P1)
- `anm_boss_ca_bop_land` (anim_clip, P1)
- `anm_boss_ca_bop_idle` (anim_clip, P1)
- `anm_boss_ca_bop_phase_change` (anim_clip, P1)
- `anm_boss_ca_bop_escape` (anim_clip, P1)
- `anm_boss_ca_bop_defeat` (anim_clip, P1)
- `anm_boss_ca_bop_telegraph_slam` (anim_clip, P1)
- `anm_boss_ca_bop_slam` (anim_clip, P1)
- `anm_boss_ca_bop_telegraph_charge` (anim_clip, P1)
- `anm_boss_ca_bop_charge` (anim_clip, P1)
- `anm_boss_ca_bop_stunned` (anim_clip, P1)
- `anm_boss_ca_bop_telegraph_spit` (anim_clip, P1)
- `anm_boss_ca_bop_spit` (anim_clip, P1)
- `anm_lib_player_remote` (anim_library, P0)
- `anm_player_remote_idle` (anim_clip, P0)
- `anm_player_remote_walk` (anim_clip, P0)
- `anm_player_remote_run` (anim_clip, P0)
- `anm_player_remote_cast` (anim_clip, P0)
- `anm_player_remote_reel` (anim_clip, P0)
- `anm_player_remote_use_tool` (anim_clip, P0)
- `anm_player_remote_knocked_out` (anim_clip, P0)
- `anm_player_remote_revive` (anim_clip, P0)
- `vfx_lootbox_reveal` (vfx, P1)
