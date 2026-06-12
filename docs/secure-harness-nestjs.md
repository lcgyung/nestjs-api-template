# 시큐어 코딩 하네스 체크리스트 — NestJS (API)

> 보안 규칙을 "지침"이 아니라 **자동 강제 게이트**로 만드는 것을 목표로 합니다.
> 우선순위: 🔴 필수 · 🟡 권장 · 🟢 선택
>
> **상태: 2026-06-11 기준 갱신** — 미체크 항목은 의도적 보류(사유 병기). 위협 모델은
> [`threat-model.md`](threat-model.md), 결정 근거는 [`adr/`](adr/README.md) 참고.
>
> **프로파일 주의** — 이 체크리스트는 **Production 프로파일** 기준이다. **MVP 프로파일**에선 §0(보안
> 자동화)·§8(CI 게이트)의 🟡/🟢 다수와 §2 일부를 보류하고, 자격증명은 ID/PW 대신 외부 본인인증
> 전략으로 대체할 수 있다(공통 세션 골격·데이터 보호 하네스는 그대로 유지). 프로파일 구분의 근거는
> [ADR 0007](adr/0007-인증-프로파일-분리-자격증명-전략.md).

---

## 0. 보안 자동화 기반 (모든 항목의 토대)

- [x] 🔴 SAST — Semgrep CI 게이트 (`ci.yml` `sast` 잡, p/typescript·p/nodejs·p/owasp-top-ten)
- [x] 🔴 `eslint-plugin-security` (recommended; `detect-object-injection` 은 오탐 과다로 비활성)
      _`eslint-plugin-no-unsanitized` 는 DOM(innerHTML) 전용이라 백엔드 비대상_
- [x] 🔴 시크릿 스캔 — gitleaks (pre-commit + CI, `fetch-depth: 0` 히스토리 포함)
- [x] 🔴 SCA(의존성 취약점) — `pnpm audit --prod --audit-level=high` CI 게이트
- [x] 🔴 lockfile 커밋 + 무결성 검사 (`pnpm install --frozen-lockfile`)
- [x] 🟡 의존성 자동 업데이트 — Dependabot (npm + github-actions, weekly)
- [x] 🟡 SBOM 생성 (CycloneDX) — `ci.yml` `sbom` 잡(cdxgen), 아티팩트 업로드
- [x] 🟡 `docs/threat-model.md` + 보안 ADR ([0005](adr/0005-jwt-쿠키-전환-csrf-전략.md)·[0006](adr/0006-refresh-토큰-회전-보류.md))
- [ ] 🟢 컨테이너 이미지 스캔 (Trivy) _(Dockerfile 부재 — 컨테이너화 시 도입)_

## 1. 입력 검증 & 직렬화

- [x] 🔴 글로벌 `ValidationPipe` — `whitelist` + `forbidNonWhitelisted` + `transform`
- [x] 🔴 모든 입력에 DTO + class-validator — Mass Assignment 차단
- [x] 🔴 출력 직렬화 `ClassSerializerInterceptor` + `@Exclude()` (`User.password`)
- [x] 🟡 페이로드 크기 제한 (json/urlencoded 100kb)
- [x] 🟡 쿼리 파라미터 화이트리스트 _정렬/필터는 화이트리스트만 수용(api-endpoint 스킬); 현재 정렬 하드코딩으로 인젝션 표면 없음_

## 2. 인증 (Authentication)

- [x] 🔴 비밀번호 해싱 — bcrypt(rounds 10), 평문 저장 금지
- [ ] 🔴 JWT — 짧은 access + refresh 토큰 회전, 서버측 폐기 _([ADR 0006](adr/0006-refresh-토큰-회전-보류.md) — 별도 기능 규모로 보류, 로드맵)_
- [x] 🔴 토큰을 `httpOnly` + `Secure`(prod) + `SameSite=Strict` 쿠키로 ([ADR 0005](adr/0005-jwt-쿠키-전환-csrf-전략.md))
- [x] 🔴 로그인 brute-force 방지 — 로그인 전용 `@Throttle`(분당 5) _계정 잠금은 상태 저장 필요로 보류_
- [x] 🟡 JWT 서명 키 환경변수 분리 + 부팅 검증(`@MinLength(16)`) _키 회전 정책은 보류_
- [ ] 🟢 MFA / 디바이스 바인딩

## 3. 인가 (Authorization)

