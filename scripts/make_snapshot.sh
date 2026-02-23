#!/usr/bin/env bash
# make_snapshot.sh — 세션 스냅샷 생성 스크립트
# 사용법: NODE_ID=PublicJQ TASK_ID=T-001 ./scripts/make_snapshot.sh
# Task 완료 후 반드시 실행. 생성된 파일을 편집 후 커밋.

set -euo pipefail

REPO_DIR="${REPO_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo "$HOME/develop/agent-ssot")}"
NODE_ID="${NODE_ID:-$(hostname)}"
TASK_ID="${TASK_ID:-unknown}"
TS=$(date '+%Y%m%d_%H%M')
TS_DISPLAY=$(date '+%Y-%m-%d %H:%M')
LAST_COMMIT=$(git -C "$REPO_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")

SNAPSHOT_DIR="$REPO_DIR/memory/snapshots"
SNAPSHOT_FILE="$SNAPSHOT_DIR/session_${TS}_${NODE_ID}.md"

mkdir -p "$SNAPSHOT_DIR"

cat > "$SNAPSHOT_FILE" << EOF
# Session Snapshot — $NODE_ID

## Metadata
- **Node**: $NODE_ID
- **When**: $TS_DISPLAY KST
- **Task**: $TASK_ID

## Worked On
- Task: $TASK_ID — {여기에 Task 제목 입력}

## What Changed
- {변경 사항 1}
- {변경 사항 2}

## Artifacts
- PR: {PR URL or "없음"}
- Commit: $LAST_COMMIT
- Files changed:
  - {파일 경로}

## Blockers / Notes
- {없음}

## Next
- {다음 Task ID 또는 다음 작업}
EOF

echo "[SNAPSHOT] 생성됨: $SNAPSHOT_FILE"
echo ""
echo "→ 파일을 열어 내용을 채운 뒤 아래 명령으로 커밋하세요:"
echo "  git add $SNAPSHOT_FILE"
echo "  git commit -m \"snapshot: $TASK_ID by $NODE_ID\""
echo "  git push origin main"
