# NestJS API Template

JWT 인증, TypeORM, Swagger, 검증·로깅이 구성된 프로덕션 지향 NestJS 백엔드 템플릿.

> **현재 상태:** 스캐폴딩 미완료. 이 저장소에는 아직 `README.md`·`CLAUDE.md`·`LICENSE`만 있고
> 실제 소스 코드(`package.json`, `src/`)는 없습니다. 아래는 **의도된 설계**이며, 코드 생성 시
> 이 문서를 기준으로 삼습니다.

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
PORT=3000

DB_HOST=localhost
DB_PORT=3306
DB_NAME=app
DB_USERNAME=root
DB_PASSWORD=password

JWT_SECRET=             # openssl rand -base64 32
JWT_EXPIRES_IN=1d
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
├── common      # filters, interceptors, decorators, guards
├── config      # env 검증 및 설정
├── database    # 연결, 마이그레이션
├── modules     # auth, users, health
├── logger
├── app.module.ts
└── main.ts
```

## Scripts

```bash
npm run start:dev          # 개발 서버
npm run test               # 단위 테스트
npm run test:e2e           # e2e 테스트
npm run migration:generate # 마이그레이션 생성
npm run migration:run      # 마이그레이션 실행
```

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
