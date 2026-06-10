# 테스트 커버리지 에픽 (작업 계획)

> 클린코드 일관성 강제 1차 작업에서 **의도적으로 미룬** 후속 에픽. 미채택 사유는 `CLAUDE.md`
> "의도적으로 채택하지 않은 것" 절에도 기록돼 있다. 이 문서는 그 에픽의 실행 계획서다.

## 배경 / 왜 지금이 아니라 별도 에픽인가

현재 단위 테스트는 **서비스 일부에만** 존재한다(`auth.service`·`users.service`·`env.validation`).
컨트롤러·전략·가드·필터·인터셉터는 미커버다. 한편 `package.json` 의 jest 설정은
`collectCoverageFrom: ["**/*.(t|j)s"]` 로 **전 파일을 분모에 넣는다**. 따라서 지금 `coverageThreshold`
를 걸면 부트스트랩/모듈 배선/DTO 같은 비로직 파일 때문에 **즉시 실패**한다.

그래서 순서가 중요하다: **(1) 로직 파일에 테스트를 먼저 채우고 → (2) 측정 분모를 정리하고 →
(3) 완만한 임계치를 CI 에 건다.** 임계치를 먼저 거는 역순은 금물.

## 현황 베이스라인 (`pnpm test:cov`, 2026-06-11 기준)

전체: **Stmts 26.09% / Branch 11.95% / Funcs 26.92% / Lines 25.88%** — 낮은 수치의 대부분은
테스트 부적합/자명 파일(부트스트랩·모듈·DTO·마이그레이션) 탓이다.

| 구분           | 파일                                                                                                            | 현재                     | 처리                                  |
| -------------- | --------------------------------------------------------------------------------------------------------------- | ------------------------ | ------------------------------------- |
| ✅ 커버됨      | `auth.service.ts`                                                                                               | 100%                     | 유지                                  |
| ✅ 커버됨      | `users.service.ts`                                                                                              | 70% (lines 50-67 미커버) | **보완**(update/remove)               |
| ✅ 커버됨      | `env.validation.ts`                                                                                             | 94%                      | 유지                                  |
| 🔴 로직·미커버 | `users.controller.ts`                                                                                           | 0%                       | **테스트 추가**                       |
| 🔴 로직·미커버 | `auth.controller.ts`                                                                                            | 0%                       | **테스트 추가**                       |
| 🔴 로직·미커버 | `auth/strategies/jwt.strategy.ts`                                                                               | 0%                       | **테스트 추가**                       |
| 🔴 로직·미커버 | `common/guards/roles.guard.ts`                                                                                  | 0%                       | **테스트 추가**                       |
| 🔴 로직·미커버 | `common/filters/all-exceptions.filter.ts`                                                                       | 0%                       | **테스트 추가**                       |
| 🟡 로직·미커버 | `common/interceptors/logging.interceptor.ts`                                                                    | 0%                       | 선택(저가치)                          |
| 🟡 로직·미커버 | `modules/health/health.controller.ts`                                                                           | 0%                       | 선택(스모크)                          |
| ⚪ 비로직      | `main.ts`·`*.module.ts`·`database/{data-source,migrations,seeds}`·`logger/winston.config.ts`·`configuration.ts` | 0%                       | **커버리지 제외**                     |
| ⚪ 선언적      | `**/dto/*.dto.ts`·`**/entities/*.entity.ts`                                                                     | 대부분 0%                | **커버리지 제외**(검증은 e2e 가 담당) |
| 🟡 데코레이터  | `common/decorators/current-user.decorator.ts`                                                                   | 0%                       | e2e 로 커버(단위테스트 부적합)        |

## 전략

1. **분모 정리** — 부트스트랩/배선/선언적 파일을 `coveragePathIgnorePatterns` 로 제외해, 측정 대상을
   *실제 로직 계층*으로 좁힌다. 의미 없는 100%/0% 노이즈 제거.
2. **로직 테스트 채우기** — 컨트롤러는 라우팅·위임 스모크, 서비스/전략/가드/필터는 분기까지.
3. **임계치 게이트** — 정리된 분모 기준 완만한 임계치를 CI 에서만 강제. `gate.sh`(Stop)는 속도를 위해
   plain `jest` 유지(커버리지 미수행).

## Phase A — 누락 단위 테스트 추가

기존 패턴 그대로: `Test.createTestingModule` + `getRepositoryToken(Entity)` `useValue` jest mock
(`src/modules/users/users.service.spec.ts` 참조). `tdd` 스킬(RED→GREEN→REFACTOR) 따른다.

