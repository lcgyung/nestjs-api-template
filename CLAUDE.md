# CLAUDE.md

이 파일은 이 저장소에서 작업하는 Claude Code에게 가이드를 제공합니다.

> **상태: 스캐폴딩 미완료.** 현재 저장소에는 `README.md`와 `LICENSE`만 존재하며
> 실제 소스 코드(`package.json`, `src/` 등)는 아직 없습니다. 아래 내용은
> `README.md`에 정의된 **의도된 설계**입니다. 코드를 생성할 때 이 규칙을 기준으로
> 삼고, 실제 파일을 추가한 뒤에는 이 문서를 실제 상태에 맞게 갱신하세요.

## 프로젝트 개요

JWT 인증, TypeORM, Swagger, 검증·로깅이 구성된 프로덕션 지향 NestJS 백엔드 템플릿.

## 기술 스택

NestJS · TypeScript · TypeORM · MySQL · JWT · Swagger · class-validator ·
Winston · ESLint · Prettier · Husky

## 예정된 명령어 (스캐폴딩 후 사용)

> 아래 스크립트는 `package.json` 생성 후 동작합니다. 현재는 정의되어 있지 않습니다.

```bash
npm install                # 의존성 설치
cp .env.example .env       # 환경 변수 설정
docker compose up -d mysql # 로컬 MySQL 기동
npm run start:dev          # 개발 서버
npm run test               # 단위 테스트
npm run test:e2e           # e2e 테스트
npm run migration:generate # 마이그레이션 생성
npm run migration:run      # 마이그레이션 실행
```

Swagger 문서: `http://localhost:3000/api-docs`

## 예정된 디렉토리 구조

```text
src
├── common      # filters, interceptors, decorators, guards
├── config      # 환경 변수 검증 및 설정
├── database    # 연결, 마이그레이션
├── modules     # auth, users, health
├── logger
├── app.module.ts
└── main.ts
```

## 환경 변수

부팅 시 환경 변수를 검증하며, `JWT_SECRET`이 비어 있거나 너무 짧으면 실행을 중단합니다.

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

## 아키텍처 규칙 / 컨벤션

- **인증**: JWT 기반, 비밀번호는 bcrypt로 해싱.
- **검증**: 모든 입력은 DTO + class-validator로 검증. 환경 변수도 부팅 시 검증.
- **에러 응답**: Global Exception Filter로 표준 형식 통일.
- **로깅**: Winston 사용.
- **보안**: helmet · CORS · rate limiting 적용.
- **코드 품질**: ESLint + Prettier, Husky pre-commit 훅으로 강제.

### 표준 에러 응답 형식

```json
{
  "statusCode": 400,
  "message": "Validation failed",
  "error": "Bad Request",
  "timestamp": "2026-01-01T00:00:00.000Z",
  "path": "/users"
}
```

## 로드맵

Refresh Token · RBAC · Redis Cache · BullMQ · S3 Upload · OpenTelemetry ·
GitHub Actions
