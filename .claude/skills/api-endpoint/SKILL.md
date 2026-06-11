---
name: api-endpoint
description: >-
  NestJS API 엔드포인트(컨트롤러 라우트·서비스 메서드)를 새로 만들거나 수정할 때의 응답 형태·
  페이지네이션·예외 타입·DTO/직렬화 규약. 목록(list) API, CRUD 라우트, @Get/@Post/@Patch/@Delete
  추가, PaginationQueryDto 사용, "엔드포인트 추가/수정", "응답 형태", "페이지네이션" 작업 시 적용.
---

# API 엔드포인트 작업 절차

**규약 정본은 [`docs/api-conventions.md`](../../../docs/api-conventions.md)** 다 — 작업 전에 먼저 읽고
그대로 적용한다(이 스킬에 규약 본문을 중복하지 않는다). 기준 예시(정답 코드)는
`src/modules/users/` 와 `src/common/dto/`.

## 절차

1. `docs/api-conventions.md` 를 읽는다(응답 형태·페이지네이션·예외 표·쿼리/관계·DTO/직렬화·IDOR).
2. 라우트/서비스를 정본 규약대로 구현한다. 특히:
   - 목록 → `PaginatedResponseDto<T>`, 단건/생성/수정 → 엔티티 직접 반환
   - 생성 201 / 본문 없는 삭제 204 를 `@HttpCode` 로 명시
   - 입력은 DTO + class-validator(수정은 `PartialType`), 비밀번호는 `@MinLength(8)`+`@MaxLength(72)`
   - 본인 리소스 엔드포인트는 서비스 계층 소유권 검증(IDOR)
3. 컨트롤러/DTO/라우트가 바뀌었으면 `pnpm openapi:generate` 로 스펙을 재생성해 함께 커밋한다.

## 마무리 검증

- `pnpm lint` · `pnpm typecheck` · `pnpm test` · `pnpm build`
- 목록은 `GET /...?page=1&limit=10` 으로 `{ items, meta }` 확인
- 신규 모듈 전체를 만드는 경우 `scaffold-module` 스킬을 함께 본다
