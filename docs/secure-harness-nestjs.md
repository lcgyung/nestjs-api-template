# 시큐어 코딩 하네스 체크리스트 — NestJS (API)

> 보안 규칙을 "지침"이 아니라 **자동 강제 게이트**로 만드는 것을 목표로 합니다.
> 우선순위: 🔴 필수 · 🟡 권장 · 🟢 선택

---

## 0. 보안 자동화 기반 (모든 항목의 토대)

- [ ] 🔴 SAST — Semgrep 또는 CodeQL CI 게이트
- [ ] 🔴 `eslint-plugin-security` + `eslint-plugin-no-unsanitized`
- [ ] 🔴 시크릿 스캔 — gitleaks/trufflehog (pre-commit + CI, 히스토리 포함)
- [ ] 🔴 SCA(의존성 취약점) — `pnpm audit` / osv-scanner / Snyk CI 게이트
- [ ] 🔴 lockfile 커밋 + 무결성 검사 (`pnpm install --frozen-lockfile`)
- [ ] 🟡 의존성 자동 업데이트 (Renovate / Dependabot)
- [ ] 🟡 SBOM 생성 (CycloneDX)
- [ ] 🟡 `docs/threat-model.md` + 보안 관련 ADR
- [ ] 🟢 컨테이너 이미지 스캔 (Trivy)

## 1. 입력 검증 & 직렬화

- [ ] 🔴 글로벌 `ValidationPipe` — `whitelist: true`, `forbidNonWhitelisted: true`, `transform: true`
- [ ] 🔴 모든 입력에 DTO + class-validator (또는 zod) — **Mass Assignment 차단**
- [ ] 🔴 출력 직렬화 `ClassSerializerInterceptor` + `@Exclude()` — 비밀번호/토큰 등 민감 필드 노출 방지
- [ ] 🟡 페이로드 크기 제한 (body-parser limit, 파일 업로드 한도)
- [ ] 🟡 쿼리 파라미터 화이트리스트 (정렬/필터 인젝션 방지)

## 2. 인증 (Authentication)

- [ ] 🔴 비밀번호 해싱 — argon2 (또는 bcrypt), 평문 저장 금지
- [ ] 🔴 JWT — 짧은 access + refresh 토큰 회전(rotation), 서버측 폐기 가능
- [ ] 🔴 토큰을 `httpOnly` + `Secure` + `SameSite` 쿠키로 (localStorage 지양)
- [ ] 🔴 로그인 brute-force 방지 (시도 제한 + 계정 잠금/지연)
- [ ] 🟡 시크릿/키 회전 정책, JWT 서명 키 환경변수 분리
- [ ] 🟢 MFA / 디바이스 바인딩

## 3. 인가 (Authorization)

- [ ] 🔴 Guard 기반 RBAC/ABAC (CASL 등)
- [ ] 🔴 **객체 소유권 검증 (IDOR/BOLA 방지)** — "이 리소스가 이 유저의 것인가"를 모든 조회/수정에서 확인
- [ ] 🟡 기본 거부(deny-by-default) — 명시적 허용만 통과
- [ ] 🟡 권한 검사 e2e 테스트 (다른 유저 리소스 접근 시 403 확인)

## 4. 인젝션 / 데이터 접근

- [ ] 🔴 ORM 파라미터화 쿼리 (Prisma/TypeORM) — raw 쿼리 시 바인딩 필수
- [ ] 🔴 NoSQL 인젝션 방지 (쿼리에 사용자 객체 직접 주입 금지)
- [ ] 🟡 파일 업로드 — MIME/확장자 검증, 크기 제한, 경로 조작(path traversal) 차단, 실행권한 제거
- [ ] 🟡 SSRF 방지 — 외부 요청 URL 화이트리스트, 내부망/메타데이터 IP 차단
- [ ] 🟢 명령 실행 회피 — `child_process` 사용자 입력 주입 금지

## 5. HTTP 가드레일

- [ ] 🔴 helmet — 보안 헤더 (HSTS, X-Content-Type-Options, frame-ancestors 등)
- [ ] 🔴 CORS — origin 화이트리스트 (와일드카드 `*` + credentials 금지)
- [ ] 🔴 rate limiting (`@nestjs/throttler`)
- [ ] 🟡 쿠키 인증 시 CSRF 토큰 (csurf 또는 double-submit)
- [ ] 🟡 TLS/HTTPS 강제 + HSTS preload
- [ ] 🟢 웹훅 서명 검증 + 멱등성 키

## 6. 시크릿 & 설정

- [ ] 🔴 시크릿은 리포에 절대 금지 — 환경변수/시크릿 매니저(Vault, AWS Secrets Manager)
- [ ] 🔴 `ConfigModule` + 환경변수 스키마 검증 (joi/zod) — 누락 시 부팅 실패
- [ ] 🟡 환경별 설정 분리 (dev/staging/prod), prod 디버그 비활성
- [ ] 🟢 시크릿 회전 자동화

## 7. 에러 처리 & 로깅

- [ ] 🔴 글로벌 예외 필터 — prod에서 **스택 트레이스/내부 정보 누출 금지**, 표준 에러 포맷
- [ ] 🔴 로그에 민감정보(비밀번호, 토큰, PII) 마스킹/제외
- [ ] 🟡 보안 이벤트 감사 로그 (로그인 성공/실패, 권한 변경)
- [ ] 🟡 구조화 로깅 + request/trace id (재현·추적용)
- [ ] 🟡 에러 트래킹 (Sentry) — PII 스크러빙 설정

## 8. CI/CD 보안 게이트

- [ ] 🔴 PR 게이트 — SAST · 시크릿 스캔 · SCA 통과 못 하면 머지 차단
- [ ] 🔴 브랜치 보호 + 필수 리뷰
- [ ] 🟡 서명 커밋(commit signing)
- [ ] 🟡 보안 테스트(인가/인증 시나리오) PR 필수
- [ ] 🟢 DAST(동적 스캔, OWASP ZAP) 스테이징 정기 실행

---

## 권장 셋업 순서

1. 보안 자동화 기반 (SAST·시크릿·SCA·lockfile) → CI 게이트화
2. ValidationPipe(whitelist) + 직렬화 + 시크릿 검증
3. 인증(해싱·JWT 회전·쿠키) + brute-force 방지
4. 인가(RBAC + IDOR 검증) + 권한 e2e 테스트
5. helmet/CORS/throttler + 예외 필터(누출 차단)
6. 감사 로그 + 에러 트래킹 + DAST
