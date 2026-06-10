---
name: tdd
description: >-
  테스트 주도 개발(RED→GREEN→REFACTOR) 흐름 안내. "TDD로", "테스트 먼저", "실패 테스트부터",
  새 서비스/메서드/기능을 테스트 우선으로 구현할 때 사용. 이 템플릿의 jest(*.spec.ts)·Repository
  모킹 패턴 기준.
---

# 테스트 주도 개발 (RED → GREEN → REFACTOR)

작은 한 사이클을 빠르게 돈다. 한 번에 하나의 동작만 다룬다. 엔드포인트 응답·예외·DTO 등
**의미적 규약**은 `api-endpoint` 스킬, 신규 모듈 파일 구조는 `scaffold-module` 스킬을 따른다
(여기에 중복 정의하지 않음).

## 1. RED — 실패하는 테스트 먼저

- 코로케이트 `*.spec.ts` 에 **아직 없는 동작**을 기술하는 테스트를 작성한다(구현 전).
- 서비스 단위 테스트는 Repository 를 jest mock 으로 주입한다 — `scaffold-module` 의 spec 패턴:

  ```typescript
  const repo = {
    findOne: jest.fn(),
    save: jest.fn(),
  };
  const module = await Test.createTestingModule({
    providers: [UsersService, { provide: getRepositoryToken(User), useValue: repo }],
  }).compile();
  ```

- 예외 케이스도 RED 로 먼저 못 박는다(없음→`NotFoundException`, 중복→`ConflictException`, 한국어 메시지).
- 실패를 **눈으로 확인**한다 — 단일 케이스만 빠르게:

  ```bash
  pnpm exec jest -t "중복 이메일이면 ConflictException"   # 테스트명(-t)으로 한 케이스
  pnpm exec jest src/modules/users/users.service.spec.ts  # 단일 파일
  pnpm test:watch                                         # 워치 루프
  ```

  "기대대로 실패"여야 한다(오타·설정 오류로 인한 실패면 테스트가 잘못된 것).

## 2. GREEN — 최소 구현으로 통과

- 테스트를 통과시키는 **가장 단순한** 코드만 쓴다. 미래 대비 추상화 금지.
- 컨트롤러엔 라우팅만, 로직은 서비스로. 환경값은 `ConfigService`. `any` 금지.
- 해당 케이스가 초록이 될 때까지 같은 `-t` 루프를 반복한다.

## 3. REFACTOR — 초록 유지하며 정리

- 테스트가 통과하는 상태를 유지한 채 중복 제거·명명 개선·경계 정리.
- `code-review` 스킬 기준을 셀프 점검: 컨트롤러 thin, DTO+class-validator, 직렬화로 내부 노출 차단,
  민감 컬럼 `@Exclude()`, 관계 명시적(`eager: true` 금지).
- 리팩터 후 전체 유닛 테스트로 회귀 확인:

  ```bash
  pnpm test          # 유닛 전체 (*.spec.ts)
  ```

## 마무리

- 다음 동작으로 넘어가기 전에 **사이클을 작게** 유지했는지 확인(테스트 1개 → 구현 → 정리).
- e2e(`test/*.e2e-spec.ts`)는 실제 DB 가 필요하므로 이 빠른 루프에 넣지 않는다(`pnpm test:e2e` 로 별도).
- Stop 게이트가 `tsc + eslint + prettier --check + 유닛 jest` 를 강제하므로, 세션 종료 전 초록 상태를 맞춘다.
