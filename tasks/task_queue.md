# Task Queue (SSOT)

> 형식: `- [ ] T-XXX | P{1-3} | owner={NODE_ID or ""} | status={TODO|IN_PROGRESS|DONE|BLOCKED} | {제목}`
> 우선순위: P1(긴급) > P2(일반) > P3(나중에)
> 완료된 Task는 tasks/done.md 로 이동

---

- [ ] T-001 | P1 | owner= | status=TODO | scripts/init.sql 로컬 Runtime DB 스키마 생성
- [ ] T-002 | P1 | owner= | status=TODO | scripts/sync.sh Git 동기화 스크립트 작성
- [ ] T-003 | P1 | owner= | status=TODO | scripts/claim.py Task 선점(claim/lease) 자동화
- [ ] T-004 | P2 | owner= | status=TODO | scripts/heartbeat.sh 하트비트 스크립트 작성
- [ ] T-005 | P2 | owner= | status=TODO | scripts/make_snapshot.sh 스냅샷 자동 생성 스크립트
- [ ] T-006 | P3 | owner= | status=TODO | scripts/digest.py 이벤트 로그 digest 자동 생성
