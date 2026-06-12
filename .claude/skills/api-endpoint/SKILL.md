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
2. 라우트/서비스를 정본 규약(§1 응답 형태 · §2 페이지네이션 · §3 예외 · §5 DTO/직렬화 ·
   §6 소유권/IDOR)대로 그대로 구현한다 — 요지를 여기 중복하지 않는다.
3. 컨트롤러/DTO/라우트가 바뀌었으면 `pnpm openapi:generate` 로 스펙을 재생성해 함께 커밋한다.

## 마무리 검증

- `pnpm lint` · `pnpm typecheck` · `pnpm test` · `pnpm build`
- 목록은 `GET /...?page=1&limit=10` 으로 `{ items, meta }` 확인
- 신규 모듈 전체를 만드는 경우 `scaffold-module` 스킬을 함께 본다
