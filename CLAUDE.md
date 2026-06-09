# CLAUDE.md

이 문서는 Claude Code(claude.ai/code)가 이 리포지토리에서 작업할 때 참고하는 가이드입니다.

**NestJS API Template** — JWT 인증·TypeORM·Swagger·검증·로깅이 구성된 프로덕션 지향 NestJS
백엔드 템플릿. 개요·기술 스택·빠른 시작·환경 변수·표준 에러 응답 등은
[`README.md`](README.md)를 참고하세요. 이 문서는 코드만 봐서는 알기 어려운 작업 규칙에
집중합니다.

> **상태: 스캐폴딩 미완료.** 현재 저장소에는 `README.md`·`CLAUDE.md`·`LICENSE`만 존재하며
> 실제 소스 코드(`package.json`, `src/` 등)는 아직 없습니다. 아래 내용은 **의도된 설계**입니다.
> 코드를 생성할 때 이 규칙을 기준으로 삼고, 실제 파일을 추가한 뒤에는 이 문서를 실제 상태에
> 맞게 갱신하세요.

## 패키지 매니저

이 프로젝트는 **npm**을 사용합니다(`package-lock.json` 추적). Node `>=20` 기준이며, CI/재현
설치에서는 `npm ci`(lockfile 고정)를 사용하세요. 명령어는 스캐폴딩 후 `package.json`의
`scripts`를 기준으로 합니다(주요 스크립트 목록은 README 참고).

## 예정된 프로젝트 구조

경로 별칭: `@/*` → `src/*` (`tsconfig`의 `paths`와 Jest `moduleNameMapper` 양쪽에 설정).

```text
src
├── common      # filters(예외), interceptors(로깅/변환), decorators(@CurrentUser), guards(JwtAuthGuard, RolesGuard)
├── config      # 환경 변수 검증·로드 (ConfigModule + 스키마 검증)
├── database    # TypeORM 연결, DataSource, 마이그레이션
├── modules     # 도메인 모듈: auth, users, health
├── logger      # Winston 기반 로거
├── app.module.ts
└── main.ts     # 부트스트랩 (전역 파이프/필터, helmet, CORS, Swagger)
```

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
- TDD/품질 게이트 자동화 설계는 [`docs/quality-gate.md`](docs/quality-gate.md) 참고.

## 로드맵

- Refresh Token · RBAC · Redis Cache · BullMQ · S3 Upload · OpenTelemetry · GitHub Actions
- [ ] **TDD/품질 게이트 자동화 (Claude Code skills + hooks)** — 편집 시 PostToolUse 자동 포맷 +
      종료 시 Stop 게이트로 `test`/`lint`/`prettier --check` 차단. 상세 설계:
      [`docs/quality-gate.md`](docs/quality-gate.md).
