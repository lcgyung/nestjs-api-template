---
paths:
  - 'test/**'
  - 'src/**/*.spec.ts'
---

# 테스트 규칙

## API 완성의 정의 (필수 3종 세트)

**컨트롤러를 가진 모듈/엔드포인트 작업은 아래 셋이 모두 갖춰져야 "완성"이다** — 하나라도 빠지면
미완성으로 본다(코드 동작과 무관). 빠르게 짠 happy-path 만으로 끝내지 말 것:

1. **서비스 단위 spec** (`<feature>.service.spec.ts`) — Repository mock, 예외·핵심 로직.
2. **컨트롤러 단위 spec** (`<feature>.controller.spec.ts`) — 서비스 mock, 각 라우트가 올바른
   서비스 메서드에 **인자 그대로 위임**하는지(+ 컨트롤러 자체 로직: 쿠키·`{ message }` 조립 등).
3. **모듈별 e2e** (`test/<feature>.e2e-spec.ts`) — 실제 DB(testcontainers)로 라우트 검증.
   **결과를 실제로 실행해 확인**한다(`pnpm test:e2e`) — 작성만 하고 미실행은 완성이 아니다.

> 정합성 기준은 레퍼런스 모듈 `users`(`users.controller.spec.ts`·`users.service.spec.ts`) 와
> `test/app.e2e-spec.ts`. 새 모듈은 이 3종을 동일하게 미러링한다.

**머신 강제(변경분 한정)** — `pnpm check:api-tests`(`scripts/check-api-tests.sh`, Stop 게이트 `gate.sh`
가 호출)가 이를 강제한다. **레포 전체가 아니라 git 변경분(작업이 들어간 파일)** 의 컨트롤러만 검사한다:
컨트롤러가 있는데 `*.controller.spec.ts`·`*.service.spec.ts` 또는 라우트 prefix 를 다루는 e2e 가
없으면 차단(exit 1). 엔티티 전용·미변경 모듈은 검사하지 않는다(API 가 일괄 구현되지 않으므로).
e2e 는 통합 파일(`app.e2e-spec.ts`)에 라우트가 있어도 인정된다(파일명에 묶지 않음). CI 는
`API_TESTS_DIFF_BASE=origin/main pnpm check:api-tests` 로 PR diff 기준 검사 가능.

## 단위 테스트 (`src/**/*.spec.ts`)

- 서비스 spec — `getRepositoryToken(Entity)` 를 `useValue` jest mock 으로 제공해 Repository 를 모킹한다
  (실 DB 금지 — 빠른 피드백 루프·Stop 게이트에 포함되는 스위트).
- 컨트롤러 spec — `Test.createTestingModule({ controllers, providers: [{ provide: XxxService, useValue: mock }] })`
  로 서비스를 mock 하고, 라우트별 위임/인자 전달을 검증한다(`users.controller.spec.ts` 기준).
- 예외 경로(404/409 등)와 핵심 로직 케이스를 함께 검증한다.
- 커버리지 임계값(branches 85 / functions 75 / lines 85 / statements 85)이 `pnpm test:cov` 와
  CI 에서 강제된다 — 새 서비스/컨트롤러 코드는 spec 을 동반한다.

## e2e 테스트 (`test/*.e2e-spec.ts`)

- **testcontainers 가 전용 PostgreSQL 을 자동 기동**한다(ADR 0009) — `test/global-setup.ts` 가
  컨테이너 기동 → env 주입 → `pnpm migration:run` → `pnpm seed` 까지 수행하므로,
  스위트는 "깨끗한 DB + admin 시드(admin@example.com / password)" 를 전제할 수 있다.
- compose DB 불필요, **Docker 데몬만 필요**(colima 소켓은 자동 인식).
- 새 스위트 보일러플레이트: `AppModule` import + `ThrottlerStorage` 를 카운트 미누적 스텁으로
  override(`overrideGuard` 는 APP_GUARD 등록 가드에 안 통한다) + `VALIDATION_PIPE_OPTIONS` +
  `cookie-parser`. `test/app.e2e-spec.ts` 가 기준 예시.
- **테스트는 멱등**해야 한다 — 같은 프로세스에서 반복 실행해도 안전하게(중복 생성은 409 허용 처리).
- **인증/인가 시나리오 필수** — 토큰 없음 401, 타 유저/롤 403, 검증 실패 400(표준 에러 형식).
- **게이트 정책** — 로컬 Stop 게이트에선 **기본 제외**(빠른 루프). `CC_E2E_GATE=1` 로 옵트인하면
  Stop 시 `pnpm test:e2e` 가 실행된다(Docker 없으면 경고 후 스킵=fail-open). CI 는 e2e 를 강제하므로
  회귀는 PR 에서 잡힌다 — 로컬 옵트인은 "PR 전에 미리 돌려보는" 용도다.
- **컨트롤러 있는 모듈은 자기 e2e 스위트(`test/<feature>.e2e-spec.ts`)를 둔다** — 통합 파일에 묻지 말 것.
  시드에 없는 도메인 데이터는 `app.get(DataSource)` 로 직접 주입해 집계·조회까지 실제 DB 로 검증한다.
- 작성 절차는 `write-e2e` 스킬 참고.
