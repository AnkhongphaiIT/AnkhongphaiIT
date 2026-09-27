#!/usr/bin/env python3
"""Tạo tài khoản CHECKPOINT cho buổi playtest (docs/10 §4: "account sạch và account checkpoint riêng").

Chỉ dành cho người vận hành máy chủ. Không có endpoint công khai nào làm việc này: công cụ chạy backend
TRONG TIẾN TRÌNH trên cùng file SQLite và đi đúng đường thật của trò chơi:
  đăng ký (API công khai) → tạo phòng → vé vào phòng → room server tiêu vé (API nội bộ, khóa dịch vụ
  ngẫu nhiên chỉ sống trong tiến trình này) → các op mà room server sẽ commit khi người chơi thật làm
  (nhận quà NPC, nói chuyện, nhặt cá, giao cá, nhận thưởng, triệu hồi + thắng boss, nhận thưởng boss)
  → trả lease + đóng phòng tạm.
Mọi thay đổi đi qua op ledger/idempotency/kiểm bất biến save như lúc chơi; không sửa JSON save bằng tay.
Tên đăng nhập luôn bắt đầu bằng `checkpoint_` để phân biệt với người chơi thật; tiến trình tạo bằng công
cụ này KHÔNG được tính là bằng chứng CONTENT-01 (chơi hết 3 đảo) — nó chỉ để người thử vào thẳng một mốc.

  # trong gói máy chủ (cùng .env với backend; nên chạy lúc chưa có người chơi):
  set -a; . ./.env; set +a
  CABAY_DATA_DIR=$PWD/data CABAY_DB_PATH=$PWD/var/cabay.db .venv/bin/python ops/seed_checkpoint.py \
      --stage isl1_boss --stage isl2_start --yes-this-is-an-operator-db

Mốc: isl1_boss (xong nhiệm vụ 1, có mồi trà sữa, sẵn sàng gọi Cá Lóc), isl2_start, isl2_boss,
isl3_start, isl3_boss, endgame. Mật khẩu ngẫu nhiên ghi vào file quyền 600 (mặc định var/checkpoint_accounts.txt);
không in mật khẩu ra màn hình.
"""
from __future__ import annotations

import argparse
import os
import secrets
import sys
import uuid
from pathlib import Path

HERE = Path(__file__).resolve().parent
BACKEND = HERE.parent / "backend"  # repo: server/backend; gói máy chủ: backend/

# Thứ tự mốc; mỗi mốc là các bước làm tiếp từ mốc trước.
STAGES = ["isl1_boss", "isl2_start", "isl2_boss", "isl3_start", "isl3_boss", "endgame"]
# (đảo, nhiệm vụ chuẩn bị, NPC giao, cá cần giao, số lượng, nhiệm vụ boss, boss, vùng gọi boss, vật phẩm rơi)
ISLANDS = [
    ("isl_01_cu_lao", "quest_01_bua_trua", "npc_ong_tu", "cre_ca_ro", 3, "quest_01_trum_song", "boss_ca_loc", "zone_01_boss_spot", "item_golden_scale"),
    ("isl_02_rung_dua", "quest_02_sua_ben", "npc_nam_sau", "cre_ca_thoi_loi", 4, "quest_02_cua_cu", "boss_cua_bun", "zone_02_boss_spot", "item_survey_tag"),
    ("isl_03_mui_da", "quest_03_hoi_cau", "npc_chi_lan", "cre_ca_nuc", 4, "quest_03_ca_bop", "boss_ca_bop", "zone_03_boss_spot", "item_festival_medal"),
]
DISPLAY = {"isl1_boss": "Mốc Đảo 1 Boss", "isl2_start": "Mốc Đảo 2", "isl2_boss": "Mốc Đảo 2 Boss",
           "isl3_start": "Mốc Đảo 3", "isl3_boss": "Mốc Đảo 3 Boss", "endgame": "Mốc Cuối Game"}


