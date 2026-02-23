# Collaboration Protocol

## 1. Task Lifecycle

```
TODO → IN_PROGRESS → DONE
           ↓
        BLOCKED (블로커 발생 시)
```

### Task 포맷 (task_queue.md)
```
- [ ] T-XXX | P{1-3} | owner={NODE_ID or ""} | status={TODO|IN_PROGRESS|DONE|BLOCKED} | {제목}
```

예시:
```
- [ ] T-001 | P1 | owner= | status=TODO | 협업 스캐폴딩 스크립트 생성
- [x] T-002 | P1 | owner=PublicJQ | status=DONE | Snapshot 템플릿 추가
```

우선순위: P1(긴급) > P2(일반) > P3(나중에)

---

## 2. Claim Rule (Task 선점)

1. `git pull --rebase origin main` 수행
2. task_queue.md 에서 `owner=` 이 비어있는 Task 선택
3. 해당 Task의 `owner={내 NODE_ID}`, `status=IN_PROGRESS` 로 수정
4. `git add tasks/task_queue.md && git commit -m "claim: T-XXX by {NODE_ID}"` 후 push
5. 로컬 orchestrator.db 의 leases 테이블에 lease 기록

> **주의**: pull --rebase 없이 owner 수정 금지. 충돌 방지를 위한 필수 규칙.

---

## 3. Snapshot Rule

Task 완료 시 반드시 스냅샷 생성:

- 경로: `memory/snapshots/session_YYYYMMDD_HHMM_{NODE_ID}.md`
- 템플릿: `memory/snapshots/TEMPLATE.md` 참고

스냅샷에 포함할 내용:
- 작업한 Task ID 및 요약
- 변경된 파일 / PR 링크 / 커밋 해시
- 다음 작업 / 미결 사항

---

## 4. Sync Rule

| 시점 | 행동 |
|------|------|
| 작업 시작 전 | `git pull --rebase origin main` |
| 작업 완료 후 | snapshot 커밋 + `git push origin main` |
| 30분마다 (하트비트) | [STATUS] Discord 전송 + last_state.md 갱신 |

---

## 5. Heartbeat Rule

30~60분 주기로 Discord에 아래 형식으로 전송:
```
[STATUS] node={NODE_ID} alive=true task={현재_TASK_ID} last_commit={hash} status={작업요약}
```

heartbeat가 2회 이상 누락되면 상대 노드는 해당 Task의 lease가 만료됐다고 간주할 수 있음.

---

## 6. Recovery Rule

세션 재시작 또는 초기화 후 순서:
1. `git pull --rebase origin main`
2. `meta/SOUL.md` 읽기
3. `meta/AGENTS.md` 읽기
4. `meta/PROTOCOL.md` 읽기
5. `memory/snapshots/` 최근 파일 1~2개 읽기
6. `runtime/last_state.md` 확인
7. `tasks/task_queue.md` 에서 내 owner Task 확인 후 재개

---

## 7. DB Rule

- `orchestrator.db` 는 각 노드 로컬 전용 (`~/agent-runtime/` 권장)
- **.gitignore 에 의해 레포에 커밋 불가**
- 레포에는 요약(digest)만 올림: `logs/events_digest.md`
- 로컬 DB 스키마는 `scripts/init.sql` 참고
