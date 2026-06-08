# NestJS API Template

JWT 인증, TypeORM, Swagger, 검증·로깅이 구성된 프로덕션 지향 NestJS 백엔드 템플릿.

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
