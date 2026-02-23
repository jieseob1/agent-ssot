#!/usr/bin/env bash
# sync.sh — Git SSOT 동기화 스크립트
# 사용법: ./scripts/sync.sh [레포 경로]
# 작업 전/후에 실행. digest/snapshot 변경사항을 자동으로 커밋/푸시.

set -euo pipefail

REPO_DIR="${1:-$(git rev-parse --show-toplevel 2>/dev/null || echo "$HOME/develop/agent-ssot")}"
NODE_ID="${NODE_ID:-$(hostname)}"

cd "$REPO_DIR"

echo "[SYNC] pull --rebase..."
git fetch origin
git pull --rebase origin main

# 공유 가능한 변경사항이 있으면 커밋
# (digest, snapshot, task_queue, runtime/last_state 등 — DB 파일 제외)
CHANGED=$(git status --porcelain | grep -v '^\?\?' | wc -l | tr -d ' ')

if [ "$CHANGED" -gt 0 ]; then
  echo "[SYNC] $CHANGED 변경 파일 감지 → 커밋/푸시"
  git add \
    memory/snapshots/ \
    runtime/last_state.md \
    tasks/ \
    logs/ \
    meta/ \
    2>/dev/null || true
  git commit -m "sync: auto update by $NODE_ID [$(date '+%Y-%m-%d %H:%M')]" || true
  git push origin main
  echo "[SYNC] push 완료"
else
  echo "[SYNC] 변경 없음. 최신 상태."
fi
