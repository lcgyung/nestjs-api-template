---
paths:
  - 'src/**'
---

# Pattern Contamination 제거 (ELEMENT 1)

같은 일을 하는 **경쟁 패턴**·**dead code**·**deprecated logic**·**미완성 마이그레이션**을 끈질기게 정리한다.
hook(`contamination-report.sh`)이 세션 시작 시 knip 오염 후보를 주입한다 — 아래는 그 후보를 다루는 규칙이다.

## 발견 시

- **경쟁 패턴** — 같은 일을 하는 방식이 둘 이상이면, **한 쪽을 표준으로 고정하고 나머지를 제거**한다.
  어느 쪽이 표준인지 모호하면 추측하지 말고 사용자/리뷰어에게 확인한다.
- **dead code · deprecated logic** — 참조가 없는 export/함수/분기, 대체된 옛 구현은 제거한다.
- **미완성 마이그레이션** — 절반만 옮겨진 패턴은 마저 옮겨 한 방향으로 통일한다(되돌리지 말 것).
- **범위** — 정리는 **현재 작업이 건드린 영역 내에서만**. 전체 코드베이스 일괄 정리는 작업 diff 에 섞지 말고
  전용 스윕(`/contamination-sweep`)으로 분리한다.

## 커밋 분리 (강제)

- 오염 정리는 기능 변경(`feat`/`fix`)과 **절대 섞지 않는다**. **단독 `chore(cleanup): ...` 커밋**으로 분리한다.
  (commitlint 가 Conventional Commits 의 `chore` 타입을 이미 강제한다.)

## False positive 가드 (삭제 전 확인)

knip 후보는 **정적 그래프 기준**이라 런타임 DI/동적 로드를 못 본다. 아래는 unused 로 보여도 **삭제 금지**:

- **NestJS DI** — provider·controller·guard·interceptor·pipe·custom decorator 는 `*.module.ts` 의
  `providers`/`controllers` 또는 데코레이터로만 참조될 수 있다.
- `*.module.ts` 자체, `src/database/migrations/**`(data-source 가 glob 로드), seeds(CLI/e2e globalSetup 실행),
  `scripts/generate-openapi.ts`(ts-node 실행) — 정적 unused 여도 삭제 금지.
- 후보가 정말 dead 인지 `git grep`/참조로 확인한 뒤 제거한다.

## 오염이 아닌 것 (고치지 말 것)

`CLAUDE.md` "의도적으로 채택하지 않은 것" 절의 항목은 오염이 아니다 — 엔티티/DTO 필드의 `!`(definite assignment),
`noUncheckedIndexedAccess` 미사용, `strictTypeChecked` 미채택 등. "정리"하려다 의도된 패턴을 깨지 말 것.