class SeedError(RuntimeError):
    pass


class Seeder:
    def __init__(self, client, service_key: str):
        self.c = client
        self.svc = {"X-Service-Key": service_key}

    # ------------------------------------------------------------ HTTP thật (trong tiến trình)
    def _ok(self, r, what: str) -> dict:
        if r.status_code != 200:
            code = ""
            try:
                code = r.json().get("error_code", "")
            except ValueError:
                pass
            raise SeedError(f"{what}: HTTP {r.status_code} {code}")
        return r.json()

    def register(self, username: str, display: str, password: str) -> dict:
        d = self._ok(self.c.post("/v1/auth/register", json={"username": username, "display_name": display, "password": password}), "đăng ký")
        d["auth"] = {"Authorization": f"Bearer {d['access_token']}"}
        return d

    def open_room(self, acc: dict, island_id: str) -> dict:
        room = self._ok(self.c.post("/v1/rooms", json={"island_id": island_id}, headers=acc["auth"]), "tạo phòng")
        ctl = self._ok(self.c.get("/internal/room-controls", headers=self.svc), "đọc lệnh phòng")["controls"]
        acks = [x["control_id"] for x in ctl if x["room_id"] == room["room_id"]]
        self._ok(self.c.post("/internal/room-status", headers=self.svc, json={"acks": acks, "rooms": [
            {"room_id": room["room_id"], "status": "ready", "island_id": island_id, "owner_account_id": acc["account_id"], "members": [acc["account_id"]]}]}), "báo phòng sẵn sàng")
        t = self._ok(self.c.post(f"/v1/rooms/{room['room_id']}/ticket", headers=acc["auth"]), "vé vào phòng")
        lease = self._ok(self.c.post("/internal/tickets/consume", headers=self.svc, json={
            "ticket": t["ticket"], "protocol_version": t["protocol_version"], "content_hash": t["content_hash"],
            "connection_id": str(uuid.uuid4())}), "tiêu vé")
        lease["_island"] = island_id
        return lease

    def close_room(self, lease: dict) -> None:
        self._ok(self.c.post("/internal/room-status", headers=self.svc, json={
            "rooms": [{"room_id": lease["room_id"], "status": "closed", "island_id": lease["_island"], "members": []}],
            "released": [{"account_id": lease["account_id"], "lease_epoch": lease["lease_epoch"], "room_id": lease["room_id"], "reason": "checkpoint_seed"}]}), "đóng phòng tạm")

    def op(self, lease: dict, op_type: str, payload: dict, server_op: bool = False) -> dict:
        """Một op như room server commit; client-op dùng expected_save_version hiện tại (giống hàng đợi bền của client)."""
        body = {"account_id": lease["account_id"], "lease_epoch": lease["lease_epoch"], "room_id": lease["room_id"],
                "op_id": str(uuid.uuid4()), "op_type": op_type, "payload": payload,
                "expected_save_version": None if server_op else lease["save"]["save_version"]}
        res = self._ok(self.c.post("/internal/accounts/commit", headers=self.svc, json=body), op_type)
        if res.get("status") != "committed":
            raise SeedError(f"{op_type} bị từ chối: {res.get('error_code')}")
        lease["save"] = res["save"]
        return res

    def checkpoint_spawn(self, lease: dict, island_id: str, zone_id: str) -> None:
        p = lease["save"]["player"]
        self._ok(self.c.post("/internal/accounts/checkpoint", headers=self.svc, json={
            "account_id": lease["account_id"], "lease_epoch": lease["lease_epoch"], "room_id": lease["room_id"],
            "hunger": p["hunger"], "hp": p["hp"], "safe_island_id": island_id, "safe_spawn_zone_id": zone_id}), "điểm hồi sinh")

    # ------------------------------------------------------------ các bước chơi
    def catch(self, lease: dict, creature: str, n: int) -> list[str]:
        uids = []
        for _ in range(n):
            uid = str(uuid.uuid4())
            self.op(lease, "inventory.pickup", {"item_uid": uid, "fresh_item": {
                "def_kind": "creature", "def_id": creature, "variant_id": None, "trick_mult_milli": 1000, "tricks": []}})
            uids.append(uid)
        return uids

    def prep_quest(self, lease: dict, idx: int) -> None:
        _isl, q_prep, npc, fish, count, *_ = ISLANDS[idx]
        st = lease["save"]["progress"]["quests"].get(q_prep, {}).get("state")
        if st == "available":
            self.op(lease, "quest.accept", {"quest_id": q_prep, "npc_id": npc})  # nhận việc tại người giao: tính luôn bước nói chuyện
        if lease["save"]["progress"]["quests"][q_prep]["step_index"] == 0:
            self.op(lease, "quest.talk", {"npc_id": npc}, server_op=True)
        step = "step_deliver_ca_ro" if idx == 0 else "step_deliver_fish"
        for _ in range(count):  # túi nhỏ: câu con nào giao con đó, như người chơi làm
            uids = self.catch(lease, fish, 1)
            self.op(lease, "quest.deliver", {"quest_id": q_prep, "step_id": step, "npc_id": npc, "item_uids": uids})
        self.op(lease, "quest.claim", {"quest_id": q_prep})
        q_boss = ISLANDS[idx][5]
        if lease["save"]["progress"]["quests"].get(q_boss, {}).get("state") == "available":
            self.op(lease, "quest.accept", {"quest_id": q_boss, "npc_id": npc})

    def win_boss(self, lease: dict, idx: int) -> None:
        _isl, _qp, npc, _f, _n, q_boss, boss, zone, drop = ISLANDS[idx]
        enc = self.op(lease, "boss.summon", {"boss_id": boss, "zone_id": zone})["receipt"]["encounter_id"]
        self.op(lease, "boss.reward", {"encounter_id": enc, "boss_id": boss}, server_op=True)
        item = next((i["uid"] for i in lease["save"]["inventory"]["bag"] if i["def_id"] == drop), None)
        if item is None:
            inbox = next((i["uid"] for i in lease["save"]["inventory"]["recovery_inbox"] if i["def_id"] == drop), None)
            if inbox is None:
                raise SeedError(f"không thấy {drop} sau khi thắng boss")
            self.op(lease, "inventory.pickup", {"item_uid": inbox})
            item = inbox
        self.op(lease, "quest.deliver", {"quest_id": q_boss, "step_id": _deliver_step(idx), "npc_id": npc, "item_uids": [item]})
        self.op(lease, "quest.claim", {"quest_id": q_boss})


