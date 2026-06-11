---
name: write-e2e
description: >-
  e2e 테스트(testcontainers PostgreSQL) 작성 절차. 새 e2e 스펙 추가, 인증/인가(401·403) 시나리오
  테스트, test/*.e2e-spec.ts 작업, "e2e 테스트 작성/추가" 요청 시 적용.
---

# e2e 테스트 작성 (testcontainers)

테스트 규칙 정본은 `.claude/rules/testing.md`. 기준 예시는 `test/app.e2e-spec.ts`.

## 전제 (globalSetup 이 보장 — 직접 만들지 말 것)

`test/global-setup.ts` 가 실행마다 자동으로:

- 전용 PostgreSQL 17 컨테이너 기동(compose DB 와 무관, Docker 데몬만 필요)
- `process.env.DB_*` 주입 → 모든 워커의 AppModule 에 전파
- `pnpm migration:run` + `pnpm seed` → **깨끗한 스키마 + admin 시드**
  (`admin@example.com` / `password`)

스위트에서 DB 연결·마이그레이션·시드 코드를 다시 작성하지 않는다.

## 새 스위트 보일러플레이트

```typescript
const moduleFixture: TestingModule = await Test.createTestingModule({
  imports: [AppModule],
})
  // overrideGuard 는 APP_GUARD 등록 가드에 적용되지 않는다 — 스토리지를 미누적 스텁으로 교체
  .overrideProvider(ThrottlerStorage)
  .useValue({
    increment: (_key: string, ttl: number) =>
      Promise.resolve({ totalHits: 1, timeToExpire: ttl, isBlocked: false, timeToBlockExpire: 0 }),
  })
  .compile();

app = moduleFixture.createNestApplication();
app.use(cookieParser()); // 쿠키 인증 경로 검증용
app.useGlobalPipes(new ValidationPipe(VALIDATION_PIPE_OPTIONS)); // main.ts 와 동일 정본
await app.init();
```

## 필수 시나리오

- **401** — 토큰 없이 보호 라우트 접근
- **403** — 일반 사용자 토큰으로 admin 라우트 접근
- **400** — 검증 실패 바디(표준 에러 형식 `statusCode/error/path/timestamp` 확인),
  DTO 에 없는 여분 필드(forbidNonWhitelisted)
- 해피 패스 — 쿠키 발급(HttpOnly·SameSite 검증)과 Bearer 폴백 둘 다

## 규칙

- **멱등성** — 반복 실행해도 안전하게. 중복 생성은 409 를 허용 처리(기존 스위트 참고).
- 파일명은 `test/<feature>.e2e-spec.ts` (`testRegex: .e2e-spec.ts$`).
- 검증: `pnpm test:e2e` (Stop 게이트엔 미포함 — 직접 실행해 확인).
