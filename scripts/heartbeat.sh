#!/usr/bin/env bash
# heartbeat.sh — 하트비트 전송 스크립트
# 사용법: NODE_ID=PrivateJQ ./scripts/heartbeat.sh [현재_TASK_ID]
# cron 또는 루프로 30~60분마다 실행 권장.

set -euo pipefail

REPO_DIR="${REPO_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo "$HOME/develop/agent-ssot")}"
NODE_ID="${NODE_ID:-$(hostname)}"
CURRENT_TASK="${1:-none}"
LAST_COMMIT=$(git -C "$REPO_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")
TS=$(date '+%Y-%m-%d %H:%M')

echo "[HEARTBEAT] node=$NODE_ID task=$CURRENT_TASK commit=$LAST_COMMIT at=$TS"

# runtime/last_state.md 갱신 (Leader만 권장, Builder는 STATUS 줄만 추가)
STATE_FILE="$REPO_DIR/runtime/last_state.md"

# 현재 활성 태스크 목록 추출
ACTIVE_TASKS=$(grep -E 'status=IN_PROGRESS' "$REPO_DIR/tasks/task_queue.md" 2>/dev/null \
  | sed 's/^- \[ \] //' | head -5 || echo "(없음)")

cat > "$STATE_FILE" << EOF
# Last State

> Leader(PrivateJQ)가 주기적으로 갱신합니다.
> 세션 복구 시 이 파일을 먼저 확인하세요.

---

## Updated
- $TS KST (by $NODE_ID)

## Active Tasks
\`\`\`
$ACTIVE_TASKS
\`\`\`

## Last Heartbeat
- node=$NODE_ID alive=true task=$CURRENT_TASK last_commit=$LAST_COMMIT
EOF

# Git 커밋/푸시
cd "$REPO_DIR"
git add runtime/last_state.md
git diff --cached --quiet || git commit -m "heartbeat: $NODE_ID @ $TS"
git push origin main

echo "[HEARTBEAT] runtime/last_state.md 갱신 및 push 완료"

# Discord 알림 (DISCORD_WEBHOOK_URL 환경변수가 있으면 전송)
if [ -n "${DISCORD_WEBHOOK_URL:-}" ]; then
  curl -s -X POST "$DISCORD_WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "{\"content\": \"[STATUS] node=$NODE_ID alive=true task=$CURRENT_TASK last_commit=$LAST_COMMIT @ $TS\"}" \
    > /dev/null
  echo "[HEARTBEAT] Discord 전송 완료"
fi
