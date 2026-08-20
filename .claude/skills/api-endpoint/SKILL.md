---
name: api-endpoint
description: >-
  NestJS API 엔드포인트(컨트롤러 라우트·서비스 메서드)를 새로 만들거나 수정할 때의 응답 형태·
  페이지네이션·예외 타입·DTO/직렬화 규약. 목록(list) API, CRUD 라우트, @Get/@Post/@Patch/@Delete
  추가, PaginationQueryDto 사용, "엔드포인트 추가/수정", "응답 형태", "페이지네이션" 작업 시 적용.
  경계: 기존 모듈에 라우트를 더하거나 고칠 때 — 신규 도메인 모듈 전체 생성은 scaffold-module 을 쓴다.
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

## 테스트 (API 완성의 필수 조건)

엔드포인트를 추가/수정했으면 **서비스 spec · 컨트롤러 spec · 모듈별 e2e** 셋을 모두 갖춰야 완성이다
(정본: `.claude/rules/testing.md` "API 완성의 정의"). 새 라우트는 컨트롤러 spec 에 위임 검증을,
`test/<feature>.e2e-spec.ts` 에 인증/인가(401·403)·검증(400)·해피패스를 추가하고 **실제로 실행**한다.

## 마무리 검증

- `pnpm lint` · `pnpm typecheck` · `pnpm test`(단위) · `pnpm test:e2e`(e2e 실제 실행) · `pnpm build`
- 목록은 `GET /...?page=1&limit=10` 으로 `{ items, meta }` 확인
- 신규 모듈 전체를 만드는 경우 `scaffold-module` 스킬을 함께 본다
