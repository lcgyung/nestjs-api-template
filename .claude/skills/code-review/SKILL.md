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

## 리뷰 출력 형식

- 발견 항목을 심각도(blocker/warning/nit)로 분류.
- 각 항목에 파일·라인·근거·수정 제안 제시.