- [x] 🔴 Guard 기반 RBAC — `RolesGuard` + `@Roles`, `Role` enum
- [x] 🔴 **객체 소유권 검증 (IDOR/BOLA 방지)** _현재 `users` 는 전부 admin 전용이라 소유권 표면 없음. 신규 도메인용 규약을 api-endpoint 스킬·[threat-model](threat-model.md) 에 명시_
- [x] 🟡 기본 거부(deny-by-default) — 전역 `JwtAuthGuard` + `@Public()` 명시 예외
- [x] 🟡 권한 검사 e2e 테스트 — 일반 사용자 → admin 라우트 403 시나리오

## 4. 인젝션 / 데이터 접근

- [x] 🔴 ORM 파라미터화 쿼리 (TypeORM Repository) — raw 보간 없음
- [x] 🔴 NoSQL 인젝션 방지 _MySQL/TypeORM 만 사용, 쿼리에 사용자 객체 직접 주입 없음_
- [ ] 🟡 파일 업로드 검증 _(업로드 기능 없음 — 도입 시 MIME/크기/path traversal 적용)_
- [ ] 🟡 SSRF 방지 _(외부 요청 표면 없음 — 도입 시 URL 화이트리스트)_
- [x] 🟢 명령 실행 회피 — `child_process` 미사용 + `eslint-plugin-security` detect-child-process 가드

## 5. HTTP 가드레일

- [x] 🔴 helmet — 보안 헤더 + HSTS 명시(maxAge 180d, includeSubDomains)
- [x] 🔴 CORS — origin 화이트리스트, production 미설정 시 fail-fast(와일드카드 차단)
- [x] 🔴 rate limiting (`@nestjs/throttler`) — 전역 + 로그인 강화
- [x] 🟡 CSRF — `SameSite=Strict` 로 차단([ADR 0005](adr/0005-jwt-쿠키-전환-csrf-전략.md)); Bearer 폴백은 CSRF 무관
- [x] 🟡 HSTS 헤더 강제 _TLS 종료·HSTS preload 등록은 배포 인프라 영역_
- [ ] 🟢 웹훅 서명 검증 + 멱등성 키 _(웹훅 없음)_

## 6. 시크릿 & 설정

- [x] 🔴 시크릿 리포 금지 — `.env` gitignore + gitleaks
- [x] 🔴 `ConfigModule` + 환경변수 스키마 검증(class-validator) — 누락 시 부팅 실패
- [x] 🟡 환경별 설정 분리 + prod 디버그 비활성 — `.env.${NODE_ENV}`, prod Swagger 비활성
- [ ] 🔴 시크릿 매니저(Vault / AWS Secrets Manager) _배포 인프라 영역 — env 주입까지 충족_
- [ ] 🟢 시크릿 회전 자동화

## 7. 에러 처리 & 로깅

- [x] 🔴 글로벌 예외 필터 — 500 스택 트레이스/내부 정보 비노출, 표준 에러 포맷
- [x] 🔴 로그 민감정보 마스킹 — 이메일 마스킹, 요청 바디 미로깅(비밀번호 노출 차단)
- [x] 🟡 보안 이벤트 감사 로그 — 로그인 성공/실패
- [x] 🟡 구조화 로깅 + request id (winston, AsyncLocalStorage 전파)
- [ ] 🟡 에러 트래킹 (Sentry) — PII 스크러빙 _(외부 계정 필요 — 로드맵)_

## 8. CI/CD 보안 게이트

- [x] 🔴 PR 게이트 — SAST · 시크릿 스캔 · SCA 통과 못 하면 머지 차단
- [ ] 🔴 브랜치 보호 + 필수 리뷰 _(GitHub Free private repo — ruleset 403; public/Pro 전환 시)_
- [ ] 🟡 서명 커밋(commit signing) _(로컬 키 정책 의존 — opt-in)_
- [x] 🟡 보안 테스트(인가 시나리오) PR 필수 — 403 e2e + 정적 게이트
- [ ] 🟢 DAST(OWASP ZAP) 스테이징 정기 실행 _(배포 인프라 영역)_

---

## 권장 셋업 순서

1. 보안 자동화 기반 (SAST·시크릿·SCA·lockfile) → CI 게이트화
2. ValidationPipe(whitelist) + 직렬화 + 시크릿 검증
3. 인증(해싱·JWT 쿠키) + brute-force 방지
4. 인가(RBAC + deny-by-default + 소유권) + 권한 e2e 테스트
5. helmet/CORS/throttler + 예외 필터(누출 차단)
6. 감사 로그 + 에러 트래킹 + DAST
