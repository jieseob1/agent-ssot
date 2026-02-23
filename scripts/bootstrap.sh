#!/usr/bin/env bash
# bootstrap.sh — 최초 1회 실행으로 전체 세팅 완료
# 사용법: NODE_ID=PublicJQ DISCORD_WEBHOOK_URL="https://..." ./scripts/bootstrap.sh

set -uo pipefail

REPO_DIR="${REPO_DIR:-$(git rev-parse --show-toplevel)}"
NODE_ID="${NODE_ID:-}"
DISCORD_WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-}"

# ── 1. NODE_ID 확인 ──────────────────────────────────────────
if [ -z "$NODE_ID" ]; then
  echo "어떤 노드입니까?"
  echo "  1) PrivateJQ (집 맥북 / 리더)"
  echo "  2) PublicJQ  (회사 맥북 / 빌더)"
  read -rp "선택 (1 or 2): " CHOICE
  case "$CHOICE" in
    1) NODE_ID="PrivateJQ" ;;
    2) NODE_ID="PublicJQ"  ;;
    *) echo "잘못된 입력"; exit 1 ;;
  esac
fi

echo ""
echo "=== bootstrap: $NODE_ID ==="

# ── 2. 로컬 런타임 폴더 + DB 생성 ────────────────────────────
RUNTIME_DIR="$HOME/agent-runtime"
DB_PATH="$RUNTIME_DIR/orchestrator.db"

mkdir -p "$RUNTIME_DIR"

if [ ! -f "$DB_PATH" ]; then
  echo "[1/5] 로컬 DB 생성..."
  sqlite3 "$DB_PATH" < "$REPO_DIR/scripts/init.sql"
  echo "      → $DB_PATH 생성 완료"
else
  echo "[1/5] 로컬 DB 이미 존재: $DB_PATH"
fi

# ── 3. 환경변수 .zshrc 등록 ──────────────────────────────────
ZSHRC="$HOME/.zshrc"
echo "[2/5] 환경변수 .zshrc 등록..."

add_env() {
  local KEY="$1" VAL="$2"
  if grep -q "export $KEY=" "$ZSHRC" 2>/dev/null; then
    # 이미 있으면 덮어쓰기
    sed -i '' "s|export $KEY=.*|export $KEY=\"$VAL\"|" "$ZSHRC"
    echo "      → $KEY 업데이트"
  else
    echo "export $KEY=\"$VAL\"" >> "$ZSHRC"
    echo "      → $KEY 추가"
  fi
}

add_env "NODE_ID"    "$NODE_ID"
add_env "REPO_DIR"   "$REPO_DIR"
add_env "DB_PATH"    "$DB_PATH"

# Discord 웹훅 (입력된 경우만)
if [ -n "$DISCORD_WEBHOOK_URL" ]; then
  add_env "DISCORD_WEBHOOK_URL" "$DISCORD_WEBHOOK_URL"
else
  echo "      → DISCORD_WEBHOOK_URL 생략 (나중에 추가하려면 .zshrc에 직접 입력)"
fi

# ── 4. cron 등록 (30분마다 heartbeat) ────────────────────────
echo "[3/5] heartbeat cron 등록 (30분마다)..."

HEARTBEAT_CMD="NODE_ID=$NODE_ID REPO_DIR=$REPO_DIR DISCORD_WEBHOOK_URL=${DISCORD_WEBHOOK_URL:-} $REPO_DIR/scripts/heartbeat.sh >> $RUNTIME_DIR/heartbeat.log 2>&1"
CRON_LINE="*/30 * * * * $HEARTBEAT_CMD"

# 기존에 등록된 heartbeat cron 제거 후 재등록
EXISTING=$(crontab -l 2>/dev/null | grep -v 'heartbeat.sh' || true)
printf '%s\n%s\n' "$EXISTING" "$CRON_LINE" | crontab - 2>/dev/null || true
echo "      → cron 등록 완료"

# ── 5. Git 최신화 ─────────────────────────────────────────────
echo "[4/5] git pull --rebase..."
cd "$REPO_DIR"
if GIT_TERMINAL_PROMPT=0 git pull --rebase origin main 2>&1; then
  echo "      → 최신 상태"
else
  echo "      → git pull 실패 (SSH키/네트워크 확인). 나중에 수동으로 실행하세요."
fi

# ── 6. 웹훅 테스트 ───────────────────────────────────────────
echo "[5/5] Discord 웹훅 테스트..."
if [ -n "$DISCORD_WEBHOOK_URL" ]; then
  curl -s -X POST "$DISCORD_WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "{\"content\": \"[STATUS] $NODE_ID 부팅 완료 ✅ | repo: $REPO_DIR\"}" > /dev/null
  echo "      → Discord 전송 완료. 채널 확인하세요."
else
  echo "      → DISCORD_WEBHOOK_URL 없음. 건너뜀."
fi

# ── 완료 ─────────────────────────────────────────────────────
echo ""
echo "=== 세팅 완료 ==="
echo ""
echo "지금 바로 적용하려면:"
echo "  source ~/.zshrc"
echo ""
if [ "$NODE_ID" = "PrivateJQ" ]; then
  echo "리더로 시작하는 방법:"
  echo "  → tasks/task_queue.md 에 Task 추가 후 git push"
else
  echo "빌더로 시작하는 방법:"
  echo "  → python3 $REPO_DIR/scripts/claim.py   # Task 선점"
fi
