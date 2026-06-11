# 하네스 엔지니어링 체크리스트 — NestJS (API)

> 백엔드 API 프로젝트 단독 셋업 기준. 공통 기반 + NestJS 특화 항목을 모두 포함합니다.
> 우선순위: 🔴 필수 · 🟡 권장 · 🟢 선택
>
> **상태: 2026-06-11 기준 갱신** — 미체크 항목은 의도적 보류(사유 병기).

---

## 1. 컨텍스트 레이어

에이전트/개발자가 매번 추론하지 않도록 규칙과 맥락을 명시합니다.

- [x] 🔴 `CLAUDE.md` (또는 `AGENTS.md`) — 빌드·테스트·실행 명령, 코딩 컨벤션, "하지 말 것"
- [x] 🔴 `README` + API 아키텍처 다이어그램 (모듈 구조, 외부 의존성) — mermaid `## Architecture`
- [x] 🟡 `docs/adr/` — Architecture Decision Records (초기 0001~0004)
- [ ] 🟡 도메인 용어집 — 엔티티/유스케이스 네이밍 통일 _(도메인이 users 뿐이라 보류 — 도메인 추가 시)_
- [x] 🟡 모듈 경계 설명 (도메인 모듈 간 의존 규칙) — `CLAUDE.md` 프로젝트 구조·레이어링 절

## 2. 피드백 루프 레이어

- [x] 🔴 ESLint + Prettier
- [x] 🔴 `tsconfig` `strict: true`
- [x] 🔴 단일 명령으로 `lint` / `typecheck` / `test` / `build`
- [x] 🔴 단위 테스트 (Jest) + 커버리지 임계값 (`coverageThreshold` + CI `test:cov`)
- [x] 🔴 e2e 테스트 (supertest) — 테스트 DB 격리는 CI service container 로 충족
      _(testcontainers 비채택 — [ADR 0003](adr/0003-e2e-db-격리-testcontainers-비채택.md))_
- [x] 🟡 애플리케이션 부트 테스트 — e2e 가 `AppModule` compile + `app.init()` 수행
- [x] 🟡 watch 모드 (`--watch`) — `start:dev` / `test:watch`

## 3. API 계약 & 타입

- [x] 🔴 Swagger/OpenAPI 자동 생성 + 스펙 파일 export (`pnpm openapi:generate` → `docs/openapi.json`)
- [x] 🔴 DTO + 검증 — class-validator, 글로벌 `ValidationPipe`(`whitelist`+`forbidNonWhitelisted`)
- [x] 🔴 OpenAPI 스펙을 프론트 타입 생성 소스로 export (orval / openapi-typescript 연동 지점) —
      CI 드리프트 게이트 포함 ([ADR 0004](adr/0004-openapi-export-datasource-override.md))
- [x] 🟢 응답 직렬화 (`ClassSerializerInterceptor`) — 민감 필드 노출 방지

## 4. 데이터 / 재현성

- [x] 🔴 DB 마이그레이션 (TypeORM) — 결정론적, 롤백 가능 (`synchronize: false`)
- [x] 🔴 `ConfigModule` + 환경변수 스키마 검증 (class-validator, 부팅 fail-fast)
- [x] 🔴 `.env.example` 커밋
- [x] 🟡 시드 데이터 스크립트 (`pnpm seed`)
- [x] 🟡 `docker-compose` — MySQL
- [x] 🔴 `.nvmrc` / `packageManager` — Node 버전 고정 + lockfile 커밋

## 5. 가드레일 / 보안

- [x] 🔴 글로벌 예외 필터 + 표준 에러 응답 포맷
- [x] 🔴 helmet · CORS 정책 · rate limiting (`@nestjs/throttler`)
- [x] 🔴 시크릿 스캔 (gitleaks) — pre-commit(설치 시) + CI(히스토리 포함)
- [x] 🟡 의존성 취약점 스캔 — CI `pnpm audit --prod --audit-level=high`
- [x] 🟡 의존성 업데이트 봇 — Dependabot (npm + github-actions, weekly)

## 6. CI/CD 게이트

- [x] 🔴 husky + lint-staged
- [x] 🔴 PR 검증 워크플로 — lint · typecheck · test(+e2e) · build (+security · openapi 드리프트)
- [x] 🟡 commitlint + Conventional Commits

## 7. 관찰가능성 / 운영

- [x] 🔴 구조화 로깅 (prod JSON, `x-request-id` 수용·생성·전 로그 전파)
- [x] 🟡 로깅 인터셉터 (요청/응답 로깅)
- [x] 🟡 헬스체크 (`@nestjs/terminus`) — `/health/liveness` · `/health/readiness` 분리
- [ ] 🟡 에러 트래킹 (Sentry) _(외부 계정 필요 — 로드맵)_
- [x] 🟢 graceful shutdown (`enableShutdownHooks`)

---

## 권장 셋업 순서

1. 컨텍스트(CLAUDE.md) + lint/tsconfig + 단일 명령
2. ConfigModule 환경변수 검증 + DB 마이그레이션
3. DTO·ValidationPipe + Swagger/OpenAPI export
4. 단위·e2e 테스트 (testcontainers)
5. 예외 필터·보안 미들웨어 + CI 게이트
6. 로깅·헬스체크·에러 트래킹
