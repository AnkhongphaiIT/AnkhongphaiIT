-- CÁ BAY backend schema v1 (07 §7). Không lưu secret dạng rõ.
CREATE TABLE accounts (
  account_id TEXT PRIMARY KEY,
  username TEXT NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  created_at TEXT NOT NULL
);
CREATE TABLE credentials (
  account_id TEXT PRIMARY KEY REFERENCES accounts(account_id) ON DELETE CASCADE,
  algo TEXT NOT NULL,
  params TEXT NOT NULL,
  salt BLOB NOT NULL,
  digest BLOB NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE TABLE recovery_codes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  account_id TEXT NOT NULL REFERENCES accounts(account_id) ON DELETE CASCADE,
  salt BLOB NOT NULL,
  digest BLOB NOT NULL,
  created_at TEXT NOT NULL,
  used_at TEXT
);
CREATE INDEX recovery_codes_account ON recovery_codes(account_id);
CREATE TABLE sessions (
  session_id TEXT PRIMARY KEY,
  account_id TEXT NOT NULL REFERENCES accounts(account_id) ON DELETE CASCADE,
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  last_auth_at INTEGER NOT NULL,
  revoked_at INTEGER
);
CREATE INDEX sessions_account ON sessions(account_id);
CREATE TABLE access_tokens (
  token_hash TEXT PRIMARY KEY,
  session_id TEXT NOT NULL REFERENCES sessions(session_id) ON DELETE CASCADE,
  expires_at INTEGER NOT NULL
);
CREATE TABLE refresh_tokens (
  token_hash TEXT PRIMARY KEY,
  session_id TEXT NOT NULL REFERENCES sessions(session_id) ON DELETE CASCADE,
  expires_at INTEGER NOT NULL,
  used_at INTEGER
);
CREATE TABLE rooms (
  room_id TEXT PRIMARY KEY,
  invite_code TEXT NOT NULL UNIQUE,
  owner_account_id TEXT,
  island_id TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('requested','ready','closed')),
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
CREATE TABLE room_members (
  room_id TEXT NOT NULL REFERENCES rooms(room_id) ON DELETE CASCADE,
  account_id TEXT NOT NULL REFERENCES accounts(account_id) ON DELETE CASCADE,
  reserved_at INTEGER NOT NULL,
  connected INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (room_id, account_id)
);
CREATE TABLE room_tickets (
  ticket_hash TEXT PRIMARY KEY,
  account_id TEXT NOT NULL REFERENCES accounts(account_id) ON DELETE CASCADE,
  room_id TEXT NOT NULL REFERENCES rooms(room_id) ON DELETE CASCADE,
  session_id TEXT NOT NULL,
  protocol_version TEXT NOT NULL,
  expires_at INTEGER NOT NULL,
  consumed_at INTEGER
);
CREATE TABLE room_controls (
  control_id INTEGER PRIMARY KEY AUTOINCREMENT,
  room_id TEXT,
  kind TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  acked_at INTEGER
);
CREATE TABLE account_saves (
  account_id TEXT PRIMARY KEY REFERENCES accounts(account_id) ON DELETE CASCADE,
  schema_version TEXT NOT NULL,
  save_version INTEGER NOT NULL CHECK (save_version >= 1),
  state_json TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE TABLE gameplay_leases (
  account_id TEXT PRIMARY KEY REFERENCES accounts(account_id) ON DELETE CASCADE,
  room_id TEXT,
  session_id TEXT,
  epoch INTEGER NOT NULL DEFAULT 0,
  connection_id TEXT,
  active INTEGER NOT NULL DEFAULT 0,
  updated_at INTEGER NOT NULL
);
-- Vị trí logic duy nhất của mỗi UID vật phẩm (07 §7, 08 §5).
CREATE TABLE item_registry (
  item_uid TEXT PRIMARY KEY,
  owner_account_id TEXT NOT NULL,
  def_kind TEXT NOT NULL,
  def_id TEXT NOT NULL,
  state TEXT NOT NULL CHECK (state IN ('bag','escrow','inbox','cooking','sold','consumed','delivered','cooked')),
  room_id TEXT,
  station_id TEXT,
  state_since INTEGER NOT NULL,
  instance_json TEXT NOT NULL
);
CREATE INDEX item_registry_owner ON item_registry(owner_account_id, state);
CREATE TABLE operations (
  account_id TEXT NOT NULL,
  op_id TEXT NOT NULL,
  op_type TEXT NOT NULL,
  payload_hash TEXT NOT NULL,
  result_json TEXT NOT NULL,
  committed_at INTEGER NOT NULL,
  PRIMARY KEY (account_id, op_id)
);
CREATE TABLE reward_claims (
  account_id TEXT NOT NULL,
  claim_key TEXT NOT NULL,
  reward_kind TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (account_id, claim_key, reward_kind)
);
CREATE TABLE boss_attempts (
  encounter_id TEXT PRIMARY KEY,
  account_id TEXT NOT NULL,
  boss_id TEXT NOT NULL,
  bait_id TEXT NOT NULL,
  room_id TEXT,
  status TEXT NOT NULL CHECK (status IN ('open','defeated','refunded')),
  created_at INTEGER NOT NULL,
  resolved_at INTEGER
);
CREATE TABLE lootbox_receipts (
  receipt_id TEXT PRIMARY KEY,
  account_id TEXT NOT NULL,
  op_id TEXT NOT NULL,
  box_id TEXT NOT NULL,
  table_version TEXT NOT NULL,
  roll INTEGER NOT NULL,
  cosmetic_id TEXT NOT NULL,
  outcome TEXT NOT NULL CHECK (outcome IN ('new','duplicate')),
  dust_granted INTEGER NOT NULL,
  balance_before TEXT NOT NULL,
  balance_after TEXT NOT NULL,
  created_at TEXT NOT NULL
);
CREATE TABLE audit_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  account_id TEXT,
  kind TEXT NOT NULL,
  detail TEXT NOT NULL,
  created_at TEXT NOT NULL
);
