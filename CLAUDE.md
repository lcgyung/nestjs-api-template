# CLAUDE.md

이 문서는 Claude Code(claude.ai/code)가 이 리포지토리에서 작업할 때 참고하는 가이드입니다.

**NestJS API Template** — JWT 인증·TypeORM·Swagger·검증·로깅이 구성된 프로덕션 지향 NestJS
백엔드 템플릿. 개요·기술 스택·빠른 시작·환경 변수·표준 에러 응답 등은
[`README.md`](README.md)를 참고하세요. 이 문서는 코드만 봐서는 알기 어려운 작업 규칙에
집중합니다.

> **상태: 핵심 스캐폴딩 완료.** `package.json`·`src/`·`test/`·`docker-compose.yml`·CI 가 구성되어
> 있고, `pnpm build`/`lint`/`test` 가 통과합니다. 아래 규칙은 설계이자 현재 코드의 기준입니다.
> 코드를 변경하면 이 문서도 실제 상태에 맞게 갱신하세요.
> (Claude Code 훅 자동화는 구현됨 — 상세는 아래 `## Claude Code 자동화` 절 참고.)

## 패키지 매니저

이 프로젝트는 **pnpm**을 사용합니다(`pnpm-lock.yaml` 추적, `package.json`의 `packageManager`
필드로 버전 고정). Node `>=22.13` 기준이며(pnpm 11.5.2 가 요구), CI/재현 설치에서는 `pnpm install --frozen-lockfile`을
사용하세요. bcrypt 같은 **네이티브 빌드 스크립트 허용은 `pnpm-workspace.yaml`의 `allowBuilds`**로
관리합니다(pnpm 10+ 부터 `package.json`의 `pnpm` 필드는 더 이상 읽지 않음).

## 자주 쓰는 명령어

```bash
pnpm start:dev                   # 개발 서버 (watch)
pnpm build                       # nest build + tsc-alias (dist 경로 별칭 치환)
pnpm lint                        # ESLint  /  pnpm lint:fix 로 자동 수정
pnpm format                      # Prettier --write

pnpm test                        # 단위 테스트 전체 (Jest, *.spec.ts)
pnpm test users.service          # 파일명 패턴으로 일부만 실행
pnpm exec jest src/modules/users/users.service.spec.ts    # 단일 파일
pnpm exec jest -t "should hash password"                  # 테스트명(-t)으로 단일 케이스
pnpm test:cov                    # 커버리지
pnpm test:e2e                    # e2e (test/*.e2e-spec.ts, 실제 DB 필요)

pnpm exec tsc --noEmit -p tsconfig.json   # 타입체크 단독 실행 (전용 스크립트 없음; Stop 게이트가 사용)

pnpm migration:generate src/database/migrations/<Name>   # 엔티티 변경 후 생성
pnpm migration:run               # 마이그레이션 적용  /  migration:revert 로 롤백
pnpm seed                        # 기본 admin 계정 시드 (admin@example.com / password)

pnpm openapi:generate            # docs/openapi.json 생성 (DB 불필요 — DataSource 스텁, ADR 0004)
```

> **컨트롤러/DTO/라우트를 변경하면 `pnpm openapi:generate` 로 `docs/openapi.json` 을 재생성해
> 함께 커밋한다.** CI 가 `git diff --exit-code` 로 스펙 드리프트를 차단한다.

> **DB 초기화 순서:** `docker compose up -d mysql` → `pnpm migration:run` → `pnpm seed`.
> 전체 스크립트·환경 변수·표준 에러 응답 형식은 [`README.md`](README.md) 참고.

## 프로젝트 구조

경로 별칭: `@/*` → `src/*`. **세 곳에 설정**되어야 한다 — `tsconfig`의 `paths`, Jest
`moduleNameMapper`, 그리고 런타임(빌드는 `tsc-alias`, ts-node 실행은 `tsconfig-paths/register`).
빌드 스크립트가 `nest build && tsc-alias` 인 이유다(별칭을 dist에서 상대경로로 치환).

```text
src
├── common      # filters(예외), interceptors(로깅), decorators(@CurrentUser/@Roles/@Public), guards(JwtAuthGuard/RolesGuard),
│               # middleware(RequestId), context(AsyncLocalStorage requestId), pipes(VALIDATION_PIPE_OPTIONS), enums(Role)
├── config      # env.validation(class-validator 스키마 + validate), configuration(load 팩토리), swagger.config(main.ts·스크립트 공유)
├── database    # database.module, data-source(CLI/마이그레이션용 standalone), migrations, seeds(admin)
├── logger      # winston.config(+requestId 자동 주입) + LoggerModule (nest-winston)
├── modules     # auth(JWT/passport-jwt), users(role 기반 RBAC), health(terminus — /health·liveness·readiness)
├── app.module.ts  # ConfigModule(validate) + Throttler + 전역 가드(Throttler→JwtAuth→Roles, deny-by-default)/필터/인터셉터 + RequestIdMiddleware(Express 5 라우트 문법 '{*splat}')
└── main.ts     # 부트스트랩 (NestExpress: 전역 ValidationPipe/필터, helmet(HSTS), cookie-parser, CORS, body limit, trust proxy, Swagger(prod 비활성), winston, enableShutdownHooks)
scripts         # generate-openapi.ts — 빌드에서 제외됨(tsconfig.build.json exclude; dist/main.js 경로 보존)
```