def _deliver_step(idx: int) -> str:
    return "step_deliver_scale" if idx == 0 else "step_deliver_badge"


def seed_one(s: Seeder, stage: str, username: str, password: str) -> dict:
    acc = s.register(username, DISPLAY[stage], password)
    target = STAGES.index(stage)
    # mỗi đảo 2 mốc: <đảo>_boss (xong chuẩn bị) rồi <đảo kế>_start (đã thắng boss); isl1_boss=0, isl2_start=1, ...
    lease = s.open_room(acc, ISLANDS[0][0])
    s.op(lease, "npc.gift", {"npc_id": "npc_co_ba"}, server_op=True)
    island_now = 0
    for step in range(target + 1):
        idx = step // 2
        if step % 2 == 0:
            if idx != island_now:
                # sang đảo mới như người chơi đi đò: đóng phòng cũ, mở phòng ở đảo vừa mở khóa
                s.close_room(lease)
                lease = s.open_room(acc, ISLANDS[idx][0])
                island_now = idx
            s.prep_quest(lease, idx)
        else:
            s.win_boss(lease, idx)
    final_idx = min(len(ISLANDS) - 1, (target + 1) // 2)
    isl = ISLANDS[final_idx][0]
    if isl in lease["save"]["progress"]["islands_unlocked"]:
        s.checkpoint_spawn(lease, isl, f"zone_0{final_idx + 1}_spawn")
    save = lease["save"]
    s.close_room(lease)
    return {"stage": stage, "username": username, "account_id": acc["account_id"], "recovery_codes": acc.get("recovery_codes", []),
            "islands": save["progress"]["islands_unlocked"], "bosses": save["progress"]["bosses_defeated"],
            "money": save["currencies"]["money"], "tickets": save["currencies"]["festival_ticket"],
            "baits": {k: v for k, v in save["inventory"]["bait_counts"].items() if v}}


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--stage", action="append", choices=STAGES, required=True)
    ap.add_argument("--prefix", default="checkpoint_", help="tiền tố tên đăng nhập (phải bắt đầu bằng checkpoint_)")
    ap.add_argument("--out", default=None, help="file ghi thông tin đăng nhập (quyền 600)")
    ap.add_argument("--yes-this-is-an-operator-db", action="store_true", help="xác nhận đang chạy trên DB máy chủ mình quản lý")
    a = ap.parse_args(argv)
    if not a.yes_this_is_an_operator_db:
        print("Từ chối: thêm --yes-this-is-an-operator-db để xác nhận (công cụ ghi vào DB backend).", file=sys.stderr)
        return 2
    if not a.prefix.startswith("checkpoint_"):
        print("Từ chối: tiền tố phải bắt đầu bằng checkpoint_", file=sys.stderr)
        return 2
    db = os.environ.get("CABAY_DB_PATH")
    if not db or not Path(db).exists():
        print("Thiếu CABAY_DB_PATH trỏ tới DB đã được backend khởi tạo (chạy backend một lần trước).", file=sys.stderr)
        return 2
    # Khóa dịch vụ riêng của tiến trình này (không ghi đĩa, không in); API nội bộ chỉ gọi trong tiến trình.
    os.environ["CABAY_SERVICE_KEY"] = secrets.token_urlsafe(32)
    sys.path.insert(0, str(BACKEND))
    from app import config  # noqa: E402
    config.reload_settings()
    import app.db, app.security, app.deps, app.save  # noqa: E402,E401
    for m in (app.db, app.security, app.deps, app.save):
        m.settings = config.settings
    from fastapi.testclient import TestClient  # noqa: E402
    from app.main import app as fastapi_app  # noqa: E402

    # Không dùng `with TestClient(...)`: không chạy lifespan (tránh quét/hoàn mồi trận boss của phòng đang chạy thật).
    client = TestClient(fastapi_app, base_url="http://127.0.0.1")
    s = Seeder(client, os.environ["CABAY_SERVICE_KEY"])
    out = Path(a.out) if a.out else Path(db).parent / "checkpoint_accounts.txt"
    results = []
    for stage in a.stage:
        username = (a.prefix + stage.replace("_", "") + secrets.token_hex(2))[:24]
        password = secrets.token_urlsafe(12)
        try:
            r = seed_one(s, stage, username, password)
        except SeedError as e:
            print(f"SEED_FAIL {stage}: {e}", file=sys.stderr)
            return 1
        r["password"] = password
        results.append(r)
        print(f"SEED_OK {stage} user={username} đảo={len(r['islands'])} boss={len(r['bosses'])} tiền={r['money']} vé={r['tickets']} mồi={r['baits']}")
    fd = os.open(out, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
    with os.fdopen(fd, "a", encoding="utf-8") as f:
        for r in results:
            f.write(f"{r['stage']}\t{r['username']}\t{r['password']}\trecovery={','.join(r['recovery_codes'])}\n")
    os.chmod(out, 0o600)
    print(f"Thông tin đăng nhập ghi vào {out} (quyền 600). Xóa file sau buổi playtest.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
