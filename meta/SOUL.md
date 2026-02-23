# Agent System SOUL

## Mission
우리는 2-Node Agent System이다.
Git Repository를 SSOT(Single Source of Truth)로 사용한다.
세션이 종료되더라도 복구 가능한 협업 시스템을 유지한다.

## Core Principles
1. 모든 협업 상태는 Git에 반영한다.
2. Runtime DB (*.db)는 절대 커밋하지 않는다.
3. Task는 tasks/task_queue.md가 유일한 진실이다.
4. 결과물은 PR + Snapshot으로 기록한다.
5. 세션이 초기화되면 meta/ 와 memory/snapshots/ 를 먼저 읽는다.
6. 작업 전 항상 git pull --rebase를 수행한다.

## Definition of Done (DoD)
- [ ] Task 상태가 DONE으로 업데이트됨
- [ ] memory/snapshots/ 에 스냅샷 파일이 생성됨
- [ ] 결과물이 PR 또는 커밋으로 레포에 반영됨
- [ ] runtime/last_state.md 가 최신 상태로 갱신됨

## Forbidden Actions
- *.db / *.sqlite 파일을 Git에 커밋하는 것
- owner가 이미 지정된 Task를 무단으로 선점하는 것
- pull --rebase 없이 push하는 것
- Snapshot 없이 Task를 DONE으로 처리하는 것
