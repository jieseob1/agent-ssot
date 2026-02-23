-- orchestrator.db 초기화 스키마
-- 사용법: sqlite3 ~/agent-runtime/orchestrator.db < scripts/init.sql
-- 주의: 이 DB 파일은 로컬 전용. 절대 Git에 커밋하지 말 것.

PRAGMA journal_mode=WAL;

CREATE TABLE IF NOT EXISTS tasks (
  task_id    TEXT PRIMARY KEY,
  title      TEXT NOT NULL,
  status     TEXT NOT NULL DEFAULT 'TODO',   -- TODO | IN_PROGRESS | DONE | BLOCKED
  owner      TEXT,
  priority   INTEGER DEFAULT 2,              -- 1=긴급, 2=일반, 3=나중에
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS leases (
  task_id     TEXT PRIMARY KEY,
  owner       TEXT NOT NULL,
  lease_until TEXT NOT NULL                  -- ISO8601 UTC
);

CREATE TABLE IF NOT EXISTS events (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  ts           TEXT NOT NULL DEFAULT (datetime('now')),
  node         TEXT NOT NULL,
  type         TEXT NOT NULL,                -- HEARTBEAT | CLAIM | UPDATE | COMPLETE | SYNC | ERROR | RELEASE
  task_id      TEXT,
  payload_json TEXT
);

CREATE TABLE IF NOT EXISTS heartbeats (
  node      TEXT PRIMARY KEY,
  ts        TEXT NOT NULL,
  status    TEXT NOT NULL,                   -- alive | idle | error
  meta_json TEXT
);

-- 인덱스
CREATE INDEX IF NOT EXISTS idx_events_ts      ON events(ts);
CREATE INDEX IF NOT EXISTS idx_events_node    ON events(node);
CREATE INDEX IF NOT EXISTS idx_events_task_id ON events(task_id);
CREATE INDEX IF NOT EXISTS idx_leases_owner   ON leases(owner);
