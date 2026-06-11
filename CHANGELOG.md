# Changelog

이 프로젝트의 주요 변경 사항을 기록합니다.
형식은 [Keep a Changelog](https://keepachangelog.com/ko/1.1.0/)를 따르며,
버전 규칙은 [Semantic Versioning](https://semver.org/lang/ko/)을 따릅니다.

## [Unreleased]

## [0.2.0] - 2026-06-11

보안·인증 하드닝과 PostgreSQL 전환, e2e 격리, 그리고 Claude Code 하네스 확장을 담은 릴리스.

### Changed

- **데이터베이스 PostgreSQL 17 전환** — TypeORM 드라이버·`docker-compose`·마이그레이션·시드를
  MySQL 에서 PostgreSQL 17 기준으로 전환(`pg`). 0.x 단계의 호환성 비유지 변경.
- **하네스 정본-참조 체계 확립** — `review-gate.sh` 가 규약 정본(`docs/api-conventions.md`)
  전문을 런타임 주입(요지 수동 동기화 0곳), `code-review`·`api-endpoint`·`tdd` 스킬의 규약 요지
  중복 제거(정본 참조로 전환), `rules/auth.md` paths 를 `src/modules/**` 로 확대, CLAUDE.md 규칙
  절 포인터화, `session-context.sh` 중복 규칙 요약 제거.
- **설정 통합** — `commitlint.config.js`·`.prettierrc` 를 `package.json` 필드로 흡수(파일 -2).

### Added

- **인증** — JWT 를 httpOnly 쿠키로 발급(+ Bearer 헤더 폴백, ADR 0005), 로그아웃 엔드포인트,
  deny-by-default 전역 인증 가드(`@Public()` 명시 예외), 로그인 throttle 강화, 로그인 성공/실패
  보안 감사 로그.
- **HTTP/설정 가드레일** — CORS production fail-fast, payload 100kb 제한, helmet HSTS,
  Swagger production 비활성, `forbidNonWhitelisted` 활성 + `ValidationPipe` 옵션 공유 상수.
- **관측/헬스** — `/health` liveness·readiness 분리(Terminus), AsyncLocalStorage 기반
  request-id 로그 전파, graceful shutdown(`enableShutdownHooks`).
- **테스트/문서** — testcontainers 로 e2e PostgreSQL 격리(마이그레이션·시드 자동, ADR 0009),
  OpenAPI 스펙 생성 스크립트(DB 불필요) + CI 드리프트 게이트, 커버리지 게이트 + 단위 테스트 확충.
- **보안 파이프라인** — gitleaks 시크릿 스캔, SAST(Semgrep) + `eslint-plugin-security`,
  SBOM(CycloneDX), `pnpm audit --prod` 게이트, Dependabot 주간 업데이트, tar override 로 bcrypt
  경유 취약점 해소.
- **거버넌스/하네스** — ADR 체계(도입·위협 모델·인증 프로파일 MVP/Production·서브에이전트 모델
  차등 0010), Claude Code 하네스 확장(서브에이전트 4종·읽기전용 DB 가드·`migration-workflow`·
  `write-e2e` 스킬·경로 스코프 rules 5종), typecheck·commitlint·simple-import-sort·네이밍/타입
  ESLint·`noUnusedLocals`/`noUnusedParameters` 강제.

### Fixed

- `scaffold-module` 스킬의 "`@UseGuards` 재부착" 안내가 전역 가드(deny-by-default) 규칙과
  모순되던 것을 수정.
- e2e 의 ThrottlerGuard override 무력화(스토리지 스텁으로 교체), `LoginDto` MaxLength·POST
  명시적 HttpCode 정합.

### Removed

- 완료된 `docs/test-coverage-epic.md`(계획 spec·커버리지 게이트 모두 반영 완료), 낡은
  `docs/harness-nestjs.md`(점검은 `docs/cc-harness-nestjs.md` 로 일원화 — 미완 항목은 README
  Roadmap 으로 이관).

## [0.1.0] - 2026-06-10

최초 배포. 프로덕션 지향 NestJS API 백엔드 템플릿의 핵심 스캐폴딩.

### Added

- **프로젝트 부트스트랩** — NestJS + TypeScript, 경로 별칭 `@/*` → `src/*`
  (tsconfig·Jest·런타임 3곳 정렬), `nest build && tsc-alias` 빌드.
- **인증** — JWT(passport-jwt) 기반 로그인, bcrypt 비밀번호 해싱, `JwtAuthGuard`·
  `RolesGuard`·`@CurrentUser()`·`@Roles()` 데코레이터.
- **users 모듈** — role 기반 RBAC, 목록 조회 페이지네이션(`PaginationQueryDto`,
  `{ items, meta }` 표준 응답).
- **데이터베이스** — TypeORM(MySQL), 앱과 분리된 마이그레이션 전용 `DataSource`,
  마이그레이션·기본 admin 시드 스크립트.
- **검증/직렬화** — 전역 `ValidationPipe`(`whitelist`·`transform`), DTO + class-validator,
  부팅 시 환경 변수 스키마 검증(fail-fast), `ClassSerializerInterceptor`.
- **에러/로깅** — Global Exception Filter(표준 에러 응답), Winston 로깅 +
  요청 로깅 인터셉터.
- **보안** — helmet · CORS · rate limiting(ThrottlerModule).
- **문서/관측** — Swagger 자동 문서(`/api-docs`), Terminus 헬스체크.
- **테스트** — Jest 단위 테스트(`*.spec.ts`, Repository 모킹), e2e(`*.e2e-spec.ts`).
- **개발 환경** — Docker Compose(MySQL), pnpm 패키지 매니저, ESLint · Prettier · Husky,
  GitHub Actions CI(lint·build·test; DB 의존 e2e 는 `RUN_E2E` 게이트).
- **Claude Code 자동화** — `.claude/` 훅(session/guard/format/Stop 게이트)과
  스킬(`code-review`·`api-endpoint`·`scaffold-module`·`tdd`).
- **거버넌스** — `CONTRIBUTING.md`(브랜치 전략·Conventional Commits·SemVer),
  PR 템플릿, 본 `CHANGELOG.md`.

### Notes

- 초기 버전으로 구조/API 가 변경될 수 있습니다(0.x).
- 로드맵: Refresh Token · RBAC 확장 · Redis Cache · BullMQ · S3 Upload · OpenTelemetry.

[Unreleased]: https://github.com/lcgyung/nestjs-api-template/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/lcgyung/nestjs-api-template/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/lcgyung/nestjs-api-template/releases/tag/v0.1.0
