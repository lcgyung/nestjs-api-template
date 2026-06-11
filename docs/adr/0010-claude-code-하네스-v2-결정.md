# 0010. Claude Code 하네스 v2 결정 묶음

- 상태: 승인
- 날짜: 2026-06-11

## 맥락

`docs/cc-harness-nestjs.md`(하네스 점검 체크리스트)를 정본으로 삼아 하네스 전반(rules/skills/
agents/hooks/docs)을 정비했다. 체크리스트 원안과 다르게 간 결정, 그리고 의도적으로 비채택한
항목의 근거를 묶어 기록한다.

## 결정

### 1. 서브에이전트 모델 — 역할별 차등 고정 (원안: 전부 opus-4-8 고정)

판단 작업(code-reviewer·security-reviewer·migration-reviewer)은 `model: opus`,
기계적 실행(test-runner·db-reader)은 `model: haiku` 로 고정한다.

- "명시적 고정으로 산출물 결정성 확보"라는 원안 취지는 유지(전부 `model` 명시, inherit 미사용).
- 테스트 실행·SELECT 조회는 모델 품질에 비탄력적 — 고비용 모델은 낭비.
- 재검토 트리거: haiku 가 요약 품질 문제를 보이면 해당 에이전트만 상향.

### 2. PostToolUse typecheck — 비채택

- PostToolUse 는 **차단 불가**(도구가 이미 실행된 뒤라 exit 2 는 피드백만) — 공식 문서 확인.
- Stop 게이트(`gate.sh`)가 풀 `tsc --noEmit` 을 이미 결정론적으로 강제한다.
- 편집마다 풀 tsc(수 초)는 피드백 루프만 느리게 한다. 영향 범위 한정 typecheck 는
  프로젝트 레퍼런스 분할이 없는 현 구조에선 불가.

### 3. .mcp.json — 비채택

- DB 조회는 db-reader 서브에이전트(psql + guard-psql 읽기전용), 이슈/PR 은 `gh` CLI 로 충분.
- 미사용 MCP 서버는 컨텍스트 낭비(체크리스트 7절 원칙 그대로 적용).
- 재검토 트리거: 외부 시스템(이슈 트래커·모니터링)을 모델이 직접 조작할 필요가 생길 때.

### 4. API 규약 정본 — 스킬 → `docs/api-conventions.md` 이전

- 기존엔 `api-endpoint` 스킬이 정본이었으나, 체크리스트 6절이 docs 정본을 요구하고
  rules/서브에이전트/review-gate/사람 리뷰어가 **한 경로만** 참조하도록 단일화했다.
- 스킬은 "정본 참조 + 작업 절차" 래퍼로 축소 — **이중 정본 금지**.
- `review-gate.sh` 의 인라인 요지는 haiku 1-shot 용으로 유지하되 정본 변경 시 동기화 의무를 주석에 명시.

### 5. `new-module` 스킬 명칭 — 기존 `scaffold-module` 유지

역할이 동일하고 description 트리거("새 모듈 만들기/X 모듈 추가")가 이미 정확하다. 개명은 churn 만 발생.

### 6. psql 쓰기 차단 — 전 세션 공통 적용

훅에는 호출 주체(서브에이전트) 식별자가 없어 db-reader 한정 적용이 불가하다. 이 프로젝트에서
정당한 psql 쓰기는 없으므로(스키마=마이그레이션, 데이터=시드) `guard-psql.sh` 를 전 세션에
적용한다. 인용 문자열/파일명 언급을 호출로 오인하지 않도록 명령 위치 감지를 구현했고,
케이스 테스트(`guard-psql.test.sh`, 21케이스)를 동봉한다.

## 결과

- 하네스 구성 전모와 항목별 상태는 `docs/cc-harness-nestjs.md` 점검 매트릭스가 정본.
- 남은 후속 과제: "동일 작업 3회 반복 회귀 확인"(scaffold-module 더미 모듈 3회 생성 비교),
  CLAUDE.md 지속 정비(자주 틀리는 규칙 추가/무시되는 규칙 삭제).
