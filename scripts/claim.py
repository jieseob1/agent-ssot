#!/usr/bin/env python3
"""
claim.py — Task 선점(claim/lease) 스크립트
사용법:
  NODE_ID=PublicJQ REPO_DIR=~/develop/agent-ssot python3 scripts/claim.py

환경변수:
  NODE_ID       이 노드의 식별자 (기본값: hostname)
  REPO_DIR      Git SSOT 레포 경로
  DB_PATH       로컬 orchestrator.db 경로
  LEASE_MINUTES lease 유지 시간(분), 기본값 30
"""

import os, re, sqlite3, json, subprocess
from datetime import datetime, timedelta, timezone
from pathlib import Path

NODE_ID       = os.environ.get("NODE_ID", os.uname().nodename)
REPO_DIR      = Path(os.environ.get("REPO_DIR", Path.home() / "develop/agent-ssot"))
DB_PATH       = Path(os.environ.get("DB_PATH", Path.home() / "agent-runtime/orchestrator.db"))
LEASE_MINUTES = int(os.environ.get("LEASE_MINUTES", "30"))

TASK_FILE = REPO_DIR / "tasks" / "task_queue.md"

# task_queue.md 한 줄 파싱 정규식
TASK_RE = re.compile(
    r"^- \[ \] (T-\d+)\s*\|\s*P(\d+)\s*\|\s*owner=(.*?)\s*\|\s*status=(.*?)\s*\|\s*(.+)$"
)

def now_utc() -> datetime:
    return datetime.now(timezone.utc)

def iso(dt: datetime) -> str:
    return dt.isoformat()

def log_event(conn, typ: str, task_id: str = None, payload: dict = None):
    conn.execute(
        "INSERT INTO events(ts,node,type,task_id,payload_json) VALUES (?,?,?,?,?)",
        (iso(now_utc()), NODE_ID, typ, task_id, json.dumps(payload or {}, ensure_ascii=False))
    )

def try_lease(conn, task_id: str) -> bool:
    """lease가 없거나 만료됐으면 선점. 성공시 True."""
    cur = conn.execute("SELECT owner, lease_until FROM leases WHERE task_id=?", (task_id,))
    row = cur.fetchone()
    new_until = iso(now_utc() + timedelta(minutes=LEASE_MINUTES))

    if row is None:
        conn.execute(
            "INSERT INTO leases(task_id,owner,lease_until) VALUES (?,?,?)",
            (task_id, NODE_ID, new_until)
        )
        return True

    owner, until_str = row
    if datetime.fromisoformat(until_str) <= now_utc():
        conn.execute(
            "UPDATE leases SET owner=?,lease_until=? WHERE task_id=?",
            (NODE_ID, new_until, task_id)
        )
        return True

    print(f"[CLAIM] {task_id} 는 {owner}가 이미 lease 중 (만료: {until_str})")
    return False

def update_task_file(task_id: str, title: str) -> bool:
    """task_queue.md 에서 해당 task의 owner/status 업데이트."""
    lines = TASK_FILE.read_text(encoding="utf-8").splitlines()
    updated = []
    found = False
    for line in lines:
        m = TASK_RE.match(line.strip())
        if m and m.group(1) == task_id:
            new_line = f"- [ ] {task_id} | P{m.group(2)} | owner={NODE_ID} | status=IN_PROGRESS | {m.group(5)}"
            updated.append(new_line)
            found = True
        else:
            updated.append(line)
    if found:
        TASK_FILE.write_text("\n".join(updated) + "\n", encoding="utf-8")
    return found

def git_commit_and_push(task_id: str):
    subprocess.run(["git", "-C", str(REPO_DIR), "pull", "--rebase", "origin", "main"], check=True)
    subprocess.run(["git", "-C", str(REPO_DIR), "add", str(TASK_FILE)], check=True)
    subprocess.run([
        "git", "-C", str(REPO_DIR), "commit",
        "-m", f"claim: {task_id} by {NODE_ID}"
    ], check=True)
    subprocess.run(["git", "-C", str(REPO_DIR), "push", "origin", "main"], check=True)

def main():
    if not TASK_FILE.exists():
        print(f"[ERROR] task_queue.md not found: {TASK_FILE}")
        return

    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(DB_PATH))

    # git pull --rebase 먼저
    print("[CLAIM] git pull --rebase...")
    subprocess.run(["git", "-C", str(REPO_DIR), "pull", "--rebase", "origin", "main"], check=True)

    lines = TASK_FILE.read_text(encoding="utf-8").splitlines()
    candidates = []
    for line in lines:
        m = TASK_RE.match(line.strip())
        if m and m.group(3).strip() == "" and m.group(4).strip() == "TODO":
            candidates.append((int(m.group(2)), m.group(1), m.group(5).strip()))  # (priority, id, title)

    if not candidates:
        print("[CLAIM] 선점 가능한 Task 없음.")
        conn.close()
        return

    candidates.sort(key=lambda x: x[0])  # 우선순위 오름차순(P1 먼저)

    with conn:
        for priority, task_id, title in candidates:
            if try_lease(conn, task_id):
                print(f"[CLAIM] {task_id} 선점 성공 (priority=P{priority}): {title}")
                log_event(conn, "CLAIM", task_id, {"title": title, "priority": priority})
                update_task_file(task_id, title)
                conn.execute(
                    "INSERT OR REPLACE INTO tasks(task_id,title,status,owner,priority,updated_at) VALUES (?,?,?,?,?,?)",
                    (task_id, title, "IN_PROGRESS", NODE_ID, priority, iso(now_utc()))
                )
                git_commit_and_push(task_id)
                print(f"[CLAIM] 완료. 이제 {task_id} 를 작업하세요.")
                conn.close()
                return

    print("[CLAIM] 모든 후보 Task가 다른 노드에 의해 lease 중.")
    conn.close()

if __name__ == "__main__":
    main()
