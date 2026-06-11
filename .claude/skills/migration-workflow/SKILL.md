---
name: migration-workflow
description: >-
  TypeORM 마이그레이션 생성→검토→적용 표준 절차(PostgreSQL). 엔티티 변경 후 스키마 반영,
  "마이그레이션 만들어/돌려/되돌려", migration:generate/run/revert, 시드 갱신 작업 시 적용.
---

# 마이그레이션 워크플로 (PostgreSQL)

규칙 정본은 `.claude/rules/migrations.md`(적용본 불변·synchronize 금지·down 가역성).
이 스킬은 그 규칙을 지키는 **실행 절차**다.

## 절차

1. **DB 기동 확인** — `docker compose up -d postgres` (healthcheck 통과까지 수 초).
2. **엔티티 수정** — `src/**/*.entity.ts`. 민감 필드 `@Exclude()` 잊지 말 것.
3. **생성** — `pnpm migration:generate src/database/migrations/<Name>` (PascalCase 이름).
   - 생성 직후 파일을 프로젝트 컨벤션에 맞게 다듬는다(`import type`, prettier — 훅이 자동 적용).
4. **생성 SQL 검토** — 적용 전에 반드시. 체크리스트:
   - 파괴적 변경(`DROP`, 컬럼 타입 축소, default 없는 `NOT NULL`)이 의도된 것인가
   - **down 이 up 의 완전한 역순인가** — PG 는 enum 이 별도 TYPE 이므로 down 에서
     테이블과 함께 `DROP TYPE` 까지 제거해야 재적용 가능
   - enum 값 추가라면 `ALTER TYPE ... ADD VALUE` 사용(트랜잭션 제약 주의)
   - 대형 테이블 `ALTER` 의 락 시간 고려
   - 깊은 검토가 필요하면 **migration-reviewer 서브에이전트에 위임**한다
5. **적용** — `pnpm migration:run`. 롤백 검증까지 하려면 `migration:revert` 후 재적용.
6. **시드 영향 확인** — 스키마 변경이 `seedAdmin()`(`src/database/seeds/seed.ts`)에 영향을
   주면 함께 수정. 시드는 멱등 유지(CLI 와 e2e globalSetup 이 공유).
7. **드리프트 확인** — `pnpm migration:generate src/database/migrations/Check` 를 다시 돌려
   "No changes in database schema" 가 나오는지 확인(나온 파일은 생성 안 됨; 변경이 생성되면
   엔티티-마이그레이션 불일치). e2e(`pnpm test:e2e`)가 깨끗한 DB 에서 마이그레이션을 검증한다.

## 금지

- **적용된(커밋된) 마이그레이션 수정/삭제** — 변경은 항상 새 마이그레이션 추가로.
- `synchronize: true`, raw SQL 로 수동 스키마 변경.
