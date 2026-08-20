---
paths:
  - 'src/database/**'
---

# 마이그레이션 / 데이터베이스 규칙 (PostgreSQL)

- **적용된 마이그레이션은 불변** — 수정·삭제 금지, 변경은 항상 새 마이그레이션 파일 추가로.
  (`git diff` 로 기존 마이그레이션 파일이 변경되면 리뷰 blocker.)
- **`synchronize: true` 금지** — 스키마는 마이그레이션으로만 변경한다. 앱과 분리된
  standalone `DataSource`(`src/database/data-source.ts`)가 CLI(generate/run/seed)의 기준.
- **절차**: 엔티티 수정 → `pnpm migration:generate src/database/migrations/<Name>` → 생성 SQL 검토
  → `pnpm migration:run`. 상세 절차는 `migration-workflow` 스킬.
- **down 은 가역적이어야 한다** — up 이 만든 모든 것(테이블·인덱스·**enum TYPE**)을 역순으로 제거.

## PostgreSQL 특이사항

- **enum 컬럼은 별도 TYPE 으로 생성**된다(`users_role_enum` 등).
  - 값 추가는 `ALTER TYPE "..._enum" ADD VALUE '...'` (트랜잭션 제약 주의).
  - down 에서 테이블만 DROP 하고 TYPE 을 남기면 재적용이 실패한다 — `DROP TYPE` 까지 포함.
- **`@UpdateDateColumn` 은 앱 레벨 동작** — MySQL 의 `ON UPDATE CURRENT_TIMESTAMP` 대응 DDL 이
  없어 TypeORM 이 `save()` 시 갱신한다. **raw SQL `UPDATE` 로는 `updatedAt` 이 갱신되지 않는다**
  (raw SQL 금지 규칙이 이를 보완 — ORM 파라미터 바인딩만 사용).
- 시드는 `src/database/seeds/seed.ts` 의 `seedAdmin()` — CLI 와 e2e globalSetup 이 공유하므로
  시드 로직 변경 시 양쪽 영향을 함께 본다. 시드는 **멱등**해야 한다(이미 있으면 skip).

## 데이터 손실 방지 (버전 업 시 데이터 유실 가드)

"마이그레이션 버전이 올라가면 테이블 데이터가 지워지는" 사고를 막기 위한 규칙이다.
(현재 코드는 `synchronize: false`·`migrationsRun: false`·단일 additive 마이그레이션이라 안전하다.)

- **forward `migration:run` 의 `up()` 은 데이터를 지우면 안 된다.** `pnpm check:migrations`
  (`scripts/check-migration-safety.ts`)가 up() 의 파괴적 DDL(DROP TABLE/COLUMN, `ALTER COLUMN ... TYPE`,
  DROP TYPE, TRUNCATE, DELETE FROM, enum temp-swap)을 정적으로 차단한다(CI `lint-build-test`·Stop 게이트).
  **의도된 파괴적 변경**이면 해당 마이그레이션 파일에 `// migration-safety-ack: <사유>` 주석으로
  명시적 승인을 남긴다(무심코 적용을 막고 검토를 강제).
- **enum 값 제거·이름 변경·타입명 변경은 데이터 손실 위험** — `migration:generate` 가 DROP/CREATE TYPE +
  컬럼 재생성(temp-type swap)을 emit 해 해당 컬럼 데이터가 날아갈 수 있다. **값 추가
  (`ALTER TYPE ... ADD VALUE`)만 안전**하다. `enumName` 을 TypeORM derived 명과 똑같이 명시하면
  false-drift(매 generate 가 no-op 재생성)가 나므로, 명시할 때는 derived 명과 다른 이름을 쓴다.
- **`migration:revert` 는 데이터 파괴 행위** — down() 이 테이블을 DROP 한다. 운영 DB 에서 되돌리기는
  데이터 백업 후에만. (revert 자체가 forward run 과 달리 데이터를 지운다는 점을 인지할 것.)
