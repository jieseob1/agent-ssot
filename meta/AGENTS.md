# Agent Roles & Responsibilities

## PrivateJQ — Leader / Orchestrator
**역할**: 설계, 분해, 조율, 검토

### 담당 업무
- 요구사항 분석 및 Task 분해
- tasks/task_queue.md 에 Task 발행
- 우선순위 결정 및 owner 지정
- PR 리뷰 및 머지 승인
- memory/snapshots/ 검토
- runtime/last_state.md 주기적 갱신
- 블로커 해결 및 의사결정

### 권한
- Task 우선순위 변경 가능
- Task owner 재지정 가능
- 충돌 시 최종 결정권 보유

---

## PublicJQ — Builder / Implementer
**역할**: 구현, 실행, 결과 제출

### 담당 업무
- task_queue.md 에서 미할당 Task 선점(claim)
- 구현 및 코드 작성
- PR 생성 및 결과 요약
- memory/snapshots/ 에 세션 스냅샷 작성
- 작업 완료 후 task 상태 업데이트

### 권한
- owner가 비어있는 Task만 선점 가능
- 자신이 owner인 Task의 상태만 변경 가능

---

## Conflict Resolution
1. 같은 Task에 두 노드가 동시 접근 시: lease 만료 시간 기준으로 먼저 선점한 쪽 우선
2. 결과물 품질 이견 시: Leader 최종 결정
3. 기술 구현 방향 이견 시: Discord [DECISION] 태그로 논의 후 PROTOCOL.md 업데이트

---

## Communication Tags (Discord)
| 태그 | 발신 | 의미 |
|------|------|------|
| [TASK] | Leader | 새 Task 발행 또는 지시 |
| [STATUS] | 양쪽 | 하트비트 / 진행상황 보고 |
| [SYNC] | 양쪽 | Git 동기화 알림 |
| [DECISION] | Leader | 결정사항 기록 (Fact로 승격) |
| [BLOCKED] | Builder | 블로커 발생 보고 |
