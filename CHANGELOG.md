# Changelog

이 프로젝트의 주요 변경 사항을 기록합니다.
형식은 [Keep a Changelog](https://keepachangelog.com/ko/1.1.0/)를 따르며,
버전 규칙은 [Semantic Versioning](https://semver.org/lang/ko/)을 따릅니다.

## [0.1.0] - 2026-06-12

최초 배포. 인증·DB·검증·로깅·보안·관측·테스트와 Claude Code 하네스를 갖춘 프로덕션 지향
NestJS API 백엔드 템플릿.

### Added

- **프로젝트 부트스트랩** — NestJS + TypeScript(strict), 경로 별칭 `@/*` → `src/*`
  (tsconfig·Jest·런타임 3곳 정렬), `nest build && tsc-alias` 빌드, pnpm 패키지 매니저.
- **인증/인가** — JWT 를 httpOnly 쿠키로 발급(+ Bearer 헤더 폴백, ADR 0005), 로그아웃
  엔드포인트, **deny-by-default 전역 인증 가드**(`@Public()` 명시 예외), role 기반 RBAC
  (`RolesGuard`·`@Roles()`·`@CurrentUser()`), bcrypt 비밀번호 해싱, 로그인 throttle 강화 및
  성공/실패 보안 감사 로그.
- **users 모듈** — role 기반 RBAC, 목록 조회 페이지네이션(`PaginationQueryDto`,
  `{ items, meta }` 표준 응답).
- **데이터베이스** — TypeORM + **PostgreSQL 17**(`pg`), `synchronize` 미사용, 앱과 분리된
  마이그레이션 전용 `DataSource`, 마이그레이션·기본 admin 시드 스크립트.
- **검증/직렬화** — 전역 `ValidationPipe`(`whitelist`·`forbidNonWhitelisted`·`transform`),
  DTO + class-validator, 부팅 시 환경 변수 스키마 검증(fail-fast), `ClassSerializerInterceptor`.
- **에러/로깅** — Global Exception Filter(표준 에러 응답), Winston 로깅 + 요청 로깅 인터셉터,
  AsyncLocalStorage 기반 request-id 자동 전파.
- **HTTP/보안 가드레일** — helmet(HSTS) · CORS(production fail-fast) · rate limiting
  (ThrottlerModule) · payload 100kb 제한 · `trust proxy` · graceful shutdown
  (`enableShutdownHooks`), Swagger production 비활성.
- **관측/헬스** — `/health` liveness·readiness 분리(Terminus).
- **문서** — Swagger 자동 문서(`/api-docs`), OpenAPI 스펙 생성 스크립트(DB 불필요) +
  CI 드리프트 게이트.
- **테스트** — Jest 단위 테스트(`*.spec.ts`, Repository 모킹), **testcontainers 로 e2e
  PostgreSQL 격리**(마이그레이션·시드 자동, ADR 0009), 커버리지 게이트.
- **보안 파이프라인** — gitleaks 시크릿 스캔, SAST(Semgrep) + `eslint-plugin-security`,
  SBOM(CycloneDX), `pnpm audit --prod` 게이트.
- **CI/의존성 관리** — GitHub Actions CI(lint·build·test·보안), Dependabot 안정화 —
  릴리즈 직후 미성숙 버전을 거르는 cooldown(patch 3·minor 7·major 30일)과 상호 의존 패밀리
  (@nestjs·eslint·jest·typescript·commitlint·@types) 호환성 그룹화.
- **Claude Code 자동화** — `.claude/` 훅(session/guard/format/Stop 게이트·모드별 보상 통제),
  스킬(`code-review`·`api-endpoint`·`scaffold-module`·`migration-workflow`·`write-e2e`·`tdd`),
  서브에이전트 4종(역할별 모델 차등 — ADR 0010), 경로 스코프 rules 5종, 읽기전용 DB 가드.
- **거버넌스** — ADR 체계(도입·위협 모델·인증 프로파일 MVP/Production 등), `CONTRIBUTING.md`
  (브랜치 전략·Conventional Commits·SemVer), PR 템플릿, 본 `CHANGELOG.md`.

### Notes

- 초기 버전으로 구조/API 가 변경될 수 있습니다(0.x).
- 로드맵: Refresh Token · RBAC 확장 · Redis Cache · BullMQ · S3 Upload · OpenTelemetry.

[0.1.0]: https://github.com/lcgyung/nestjs-api-template/releases/tag/v0.1.0
