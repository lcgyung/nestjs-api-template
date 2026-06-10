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
```

> **DB 초기화 순서:** `docker compose up -d mysql` → `pnpm migration:run` → `pnpm seed`.
> 전체 스크립트·환경 변수·표준 에러 응답 형식은 [`README.md`](README.md) 참고.

## 프로젝트 구조

경로 별칭: `@/*` → `src/*`. **세 곳에 설정**되어야 한다 — `tsconfig`의 `paths`, Jest
`moduleNameMapper`, 그리고 런타임(빌드는 `tsc-alias`, ts-node 실행은 `tsconfig-paths/register`).
빌드 스크립트가 `nest build && tsc-alias` 인 이유다(별칭을 dist에서 상대경로로 치환).

```text
src
├── common      # filters(예외), interceptors(로깅), decorators(@CurrentUser/@Roles), guards(JwtAuthGuard/RolesGuard), enums(Role)
├── config      # env.validation(class-validator 스키마 + validate), configuration(load 팩토리)
├── database    # database.module, data-source(CLI/마이그레이션용 standalone), migrations, seeds(admin)
├── logger      # winston.config + LoggerModule (nest-winston)
├── modules     # auth(JWT/passport-jwt), users(role 기반 RBAC), health(terminus)
├── app.module.ts  # ConfigModule(validate) + Throttler + 전역 APP_FILTER/APP_INTERCEPTOR/APP_GUARD
└── main.ts     # 부트스트랩 (전역 ValidationPipe/필터, helmet, CORS, Swagger /api-docs, winston)
```

비자명한 규칙: 환경 변수의 숫자 필드는 `@Type(() => Number)` 로 명시 변환한다
(`enableImplicitConversion` 은 reflect 메타데이터 의존성 때문에 빌드/테스트 환경에 따라 불안정).
Jest 는 `setupFiles: ['reflect-metadata']` 로 데코레이터 메타데이터를 로드한다.

## 아키텍처 / 규칙

- **레이어링** → Controller(얇게: 라우팅·DTO 바인딩) → Service(비즈니스 로직) →
  Repository(TypeORM). 컨트롤러에 비즈니스 로직을 두지 말고 서비스로 위임합니다.
- **입력 검증** → 모든 입력은 DTO + class-validator로 검증. 전역 `ValidationPipe`에
  `whitelist: true`(정의되지 않은 속성 제거), `transform: true`(타입 변환)를 켭니다.

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
  보호된 라우트는 가드로, 인증 사용자 주입은 커스텀 데코레이터로 처리합니다.

  ```typescript
  @UseGuards(JwtAuthGuard)
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
- **보안** → `main.ts`에서 helmet · CORS · rate limiting(ThrottlerModule)을 적용합니다.
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
  **리뷰는 기본 비활성 — `CC_AUTO_REVIEW=1` 일 때만 동작**(`.claude/settings.json` 의 `env` 또는 셸 export).
  규약 위반 blocker 시 `exit 2` 로 계속 수정 유도. 순수 bash 타임아웃(바이너리 불요)·연속 라운드 상한
  2회·`claude` 미설치/타임아웃 시 비차단(graceful degrade).
- **스킬(`.claude/skills/`)** → `code-review`(백엔드 리뷰 기준), `api-endpoint`(엔드포인트 응답·예외·DTO 규약),
  `scaffold-module`(신규 모듈 스캐폴딩 — `src/modules/users/` 를 살아있는 템플릿으로 미러링),
  `tdd`(`/tdd` — RED→GREEN→REFACTOR 사이클 안내). 작업 맥락에 맞춰 자동 로드된다.
- `.claude/agents/code-reviewer.md` 서브에이전트도 함께 제공된다(`code-review` 스킬 기준 적용).

## 로드맵

- Refresh Token · RBAC · Redis Cache · BullMQ · S3 Upload · OpenTelemetry · GitHub Actions
