# CLAUDE.md

이 문서는 Claude Code(claude.ai/code)가 이 리포지토리에서 작업할 때 참고하는 가이드입니다.

**NestJS API Template** — JWT 인증·TypeORM·Swagger·검증·로깅이 구성된 프로덕션 지향 NestJS
백엔드 템플릿. 개요·기술 스택·빠른 시작·환경 변수·표준 에러 응답 등은
[`README.md`](README.md)를 참고하세요. 이 문서는 코드만 봐서는 알기 어려운 작업 규칙에
집중합니다.

> **상태: 핵심 스캐폴딩 완료.** `package.json`·`src/`·`test/`·`docker-compose.yml`·CI 가 구성되어
> 있고, `npm run build`/`lint`/`test` 가 통과합니다. 아래 규칙은 설계이자 현재 코드의 기준입니다.
> 코드를 변경하면 이 문서도 실제 상태에 맞게 갱신하세요.
> (Claude Code 훅 자동화는 구현됨 — 현황·잔여 작업은 [`docs/claude-hooks-status.md`](docs/claude-hooks-status.md)).

## 패키지 매니저

이 프로젝트는 **npm**을 사용합니다(`package-lock.json` 추적). Node `>=20` 기준이며, CI/재현
설치에서는 `npm ci`(lockfile 고정)를 사용하세요. 명령어는 스캐폴딩 후 `package.json`의
`scripts`를 기준으로 합니다(주요 스크립트 목록은 README 참고).

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
- **ESLint + Prettier** — 모든 코드는 린트/포매팅 규칙을 통과해야 합니다 (`npm run lint`, `npm run format`).
- **Husky + Lint-Staged** — 커밋 시 변경 파일에 자동으로 `eslint --fix` + `prettier`가 적용됩니다.

## 테스트

- **단위 테스트** → Jest(`*.spec.ts`). 서비스는 Repository를 모킹하여 비즈니스 로직을 검증합니다.
- **e2e 테스트** → `test/*.e2e-spec.ts`. 실제 DB(또는 테스트 컨테이너)가 필요하므로 빠른
  피드백 루프(저장 시 게이트)에는 포함하지 않습니다.
- Claude Code 훅 자동화 현황·잔여는 [`docs/claude-hooks-status.md`](docs/claude-hooks-status.md) 참고.

## 로드맵

- Refresh Token · RBAC · Redis Cache · BullMQ · S3 Upload · OpenTelemetry · GitHub Actions