- `src/modules/users/users.controller.spec.ts` — 각 라우트가 서비스 메서드에 올바른 인자로 위임하는지
  (서비스 mock), `getMe` 가 주입 user 반환, 페이지네이션 쿼리 전달.
- `src/modules/auth/auth.controller.spec.ts` — `login` 이 서비스 위임·토큰 반환.
- `src/modules/auth/strategies/jwt.strategy.spec.ts` — `validate(payload)` 가 존재 user 반환,
  부재 시 `UnauthorizedException`. `UsersService` mock.
- `src/common/guards/roles.guard.spec.ts` — `@Roles` 없으면 통과, 역할 불일치 시 `ForbiddenException`,
  일치 시 통과. `Reflector` + mock `ExecutionContext`.
- `src/common/filters/all-exceptions.filter.spec.ts` — `HttpException`/일반 `Error`/unknown 각각의
  표준 응답 본문·상태코드 매핑, 5xx 로깅 분기.
- `users.service.spec.ts` **보완** — `update`(비밀번호 재해시 분기 포함)·`remove`(미존재 404) 케이스로
  lines 50-67 커버.
- (선택) `logging.interceptor.spec.ts`·`health.controller.spec.ts` — 저가치, 시간 여유 시.

## Phase B — 커버리지 측정 분모 정리

`package.json` 의 jest 블록에 추가:

```jsonc
"coveragePathIgnorePatterns": [
  "/node_modules/",
  "\\.module\\.ts$",
  "main\\.ts$",
  "src/database/",          // data-source·migrations·seeds
  "src/logger/winston.config\\.ts$",
  "src/config/configuration\\.ts$",
  "\\.dto\\.ts$",           // 선언적 — 검증은 e2e
  "\\.entity\\.ts$"
]
```

> 데코레이터(`current-user.decorator.ts`)는 단위테스트가 부적합하니 e2e 도입 전까지는 제외하거나
> 낮은 임계치로 흡수한다. 제외 목록은 베이스라인을 보며 조정.

`pnpm test:cov` 로 **정리된 분모 기준 새 베이스라인**을 측정해 임계치 출발점을 잡는다.

## Phase C — 임계치 + CI 게이트

1. `package.json` jest 에 `coverageThreshold` 추가 — **정리 후 베이스라인보다 약간 낮게** 시작해
   회귀만 막고, 이후 점진 상향:

   ```jsonc
   "coverageThreshold": {
     "global": { "lines": 70, "branches": 60, "functions": 65, "statements": 70 }
   }
   ```

   (숫자는 Phase B 측정값으로 확정. 처음부터 높게 잡지 말 것.)

2. `.github/workflows/ci.yml` `lint-build-test` 잡에 `- run: pnpm test:cov` 스텝 추가
   (`pnpm test` 를 대체하거나 뒤에 추가). 임계치 미달 시 CI 실패.

3. `gate.sh` 는 **변경 없음** — Stop 게이트는 빠른 plain `jest` 유지(커버리지는 느림). 계층 의도 유지:
   커밋 훅=포맷/린트, Stop=빠른 정적+단위, CI=정적+빌드+커버리지.

## 수용 기준 (Acceptance)

- [ ] Phase A 신규 spec 전부 그린, `users.service` lines 50-67 커버.
- [ ] `coveragePathIgnorePatterns` 적용 후 분모가 로직 계층으로 좁혀짐.
- [ ] `pnpm test:cov` 가 설정한 `coverageThreshold` 통과.
- [ ] CI 커버리지 스텝 그린.
- [ ] `gate.sh` 는 여전히 plain jest(속도 회귀 없음).

## 커밋 분할 제안

```text
test(users): 컨트롤러 라우팅·서비스 update/remove 단위 테스트
test(auth): 컨트롤러·jwt.strategy 단위 테스트
test(common): roles.guard·all-exceptions.filter 단위 테스트
chore(jest): coveragePathIgnorePatterns 로 측정 분모 정리
chore(jest): coverageThreshold 도입
chore(ci): test:cov 커버리지 게이트 스텝 추가
```

## 참고

- 테스트 작성 흐름: `.claude/skills/tdd/SKILL.md` (RED→GREEN→REFACTOR, `-t` 단일 케이스 루프).
- mock 패턴: `getRepositoryToken(Entity)` + `useValue`, `Test.createTestingModule`
  (`src/modules/users/users.service.spec.ts`).
- e2e(`test/*.e2e-spec.ts`)는 실제 DB 필요 → 본 에픽의 단위 커버리지와 분리. DTO/데코레이터/엔티티의
  런타임 검증은 e2e 가 담당(별도 에픽).
