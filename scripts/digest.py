#!/usr/bin/env python3
"""
digest.py — 로컬 orchestrator.db 에서 이벤트 요약(digest)을 추출해 레포에 커밋
사용법:
  NODE_ID=PublicJQ DB_PATH=~/agent-runtime/orchestrator.db python3 scripts/digest.py

환경변수:
  DB_PATH    로컬 orchestrator.db 경로
  REPO_DIR   Git SSOT 레포 경로
  NODE_ID    이 노드 식별자
  MAX_EVENTS 최대 출력 이벤트 수 (기본값 50)
"""

import os, sqlite3, json, subprocess
from datetime import datetime, timezone
from pathlib import Path

DB_PATH    = Path(os.environ.get("DB_PATH", Path.home() / "agent-runtime/orchestrator.db"))
REPO_DIR   = Path(os.environ.get("REPO_DIR", Path.home() / "develop/agent-ssot"))
NODE_ID    = os.environ.get("NODE_ID", os.uname().nodename)
MAX_EVENTS = int(os.environ.get("MAX_EVENTS", "50"))

DIGEST_FILE = REPO_DIR / "logs" / "events_digest.md"

def now_kst_str() -> str:
    from datetime import timedelta
    kst = datetime.now(timezone.utc) + timedelta(hours=9)
    return kst.strftime("%Y-%m-%d %H:%M")

def main():
    if not DB_PATH.exists():
        print(f"[DIGEST] DB not found: {DB_PATH}")
        print("[DIGEST] 먼저 scripts/init.sql 로 DB를 생성하세요.")
        return

    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row

    # 최근 이벤트
    events = conn.execute(
        "SELECT ts, node, type, task_id, payload_json FROM events ORDER BY ts DESC LIMIT ?",
        (MAX_EVENTS,)
    ).fetchall()

    # 현재 활성 태스크
    active_tasks = conn.execute(
        "SELECT task_id, title, status, owner FROM tasks WHERE status NOT IN ('DONE')"
    ).fetchall()

    # 하트비트 현황
    heartbeats = conn.execute(
        "SELECT node, ts, status FROM heartbeats ORDER BY ts DESC"
    ).fetchall()

    conn.close()

    lines = [
        "# Events Digest",
        f"\n> 생성: {now_kst_str()} KST (by {NODE_ID})",
        f"> 최근 {MAX_EVENTS}개 이벤트 요약\n",
        "---\n",
        "## Active Tasks",
    ]

    if active_tasks:
        lines.append("| Task ID | Title | Status | Owner |")
        lines.append("|---------|-------|--------|-------|")
        for t in active_tasks:
            lines.append(f"| {t['task_id']} | {t['title']} | {t['status']} | {t['owner'] or '—'} |")
    else:
        lines.append("(없음)")

    lines += ["\n## Heartbeats"]
    if heartbeats:
        lines.append("| Node | Last Seen | Status |")
        lines.append("|------|-----------|--------|")
        for h in heartbeats:
            lines.append(f"| {h['node']} | {h['ts']} | {h['status']} |")
    else:
        lines.append("(없음)")

    lines += ["\n## Recent Events (최신순)"]
    if events:
        lines.append("| Timestamp | Node | Type | Task | Payload |")
        lines.append("|-----------|------|------|------|---------|")
        for e in events:
            payload = e['payload_json'] or '{}'
            try:
                payload_str = json.dumps(json.loads(payload), ensure_ascii=False)[:60]
            except Exception:
                payload_str = payload[:60]
            lines.append(f"| {e['ts']} | {e['node']} | {e['type']} | {e['task_id'] or '—'} | {payload_str} |")
    else:
        lines.append("(없음)")

    DIGEST_FILE.parent.mkdir(parents=True, exist_ok=True)
    DIGEST_FILE.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"[DIGEST] {DIGEST_FILE} 생성 완료")

    # Git 커밋/푸시
    subprocess.run(["git", "-C", str(REPO_DIR), "add", str(DIGEST_FILE)], check=True)
    result = subprocess.run(
        ["git", "-C", str(REPO_DIR), "diff", "--cached", "--quiet"],
        capture_output=True
    )
    if result.returncode != 0:
        subprocess.run([
            "git", "-C", str(REPO_DIR), "commit",
            "-m", f"digest: events summary by {NODE_ID} [{now_kst_str()}]"
        ], check=True)
        subprocess.run(["git", "-C", str(REPO_DIR), "push", "origin", "main"], check=True)
        print("[DIGEST] push 완료")
    else:
        print("[DIGEST] 변경 없음.")

if __name__ == "__main__":
    main()
