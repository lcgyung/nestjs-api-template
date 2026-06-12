# NestJS API Template

JWT 인증, TypeORM, Swagger, 검증·로깅이 구성된 프로덕션 지향 NestJS 백엔드 템플릿.

> **상태:** 핵심 스캐폴딩 완료 — 부트스트랩(`main.ts`)·JWT 인증·users·health·전역 검증/예외
> 필터/로깅·TypeORM 마이그레이션·단위/e2e 테스트·Docker(MySQL)·GitHub Actions CI 가 구성되어
> 있습니다. 미구현 항목은 하단 [Roadmap](#roadmap) 참고.

## Stack

NestJS · TypeScript · TypeORM · MySQL · JWT · Swagger · class-validator · Winston · ESLint · Prettier · Husky

## Features

- JWT 인증 (bcrypt 해싱)
- TypeORM + 마이그레이션
- Swagger 자동 문서화
- DTO 검증 + 환경 변수 검증
- Global Exception Filter (표준 에러 응답)
- helmet · CORS · rate limiting
- Winston 로깅
- ESLint + Prettier + Husky

## Quick Start

```bash
git clone https://github.com/<owner>/nestjs-api-template.git
cd nestjs-api-template
npm install
cp .env.example .env        # 값 채우기
docker compose up -d mysql  # 로컬 DB
npm run start:dev
```

Swagger: `http://localhost:3000/api-docs`

## Environment

```env
NODE_ENV=development
PORT=3000

DB_HOST=localhost
DB_PORT=3306
DB_NAME=app
DB_USERNAME=root
DB_PASSWORD=password

JWT_SECRET=             # openssl rand -base64 32 (16자 이상 필수)
JWT_EXPIRES_IN=1d

CORS_ORIGIN=            # 콤마 구분, 비우면 전체 허용
THROTTLE_TTL=60000      # rate limit 윈도(ms)
THROTTLE_LIMIT=100      # 윈도당 최대 요청 수
```

부팅 시 환경 변수를 검증하며, `JWT_SECRET`이 비어 있거나 너무 짧으면 실행을 중단합니다.

모드별 분리: `.env.development` / `.env.production`. 값 예시는 `.env.example` 참고.

## Seed Account & Auth Flow

시드 스크립트가 기본 관리자 계정을 생성합니다 (비밀번호 `password`).

| 이메일            | 역할  | 비고      |
| ----------------- | ----- | --------- |
| admin@example.com | admin | 전체 권한 |

로그인 → 토큰 발급 → 인증이 필요한 엔드포인트 호출:

```bash
# 1) 로그인 → accessToken 발급
curl -X POST http://localhost:3000/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"admin@example.com","password":"password"}'

# 2) 발급받은 토큰으로 보호된 엔드포인트 호출
curl http://localhost:3000/users/me \
  -H 'Authorization: Bearer <accessToken>'
```

## API / Swagger

엔드포인트 탐색·시도는 Swagger UI(`/api-docs`)에서. 보호된 라우트는 우상단 **Authorize**에
`Bearer <accessToken>`을 넣어 호출합니다. 요청 바디는 DTO + class-validator로 검증되며,
검증 실패·예외는 아래 **표준 에러 응답** 형식으로 통일됩니다.

## Structure

```text
src
├── common      # filters, interceptors, decorators, guards, enums(Role)
├── config      # env 검증(env.validation) 및 설정 로드(configuration)
├── database    # database.module, data-source(CLI), migrations, seeds
├── logger      # winston 설정 + LoggerModule
├── modules     # auth(JWT), users(role/RBAC), health(terminus)
├── app.module.ts
└── main.ts     # 부트스트랩 (전역 파이프/필터, helmet, CORS, Swagger, winston)
```

## Scripts

```bash
npm run start:dev          # 개발 서버 (watch)
npm run build              # 컴파일 (nest build + tsc-alias 경로 별칭 변환)
npm run lint               # ESLint
npm run format             # Prettier --write
npm run test               # 단위 테스트
npm run test:e2e           # e2e 테스트 (실제 DB 필요)
npm run migration:generate # 마이그레이션 생성 (-- src/database/migrations/<Name>)
npm run migration:run      # 마이그레이션 실행
npm run seed               # 기본 admin 계정 시드
```

> **DB 초기화 순서:** `docker compose up -d mysql` → `npm run migration:run` → `npm run seed`.
> 경로 별칭 `@/*` → `src/*` 는 `tsconfig`·Jest·런타임(`tsc-alias`/`tsconfig-paths`) 모두에 설정됩니다.

## Standard Error Response

```json
{
  "statusCode": 400,
  "message": "Validation failed",
  "error": "Bad Request",
  "timestamp": "2026-01-01T00:00:00.000Z",
  "path": "/users"
}
```

## Roadmap

Refresh Token · RBAC · Redis Cache · BullMQ · S3 Upload · OpenTelemetry · GitHub Actions

## License

MIT
