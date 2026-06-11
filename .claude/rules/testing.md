---
paths:
  - 'test/**'
  - 'src/**/*.spec.ts'
---

# 테스트 규칙

## 단위 테스트 (`src/**/*.spec.ts`)

- 서비스는 `getRepositoryToken(Entity)` 를 `useValue` jest mock 으로 제공해 Repository 를 모킹한다
  (실 DB 금지 — 빠른 피드백 루프·Stop 게이트에 포함되는 스위트).
- 예외 경로(404/409 등)와 핵심 로직 케이스를 함께 검증한다.
- 커버리지 임계값(branches 85 / functions 75 / lines 85 / statements 85)이 `pnpm test:cov` 와
  CI 에서 강제된다 — 새 서비스 코드는 spec 을 동반한다.

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
- 작성 절차는 `write-e2e` 스킬 참고.
