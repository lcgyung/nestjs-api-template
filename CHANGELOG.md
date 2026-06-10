# Changelog

이 프로젝트의 주요 변경 사항을 기록합니다.
형식은 [Keep a Changelog](https://keepachangelog.com/ko/1.1.0/)를 따르며,
버전 규칙은 [Semantic Versioning](https://semver.org/lang/ko/)을 따릅니다.

## [Unreleased]

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

[Unreleased]: https://github.com/lcgyung/nestjs-api-template/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/lcgyung/nestjs-api-template/releases/tag/v0.1.0