비자명한 규칙(검증 경로가 둘로 나뉜다): 환경 변수 검증(`config/env.validation.ts`)은 부팅 시
`plainToInstance` + `validateSync` 로 **전역 `ValidationPipe` 와 무관하게** 직접 수행한다. 이 경로엔
implicit 변환이 없으므로 숫자 필드는 `@Type(() => Number)` 로 명시 변환한다(reflect 메타데이터 의존
제거 → 빌드/테스트 환경 무관). 반면 **요청 DTO** 용 전역 `ValidationPipe`(`main.ts`)는
`transformOptions.enableImplicitConversion: true` 를 켠다 — 둘을 혼동해 한쪽 설정을 다른 쪽에 맞추지
말 것. Jest 는 `setupFiles: ['reflect-metadata']` 로 데코레이터 메타데이터를 로드한다.

## 아키텍처 / 규칙

- **레이어링** → Controller(얇게: 라우팅·DTO 바인딩) → Service(비즈니스 로직) →
  Repository(TypeORM). 컨트롤러에 비즈니스 로직을 두지 말고 서비스로 위임합니다.
- **입력 검증** → 모든 입력은 DTO + class-validator로 검증. 전역 `ValidationPipe` 옵션의 정본은
  `src/common/pipes/validation-pipe.options.ts`(`VALIDATION_PIPE_OPTIONS`) — main.ts 와 e2e 가
  공유하므로 한쪽만 고치지 말 것. `whitelist` + `forbidNonWhitelisted`(DTO 에 없는 필드는 silent
  strip 이 아니라 400) + `transform`.

  ```typescript
  export class CreateUserDto {
    @IsEmail()
    email: string;

    @IsString()
    @MinLength(8)
    password: string;
  }
  ```

- **인증** → JWT 기반. 비밀번호는 bcrypt로 해싱하고 평문/해시를 응답에 노출하지 않습니다.
  토큰은 **httpOnly 쿠키(`access_token`)로 발급**하고 `jwt.strategy` 가 쿠키 우선·Bearer 헤더 폴백으로
  추출한다(모바일·서버 간 호출 유지 — [ADR 0005](docs/adr/0005-jwt-쿠키-전환-csrf-전략.md)). 인증은
  **deny-by-default** — `JwtAuthGuard`·`RolesGuard` 가 `app.module.ts` 에 전역 `APP_GUARD` 로 등록되어
  모든 라우트를 보호한다. 인증 없이 열 라우트만 `@Public()` 을 명시하고(로그인·로그아웃·health), 역할
  제한은 `@Roles(Role.Admin)` 으로 건다 — **컨트롤러에 `@UseGuards(JwtAuthGuard)` 를 다시 붙이지 말 것.**
  응답 민감 필드 제거는 전역 `ClassSerializerInterceptor` + 엔티티의 `@Exclude()`(예: `User.password`)
  조합으로 강제된다. **새 엔티티에 비밀/토큰 등 민감 필드를 추가하면 반드시 `@Exclude()` 를 붙인다.**

  ```typescript
  // 전역 가드가 보호하므로 @UseGuards 불필요. 인증된 사용자는 @CurrentUser 로 주입.
  @Get('me')
  getMe(@CurrentUser() user: User) {
    return user;
  }
  ```

- **에러 응답** → Global Exception Filter가 모든 예외를 표준 형식으로 통일합니다
  (형식은 README "Standard Error Response" 참고 — 이 문서에서 중복 정의하지 않음).
- **응답·세부 규약** → 성공 응답 형태(단건=엔티티 직접 반환, 목록=`{ items, meta }` 페이지네이션),
  예외 타입 매핑, 쿼리/관계, DTO 직렬화 등 세부 규약은
  `api-endpoint` 스킬을 따릅니다(엔드포인트 작업 시 자동 로드됨 — 규약 정본이며 본문은 이 문서에 중복하지 않음).
- **설정/검증** → 환경 변수는 부팅 시 스키마로 검증하여 잘못된 설정이면 즉시 중단(fail-fast)합니다.
  특히 `JWT_SECRET`이 비었거나 너무 짧으면 실행을 막습니다(변수 목록은 README 참고).
