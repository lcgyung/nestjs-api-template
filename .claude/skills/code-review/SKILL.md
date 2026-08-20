---
name: code-review
description: NestJS 코드 변경에 대한 백엔드 리뷰 기준. 컨트롤러/서비스 분리, DTO 검증, DI, 예외 처리, 타입 안전성을 점검할 때 사용.
---

# NestJS 코드 리뷰 기준

## 아키텍처

- 컨트롤러는 라우팅/요청-응답 변환만. 비즈니스 로직은 서비스로.
- 모듈 경계가 명확한가. 순환 의존이 없는가.

## 검증 & 계약

- 입력 DTO에 class-validator 데코레이터가 있는가.
- 응답 직렬화(ClassSerializerInterceptor/DTO)로 내부 엔티티 노출을 막는가.

## 타입 안전성

- `any` / 비검증 타입 단언이 없는가.
- nullable 처리가 명시적인가.

## 안정성

- 예외는 도메인에 맞는 HttpException/필터로 변환되는가.
- 환경변수는 ConfigService로 접근하는가(직접 process.env 금지).
- DB 트랜잭션/리소스 정리 누락이 없는가.

## 프로젝트 고유 규약 점검 (정본: docs/api-conventions.md)

tsc/lint 를 통과해도 어긋날 수 있는 의미적 규약은 정본 `docs/api-conventions.md` **§1~§6 을
먼저 읽고** 각 절(응답 형태·페이지네이션·예외 타입·쿼리/관계·DTO/직렬화·인가/소유권) 위반을
점검한다. 정본에 없는 추가 점검 항목:

- **신규 모듈** → controller/service/module/spec/dto/entity 표준 파일 셋을 갖췄는가(`scaffold-module` 기준).
- **테스트 3종(blocker)** → 컨트롤러를 가진 모듈/엔드포인트는 **service spec + controller spec +
  모듈별 e2e(`test/<feature>.e2e-spec.ts`)** 가 모두 있어야 한다(정본: `.claude/rules/testing.md`
  "API 완성의 정의"). service spec 만 있고 controller spec·e2e 가 없으면 **미완성(blocker)** 으로 본다.
- **네이밍 품질** → 네이밍 _형식_(camel/Pascal/UPPER)은 `naming-convention` 룰이 강제하므로, 리뷰는
  *의미*에 집중한다(이름이 역할을 정확히 드러내는가, 약어·오해 소지 없는가).

## 리뷰 출력 형식

- 발견 항목을 심각도(blocker/warning/nit)로 분류.
- 각 항목에 파일·라인·근거·수정 제안 제시.
