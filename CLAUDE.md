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
pnpm test:e2e                    # e2e (testcontainers 가 PG 자동 기동 — Docker 데몬만 필요)

pnpm exec tsc --noEmit -p tsconfig.json   # 타입체크 단독 실행 (전용 스크립트 없음; Stop 게이트가 사용)

pnpm migration:generate src/database/migrations/<Name>   # 엔티티 변경 후 생성
pnpm migration:run               # 마이그레이션 적용  /  migration:revert 로 롤백
pnpm seed                        # 기본 admin 계정 시드 (admin@example.com / password)

pnpm openapi:generate            # docs/openapi.json 생성 (DB 불필요 — DataSource 스텁, ADR 0004)
```

> **컨트롤러/DTO/라우트를 변경하면 `pnpm openapi:generate` 로 `docs/openapi.json` 을 재생성해
> 함께 커밋한다.** CI 가 `git diff --exit-code` 로 스펙 드리프트를 차단한다.

> **DB 초기화 순서:** `docker compose up -d postgres` → `pnpm migration:run` → `pnpm seed`.
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

비자명한 규칙: **검증 경로가 둘로 나뉜다** — env 검증(명시 `@Type` 변환)과 요청 DTO 검증(implicit
변환)은 설정을 서로 맞추면 안 된다. 상세는 [`docs/architecture.md`](docs/architecture.md) 참고.

## 아키텍처 / 규칙

- **레이어링** → Controller(얇게: 라우팅·DTO 바인딩) → Service(비즈니스 로직) →
  Repository(TypeORM). 컨트롤러에 비즈니스 로직을 두지 말고 서비스로 위임합니다.
- **입력 검증** → 모든 입력은 DTO + class-validator. `ValidationPipe` 옵션 정본 위치·bcrypt 쌍규칙
  등 상세는 `.claude/rules/dto-validation.md`(해당 파일 작업 시 자동 로드).
- **인증/인가** → JWT(httpOnly 쿠키 + Bearer 폴백 — ADR 0005), **deny-by-default**(전역
  `APP_GUARD`). 데코레이터 사용법·소유권 검증(IDOR) 등 상세는 `.claude/rules/auth.md`.
- **에러 응답** → Global Exception Filter가 모든 예외를 표준 형식으로 통일합니다
  (형식은 README "Standard Error Response" 참고 — 이 문서에서 중복 정의하지 않음).
- **응답·세부 규약** → 성공 응답 형태(단건=엔티티 직접 반환, 목록=`{ items, meta }` 페이지네이션),
  예외 타입 매핑, 쿼리/관계, DTO 직렬화 등 세부 규약의 **정본은
  [`docs/api-conventions.md`](docs/api-conventions.md)**(`api-endpoint` 스킬이 절차 래퍼로 참조 —
  본문은 이 문서에 중복하지 않음).
- **설정/검증** → 환경 변수는 부팅 시 스키마로 검증하여 잘못된 설정이면 즉시 중단(fail-fast)합니다.
  특히 `JWT_SECRET`이 비었거나 너무 짧으면 실행을 막습니다(변수 목록은 README 참고).
- **로깅** → Winston. 요청 로깅은 인터셉터로, 애플리케이션 로그는 Nest `Logger` 대체 구현으로.
  **request id** 는 `RequestIdMiddleware`(AsyncLocalStorage)가 시작하고 winston format 이 모든
  로그에 자동 주입한다 — 로거 호출부에서 id 를 수동으로 넘기지 말 것.
- **보안** → `main.ts`에서 helmet(HSTS) · CORS · rate limiting(ThrottlerModule) · payload 100kb 제한 ·
  `trust proxy`. CORS_ORIGIN 은 **production 에서 필수**(미설정 시 부팅 차단), Swagger `/api-docs` 는
  prod 비활성. 시크릿 스캔 gitleaks + **SAST Semgrep**(CI `sast` 잡, private Free repo 라 CodeQL 대신) +
  `pnpm audit --prod`(CI) + `eslint-plugin-security` + SBOM(CycloneDX). 수정 불가 CVE 는
  `pnpm-workspace.yaml` `auditConfig.ignoreCves` 에 사유와 함께 기록. 로그인 brute-force 완화·감사
  로그는 `.claude/rules/auth.md`. 체크리스트: [`docs/secure-harness-nestjs.md`](docs/secure-harness-nestjs.md),
  위협 모델: [`docs/threat-model.md`](docs/threat-model.md).
- **마이그레이션(비자명 규칙)** → `synchronize: true` 금지 — 앱과 분리된 `DataSource` 기준으로
  스키마는 마이그레이션으로만 변경(생성 → 검토 → `migration:run`).
  상세: `.claude/rules/migrations.md` · `migration-workflow` 스킬.

## 코드 컨벤션

- **타입 안정성 우선** — TypeScript 타입을 명확히 지정하고 `any` 사용을 지양합니다.
  `tsconfig`의 `strict`를 켭니다.
- **최소 보일러플레이트** — 불필요한 추상화를 피하고 NestJS 관용 구조(모듈/프로바이더)를 따릅니다.
- **ESLint + Prettier** — 모든 코드는 린트/포매팅 규칙을 통과해야 합니다 (`pnpm lint`, `pnpm format`).
- **Husky + Lint-Staged** — 커밋 시 변경 파일에 자동으로 `eslint --fix` + `prettier`가 적용됩니다.

### 머신이 강제하는 일관성 규칙

네이밍(kebab-case 파일·PascalCase enum 멤버 등)·import 정렬·`import type`·커밋 메시지
(Conventional Commits)는 *관례가 아니라 린터/타입체커/commitlint 가 강제*한다 — 어기면
`pnpm lint`/`typecheck`(따라서 Stop 게이트·CI·커밋 훅)가 실패한다. 상세 목록은
[`CONTRIBUTING.md`](CONTRIBUTING.md) "머신이 강제하는 스타일" 절 참고.

### 의도적으로 채택하지 않은 것 (고치지 말 것)

다음은 누락이 아니라 **의도적 선택**이다. "강화"하려다 오히려 기존 패턴을 깨지 않도록 주의.
근거 상세·재검토 트리거는 [`docs/adr/`](docs/adr/README.md) (특히 ADR 0002·0003) 참고:

- **`noUncheckedIndexedAccess` 미사용** — 코드가 이미 `??`/`?.`로 방어적이고 churn 대비 이득이 작다
  (테스트·배열 코드에 부담). 데이터 중심 로직이 늘면 재검토.
- **typescript-eslint `strictTypeChecked` 프리셋 미채택** — `no-non-null-assertion` 이 엔티티 필드의
  의도적 `!`(definite assignment) 관례와 충돌. 가치 있는 룰만 개별 채택했다.
- **복잡도 캡(complexity/max-lines 등) 미도입** — 아직 없는 문제. 필요 시 추가.
- **엔티티/DTO 필드의 `!`** — TypeORM/검증이 런타임에 채우는 값이라 의도적이다. non-null assertion 제거 금지.

## 테스트

- **단위 테스트** → Jest(`*.spec.ts`). 서비스는 Repository를 모킹하여 비즈니스 로직을 검증합니다.
- **e2e 테스트** → `test/*.e2e-spec.ts`. **testcontainers 가 전용 PG 를 자동 기동**(마이그레이션·시드
  포함 — ADR 0009)하므로 compose DB 불필요, 단 Docker 데몬은 필요. 빠른 피드백 루프(Stop 게이트)에는
  포함하지 않습니다.

## Claude Code 자동화 (`.claude/`)

`.claude/settings.json` 이 훅을 등록한다. 코드를 만질 때 아래 동작을 전제로 한다.

- **SessionStart** → `session-context.sh`: 브랜치 등 컨텍스트를 주입.
- **PreToolUse(Bash)** → `guard-bash.sh`(파괴적 명령 차단: `rm -rf /`, force push, `reset --hard`,
  DROP/TRUNCATE) + `guard-psql.sh`(psql 은 `-c '<SELECT...>'` 단일 읽기 구문만 허용 — db-reader 가드,
  케이스 테스트는 `guard-psql.test.sh`). `permissions.deny` 가 sudo·publish 등을 이중 차단.
- **PostToolUse(Edit/Write)** → `format-changed-file.sh`: 변경된 `*.ts` 에 `eslint --fix` + `prettier` 자동 적용.
- **Stop** → `gate.sh`: 세션 종료 전 정적 검사 `tsc --noEmit` + `eslint` + `prettier --check` 후
  **유닛 `jest`**(`*.spec.ts`만; e2e 제외) 게이트. 통과 시 `review-gate.sh` 가 변경된 `src/*.ts` 를
  헤드리스 haiku 로 의미 리뷰한다 — **규약 정본(`docs/api-conventions.md`) 전문을 런타임
  주입**(동기화 불요). blocker 시 `exit 2`, 라운드 상한 2회, `claude` 미설치/타임아웃 시 비차단.
  `CC_AUTO_REVIEW=1`(settings.json `env`)로 상시 활성(끄려면 값 제거/`0`).
- **경로 스코프 규칙(`.claude/rules/`)** → `controllers`·`dto-validation`·`migrations`·`auth`·`testing`.
  frontmatter `paths` 글롭에 맞는 파일을 만질 때만 자동 로드된다(CLAUDE.md 비대화 방지) —
  이 문서의 요지 뒤에 숨은 상세 규칙은 거기에 있다.
- **스킬(`.claude/skills/`)** → `code-review`(백엔드 리뷰 기준), `api-endpoint`(정본
  `docs/api-conventions.md` 의 절차 래퍼), `scaffold-module`(신규 모듈 스캐폴딩 —
  `src/modules/users/` 를 살아있는 템플릿으로 미러링), `migration-workflow`(마이그레이션
  생성→검토→적용 절차), `write-e2e`(testcontainers e2e 작성 절차), `tdd`(`/tdd` —
  RED→GREEN→REFACTOR). 작업 맥락에 맞춰 자동 로드된다.
- **서브에이전트(`.claude/agents/`)** → 역할별 모델 차등 고정(판단=opus, 실행=haiku — ADR 0010):
  `code-reviewer`(opus)·`security-reviewer`(opus, 읽기전용+memory)·`migration-reviewer`(opus)·
  `test-runner`(haiku, 실패만 요약)·`db-reader`(haiku, psql SELECT 전용 — guard-psql 이 강제).

## 로드맵

[README.md](README.md) "Roadmap" 절 참고(Refresh Token 보류 — ADR 0006, 인증 프로파일
MVP/Production 분리 — ADR 0007 포함).