- **로깅** → Winston. 요청 로깅은 인터셉터로, 애플리케이션 로그는 Nest `Logger` 대체 구현으로.
  **request id** 는 `RequestIdMiddleware`(AsyncLocalStorage)가 시작하고 winston format 이 모든
  로그에 자동 주입한다 — 로거 호출부에서 id 를 수동으로 넘기지 말 것.
- **보안** → `main.ts`에서 helmet(HSTS) · CORS · rate limiting(ThrottlerModule) · payload 100kb 제한 ·
  `trust proxy` 를 적용합니다. CORS_ORIGIN 은 **production 에서 필수**(미설정 시 부팅 차단), Swagger
  `/api-docs` 는 prod 에서 비활성. 시크릿 스캔은 gitleaks + **SAST 는 Semgrep**(CI `sast` 잡, private
  Free repo 라 CodeQL 대신) + 의존성 취약점은 `pnpm audit --prod`(CI) + `eslint-plugin-security` +
  SBOM(CycloneDX). 수정 불가 CVE 는 `pnpm-workspace.yaml` `auditConfig.ignoreCves` 에 사유와 함께 기록.
  로그인은 전용 `@Throttle`(분당 5)로 brute-force 를 완화하고, 성공/실패는 이메일 마스킹 감사 로그를 남긴다.
  시큐어 코딩 체크리스트는 [`docs/secure-harness-nestjs.md`](docs/secure-harness-nestjs.md), 위협 모델은
  [`docs/threat-model.md`](docs/threat-model.md).
- **마이그레이션(비자명 규칙)** → 운영에서 `synchronize: true`를 **사용하지 않습니다**. 앱과
  분리된 `DataSource`를 두고 마이그레이션으로만 스키마를 변경합니다. `migration:generate`는
  컴파일된 `DataSource`를 기준으로 동작하므로, 엔티티 변경 후 생성 → 검토 → `migration:run`
  순서를 지킵니다.

## 코드 컨벤션

- **타입 안정성 우선** — TypeScript 타입을 명확히 지정하고 `any` 사용을 지양합니다.
  `tsconfig`의 `strict`를 켭니다.
- **최소 보일러플레이트** — 불필요한 추상화를 피하고 NestJS 관용 구조(모듈/프로바이더)를 따릅니다.
- **ESLint + Prettier** — 모든 코드는 린트/포매팅 규칙을 통과해야 합니다 (`pnpm lint`, `pnpm format`).
- **Husky + Lint-Staged** — 커밋 시 변경 파일에 자동으로 `eslint --fix` + `prettier`가 적용됩니다.

### 머신이 강제하는 일관성 규칙

아래는 *관례가 아니라 린터/타입체커가 강제*한다 — 어기면 `pnpm lint`/`typecheck`(따라서 Stop
게이트·CI·커밋 훅)가 실패한다. 새 코드를 이 스타일에 맞추면 통과한다.

- **네이밍**(`@typescript-eslint/naming-convention`) — 파일은 kebab-case(`*.service.ts` 등),
  클래스/타입/인터페이스는 PascalCase(+역할 suffix: `…Controller`/`…Service`/`…Dto`), **enum 멤버는
  PascalCase**(`Role.User`), `private static readonly` 상수는 UPPER_CASE(`SALT_ROUNDS`), 변수/멤버는
  camelCase. 예외로 데코레이터 팩토리·`DataSource` const 는 PascalCase, env 미러링 클래스
  (`EnvironmentVariables`)의 프로퍼티는 UPPER_CASE 가 허용된다.
- **import 정렬**(`simple-import-sort`) — external → `@/` 별칭 → 상대경로 순, 그룹 간 빈 줄. **auto-fix**
  되므로 저장/커밋 시 자동 정렬된다.
- **타입 전용 import 는 `import type`**(`consistent-type-imports`, auto-fix). 단 `emitDecoratorMetadata`
  로 DI/데코레이터 메타데이터에 쓰이는 타입(`Repository<T>` 등)은 값 import 로 남는다(룰이 자동 판별).
- **기타** — 타입 정의는 `interface`, 배열은 `T[]`, `??`/`?.` 선호, `===` 만, 미사용 지역변수/파라미터
  금지(`noUnusedLocals`/`noUnusedParameters`; 의도적 미사용은 `_` prefix), 떠도는 Promise 금지
  (`no-floating-promises` error).
- **커밋 메시지** — Conventional Commits(`commitlint` + `.husky/commit-msg`). `<type>(<scope>): <subject>`.
  한국어·영문 혼용 subject 허용(`subject-case` 비활성), type/scope·헤더 길이는 강제. 상세는 `CONTRIBUTING.md`.

### 의도적으로 채택하지 않은 것 (고치지 말 것)

다음은 누락이 아니라 **의도적 선택**이다. "강화"하려다 오히려 기존 패턴을 깨지 않도록 주의.
근거 상세·재검토 트리거는 [`docs/adr/`](docs/adr/README.md) (특히 ADR 0002·0003) 참고:

- **`noUncheckedIndexedAccess` 미사용** — 코드가 이미 `??`/`?.`로 방어적이고 churn 대비 이득이 작다
  (테스트·배열 코드에 부담). 데이터 중심 로직이 늘면 재검토.
- **typescript-eslint `strictTypeChecked` 프리셋 미채택** — `no-non-null-assertion` 이 엔티티 필드의
  의도적 `!`(definite assignment) 관례와 충돌. 가치 있는 룰만 개별 채택했다.
- **복잡도 캡(complexity/max-lines 등) 미도입** — 아직 없는 문제. 필요 시 추가.
- **엔티티/DTO 필드의 `!`** — TypeORM/검증이 런타임에 채우는 값이라 의도적이다. non-null assertion 제거 금지.
- **e2e testcontainers 미도입** — CI service container 가 런마다 깨끗한 DB 를 보장하고 e2e 스위트가
  1개뿐. 상세는 ADR 0003.

## 테스트

- **단위 테스트** → Jest(`*.spec.ts`). 서비스는 Repository를 모킹하여 비즈니스 로직을 검증합니다.
- **e2e 테스트** → `test/*.e2e-spec.ts`. 실제 DB(또는 테스트 컨테이너)가 필요하므로 빠른
  피드백 루프(저장 시 게이트)에는 포함하지 않습니다.

## Claude Code 자동화 (`.claude/`)

`.claude/settings.json` 이 훅을 등록한다. 코드를 만질 때 아래 동작을 전제로 한다.

- **SessionStart** → `session-context.sh`: 브랜치 등 컨텍스트를 주입.
- **PreToolUse(Bash)** → `guard-bash.sh`: 파괴적 명령(`rm -rf /`, force push, `reset --hard` 등)을 차단.
- **PostToolUse(Edit/Write)** → `format-changed-file.sh`: 변경된 `*.ts` 에 `eslint --fix` + `prettier` 자동 적용.
- **Stop** → `gate.sh`: 세션 종료 전 정적 검사 `tsc --noEmit` + `eslint` + `prettier --check`(누적, 셋 다
  `pnpm exec`) 후 **유닛 `jest`**(`*.spec.ts`만; e2e 는 별도 config 라 제외) 게이트. 모두 통과하면
  `review-gate.sh` 가 변경된 `src/*.ts` 를 헤드리스 `claude -p --model haiku` 로 의미적 규약 리뷰한다.
  **리뷰는 `.claude/settings.json` 의 `env` 에서 `CC_AUTO_REVIEW=1` 로 상시 활성화**되어 있다(끄려면 값
  제거/`0`, 셸 export 로도 토글 가능).
  규약 위반 blocker 시 `exit 2` 로 계속 수정 유도. 순수 bash 타임아웃(바이너리 불요)·연속 라운드 상한
  2회·`claude` 미설치/타임아웃 시 비차단(graceful degrade).
- **스킬(`.claude/skills/`)** → `code-review`(백엔드 리뷰 기준), `api-endpoint`(엔드포인트 응답·예외·DTO 규약),
  `scaffold-module`(신규 모듈 스캐폴딩 — `src/modules/users/` 를 살아있는 템플릿으로 미러링),
  `tdd`(`/tdd` — RED→GREEN→REFACTOR 사이클 안내). 작업 맥락에 맞춰 자동 로드된다.
- `.claude/agents/code-reviewer.md` 서브에이전트도 함께 제공된다(`code-review` 스킬 기준 적용).

## 로드맵

- Refresh Token(회전·서버측 폐기 — [ADR 0006](docs/adr/0006-refresh-토큰-회전-보류.md) 로 보류 중) ·
  SSO/소셜 로그인 · Redis Cache · BullMQ · S3 Upload · OpenTelemetry · Sentry(에러 트래킹)
- **인증 프로파일(MVP/Production)** — 인증을 _자격증명 전략(ID/PW·외부 본인인증·SSO) + 공통 세션 골격_
  으로 보고, MVP 프로파일에선 외부 본인인증 전략만 켜고 일부 보안 자동화(SAST·SBOM·위협모델 풀버전 등)를
  보류한다. ID/PW 로그인은 삭제하지 않고 비활성 보존한다. 근거·범위는
  [ADR 0007](docs/adr/0007-인증-프로파일-분리-자격증명-전략.md).
